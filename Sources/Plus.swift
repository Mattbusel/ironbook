import SwiftUI
import StoreKit
import Charts
import TipKit

// MARK: - Paywall

/// One paywall for both ways in: Ironbook Plus (monthly or yearly, the yearly with a free week) and the one-time Pro unlock.
/// Shows the price, the period, the trial terms, auto-renewal, Terms of Use and Privacy, Restore and code redemption.
struct PaywallView: View {
    @Environment(Pro.self) private var pro
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let reason: Pro.Reason
    @State private var shown = false
    @State private var plan: String = Pro.plusYearlyID
    @State private var redeeming = false
    @State private var managing = false

    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacy = URL(string: "https://tensorust.com/apps/ironbook/privacy/")!
    static let plusReasons: Set<Pro.Reason> = [.plus, .insights, .backup, .medal]

    var body: some View {
        ZStack {
            BoardBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Tape(text: "Ironbook Plus", tilt: -2)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 14, weight: .black)).foregroundStyle(Chalk.dust)
                                .frame(width: 38, height: 38).overlay(Circle().strokeBorder(Chalk.line))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(headline).font(.slab(36)).italic().foregroundStyle(Chalk.white).fixedSize(horizontal: false, vertical: true)
                        Text(pro.unlocked ? "You own Pro and keep it. Plus adds the monthly extras on top."
                                          : "Logging stays free forever. Pro and Plus read the book back to you.")
                            .font(.chalk(15, .medium)).foregroundStyle(Chalk.dust).fixedSize(horizontal: false, vertical: true)
                    }
                    teaser
                    comparison
                    VStack(spacing: 10) {
                        planRow(Pro.plusYearlyID)
                        planRow(Pro.plusMonthlyID)
                        if !pro.unlocked { planRow(Pro.productID) }
                    }
                    if let m = pro.message {
                        Text(m).font(.chalk(13, .semibold)).foregroundStyle(Chalk.gold).frame(maxWidth: .infinity, alignment: .center).multilineTextAlignment(.center)
                    }
                    if pro.plus {
                        TapeButton(title: "Manage subscription", icon: "gearshape.fill", fill: Chalk.gold) { managing = true }
                    } else {
                        TapeButton(title: pro.busy ? "One moment" : cta, icon: plan == Pro.productID ? "lock.open.fill" : "star.fill", fill: Chalk.gold) {
                            Task { await pro.buy(plan) }
                        }
                        .disabled(pro.busy)
                        Text(ctaDetail).font(.chalk(12, .semibold)).foregroundStyle(Chalk.dust)
                            .multilineTextAlignment(.center).frame(maxWidth: .infinity).fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(spacing: 10) {
                        GhostButton(title: "Restore", icon: "arrow.clockwise") { Task { await pro.restore() } }
                        GhostButton(title: "Redeem code", icon: "ticket") { redeeming = true }
                        Spacer(minLength: 0)
                    }
                    Text(finePrint).font(.chalk(11, .medium)).foregroundStyle(Chalk.faint).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 14) {
                        Link("Terms of Use (EULA)", destination: PaywallView.terms)
                        Link("Privacy Policy", destination: PaywallView.privacy)
                    }
                    .font(.chalk(12, .bold)).tint(Chalk.dust)
                }
                .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 40)
            }
        }
        .offerCodeRedemption(isPresented: $redeeming) { _ in Task { await pro.refresh() } }
        .manageSubscriptionsSheet(isPresented: $managing)
        .task { await pro.loadProducts() }
        .onAppear {
            if pro.unlocked && plan == Pro.productID { plan = Pro.plusYearlyID }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.15)) { shown = true }
        }
        .onChange(of: pro.plus) { _, now in if now { dismiss() } }
        .onChange(of: pro.unlocked) { _, now in if now && !PaywallView.plusReasons.contains(reason) { dismiss() } }
    }

    var headline: String {
        switch reason {
        case .records: return "Your wall of fame is waiting."
        case .programs: return "Proven programs, one tap away."
        case .history: return "Every time you've lifted it."
        case .health: return "Your lifting, in Apple Health."
        case .export: return "Your whole book, as a spreadsheet."
        case .widget: return "Your week on the Home Screen."
        case .insights: return "See every muscle's week."
        case .backup: return "Your whole log, safe in iCloud."
        case .medal: return "Hang your medal on the wall."
        case .plus: return "Train with the whole book."
        default: return "See the line go up."
        }
    }

    // MARK: plans

    var trialEligibleNow: Bool {
        guard pro.trialEligible else { return false }
        guard let offer = pro.products[Pro.plusYearlyID]?.subscription?.introductoryOffer else { return pro.products[Pro.plusYearlyID] == nil }
        return offer.paymentMode == .freeTrial
    }
    var trialLength: String {
        guard let offer = pro.products[Pro.plusYearlyID]?.subscription?.introductoryOffer else { return "1 week" }
        let n = offer.period.value
        switch offer.period.unit {
        case .day: return n == 7 ? "1 week" : "\(n) days"
        case .week: return n == 1 ? "1 week" : "\(n) weeks"
        case .month: return n == 1 ? "1 month" : "\(n) months"
        case .year: return "1 year"
        @unknown default: return "\(n) days"
        }
    }
    var yearlyPerMonth: String {
        guard let p = pro.products[Pro.plusYearlyID] else { return "$1.25" }
        return (p.price / 12).formatted(p.priceFormatStyle)
    }
    func title(_ id: String) -> String {
        id == Pro.plusYearlyID ? "Plus, yearly" : id == Pro.plusMonthlyID ? "Plus, monthly" : "Pro, one time"
    }
    func subtitle(_ id: String) -> String {
        switch id {
        case Pro.plusYearlyID: return trialEligibleNow ? "\(trialLength) free, then \(pro.price(id)) a year" : "\(yearlyPerMonth) a month, billed yearly"
        case Pro.plusMonthlyID: return "Everything in Plus. Cancel anytime."
        default: return "Pro features only, yours for good"
        }
    }
    func per(_ id: String) -> String { id == Pro.plusYearlyID ? "PER YEAR" : id == Pro.plusMonthlyID ? "PER MONTH" : "ONCE" }

    var cta: String {
        switch plan {
        case Pro.productID: return "Unlock Pro for \(pro.price)"
        case Pro.plusYearlyID: return trialEligibleNow ? "Start my free \(trialLength.replacingOccurrences(of: "1 ", with: ""))" : "Subscribe for \(pro.price(plan)) a year"
        default: return "Subscribe for \(pro.price(plan)) a month"
        }
    }
    var ctaDetail: String {
        switch plan {
        case Pro.productID: return "One payment. Family Sharing works."
        case Pro.plusYearlyID:
            return trialEligibleNow ? "Free for \(trialLength), then \(pro.price(plan)) per year. Renews automatically. Cancel anytime, at least 24 hours before the trial ends, to pay nothing."
                                    : "\(pro.price(plan)) per year. Renews automatically until you cancel."
        default: return "\(pro.price(plan)) per month. Renews automatically until you cancel."
        }
    }
    var finePrint: String {
        "Ironbook Plus is an auto-renewable subscription, \(pro.price(Pro.plusMonthlyID)) per month or \(pro.price(Pro.plusYearlyID)) per year. "
        + "Payment is charged to your Apple ID when you confirm the purchase, or when a free trial ends. It renews automatically unless it is "
        + "cancelled at least 24 hours before the end of the current period, and the renewal is charged within the 24 hours before that. "
        + "Manage or cancel anytime in Settings, under your name, then Subscriptions. Any unused part of a free trial ends when you buy a subscription. "
        + "Pro is a one-time purchase. Everything you have logged stays yours either way."
    }

    func planRow(_ id: String) -> some View {
        let on = plan == id
        return Button { withAnimation(.snappy(duration: 0.2)) { plan = id }; UISelectionFeedbackGenerator().selectionChanged() } label: {
            HStack(spacing: 12) {
                Image(systemName: on ? "largecircle.fill.circle" : "circle").font(.system(size: 20, weight: .bold))
                    .foregroundStyle(on ? Chalk.gold : Chalk.faint)
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title(id)).font(.slab(18)).italic().foregroundStyle(Chalk.white)
                        if id == Pro.plusYearlyID {
                            Text("BEST VALUE").font(.chalk(9, .black)).tracking(1).foregroundStyle(Chalk.board)
                                .padding(.horizontal, 6).padding(.vertical, 3).background(Capsule().fill(Chalk.gold))
                        }
                    }
                    Text(subtitle(id)).font(.chalk(12, .medium)).foregroundStyle(Chalk.dust).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(pro.price(id)).font(.digits(20, .black)).foregroundStyle(Chalk.white)
                    Text(per(id)).font(.chalk(9, .black)).tracking(1).foregroundStyle(Chalk.faint)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(on ? Chalk.slateHi : Chalk.slate))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(on ? Chalk.gold : Chalk.line, lineWidth: on ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title(id)), \(pro.price(id)) \(per(id).lowercased()). \(subtitle(id))")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: what you get

    var comparison: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 0) {
                Eyebrow("What you get")
                Spacer()
                ForEach(["FREE", "PRO", "PLUS"], id: \.self) { c in
                    Text(c).font(.chalk(10, .black)).tracking(1).foregroundStyle(c == "PLUS" ? Chalk.gold : Chalk.faint).frame(width: 42)
                }
            }
            row("Unlimited logging, rest timer, widgets", 0)
            row("Monthly challenge and medals", 0)
            row("Progress charts, the full records wall", 1)
            row("Lift history, programs, Health, CSV", 1)
            row("Muscle balance and gains insights", 2)
            row("Monthly refill: 1 Next Block, 3 posters, 2 shields", 2)
            row("Every tape colour and PR Fireworks", 2)
            row("iCloud backup of your whole log", 2)
            row("A poster for every challenge medal", 2)
        }
        .slate()
    }

    /// `from`: 0 free and up, 1 Pro and up, 2 Plus only.
    func row(_ text: String, _ from: Int) -> some View {
        HStack(spacing: 0) {
            Text(text).font(.chalk(13, .semibold)).foregroundStyle(Chalk.white).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 6)
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i >= from ? "checkmark" : "minus").font(.system(size: 12, weight: .black))
                    .foregroundStyle(i >= from ? (i == 2 ? Chalk.gold : Chalk.green) : Chalk.faint).frame(width: 42)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(text): \(from == 0 ? "free" : from == 1 ? "Pro and Plus" : "Plus only")")
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
            .frame(height: 110)
            .blur(radius: 3.5)
            .overlay(alignment: .center) {
                ZStack {
                    Star(points: 14, inner: 0.78).fill(Chalk.gold).frame(width: 80, height: 80)
                        .rotationEffect(.degrees(shown ? 0 : -40))
                    VStack(spacing: 0) {
                        Image(systemName: "lock.fill").font(.system(size: 15, weight: .black))
                        Text("PLUS").font(.chalk(11, .black)).tracking(1.5)
                    }
                    .foregroundStyle(Chalk.board)
                }
                .scaleEffect(shown ? 1 : 0.3)
                .shadow(color: Chalk.gold.opacity(0.4), radius: 18)
            }
        }
        .slate()
        .accessibilityHidden(true)
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
                Tape(text: "Pro and Plus", tilt: 2)
                Text(title).font(.slab(32)).italic().foregroundStyle(Chalk.white).multilineTextAlignment(.center)
                Text(pitch).font(.chalk(15, .medium)).foregroundStyle(Chalk.dust).multilineTextAlignment(.center).padding(.horizontal, 12)
                TapeButton(title: "See the plans", icon: "star.fill", fill: Chalk.gold) { pro.ask(reason) }
                    .padding(.horizontal, 30)
                Text("Pro once, or Plus by the month. Your log stays free.").font(.chalk(12, .bold)).foregroundStyle(Chalk.faint)
            }
            .padding(.horizontal, 24).padding(.bottom, 90)
        }
    }
}

