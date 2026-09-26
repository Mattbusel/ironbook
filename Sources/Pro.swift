import SwiftUI
import StoreKit
import Charts

/// Ironbook Pro: one non-consumable. Logging is free forever; Pro is the analysis layer.
///
/// People who paid for Ironbook before it went free keep everything. AppTransaction's
/// originalPurchaseDate says when this Apple ID first got the app; anyone before the
/// moment the price dropped paid for it. Only trusted in production: sandbox and Xcode
/// report made-up values, and App Review must see the real paywall.
@MainActor
@Observable
final class Pro {
    static let productID = "com.mattbusel.ironbook.pro"
    /// The price went to Free at 2026-09-25 15:18 UTC. Storefronts can take hours to catch up,
    /// so anyone who got the app before 18:18 UTC is treated as a buyer.
    static let wentFree = Date(timeIntervalSince1970: 1_790_360_309)

    enum Reason: String, Identifiable { case progress, records, plates, programs, settings; var id: String { rawValue } }

    private(set) var unlocked: Bool
    private(set) var grandfathered = false
    private(set) var product: Product?
    var busy = false
    var message: String?
    var paywall: Reason? = nil

    private var updates: Task<Void, Never>?
    private let key = "ironbook.pro.unlocked"
    private let forced: Bool

    /// `forced` is for screenshots and the review recording, which must not touch StoreKit.
    init(forced: Bool? = nil) {
        self.forced = forced != nil
        if let forced { unlocked = forced; return }
        unlocked = UserDefaults.standard.bool(forKey: key)
        updates = Task { [weak self] in
            for await result in Transaction.updates { await self?.apply(result) }
        }
        Task { await refresh() }
    }

    var price: String { product?.displayPrice ?? "$9.99" }

    func ask(_ why: Reason) { if !unlocked { paywall = why } }

    func refresh() async {
        guard !forced else { return }
        if product == nil { product = try? await Product.products(for: [Pro.productID]).first }
        for await result in Transaction.currentEntitlements { await apply(result) }
        if case .verified(let app)? = try? await AppTransaction.shared,
           app.environment == .production, app.originalPurchaseDate < Pro.wentFree {
            grandfathered = true
            grant()
        }
    }

    func buy() async {
        guard !forced, !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        if product == nil { product = try? await Product.products(for: [Pro.productID]).first }
        guard let product else {
            message = "The App Store did not answer. Check your connection and try again."
            return
        }
        do {
            switch try await product.purchase() {
            case .success(let result):
                await apply(result)
                if !unlocked { message = "Apple could not confirm the purchase. Try Restore in a minute." }
            case .pending:
                message = "Waiting for approval. Pro unlocks by itself once it is approved."
            case .userCancelled:
                break
            @unknown default:
                message = "Something unexpected happened. You were not charged."
            }
        } catch {
            message = "The purchase did not go through: \(error.localizedDescription)"
        }
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
        message = unlocked ? "Pro is unlocked. Welcome back." : "No Pro purchase found on this Apple ID."
    }

    private func apply(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let t) = result, t.productID == Pro.productID else { return }
        if t.revocationDate == nil { grant() } else if !grandfathered { revoke() }
        await t.finish()
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

// MARK: - Paywall

struct PaywallView: View {
    @Environment(Pro.self) private var pro
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let reason: Pro.Reason
    @State private var shown = false

