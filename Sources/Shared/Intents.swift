import AppIntents
import Foundation

/// Things the app is asked to do from outside: a Control Center button, Siri, Shortcuts, a widget.
/// The intent leaves a note in the app group and, when it runs inside the app, posts it straight away.
enum PendingAction {
    static let key = "pendingAction"
    static let notification = Notification.Name("ironbook.pendingAction")
    static func post(_ action: String) {
        Shared.defaults.set(action, forKey: key)
        NotificationCenter.default.post(name: notification, object: action)
    }
    static func take() -> String? {
        guard let a = Shared.defaults.string(forKey: key) else { return nil }
        Shared.defaults.removeObject(forKey: key)
        return a
    }
}

struct StartNextWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Next Workout"
    static var description = IntentDescription("Opens Ironbook and starts the template after the one you did last.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        PendingAction.post("start-next")
        return .result()
    }
}

struct OpenChallengeIntent: AppIntent {
    static var title: LocalizedStringResource = "Show This Month's Challenge"
    static var description = IntentDescription("Opens Ironbook on the monthly challenge and your medals.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        PendingAction.post("challenge")
        return .result()
    }
}