/// Membership status on the Train tab and in Settings, with Restore always in reach.
struct ProCard: View {
    @Environment(Pro.self) private var pro
    @State private var managing = false
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Star(points: 12, inner: 0.74).fill(pro.full ? Chalk.gold : Chalk.slateHi)
                Image(systemName: pro.plus ? "crown.fill" : pro.unlocked ? "checkmark" : "lock.fill").font(.system(size: 13, weight: .black))
                    .foregroundStyle(pro.full ? Chalk.board : Chalk.dust)
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(pro.plus ? "Ironbook Plus" : pro.unlocked ? "Ironbook Pro" : "Ironbook Plus and Pro").font(.slab(17)).italic().foregroundStyle(Chalk.white)
                Text(statusLine).font(.chalk(12, .medium)).foregroundStyle(Chalk.dust).fixedSize(horizontal: false, vertical: true)
                if let m = pro.message, pro.paywall == nil { Text(m).font(.chalk(11.5, .semibold)).foregroundStyle(Chalk.gold) }
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 8) {
                if pro.plus {
                    Button { managing = true } label: { pill("MANAGE") }.buttonStyle(.plain)
                } else {
                    Button { pro.paywall = pro.unlocked ? .plus : .settings } label: { pill(pro.unlocked ? "PLUS" : "SEE") }.buttonStyle(.plain)
                    Button { Task { await pro.restore() } } label: {
                        Text("Restore").font(.chalk(11, .bold)).foregroundStyle(Chalk.faint).underline()
                    }.buttonStyle(.plain)
                }
            }
        }
        .slate(padding: 14)
        .manageSubscriptionsSheet(isPresented: $managing)
    }

    var statusLine: String {
        if pro.plus {
            if let d = pro.plusUntil, d < .distantFuture { return "Active. Renews or ends \(d.formatted(date: .abbreviated, time: .omitted))." }
            return "Active. Thank you."
        }
        if pro.unlocked { return pro.grandfathered ? "Unlocked. Thanks for buying Ironbook early. Plus adds monthly refills and insights." : "Unlocked for good. Plus adds monthly refills and insights." }
        return "Charts, records, insights, monthly refills and every tape."
    }

    func pill(_ t: String) -> some View {
        Text(t).font(.chalk(12, .black)).tracking(1.5).foregroundStyle(Chalk.board).padding(.horizontal, 14).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Chalk.gold))
    }
}