    var body: some View {
        ZStack {
            BoardBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Tape(text: "Ironbook Pro", tilt: -2)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 14, weight: .black)).foregroundStyle(Chalk.dust)
                                .frame(width: 38, height: 38).overlay(Circle().strokeBorder(Chalk.line))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(headline).font(.slab(40)).italic().foregroundStyle(Chalk.white).fixedSize(horizontal: false, vertical: true)
                        Text("Logging stays free forever. Pro reads the book back to you.")
                            .font(.chalk(15, .medium)).foregroundStyle(Chalk.dust)
                    }
                    teaser
                    VStack(alignment: .leading, spacing: 14) {
                        feature("chart.line.uptrend.xyaxis", "Progress charts", "Estimated one-rep max per lift, PR sessions in gold, weekly volume.")
                        feature("trophy.fill", "Records wall", "Every lift ranked: est. 1RM, best set, heaviest set.")
                        feature("circle.grid.cross.fill", "Plate maths", "Type the load, get the plates per side for any bar.")
                        feature("list.bullet.rectangle.portrait.fill", "Program library", "5×5, push pull legs, upper lower and more, ready to start.")
                    }
                    .slate()
                    priceBlock
                    if let m = pro.message {
                        Text(m).font(.chalk(13, .semibold)).foregroundStyle(Chalk.gold).frame(maxWidth: .infinity, alignment: .center).multilineTextAlignment(.center)
                    }
                    TapeButton(title: pro.busy ? "One moment" : "Unlock Pro for \(pro.price)", icon: "lock.open.fill") {
                        Task { await pro.buy() }
                    }
                    .disabled(pro.busy)
                    HStack(spacing: 10) {
                        GhostButton(title: "Restore purchase", icon: "arrow.clockwise") { Task { await pro.restore() } }
                        Spacer()
                        GhostButton(title: "Not now") { dismiss() }
                    }
                    Text("One payment, yours for good. No subscription. Family Sharing works. Everything you have logged stays yours, Pro or not.")
                        .font(.chalk(11.5, .medium)).foregroundStyle(Chalk.faint).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 40)
            }
        }
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.15)) { shown = true } }
        .onChange(of: pro.unlocked) { _, now in if now { dismiss() } }
    }

    var headline: String {
        switch reason {
        case .records: return "Your wall of fame is waiting."
        case .plates: return "Stop doing plate maths in your head."
        case .programs: return "Proven programs, one tap away."
        default: return "See the line go up."
        }
    }

    /// The user's own best lift, drawn and then taped over. Sample data if the book is empty.
    var teaser: some View {
        let name = store.exerciseNames.first { store.progress($0).count >= 2 }
        let pts = name.map { store.progress($0) } ?? Pro.samplePoints
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Eyebrow(name.map { "\($0), est. 1RM" } ?? "What it looks like")
                Spacer()
                if let last = pts.last { Text(fmtWeight(last.e1rm.rounded()) + " " + store.unit).font(.digits(15, .black)).foregroundStyle(Chalk.red) }
            }
            Chart(pts) { p in
                AreaMark(x: .value("Date", p.date), y: .value("1RM", p.e1rm)).foregroundStyle(LinearGradient(colors: [Chalk.red.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom)).interpolationMethod(.monotone)
                LineMark(x: .value("Date", p.date), y: .value("1RM", p.e1rm)).foregroundStyle(Chalk.red).lineStyle(StrokeStyle(lineWidth: 2.5)).interpolationMethod(.monotone)
                PointMark(x: .value("Date", p.date), y: .value("1RM", p.e1rm)).foregroundStyle(p.isPR ? Chalk.gold : Chalk.red).symbolSize(p.isPR ? 60 : 24)
            }
            .chartYScale(domain: (pts.map { $0.e1rm }.min() ?? 0) * 0.92...(pts.map { $0.e1rm }.max() ?? 1) * 1.05)
            .chartXAxis(.hidden).chartYAxis(.hidden)
            .frame(height: 130)
            .blur(radius: 3.5)
            .overlay(alignment: .center) {
                ZStack {
                    Star(points: 14, inner: 0.78).fill(Chalk.gold).frame(width: 86, height: 86)
                        .rotationEffect(.degrees(shown ? 0 : -40))
                    VStack(spacing: 0) {
                        Image(systemName: "lock.fill").font(.system(size: 16, weight: .black))
                        Text("PRO").font(.chalk(12, .black)).tracking(1.5)
                    }
                    .foregroundStyle(Chalk.board)
                }
                .scaleEffect(shown ? 1 : 0.3)
                .shadow(color: Chalk.gold.opacity(0.4), radius: 18)
            }
        }
        .slate()
    }

    var priceBlock: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(pro.price).font(.digits(38, .black)).foregroundStyle(Chalk.white)
                Text("ONCE. NOT A MONTH.").font(.chalk(11, .black)).tracking(1.8).foregroundStyle(Chalk.gold)
            }
            Spacer()
            Text("No\nsubscription").font(.chalk(12, .black)).multilineTextAlignment(.trailing).foregroundStyle(Chalk.dust)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Chalk.faint, style: StrokeStyle(lineWidth: 1.2, dash: [4, 3])))
                .rotationEffect(.degrees(3))
        }
        .slate()
    }

    func feature(_ icon: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.system(size: 16, weight: .black)).foregroundStyle(Chalk.gold)
                .frame(width: 36, height: 36).background(Circle().fill(Chalk.board)).overlay(Circle().strokeBorder(Chalk.line))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.slab(18)).italic().foregroundStyle(Chalk.white)
                Text(body).font(.chalk(13, .medium)).foregroundStyle(Chalk.dust).fixedSize(horizontal: false, vertical: true)
            }
        }
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

