import SwiftUI

/// Drives the real screens for the App Review recording (-demoAutoplay).
/// Only sends cues; the live screen performs the same actions its buttons would.
@Observable
final class Autopilot {
    static let shared = Autopilot()
    static var on: Bool { ProcessInfo.processInfo.arguments.contains("-demoAutoplay") }
    private(set) var tick = 0
    private(set) var cue = ""
    private var running = false

    @MainActor private func send(_ c: String, then pause: Double = 0.8) async {
        cue = c; tick += 1
        try? await Task.sleep(for: .seconds(pause))
    }
    @MainActor private func wait(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }

    @MainActor
    func run(_ store: Store, _ router: Router) {
        guard Autopilot.on, !running else { return }
        running = true
        Task { @MainActor in
            await wait(3)
            router.tab = .history; await wait(2.5)
            router.tab = .progress; await wait(3)
            router.tab = .records; await wait(2.5)
            router.tab = .train; await wait(1.5)
            store.start(store.templates[0]); router.showLive = true
            await wait(2.5)
            for c in ["live.tick.0.0.2.5", "live.tick.0.1.2.5", "live.tick.0.2.2.5", "live.tick.1.0.0", "live.tick.1.1.0", "live.tick.2.0.0"] {
                await send(c, then: 1.6)
            }
            await wait(1.5)
            await send("live.finish", then: 3)
            router.showLive = false
            await wait(1.5)
            router.tab = .history; await wait(2)
            router.tab = .records; await wait(2)
            let done = URL.documentsDirectory.appending(path: "demo_done")
            try? Data("ok".utf8).write(to: done)
        }
    }
}

/// Views subscribe to cues with this. The handler runs once per cue.
struct CueSink: ViewModifier {
    let handler: (String) -> Void
    @State private var seen = 0
    func body(content: Content) -> some View {
        content.onChange(of: Autopilot.shared.tick) { _, t in
            if t != seen { seen = t; handler(Autopilot.shared.cue) }
        }
    }
}
extension View { func cueSink(_ h: @escaping (String) -> Void) -> some View { modifier(CueSink(handler: h)) } }
