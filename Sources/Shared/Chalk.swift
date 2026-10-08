import ActivityKit
import SwiftUI

/// The tape colour. Red is the original; the others are 99-cent themes, each with a matching app icon.
struct TapePalette: Identifiable, Hashable {
    let id: String
    let name: String
    let blurb: String
    let tape: Color
    let deep: Color
    /// The alternate icon in the asset catalog, nil for the default.
    var icon: String? { id == "red" ? nil : "AppIcon-" + name }

    static func rgb(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
    static let all: [TapePalette] = [
        TapePalette(id: "red", name: "Red", blurb: "Gaffer tape. The original.", tape: rgb(0xE6382F), deep: rgb(0x8C1A1A)),
        TapePalette(id: "cobalt", name: "Cobalt", blurb: "Cold steel blue.", tape: rgb(0x2F7BE6), deep: rgb(0x173E8C)),
        TapePalette(id: "volt", name: "Volt", blurb: "Lifting-shoe green.", tape: rgb(0x7BD62B), deep: rgb(0x3D7A12)),
        TapePalette(id: "rose", name: "Rose", blurb: "Hot pink plates.", tape: rgb(0xE6408C), deep: rgb(0x8C1A4D)),
        TapePalette(id: "bone", name: "Bone", blurb: "White tape on black iron.", tape: rgb(0xD9D2C3), deep: rgb(0x8A8170)),
    ]
    /// Read once and kept: every view asks for it.
    static var current: TapePalette = byID(Shared.theme)
    static func byID(_ id: String) -> TapePalette { all.first { $0.id == id } ?? all[0] }
    static func reload() { current = byID(Shared.theme) }
    static func apply(_ id: String) { Shared.theme = id; current = byID(id) }
}

/// Chalk on iron. A blackboard in a gym: chalk dust, tape, gold for records.
enum Chalk {
    static let board = Color(red: 0.043, green: 0.043, blue: 0.047)      // #0B0B0C
    static let slate = Color(red: 0.086, green: 0.086, blue: 0.094)      // cards
    static let slateHi = Color(red: 0.125, green: 0.125, blue: 0.137)
    static let white = Color(red: 0.96, green: 0.95, blue: 0.92)
    static let dust = Color(red: 0.96, green: 0.95, blue: 0.92).opacity(0.55)
    static let faint = Color(red: 0.96, green: 0.95, blue: 0.92).opacity(0.22)
    static let line = Color(red: 0.96, green: 0.95, blue: 0.92).opacity(0.10)
    /// The tape, in whichever colour the person picked.
    static var red: Color { TapePalette.current.tape }
    static var redDeep: Color { TapePalette.current.deep }
    /// Text on tape: dark on the pale Bone tape, chalk white on the rest.
    static var onTape: Color { TapePalette.current.id == "bone" ? board : white }
    static let gold = Color(red: 0.98, green: 0.80, blue: 0.20)
    static let green = Color(red: 0.36, green: 0.82, blue: 0.48)
}

extension Font {
    /// Big hand-lettered feel: rounded, black, italic.
    static func slab(_ size: CGFloat) -> Font { .system(size: size, weight: .black, design: .rounded) }
    static func chalk(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font { .system(size: size, weight: weight, design: .rounded) }
    static func digits(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font { .system(size: size, weight: weight, design: .rounded).monospacedDigit() }
    static func mono(_ size: CGFloat) -> Font { .system(size: size, weight: .medium, design: .monospaced) }
}

/// What the app shares with its widgets: a small summary, not the whole log.
enum Shared {
    static let group = "group.com.mattbusel.ironbook"
    static let defaults = UserDefaults(suiteName: group) ?? .standard
    static var theme: String {
        get { defaults.string(forKey: "theme") ?? "red" }
        set { defaults.set(newValue, forKey: "theme") }
    }
    static var snapshotURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?.appending(path: "week.json")
    }
}

/// The widget's view of the week, written by the app whenever the log changes.
struct WeekSnapshot: Codable {
    var goal: Int
    var done: Int
    /// Monday first: did a session happen that day.
    var days: [Bool]
    var streakWeeks: Int
    var nextTemplate: String
    var lastPR: String
    var lastPRValue: String
    var unit: String
    var pro: Bool
    var updated: Date

    static let sample = WeekSnapshot(goal: 3, done: 2, days: [true, false, true, false, false, false, false], streakWeeks: 7,
                                     nextTemplate: "Lower A", lastPR: "Bench press", lastPRValue: "117.5", unit: "kg", pro: true, updated: .now)
    static func load() -> WeekSnapshot {
        guard let u = Shared.snapshotURL, let d = try? Data(contentsOf: u), let s = try? JSONDecoder().decode(WeekSnapshot.self, from: d) else { return .sample }
        return s
    }
    func save() {
        guard let u = Shared.snapshotURL, let d = try? JSONEncoder().encode(self) else { return }
        try? d.write(to: u, options: .atomic)
    }
}

/// The rest timer on the Lock Screen and in the Dynamic Island.
struct RestAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var end: Date
        var start: Date
        var next: String
    }
    var workout: String
}

/// A starburst, the PR mark.
struct Star: Shape {
    var points: Int
    var inner: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        for i in 0..<(points * 2) {
            let a = CGFloat(i) * .pi / CGFloat(points) - .pi / 2
            let rr = i % 2 == 0 ? r : r * inner
            let pt = CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}