// MARK: - Locked tabs

/// A Pro tab for a free user: the real page drawn from their own data, frosted, with a way in.
struct LockedPage<Content: View>: View {
    @Environment(Pro.self) private var pro
    let reason: Pro.Reason
    let title: String
    let pitch: String
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            content.blur(radius: 9).allowsHitTesting(false).accessibilityHidden(true)
            LinearGradient(colors: [Chalk.board.opacity(0.15), Chalk.board.opacity(0.85)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 18) {
                ZStack {
                    Star(points: 14, inner: 0.78).fill(Chalk.gold).frame(width: 110, height: 110)
                    Image(systemName: "lock.fill").font(.system(size: 30, weight: .black)).foregroundStyle(Chalk.board)
                }
                .shadow(color: Chalk.gold.opacity(0.35), radius: 24)
                Tape(text: "Pro", tilt: 2)
                Text(title).font(.slab(32)).italic().foregroundStyle(Chalk.white).multilineTextAlignment(.center)
                Text(pitch).font(.chalk(15, .medium)).foregroundStyle(Chalk.dust).multilineTextAlignment(.center).padding(.horizontal, 12)
                TapeButton(title: "See Ironbook Pro", icon: "star.fill", fill: Chalk.gold) { pro.ask(reason) }
                    .padding(.horizontal, 30)
                Text("\(pro.price) once. Your log stays free.").font(.chalk(12, .bold)).foregroundStyle(Chalk.faint)
            }
            .padding(.horizontal, 24).padding(.bottom, 90)
        }
    }
}

/// The Pro status card on the Train tab, with Restore always in reach.
struct ProCard: View {
    @Environment(Pro.self) private var pro
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Star(points: 12, inner: 0.74).fill(pro.unlocked ? Chalk.gold : Chalk.slateHi)
                Image(systemName: pro.unlocked ? "checkmark" : "lock.fill").font(.system(size: 13, weight: .black)).foregroundStyle(pro.unlocked ? Chalk.board : Chalk.dust)
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(pro.unlocked ? "Ironbook Pro" : "Ironbook Pro, \(pro.price) once").font(.slab(17)).italic().foregroundStyle(Chalk.white)
                Text(pro.unlocked ? (pro.grandfathered ? "Unlocked. Thanks for buying Ironbook early." : "Unlocked. Thank you.") : "Charts, records, plate maths, programs.")
                    .font(.chalk(12, .medium)).foregroundStyle(Chalk.dust)
                if let m = pro.message, pro.paywall == nil { Text(m).font(.chalk(11.5, .semibold)).foregroundStyle(Chalk.gold) }
            }
            Spacer(minLength: 6)
            if !pro.unlocked {
                VStack(alignment: .trailing, spacing: 8) {
                    Button { pro.ask(.settings) } label: {
                        Text("SEE").font(.chalk(12, .black)).tracking(1.5).foregroundStyle(Chalk.board).padding(.horizontal, 14).padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Chalk.gold))
                    }.buttonStyle(.plain)
                    Button { Task { await pro.restore() } } label: {
                        Text("Restore").font(.chalk(11, .bold)).foregroundStyle(Chalk.faint).underline()
                    }.buttonStyle(.plain)
                }
            }
        }
        .slate(padding: 14)
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
                                    TapeButton(title: pro.unlocked ? "Add to my templates" : "Unlock with Pro", icon: pro.unlocked ? "plus" : "lock.fill", fill: pro.unlocked ? Chalk.red : Chalk.gold) {
                                        guard pro.unlocked else { pro.ask(.programs); return }
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
