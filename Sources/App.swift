import SwiftUI
import WidgetKit

@main
struct IronbookApp: App {
    @State private var store: Store
    @State private var router = Router()
    @State private var pro: Pro

    init() {
        let args = ProcessInfo.processInfo.arguments
        let demo = args.contains("-shot") || args.contains("-demoAutoplay")
        let shotName = args.firstIndex(of: "-shot").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
        if demo { TapePalette.current = TapePalette.byID(shotName == "theme" ? "cobalt" : "red") }
        _store = State(initialValue: Store(demo: demo))
        // Screenshots and the review recording show Pro; the paywall shots show it locked.
        let shot = args.firstIndex(of: "-shot").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
        let lockedShot = shot.map { $0.hasPrefix("paywall") || $0.hasPrefix("locked") } ?? false
        // The shop shot shows the extras unbought.
        _pro = State(initialValue: demo ? Pro(forced: !lockedShot, extras: shot != "shop") : Pro())
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
                        default: break
                        }
                        store.save()
                    }
                    store.didSave = { [store, pro] in
                        store.snapshot(pro: pro.unlocked).save()
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                    if !router.demo { store.snapshot(pro: pro.unlocked).save(); WidgetCenter.shared.reloadAllTimelines() }
                    router.applyShotArgs(store, pro)
                    Autopilot.shared.run(store, router)
                }
                .onChange(of: pro.unlocked) { _, on in if !router.demo { store.snapshot(pro: on).save(); WidgetCenter.shared.reloadAllTimelines() } }
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
    var showcase = false
    var liftHistory: LiftName? = nil
    var finishShot: Bool = false
    /// Bumped when the tape colour changes, so every view redraws in it.
    var themeTick = 0
    let demo = ProcessInfo.processInfo.arguments.contains("-shot") || ProcessInfo.processInfo.arguments.contains("-demoAutoplay")

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
                    if pro.unlocked { ProgressTab() } else {
                        LockedPage(reason: .progress, title: "See the line go up.", pitch: "Your estimated one-rep max for every lift, PR sessions in gold, and weekly volume, drawn from the workouts you log.") { ProgressTab() }
                    }
                case .records: RecordsView()
                }
            }
            BoardTabBar(selection: $router.tab).padding(.bottom, 2)
            if router.showcase { WidgetShowcase() }
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
        .sheet(isPresented: $router.showSettings) { SettingsSheet().presentationBackground(Chalk.board) }
        .sheet(isPresented: $router.showShop) { ShopSheet().presentationBackground(Chalk.board) }
        .sheet(isPresented: $router.showBlock) { BlockSheet().presentationBackground(Chalk.board) }
        .sheet(item: $router.liftHistory) { l in LiftHistorySheet(name: l.name).presentationBackground(Chalk.board) }
    }
}

extension RootView {
    /// The paywall hangs off whichever sheet is on top: the program library when it is open, the root otherwise.
    func paywall(when programs: Bool) -> Binding<Pro.Reason?> {
        Binding(get: { router.showPrograms == programs ? pro.paywall : nil }, set: { pro.paywall = $0 })
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
