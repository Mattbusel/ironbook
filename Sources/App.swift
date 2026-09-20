import SwiftUI

@main
struct IronbookApp: App {
    @State private var store: Store
    @State private var router = Router()

    init() {
        let args = ProcessInfo.processInfo.arguments
        let demo = args.contains("-shot") || args.contains("-demoAutoplay")
        _store = State(initialValue: Store(demo: demo))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(router)
                .preferredColorScheme(.dark)
                .tint(Chalk.red)
                .onAppear { router.applyShotArgs(store); Autopilot.shared.run(store, router) }
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

    func applyShotArgs(_ s: Store) {
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
        default: break
        }
    }
}

struct RootView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        ZStack(alignment: .bottom) {
            BoardBackground()
            Group {
                switch router.tab {
                case .train: TrainView()
                case .history: HistoryView()
                case .progress: ProgressTab()
                case .records: RecordsView()
                }
            }
            BoardTabBar(selection: $router.tab).padding(.bottom, 2)
        }
        .fullScreenCover(isPresented: $router.showLive) { LiveSessionView() }
        .sheet(item: $router.viewing) { s in SessionDetailView(session: s).presentationBackground(Chalk.board) }
        .sheet(item: $router.editingTemplate) { t in TemplateEditor(template: t).presentationBackground(Chalk.board) }
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