// MARK: - Plus refill

extension Store {
    /// On the first open of each month with Plus active: one Next Block, three PR posters, two Week Shields.
    @discardableResult func refillIfDue(plus: Bool) -> Bool {
        guard plus, !plusRefills.contains(monthKey) else { return false }
        plusRefills.append(monthKey)
        blockCredits += 1; posterCredits += 3; shieldCredits += 2
        save()
        return true
    }
}

// MARK: - Monthly challenge

/// A new challenge on the 1st of every month, worked out on the device. Free for everyone; finishing it earns a medal.
struct Challenge {
    enum Kind { case prs, volume, sessions, sets }
    let key: String
    let month: String
    let kind: Kind
    let goal: Double
    let start: Date
    let end: Date

    static func current(unit: String, now: Date = .now) -> Challenge {
        let cal = Store.iso
        let start = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        let end = cal.date(byAdding: .month, value: 1, to: start)!
        let comps = cal.dateComponents([.year, .month], from: now)
        let idx = ((comps.year ?? 2026) * 12 + (comps.month ?? 1) - 1) % 4
        let kinds: [Kind] = [.prs, .volume, .sessions, .sets]
        let kind = kinds[idx]
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "MMMM"
        let goal: Double
        switch kind {
        case .prs: goal = 3
        case .volume: goal = unit == "lb" ? 90_000 : 40_000
        case .sessions: goal = 12
        case .sets: goal = 150
        }
        return Challenge(key: String(Store.dayKey.string(from: start).prefix(7)), month: f.string(from: start), kind: kind, goal: goal, start: start, end: end)
    }

