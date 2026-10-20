import SwiftUI
import StoreKit
import Charts

/// Ironbook Pro: one non-consumable. Logging is free forever; Pro is the analysis layer.
/// Beside it, 99-cent extras: three consumables that get used up (Next Block, PR Posters, Week Shield)
/// and one-time cosmetics (four tape colours with matching icons, PR Fireworks).
///
/// People who paid for Ironbook before it went free keep everything. AppTransaction's
/// originalPurchaseDate says when this Apple ID first got the app; anyone before the
/// moment the price dropped paid for it. Only trusted in production: sandbox and Xcode
/// report made-up values, and App Review must see the real paywall.
@MainActor
@Observable
final class Pro {
    static let productID = "com.mattbusel.ironbook.pro"
    static let blockID = "com.mattbusel.ironbook.block"
    static let posterID = "com.mattbusel.ironbook.posters"
    static let shieldID = "com.mattbusel.ironbook.shield"
    static let fireworksID = "com.mattbusel.ironbook.fireworks"
    static let shieldPackID = "com.mattbusel.ironbook.shield3"
    /// Ironbook Plus, the auto-renewable group: everything in Pro plus monthly refills, insights, every tape and iCloud backup.
    static let plusMonthlyID = "com.mattbusel.ironbook.plus.monthly"
    static let plusYearlyID = "com.mattbusel.ironbook.plus.yearly"
    static let plusIDs: [String] = [plusYearlyID, plusMonthlyID]
    static let plusGroupID = "22494975"
    static let fallbackPrice: [String: String] = [plusMonthlyID: "$2.99", plusYearlyID: "$14.99", shieldPackID: "$1.99", productID: "$4.99"]
    static func themeID(_ id: String) -> String { "com.mattbusel.ironbook.theme." + id }
    static var allIDs: [String] {
        [productID, blockID, posterID, shieldID, shieldPackID, fireworksID] + TapePalette.all.filter { $0.id != "red" }.map { themeID($0.id) }
    }
    static let consumables: Set<String> = [blockID, posterID, shieldID, shieldPackID]
    /// Everything the store sells, subscriptions included.
    static var storeIDs: [String] { allIDs + plusIDs }
    /// The price went to Free at 2026-09-25 15:18 UTC. Storefronts can take hours to catch up,
    /// so anyone who got the app before 18:18 UTC is treated as a buyer.
    static let wentFree = Date(timeIntervalSince1970: 1_790_360_309)

    enum Reason: String, Identifiable { case progress, records, plates, programs, settings, history, health, export, widget, plus, insights, backup, medal; var id: String { rawValue } }

    private(set) var unlocked: Bool
    /// An active Ironbook Plus subscription.
    private(set) var plus = false
    private(set) var plusUntil: Date? = nil
    private(set) var plusProductID: String? = nil
    /// Whether this Apple ID can still take the yearly plan's free week.
    private(set) var trialEligible = true
    /// Pro features: the one-time unlock, or Plus.
    var full: Bool { unlocked || plus }
    private(set) var grandfathered = false
    private(set) var product: Product?
    private(set) var products: [String: Product] = [:]
    /// Non-consumable extras owned (themes, fireworks).
    private(set) var owned: Set<String> = []
    var busy = false
    var busyID: String? = nil
    var message: String?
    var paywall: Reason? = nil
    /// Called once per consumable transaction, with its product id, so the store can bank the credit.
    var onCredit: ((String) -> Void)?

    private var updates: Task<Void, Never>?
    private let key = "ironbook.pro.unlocked"
    private let ownedKey = "ironbook.owned"
    private let plusKey = "ironbook.plus.until"
    private var intents: Task<Void, Never>?
    private let forced: Bool

