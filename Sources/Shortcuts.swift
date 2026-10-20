import AppIntents
import Foundation

/// Answers without opening the app: this week against the goal, and the streak.
struct WeekStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "How Is My Training Week"
    static var description = IntentDescription("Says how many sessions you have done this week against your goal, and your week streak.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let s = WeekSnapshot.load()
        let left = max(0, s.goal - s.done)
        var line = "\(s.done) of \(s.goal) sessions this week."
        line += left == 0 ? " Goal hit." : " \(left) to go."
        if s.streakWeeks > 0 { line += " \(s.streakWeeks)-week streak." }
        if !s.nextTemplate.isEmpty { line += " Next up: \(s.nextTemplate)." }
        return .result(dialog: IntentDialog(stringLiteral: line))
    }
}

struct IronbookShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartNextWorkoutIntent(),
                    phrases: ["Start my workout in \(.applicationName)", "Start the next \(.applicationName) workout", "Start \(.applicationName)"],
                    shortTitle: "Start Next Workout", systemImageName: "dumbbell.fill")
        AppShortcut(intent: WeekStatusIntent(),
                    phrases: ["How is my week in \(.applicationName)", "\(.applicationName) streak", "Check my \(.applicationName) week"],
                    shortTitle: "This Week", systemImageName: "flame.fill")
        AppShortcut(intent: OpenChallengeIntent(),
                    phrases: ["Show my \(.applicationName) challenge", "\(.applicationName) monthly challenge"],
                    shortTitle: "Monthly Challenge", systemImageName: "medal.fill")
    }
}
