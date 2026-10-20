import SwiftUI
import TipKit
import WidgetKit

@main
struct IronbookApp: App {
    @State private var store: Store
    @State private var router = Router()
    @State private var pro: Pro
    @Environment(\.scenePhase) private var scenePhase

    /// Plus: bank this month's credits once, and say so.
    func refill() {
        if store.refillIfDue(plus: pro.plus) { router.flash("Plus refill: 1 Next Block, 3 PR posters and 2 Week Shields added.") }
    }

    init() {
        let args = ProcessInfo.processInfo.arguments
        let demo = args.contains("-shot") || args.contains("-demoAutoplay")
        let shotName = args.firstIndex(of: "-shot").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
        if demo { TapePalette.current = TapePalette.byID(shotName == "theme" ? "cobalt" : "red") }
        _store = State(initialValue: Store(demo: demo))
        // Screenshots and the review recording show Pro; the paywall shots show it locked.
        let shot = args.firstIndex(of: "-shot").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
        let lockedShot = shot.map { $0.hasPrefix("paywall") || $0.hasPrefix("locked") || $0.hasPrefix("plus") } ?? false
        // The shop shot shows the extras unbought. Shots show Plus, except the paywall and shop.
        let plusShot = !lockedShot && shot != "shop"
        _pro = State(initialValue: demo ? Pro(forced: !lockedShot, extras: shot != "shop", plus: plusShot) : Pro())
        if !demo { try? Tips.configure([.displayFrequency(.immediate)]) }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(router)
                .environment(pro)
                .preferredColorScheme(.dark)
                .tint(Chalk.red)
                .onAppear {
                    pro.onCredit = { [store] id in
                        switch id {
                        case Pro.blockID: store.blockCredits += 1
                        case Pro.posterID: store.posterCredits += 3
                        case Pro.shieldID: store.shieldCredits += 1
                        case Pro.shieldPackID: store.shieldCredits += 3
                        default: break
                        }
                        store.save()
                    }
                    store.didSave = { [store, pro, router] in
                        store.snapshot(pro: pro.full).save()
                        WidgetCenter.shared.reloadAllTimelines()
                        // Plus: the iCloud copy follows the log, at most once a minute.
                        if !router.demo, pro.plus, store.cloudOn, Date.now.timeIntervalSince(router.lastBackup) > 60 {
                            router.lastBackup = .now
                            _ = CloudBackup.save(store.disk)
                        }
                    }
                    if !router.demo { store.snapshot(pro: pro.full).save(); WidgetCenter.shared.reloadAllTimelines() }
                    router.applyShotArgs(store, pro)
                    Autopilot.shared.run(store, router)
                    if !router.demo {
                        refill()
                        if store.checkMedal() { router.flash("Challenge done. A new medal is on your wall.") }
                        if let a = PendingAction.take() { router.perform(a, store, pro) }
                    }
                }
                .onChange(of: pro.full) { _, on in if !router.demo { store.snapshot(pro: on).save(); WidgetCenter.shared.reloadAllTimelines() } }
                .onChange(of: pro.plus) { _, _ in if !router.demo { refill() } }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active, !router.demo else { return }
                    refill()
                    if let a = PendingAction.take() { router.perform(a, store, pro) }
                }
                .onReceive(NotificationCenter.default.publisher(for: PendingAction.notification)) { _ in
                    if let a = PendingAction.take() { router.perform(a, store, pro) }
                }
                .onOpenURL { url in router.perform(url.host() ?? "", store, pro) }
        }
    }
}

enum Tab: String, CaseIterable {
    case train = "Train", history = "History", progress = "Progress", records = "Records"
    var icon: String {
        switch self {
        case .train: return "dumbbell.fill"
        case .history: return "calendar"
        case .progress: return "chart.line.uptrend.xyaxis"
        case .records: return "trophy.fill"
        }
    }
}

@Observable
final class Router {
    var tab: Tab = .train
    var showLive = false
    var showTimer = false
    var viewing: Session? = nil
    var editingTemplate: Template? = nil
    var showPrograms = false
    var showSettings = false
    var showShop = false
    var showBlock = false
    var showChallenge = false
    var showInsights = false
    var showCalc = false
    var toast: String? = nil
    var lastBackup = Date.distantPast
    var showcase = false
    var liftHistory: LiftName? = nil
    var finishShot: Bool = false
    /// Bumped when the tape colour changes, so every view redraws in it.
    var themeTick = 0
    let demo = ProcessInfo.processInfo.arguments.contains("-shot") || ProcessInfo.processInfo.arguments.contains("-demoAutoplay")