    /// `forced` is for screenshots and the review recording, which must not touch StoreKit.
    init(forced: Bool? = nil, extras: Bool = true, plus: Bool = false) {
        self.forced = forced != nil
        if let forced {
            unlocked = forced
            self.plus = plus
            if plus { plusUntil = Calendar.current.date(byAdding: .day, value: 23, to: .now); plusProductID = Pro.plusYearlyID }
            owned = extras && forced ? Set(Pro.allIDs).subtracting(Pro.consumables).subtracting([Pro.productID]) : []
            return
        }
        if let until = UserDefaults.standard.object(forKey: plusKey) as? Date, until > .now { self.plus = true; plusUntil = until }
        unlocked = UserDefaults.standard.bool(forKey: key)
        owned = Set(UserDefaults.standard.stringArray(forKey: ownedKey) ?? [])
        updates = Task { [weak self] in
            for await result in Transaction.updates { await self?.apply(result) }
        }
        // A promoted purchase tapped on the App Store product page lands here.
        intents = Task { [weak self] in
            for await intent in PurchaseIntent.intents { _ = await self?.buy(intent.product.id) }
        }
        Task { await refresh() }
    }

    var price: String { product?.displayPrice ?? "$4.99" }
    func price(_ id: String) -> String { products[id]?.displayPrice ?? Pro.fallbackPrice[id] ?? "$0.99" }
    func ownsTheme(_ id: String) -> Bool { id == "red" || plus || owned.contains(Pro.themeID(id)) }
    var ownsFireworks: Bool { plus || owned.contains(Pro.fireworksID) }

    /// Pro features: the paywall only for someone with neither Pro nor Plus.
    func ask(_ why: Reason) { if !full { paywall = why } }
    /// Plus-only features.
    func askPlus(_ why: Reason) { if !plus { paywall = why } }

    func loadProducts() async {
        guard !forced, products.count < Pro.storeIDs.count else { return }
        if let ps = try? await Product.products(for: Pro.storeIDs) { for p in ps { products[p.id] = p } }
        if product == nil { product = products[Pro.productID] }
        if let sub = products[Pro.plusYearlyID]?.subscription { trialEligible = await sub.isEligibleForIntroOffer }
    }

    /// Plus is on while any transaction in the group is unexpired and not revoked.
    func recomputePlus() async {
        guard !forced else { return }
        var until: Date? = nil
        var pid: String? = nil
        for await r in Transaction.currentEntitlements {
            guard case .verified(let t) = r, Pro.plusIDs.contains(t.productID), t.revocationDate == nil else { continue }
            let end = t.expirationDate ?? .distantFuture
            if end > .now, end > (until ?? .distantPast) { until = end; pid = t.productID }
        }
        plusUntil = until
        plusProductID = pid
        let on = until != nil
        if on != plus { withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { plus = on } }
        if on { paywall = nil; UserDefaults.standard.set(until, forKey: plusKey) } else { UserDefaults.standard.removeObject(forKey: plusKey) }
    }