    var title: String {
        switch kind {
        case .prs: return "PR Hunt"
        case .volume: return "Ton Club"
        case .sessions: return "Iron Month"
        case .sets: return "Set Stacker"
        }
    }
    func detail(unit: String) -> String {
        switch kind {
        case .prs: return "Set 3 personal records in \(month). Any lift counts."
        case .volume: return "Move \(fmtVolume(goal)) \(unit) in \(month). Every working set counts."
        case .sessions: return "Train 12 times in \(month). Three a week gets you there."
        case .sets: return "Log 150 working sets in \(month). Warm-ups do not count."
        }
    }
    var icon: String {
        switch kind {
        case .prs: return "trophy.fill"
        case .volume: return "scalemass.fill"
        case .sessions: return "calendar.badge.checkmark"
        case .sets: return "square.stack.3d.up.fill"
        }
    }
    var daysLeft: Int { max(0, Store.iso.dateComponents([.day], from: .now, to: end).day ?? 0) }
}

extension Store {
    func progress(_ c: Challenge) -> Double {
        let ss = sessions.filter { $0.date >= c.start && $0.date < c.end }
        switch c.kind {
        case .sessions: return Double(ss.count)
        case .sets: return Double(ss.reduce(0) { $0 + $1.setCount })
        case .volume: return ss.reduce(0) { $0 + $1.volume }
        case .prs:
            var n = 0
            for s in ss { for e in s.exercises where e.best > 0 {
                let before = bestE1RM(e.name, before: s.date)
                if before > 0 && e.best > before + 0.01 { n += 1 }
            } }
            return Double(n)
        }
    }
    /// Banks this month's medal once the challenge is done. True the first time.
    @discardableResult func checkMedal() -> Bool {
        let c = Challenge.current(unit: unit)
        guard !medals.contains(c.key), progress(c) >= c.goal else { return false }
        medals.append(c.key); save()
        return true
    }
}

struct ChallengeCard: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    var body: some View {
        let c = Challenge.current(unit: store.unit)
        let p = store.progress(c)
        let done = store.medals.contains(c.key) || p >= c.goal
        Button { router.showChallenge = true } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ZStack {
                        Star(points: 12, inner: 0.74).fill(done ? Chalk.gold : Chalk.slateHi).frame(width: 42, height: 42)
                        Image(systemName: done ? "checkmark" : c.icon).font(.system(size: 15, weight: .black)).foregroundStyle(done ? Chalk.board : Chalk.gold)
                            .symbolEffect(.bounce, value: done)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(c.month.uppercased()) CHALLENGE").font(.chalk(10, .black)).tracking(1.5).foregroundStyle(Chalk.gold)
                        Text(c.title).font(.slab(19)).italic().foregroundStyle(Chalk.white)
                    }
                    Spacer()
                    Text(done ? "Medal won" : "\(c.daysLeft) days left").font(.chalk(11, .black)).foregroundStyle(done ? Chalk.gold : Chalk.dust)
                }
                ChallengeBar(value: p, goal: c.goal)
                Text(done ? "Done. The medal is on your wall." : "\(fmtProgress(p, c)) of \(fmtProgress(c.goal, c)). " + c.detail(unit: store.unit))
                    .font(.chalk(12, .medium)).foregroundStyle(Chalk.dust).fixedSize(horizontal: false, vertical: true)
            }
            .slate()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(c.month) challenge, \(c.title). \(fmtProgress(p, c)) of \(fmtProgress(c.goal, c)).")
    }
}

func fmtProgress(_ v: Double, _ c: Challenge) -> String { c.kind == .volume ? fmtVolume(v) : String(Int(v)) }

struct ChallengeBar: View {
    let value: Double
    let goal: Double
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Chalk.board)
                Capsule().fill(LinearGradient(colors: [Chalk.gold, Chalk.red], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(10, g.size.width * min(1, value / max(1, goal))))
            }
        }
        .frame(height: 12)
        .overlay(Capsule().strokeBorder(Chalk.line))
    }
}