    @MainActor
    func flash(_ text: String) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
            withAnimation(.easeOut(duration: 0.3)) { if self?.toast == text { self?.toast = nil } }
        }
    }

    /// Deep links (ironbook://start-next, ://challenge, ://plus, ://calc, ://train) and intents.
    @MainActor
    func perform(_ action: String, _ s: Store, _ pro: Pro) {
        switch action {
        case "start-next":
            if s.live == nil { s.start(s.nextTemplate) }
            tab = .train; showLive = true
        case "challenge": tab = .train; showChallenge = true
        case "plus": if !pro.plus { pro.paywall = .plus }
        case "calc": tab = .train; showCalc = true
        case "progress": tab = .progress
        default: tab = .train
        }
    }

    @MainActor
    func applyShotArgs(_ s: Store, _ pro: Pro) {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-shot"), i + 1 < a.count else {
            if a.contains("-demoAutoplay") { s.live = nil; s.liveStart = nil }
            return
        }
        switch a[i + 1] {
        case "session": showLive = true
        case "timer": showLive = true; showTimer = true
        case "history": s.live = nil; tab = .history
        case "progress": s.live = nil; tab = .progress
        case "records": s.live = nil; tab = .records
        case "programs": s.live = nil; showPrograms = true
        case "paywall": s.live = nil; tab = .progress; pro.ask(.progress)
        case "locked": s.live = nil; tab = .progress
        case "shop", "theme": s.live = nil; showShop = true
        case "block": s.live = nil; showBlock = true
        case "settings": s.live = nil; showSettings = true
        case "widgets": s.live = nil; showcase = true
        case "challenge": s.live = nil; showChallenge = true
        case "balance": s.live = nil; tab = .progress; showInsights = true
        case "calc": s.live = nil; showCalc = true
        case "plus": s.live = nil; tab = .progress; pro.paywall = .plus
        case "finish", "poster": showLive = true; finishShot = true
        case "lift": s.live = nil; tab = .records; liftHistory = LiftName(name: "Bench press")
        default: break
        }
    }
}

struct RootView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro

    var body: some View {
        @Bindable var router = router
        ZStack(alignment: .bottom) {
            BoardBackground()
            Group {
                switch router.tab {
                case .train: TrainView()
                case .history: HistoryView()
                case .progress:
                    if pro.full { ProgressTab() } else {
                        LockedPage(reason: .progress, title: "See the line go up.", pitch: "Your estimated one-rep max for every lift, PR sessions in gold, and weekly volume, drawn from the workouts you log.") { ProgressTab() }
                    }
                case .records: RecordsView()
                }
            }
            BoardTabBar(selection: $router.tab).padding(.bottom, 2)
            if router.showcase { WidgetShowcase() }
        }
        .overlay(alignment: .top) {
            if let t = router.toast { Toast(text: t).padding(.top, 6).transition(.move(edge: .top).combined(with: .opacity)) }
        }
        .id(router.themeTick)
        .fullScreenCover(isPresented: $router.showLive) { LiveSessionView() }
        .sheet(item: $router.viewing) { s in SessionDetailView(session: s).presentationBackground(Chalk.board) }
        .sheet(item: $router.editingTemplate) { t in TemplateEditor(template: t).presentationBackground(Chalk.board) }
        .sheet(isPresented: $router.showPrograms) {
            ProgramLibrary().presentationBackground(Chalk.board)
                .sheet(item: paywall(when: true)) { r in PaywallView(reason: r).presentationBackground(Chalk.board) }
        }
        .sheet(item: paywall(when: false)) { r in PaywallView(reason: r).presentationBackground(Chalk.board) }
        .sheet(isPresented: $router.showSettings) {
            SettingsSheet().presentationBackground(Chalk.board)
                .sheet(item: paywallOn(\.showSettings)) { r in PaywallView(reason: r).presentationBackground(Chalk.board) }
        }
        .sheet(isPresented: $router.showShop) { ShopSheet().presentationBackground(Chalk.board) }
        .sheet(isPresented: $router.showBlock) { BlockSheet().presentationBackground(Chalk.board) }
        .sheet(isPresented: $router.showChallenge) {
            ChallengeSheet().presentationBackground(Chalk.board)
                .sheet(item: paywallOn(\.showChallenge)) { r in PaywallView(reason: r).presentationBackground(Chalk.board) }
        }
        .sheet(isPresented: $router.showInsights) { InsightsSheet().presentationBackground(Chalk.board) }
        .sheet(isPresented: $router.showCalc) { CalcSheet().presentationBackground(Chalk.board) }
        .sheet(item: $router.liftHistory) { l in LiftHistorySheet(name: l.name).presentationBackground(Chalk.board) }
    }
}

extension RootView {
    /// The paywall hangs off whichever sheet is on top: the program library when it is open, the root otherwise.
    func paywall(when programs: Bool) -> Binding<Pro.Reason?> {
        Binding(get: {
            let hosted = router.showPrograms || router.showChallenge || router.showSettings
            return (programs ? router.showPrograms : !hosted) ? pro.paywall : nil
        }, set: { pro.paywall = $0 })
    }
    /// The paywall over another sheet that can ask for it.
    func paywallOn(_ flag: KeyPath<Router, Bool>) -> Binding<Pro.Reason?> {
        Binding(get: { router[keyPath: flag] ? pro.paywall : nil }, set: { pro.paywall = $0 })
    }
}

struct LiftName: Identifiable, Hashable {
    let name: String
    var id: String { name }
}

/// Every tab: a scroll view with room for the floating bar.
struct Page<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) { content }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 110)
        }
    }
}

struct PageHeader: View {
    let tape: String
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Tape(text: tape)
            Text(title).font(.slab(38)).italic().foregroundStyle(Chalk.white)
        }
        .padding(.top, 12)
    }
}