    func refresh() async {
        guard !forced else { return }
        await loadProducts()
        if product == nil { product = try? await Product.products(for: [Pro.productID]).first }
        var extras: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID != Pro.productID, t.revocationDate == nil, !Pro.consumables.contains(t.productID), !Pro.plusIDs.contains(t.productID) { extras.insert(t.productID) }
            await apply(result)
        }
        owned = extras
        UserDefaults.standard.set(Array(extras), forKey: ownedKey)
        await recomputePlus()
        if !ownsTheme(Shared.theme) { TapePalette.apply("red") }
        // A consumable bought on a flaky connection may never have been finished.
        for await result in Transaction.unfinished { await apply(result) }
        if case .verified(let app)? = try? await AppTransaction.shared,
           app.environment == .production, app.originalPurchaseDate < Pro.wentFree {
            grandfathered = true
            grant()
        }
    }

    func buy() async { _ = await buy(Pro.productID) }

    /// True when the thing bought is in hand (or, for a consumable, banked).
    @discardableResult
    func buy(_ id: String) async -> Bool {
        if forced {
            if Pro.consumables.contains(id) { onCredit?(id) } else if id == Pro.productID { grant() } else if Pro.plusIDs.contains(id) { plus = true } else { owned.insert(id) }
            return true
        }
        guard !busy else { return false }
        busy = true; busyID = id; message = nil
        defer { busy = false; busyID = nil }
        await loadProducts()
        guard let product = products[id] ?? (id == Pro.productID ? product : nil) else {
            message = "The App Store did not answer. Check your connection and try again."
            return false
        }
        do {
            switch try await product.purchase() {
            case .success(let result):
                await apply(result)
                if id == Pro.productID {
                    if !unlocked { message = "Apple could not confirm the purchase. Try Restore in a minute." }
                    return unlocked
                }
                if Pro.plusIDs.contains(id) {
                    if !plus { message = "Apple could not confirm the subscription. Try Restore in a minute." }
                    else { UINotificationFeedbackGenerator().notificationOccurred(.success) }
                    return plus
                }
                if case .verified = result { UINotificationFeedbackGenerator().notificationOccurred(.success); return true }
                message = "Apple could not confirm the purchase. You were not charged twice; try again in a minute."
            case .pending:
                message = "Waiting for approval. It arrives by itself once it is approved."
            case .userCancelled:
                break
            @unknown default:
                message = "Something unexpected happened. You were not charged."
            }
        } catch {
            message = "The purchase did not go through: \(error.localizedDescription)"
        }
        return false
    }

    func restore() async {
        guard !forced, !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        do { try await AppStore.sync() } catch {
            if let e = error as? StoreKitError, case .userCancelled = e { return }
            message = "Could not reach the App Store. Check your connection and try again."
            return
        }
        await refresh()
        message = plus ? "Ironbook Plus is active. Welcome back." : unlocked ? "Pro is unlocked. Welcome back." : owned.isEmpty ? "No Pro purchase or Plus subscription found on this Apple ID." : "Your extras are restored."
    }

    private func apply(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let t) = result else { return }
        if Pro.plusIDs.contains(t.productID) {
            await recomputePlus()
        } else if t.productID == Pro.productID {
            if t.revocationDate == nil { grant() } else if !grandfathered { revoke() }
        } else if Pro.consumables.contains(t.productID) {
            credit(t)
        } else if Pro.allIDs.contains(t.productID) {
            if t.revocationDate == nil { owned.insert(t.productID) } else { owned.remove(t.productID) }
            UserDefaults.standard.set(Array(owned), forKey: ownedKey)
        }
        await t.finish()
    }

    /// Bank a consumable once per transaction, however many times StoreKit reports it.
    private func credit(_ t: StoreKit.Transaction) {
        guard t.revocationDate == nil else { return }
        let d = UserDefaults.standard
        var seen = Set(d.stringArray(forKey: "ironbook.credited") ?? [])
        guard !seen.contains(String(t.id)) else { return }
        seen.insert(String(t.id))
        d.set(Array(seen), forKey: "ironbook.credited")
        onCredit?(t.productID)
    }

    private func grant() {
        guard !unlocked else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { unlocked = true }
        paywall = nil
        UserDefaults.standard.set(true, forKey: key)
    }

    private func revoke() {
        unlocked = false
        UserDefaults.standard.set(false, forKey: key)
    }
}

extension Pro {
    static var samplePoints: [ProgressPoint] {
        let vals: [Double] = [92, 95, 94, 98, 101, 100, 104, 107, 106, 110]
        var best = 0.0
        return vals.enumerated().map { i, v in
            defer { best = max(best, v) }
            return ProgressPoint(date: Date.now.addingTimeInterval(Double(i - vals.count) * 7 * 86400), e1rm: v, top: v * 0.85, isPR: v > best)
        }
    }
}

// MARK: - Program library (Pro)

struct Program: Identifiable {
    var id: String { name }
    let name: String
    let blurb: String
    let templates: [Template]
}