struct ChallengeSheet: View {
    @Environment(Store.self) private var store
    @Environment(Pro.self) private var pro
    @Environment(\.dismiss) private var dismiss
    @State private var poster: UIImage? = nil
    var body: some View {
        let c = Challenge.current(unit: store.unit)
        let p = store.progress(c)
        let won = store.medals.contains(c.key) || p >= c.goal
        NavigationStack {
            ZStack {
                BoardBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        Tape(text: "\(c.month) challenge")
                        Text(c.title + ".").font(.slab(40)).italic().foregroundStyle(Chalk.white)
                        Text(c.detail(unit: store.unit)).font(.chalk(15, .medium)).foregroundStyle(Chalk.dust).fixedSize(horizontal: false, vertical: true)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .lastTextBaseline) {
                                Figure(value: fmtProgress(p, c), unit: "of " + fmtProgress(c.goal, c) + (c.kind == .volume ? " " + store.unit : ""), color: won ? Chalk.gold : Chalk.white, size: 44)
                                Spacer()
                                Text(won ? "MEDAL WON" : "\(c.daysLeft) DAYS LEFT").font(.chalk(11, .black)).tracking(1.5).foregroundStyle(won ? Chalk.gold : Chalk.dust)
                            }
                            ChallengeBar(value: p, goal: c.goal)
                        }
                        .slate()
                        if won {
                            if let poster {
                                Image(uiImage: poster).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 14)).shadow(color: Chalk.gold.opacity(0.3), radius: 20)
                                ShareLink(item: Image(uiImage: poster), preview: SharePreview("\(c.month) medal", image: Image(uiImage: poster))) {
                                    Label("Share the medal", systemImage: "square.and.arrow.up").font(.chalk(14, .black)).tracking(1).foregroundStyle(Chalk.board)
                                        .frame(maxWidth: .infinity).padding(.vertical, 15).background(RoundedRectangle(cornerRadius: 12).fill(Chalk.gold))
                                }
                            } else {
                                TapeButton(title: pro.plus ? "Make the medal poster" : store.posterCredits > 0 ? "Medal poster (1 of \(store.posterCredits) credits)" : "Medal poster with Plus",
                                           icon: "medal.fill", fill: Chalk.gold) {
                                    if pro.plus { poster = MedalPoster.render(c, unit: store.unit) }
                                    else if store.posterCredits > 0 { store.posterCredits -= 1; store.save(); poster = MedalPoster.render(c, unit: store.unit) }
                                    else { pro.askPlus(.medal) }
                                }
                            }
                        }
                        Eyebrow("Your medals")
                        let all = (store.medals + (won && !store.medals.contains(c.key) ? [c.key] : [])).sorted(by: >)
                        if all.isEmpty {
                            Text("Finish a monthly challenge and its medal goes here. A new one lands on the 1st of every month.")
                                .font(.chalk(13, .medium)).foregroundStyle(Chalk.dust).slate()
                        } else {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 12) {
                                ForEach(all, id: \.self) { k in MedalBadge(key: k) }
                            }
                        }
                    }
                    .padding(18)
                }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() }.foregroundStyle(Chalk.dust) } }
        }
        .onAppear { store.checkMedal() }
    }
}

struct MedalBadge: View {
    let key: String
    var label: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM"
        guard let d = f.date(from: key) else { return key }
        f.dateFormat = "MMM yy"
        return f.string(from: d).uppercased()
    }
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Star(points: 14, inner: 0.8).fill(Chalk.gold).frame(width: 58, height: 58).shadow(color: Chalk.gold.opacity(0.35), radius: 10)
                Image(systemName: "medal.fill").font(.system(size: 20, weight: .black)).foregroundStyle(Chalk.board)
            }
            Text(label).font(.chalk(10, .black)).tracking(1).foregroundStyle(Chalk.dust)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Medal, \(label)")
    }
}

/// The medal poster: gold medal on the chalkboard, the month and the challenge.
struct MedalPoster: View {
    let c: Challenge
    let unit: String
    var body: some View {
        ZStack {
            BoardBackground()
            Star(points: 18, inner: 0.82).fill(Chalk.gold.opacity(0.14)).frame(width: 560, height: 560).offset(x: 0, y: -60)
            VStack(spacing: 18) {
                Tape(text: "\(c.month) challenge", tilt: -3)
                ZStack {
                    Star(points: 16, inner: 0.8).fill(Chalk.gold).frame(width: 220, height: 220)
                    Image(systemName: "medal.fill").font(.system(size: 80, weight: .black)).foregroundStyle(Chalk.board)
                }
                Text(c.title).font(.system(size: 56, weight: .black, design: .rounded)).italic().foregroundStyle(Chalk.white)
                Text(c.detail(unit: unit)).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(Chalk.dust).multilineTextAlignment(.center).padding(.horizontal, 40)
                Spacer()
                Text("IRONBOOK").font(.system(size: 14, weight: .black, design: .rounded)).tracking(3).foregroundStyle(Chalk.faint)
            }
            .padding(.vertical, 48)
        }
        .frame(width: 600, height: 750)
    }
    @MainActor static func render(_ c: Challenge, unit: String) -> UIImage? {
        let r = ImageRenderer(content: MedalPoster(c: c, unit: unit))
        r.scale = 2
        return r.uiImage
    }
}

// MARK: - Insights (Plus)

enum Muscle: String, CaseIterable, Identifiable {
    case chest = "Chest", back = "Back", shoulders = "Shoulders", quads = "Quads", hamstrings = "Hamstrings"
    case glutes = "Glutes", biceps = "Biceps", triceps = "Triceps", calves = "Calves", core = "Core"
    var id: String { rawValue }
}

enum MuscleMap {
    /// Which muscles a lift trains, by its name. Primary muscles count a full set, helpers half a set.
    static func hits(_ name: String) -> [(Muscle, Double)] {
        let n = name.lowercased()
        func has(_ keys: String...) -> Bool { keys.contains { n.contains($0) } }
        if has("dip") { return [(.chest, 1), (.triceps, 1)] }
        if has("overhead press", "shoulder press", "military", "ohp", "arnold", "push press") { return [(.shoulders, 1), (.triceps, 0.5)] }
        if has("bench", "push-up", "push up", "chest", "fly", "flye", "pec", "incline", "decline", "dumbbell press") { return [(.chest, 1), (.triceps, 0.5), (.shoulders, 0.5)] }
        if has("lateral raise", "rear delt", "face pull", "upright row", "front raise") { return [(.shoulders, 1)] }
        if has("romanian", "rdl", "stiff", "good morning", "leg curl", "hamstring", "nordic") { return [(.hamstrings, 1), (.glutes, 0.5)] }
        if has("deadlift") { return [(.back, 1), (.hamstrings, 1), (.glutes, 0.5)] }
        if has("hip thrust", "glute", "bridge") { return [(.glutes, 1), (.hamstrings, 0.5)] }
        if has("squat", "leg press", "lunge", "step-up", "step up", "hack", "leg extension") { return [(.quads, 1), (.glutes, 0.5)] }
        if has("pull-up", "pull up", "pullup", "chin", "pulldown", "row", "lat ") { return [(.back, 1), (.biceps, 0.5)] }
        if has("shrug") { return [(.back, 1)] }
        if has("curl") { return [(.biceps, 1)] }
        if has("pushdown", "skull", "tricep", "extension", "close-grip", "kickback") { return [(.triceps, 1)] }
        if has("calf") { return [(.calves, 1)] }
        if has("plank", "crunch", "leg raise", "ab wheel", "sit-up", "situp", "core", "pallof", "hollow") { return [(.core, 1)] }
        return []
    }
}

