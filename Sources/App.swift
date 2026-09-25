import SwiftUI

@main
struct IronbookApp: App {
    @State private var store: Store
    @State private var router = Router()
    @State private var pro: Pro

    init() {
        let args = ProcessInfo.processInfo.arguments
        let demo = args.contains("-shot") || args.contains("-demoAutoplay")
        _store = State(initialValue: Store(demo: demo))
        // Screenshots and the review recording show Pro; the paywall shots show it locked.
        let shot = args.firstIndex(of: "-shot").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
        let lockedShot = shot.map { $0.hasPrefix("paywall") || $0.hasPrefix("locked") } ?? false
        _pro = State(initialValue: demo ? Pro(forced: !lockedShot) : Pro())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(router)
                .environment(pro)
                .preferredColorScheme(.dark)
                .tint(Chalk.red)
                .onAppear { router.applyShotArgs(store, pro); Autopilot.shared.run(store, router) }
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
                case .records:
                    if pro.unlocked { RecordsView() } else {
                        LockedPage(reason: .records, title: "Your wall of fame.", pitch: "Every lift ranked by estimated one-rep max, with your best set and your heaviest set.") { RecordsView() }
                    }
                }
            }
            BoardTabBar(selection: $router.tab).padding(.bottom, 2)
        }
        .fullScreenCover(isPresented: $router.showLive) { LiveSessionView() }
        .sheet(item: $router.viewing) { s in SessionDetailView(session: s).presentationBackground(Chalk.board) }
        .sheet(item: $router.editingTemplate) { t in TemplateEditor(template: t).presentationBackground(Chalk.board) }
        .sheet(isPresented: $router.showPrograms) {
            ProgramLibrary().presentationBackground(Chalk.board)
                .sheet(item: paywall(when: true)) { r in PaywallView(reason: r).presentationBackground(Chalk.board) }
        }
        .sheet(item: paywall(when: false)) { r in PaywallView(reason: r).presentationBackground(Chalk.board) }
    }
}

extension RootView {
    /// The paywall hangs off whichever sheet is on top: the program library when it is open, the root otherwise.
    func paywall(when programs: Bool) -> Binding<Pro.Reason?> {
        Binding(get: { router.showPrograms == programs ? pro.paywall : nil }, set: { pro.paywall = $0 })
    }
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