enum Programs {
    static func t(_ name: String, _ ex: [(String, Int, Int)]) -> Template {
        Template(name: name, exercises: ex.map { TemplateExercise(name: $0.0, sets: $0.1, reps: $0.2) })
    }
    static let all: [Program] = [
        Program(name: "5×5 strength", blurb: "Two alternating days, three times a week. Add weight every session.", templates: [
            t("5×5 A", [("Squat", 5, 5), ("Bench press", 5, 5), ("Barbell row", 5, 5)]),
            t("5×5 B", [("Squat", 5, 5), ("Overhead press", 5, 5), ("Deadlift", 1, 5)]),
        ]),
        Program(name: "Push pull legs", blurb: "Six days, or three if life happens. Volume for size.", templates: [
            t("Push", [("Bench press", 4, 6), ("Overhead press", 3, 8), ("Incline dumbbell press", 3, 10), ("Lateral raise", 4, 15), ("Triceps pushdown", 3, 12)]),
            t("Pull", [("Deadlift", 3, 5), ("Pull-up", 4, 8), ("Barbell row", 3, 8), ("Face pull", 3, 15), ("Dumbbell curl", 3, 12)]),
            t("Legs", [("Squat", 4, 6), ("Romanian deadlift", 3, 8), ("Leg press", 3, 12), ("Leg curl", 3, 12), ("Calf raise", 4, 15)]),
        ]),
        Program(name: "Upper lower", blurb: "Four days. Heavy and light versions of each.", templates: [
            t("Upper heavy", [("Bench press", 4, 5), ("Barbell row", 4, 5), ("Overhead press", 3, 6), ("Pull-up", 3, 6)]),
            t("Lower heavy", [("Squat", 4, 5), ("Deadlift", 3, 4), ("Leg press", 3, 8), ("Calf raise", 4, 10)]),
            t("Upper light", [("Incline dumbbell press", 3, 10), ("Lat pulldown", 3, 12), ("Lateral raise", 3, 15), ("Dumbbell curl", 3, 12), ("Triceps pushdown", 3, 12)]),
            t("Lower light", [("Front squat", 3, 8), ("Romanian deadlift", 3, 10), ("Walking lunge", 3, 12), ("Leg curl", 3, 12)]),
        ]),
        Program(name: "Three-day full body", blurb: "Everything, three times a week. The best start there is.", templates: [
            t("Full body A", [("Squat", 3, 5), ("Bench press", 3, 5), ("Barbell row", 3, 8), ("Plank", 3, 45)]),
            t("Full body B", [("Deadlift", 3, 5), ("Overhead press", 3, 6), ("Pull-up", 3, 8), ("Dumbbell curl", 2, 12)]),
            t("Full body C", [("Front squat", 3, 6), ("Incline dumbbell press", 3, 8), ("Lat pulldown", 3, 10), ("Hip thrust", 3, 10)]),
        ]),
        Program(name: "Dumbbells only", blurb: "For a home gym or a crowded one.", templates: [
            t("DB upper", [("Dumbbell bench press", 4, 10), ("One-arm row", 4, 10), ("Dumbbell shoulder press", 3, 10), ("Dumbbell curl", 3, 12)]),
            t("DB lower", [("Goblet squat", 4, 12), ("Dumbbell RDL", 4, 10), ("Split squat", 3, 10), ("Calf raise", 3, 15)]),
        ]),
    ]
}

struct ProgramLibrary: View {
    @Environment(Store.self) private var store
    @Environment(Pro.self) private var pro
    @Environment(\.dismiss) private var dismiss
    @State private var added: Set<String> = []

    var body: some View {
        NavigationStack {
            ZStack {
                BoardBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Tape(text: "Program library")
                        Text("Pick one, it lands in your templates.").font(.slab(28)).italic().foregroundStyle(Chalk.white).fixedSize(horizontal: false, vertical: true)
                        ForEach(Programs.all) { p in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(p.name).font(.slab(21)).italic().foregroundStyle(Chalk.white)
                                    Spacer()
                                    Text("\(p.templates.count) days").font(.chalk(11, .black)).tracking(1).foregroundStyle(Chalk.faint)
                                }
                                Text(p.blurb).font(.chalk(13, .medium)).foregroundStyle(Chalk.dust)
                                Text(p.templates.map { $0.name }.joined(separator: " · ")).font(.mono(11)).foregroundStyle(Chalk.faint)
                                if added.contains(p.name) {
                                    Label("Added to your templates", systemImage: "checkmark").font(.chalk(12, .black)).foregroundStyle(Chalk.green)
                                } else {
                                    TapeButton(title: pro.full ? "Add to my templates" : "Unlock with Pro or Plus", icon: pro.full ? "plus" : "lock.fill", fill: pro.full ? Chalk.red : Chalk.gold) {
                                        guard pro.full else { pro.ask(.programs); return }
                                        for t in p.templates { var c = t; c.id = UUID(); store.templates.append(c) }
                                        store.save()
                                        withAnimation(.spring) { _ = added.insert(p.name) }
                                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                                    }
                                }
                            }
                            .slate()
                        }
                    }
                    .padding(18)
                }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() }.foregroundStyle(Chalk.dust) } }
        }
    }
}