struct MuscleSets: Identifiable {
    var id: String { muscle.rawValue }
    let muscle: Muscle
    let sets: Double
}

struct Gain: Identifiable {
    var id: String { name }
    let name: String
    let from: Double
    let to: Double
}

extension Store {
    /// Working sets per muscle over the last `days` days.
    func muscleSets(days: Int = 7) -> [MuscleSets] {
        let since = Date.now.addingTimeInterval(-Double(days) * 86_400)
        var tally: [Muscle: Double] = [:]
        for s in sessions where s.date >= since {
            for e in s.exercises {
                let n = Double(e.work.count)
                for (m, w) in MuscleMap.hits(e.name) { tally[m, default: 0] += n * w }
            }
        }
        return Muscle.allCases.map { MuscleSets(muscle: $0, sets: tally[$0] ?? 0) }
    }
    /// Lifts whose best estimated 1RM in the last 30 days beat their best before that, biggest first.
    func gains(days: Int = 30) -> [Gain] {
        let since = Date.now.addingTimeInterval(-Double(days) * 86_400)
        return exerciseNames.compactMap { name -> Gain? in
            let before = bestE1RM(name, before: since)
            var recent = 0.0
            for s in sessions where s.date >= since { for e in s.exercises where e.name == name { recent = max(recent, e.best) } }
            guard before > 0, recent > before + 0.01 else { return nil }
            return Gain(name: name, from: before, to: recent)
        }
        .sorted { ($0.to - $0.from) / $0.from > ($1.to - $1.from) / $1.from }
    }
}

/// On the Progress tab: the way into Insights. Plus users open it; everyone else sees what it is.
struct InsightsCard: View {
    @Environment(Store.self) private var store
    @Environment(Pro.self) private var pro
    @Environment(Router.self) private var router
    var body: some View {
        let ms = store.muscleSets()
        let low = ms.min { $0.sets < $1.sets }
        Button { if pro.plus { router.showInsights = true } else { pro.askPlus(.insights) } } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Chalk.gold).frame(width: 44, height: 44)
                    Image(systemName: "figure.strengthtraining.traditional").font(.system(size: 20, weight: .black)).foregroundStyle(Chalk.board)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Muscle balance").font(.slab(19)).italic().foregroundStyle(Chalk.white)
                        if !pro.plus { Tape(text: "Plus", tilt: 3) }
                    }
                    Text(pro.plus ? (low.map { "Least trained this week: \($0.muscle.rawValue.lowercased()), \(fmtSets($0.sets)) sets." } ?? "Sets per muscle, this week.")
                                  : "Sets per muscle this week, and the lifts climbing fastest.")
                        .font(.chalk(12, .medium)).foregroundStyle(Chalk.dust).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .black)).foregroundStyle(Chalk.gold)
            }
            .slate()
        }
        .buttonStyle(.plain)
    }
}

func fmtSets(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v) }

struct InsightsSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        let ms = store.muscleSets()
        let gains = Array(store.gains().prefix(5))
        NavigationStack {
            ZStack {
                BoardBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Tape(text: "Insights")
                        Text("Every muscle's week.").font(.slab(34)).italic().foregroundStyle(Chalk.white)
                        Text("Working sets in the last 7 days. Helper muscles count half a set. A common guide for growth is 10 to 20 hard sets a week per muscle.")
                            .font(.chalk(13, .medium)).foregroundStyle(Chalk.dust).fixedSize(horizontal: false, vertical: true)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Eyebrow("Sets per muscle")
                                Spacer()
                                HStack(spacing: 4) { Rectangle().fill(Chalk.green.opacity(0.6)).frame(width: 2, height: 10); Text("10 and 20 sets").font(.chalk(10, .bold)).foregroundStyle(Chalk.faint) }
                            }
                            Chart {
                                RuleMark(x: .value("Low", 10.0)).foregroundStyle(Chalk.green.opacity(0.6)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                RuleMark(x: .value("High", 20.0)).foregroundStyle(Chalk.green.opacity(0.6)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                ForEach(ms) { m in
                                    BarMark(x: .value("Sets", m.sets), y: .value("Muscle", m.muscle.rawValue))
                                        .foregroundStyle(m.sets >= 10 && m.sets <= 20 ? Chalk.gold : m.sets > 20 ? Chalk.red : Chalk.white.opacity(0.55))
                                        .cornerRadius(4)
                                        .annotation(position: .trailing) { Text(fmtSets(m.sets)).font(.mono(10)).foregroundStyle(Chalk.dust) }
                                }
                            }
                            .chartXScale(domain: 0...max(24, (ms.map { $0.sets }.max() ?? 0) + 4))
                            .chartXAxis { AxisMarks(values: [0, 10, 20]) { _ in AxisGridLine().foregroundStyle(Chalk.line); AxisValueLabel().foregroundStyle(Chalk.faint).font(.mono(10)) } }
                            .chartYAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(Chalk.white).font(.chalk(12, .bold)) } }
                            .frame(height: 330)
                        }
                        .slate()
                        let under = ms.filter { $0.sets < 10 }.map { $0.muscle.rawValue.lowercased() }
                        if !under.isEmpty {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "lightbulb.fill").foregroundStyle(Chalk.gold)
                                Text("Under 10 sets this week: \(under.joined(separator: ", ")). Worth a look if they matter to your goal.")
                                    .font(.chalk(13, .semibold)).foregroundStyle(Chalk.white).fixedSize(horizontal: false, vertical: true)
                            }
                            .slate(padding: 14)
                        }
                        Eyebrow("Climbing fastest, last 30 days")
                        if gains.isEmpty {
                            Text("Beat an old best in the next few weeks and the lift shows up here.").font(.chalk(13, .medium)).foregroundStyle(Chalk.dust).slate()
                        }
                        ForEach(gains) { g in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(g.name).font(.slab(17)).italic().foregroundStyle(Chalk.white)
                                    Text("est. 1RM \(fmtWeight(g.from.rounded())) to \(fmtWeight(g.to.rounded())) \(store.unit)").font(.mono(11)).foregroundStyle(Chalk.dust)
                                }
                                Spacer()
                                Text("+\(Int(((g.to - g.from) / g.from * 100).rounded()))%").font(.digits(20, .black)).foregroundStyle(Chalk.green)
                            }
                            .slate(padding: 14)
                        }
                    }
                    .padding(18)
                }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() }.foregroundStyle(Chalk.dust) } }
        }
    }
}

// MARK: - iCloud backup (Plus)

/// The whole log, compressed, in iCloud key-value storage. Nothing leaves Apple's servers or the person's account.
@MainActor
enum CloudBackup {
    static var kv: NSUbiquitousKeyValueStore { .default }
    static var signedIn: Bool { FileManager.default.ubiquityIdentityToken != nil }

    /// Nil when it worked, otherwise what went wrong in plain words.
    static func save(_ disk: Store.Disk) -> String? {
        guard signedIn else { return "Sign in to iCloud in the Settings app to back up." }
        guard let raw = try? JSONEncoder().encode(disk), let z = try? (raw as NSData).compressed(using: .lzfse) as Data else { return "Could not pack the log." }
        guard z.count < 900_000 else { return "The log is too big for an iCloud backup. Use CSV export instead." }
        kv.set(z, forKey: "log.v1")
        kv.set(Date.now, forKey: "log.when")
        kv.set(Int64(disk.sessions.count), forKey: "log.sessions")
        kv.synchronize()
        return nil
    }
    static var last: (when: Date, sessions: Int)? {
        guard let d = kv.object(forKey: "log.when") as? Date else { return nil }
        return (d, Int(kv.longLong(forKey: "log.sessions")))
    }
    static func load() -> Store.Disk? {
        guard let z = kv.data(forKey: "log.v1"), let raw = try? (z as NSData).decompressed(using: .lzfse) as Data else { return nil }
        return try? JSONDecoder().decode(Store.Disk.self, from: raw)
    }
}

struct BackupCard: View {
    @Environment(Store.self) private var store
    @Environment(Pro.self) private var pro
    @Environment(\.dismiss) private var dismiss
    @State private var note: String? = nil
    @State private var confirmRestore = false
    @State private var tick = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Eyebrow("iCloud backup"); Spacer(); if !pro.plus { Tape(text: "Plus", tilt: 3) } }
            if pro.plus {
                Toggle(isOn: Binding(get: { store.cloudOn }, set: { store.cloudOn = $0; store.save() })) {
                    Text("Back up after every workout").font(.chalk(15, .bold)).foregroundStyle(Chalk.white)
                }.tint(Chalk.red)
                let last = CloudBackup.last
                Text(last.map { "Last backup \($0.when.formatted(date: .abbreviated, time: .shortened)), \($0.sessions) workouts." } ?? "No backup yet.")
                    .font(.chalk(12, .medium)).foregroundStyle(Chalk.dust).id(tick)
                HStack(spacing: 10) {
                    GhostButton(title: "Back up now", icon: "icloud.and.arrow.up") {
                        note = CloudBackup.save(store.disk) ?? "Backed up."
                        tick += 1
                        UINotificationFeedbackGenerator().notificationOccurred(note == "Backed up." ? .success : .warning)
                    }
                    if last != nil { GhostButton(title: "Restore", icon: "icloud.and.arrow.down") { confirmRestore = true } }
                }
                if let note { Text(note).font(.chalk(12, .semibold)).foregroundStyle(Chalk.gold) }
            } else {
                Text("Plus keeps a copy of your whole log in your own iCloud, so a new phone picks up where you left off.")
                    .font(.chalk(12.5, .medium)).foregroundStyle(Chalk.dust).fixedSize(horizontal: false, vertical: true)
                Button { dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { pro.askPlus(.backup) } } label: {
                    Label("Turn on iCloud backup", systemImage: "icloud").font(.chalk(14, .black)).foregroundStyle(Chalk.gold)
                }.buttonStyle(.plain)
            }
        }
        .slate()
        .confirmationDialog("Replace this phone's log with the iCloud backup?", isPresented: $confirmRestore, titleVisibility: .visible) {
            Button("Replace with the backup", role: .destructive) {
                if let d = CloudBackup.load() { store.apply(d); store.save(); note = "Restored \(d.sessions.count) workouts." } else { note = "Could not read the backup." }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Workouts logged on this phone since that backup will be replaced.")
        }
    }
}

// MARK: - 1RM calculator (free)

struct CalcSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var weight = ""
    @State private var reps = "5"
    var body: some View {
        let w = Double(weight.replacingOccurrences(of: ",", with: ".")) ?? 0
        let r = Int(reps) ?? 0
        let one = Session.e1rm(w, r)
        NavigationStack {
            ZStack {
                BoardBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Tape(text: "1RM calculator")
                        Text("What could you lift once?").font(.slab(32)).italic().foregroundStyle(Chalk.white).fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 10) {
                            field("weight", $weight, decimal: true)
                            Text(store.unit).font(.chalk(14, .black)).foregroundStyle(Chalk.dust)
                            Text("×").font(.slab(22)).foregroundStyle(Chalk.faint)
                            field("reps", $reps, decimal: false)
                            Text("reps").font(.chalk(14, .black)).foregroundStyle(Chalk.dust)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Figure(value: one > 0 ? fmtWeight(store.roundLoad(one)) : "–", unit: store.unit, color: Chalk.gold, size: 58)
                            Text("Estimated one-rep max (Epley). Most reliable from 2 to 10 reps.").font(.chalk(12, .medium)).foregroundStyle(Chalk.faint)
                        }
                        .slate()
                        if one > 0 {
                            VStack(alignment: .leading, spacing: 8) {
                                Eyebrow("Working weights")
                                ForEach([95, 90, 85, 80, 75, 70, 65, 60, 50], id: \.self) { pct in
                                    let load = store.roundLoad(one * Double(pct) / 100)
                                    let reps = max(1, Int((30 * (100 / Double(pct) - 1)).rounded()))
                                    HStack {
                                        Text("\(pct)%").font(.digits(15, .black)).foregroundStyle(pct >= 85 ? Chalk.gold : Chalk.white).frame(width: 52, alignment: .leading)
                                        Text("\(fmtWeight(load)) \(store.unit)").font(.digits(15, .bold)).foregroundStyle(Chalk.white)
                                        Spacer()
                                        Text("about \(reps) rep\(reps == 1 ? "" : "s")").font(.chalk(12, .semibold)).foregroundStyle(Chalk.dust)
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                            .slate()
                        }
                        PlateCard()
                    }
                    .padding(18)
                }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() }.foregroundStyle(Chalk.dust) } }
        }
        .onAppear {
            if weight.isEmpty, let top = store.records.first { weight = fmtWeight(top.bestWeight); reps = String(top.bestReps) }
            if weight.isEmpty { weight = store.unit == "lb" ? "225" : "100" }
        }
    }
    func field(_ p: String, _ b: Binding<String>, decimal: Bool) -> some View {
        TextField(p, text: b).keyboardType(decimal ? .decimalPad : .numberPad).multilineTextAlignment(.center)
            .font(.digits(24)).foregroundStyle(Chalk.white).frame(width: 96, height: 50)
            .background(RoundedRectangle(cornerRadius: 10).fill(Chalk.board)).overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Chalk.line))
    }
}

/// On the Train tab: the tools row.
struct ToolsCard: View {
    @Environment(Router.self) private var router
    var body: some View {
        Button { router.showCalc = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Chalk.slateHi).frame(width: 44, height: 44)
                    Image(systemName: "function").font(.system(size: 19, weight: .black)).foregroundStyle(Chalk.red)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("1RM calculator").font(.slab(19)).italic().foregroundStyle(Chalk.white)
                    Text("Your one-rep max from any set, every percentage worked out, and the plates.").font(.chalk(12, .medium)).foregroundStyle(Chalk.dust)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .black)).foregroundStyle(Chalk.red)
            }
            .slate()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tips (TipKit)

struct TickTip: Tip {
    var title: Text { Text("Tick a set when it's done") }
    var message: Text? { Text("Blank fields copy last time's numbers, and the rest timer starts on your Lock Screen.") }
    var image: Image? { Image(systemName: "checkmark.circle.fill") }
}

struct LockScreenTip: Tip {
    var title: Text { Text("Your week on the Lock Screen") }
    var message: Text? { Text("Touch and hold the Lock Screen, tap Customize, then add the Ironbook ring. There is a Control Center button too.") }
    var image: Image? { Image(systemName: "lock.fill") }
}

// MARK: - Toast

struct Toast: View {
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles").foregroundStyle(Chalk.gold)
            Text(text).font(.chalk(13, .bold)).foregroundStyle(Chalk.white).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Capsule().fill(Chalk.slateHi).shadow(color: .black.opacity(0.5), radius: 16, y: 6))
        .overlay(Capsule().strokeBorder(Chalk.gold.opacity(0.5)))
        .padding(.horizontal, 18)
    }
}
