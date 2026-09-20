import Foundation
import Observation

struct TemplateExercise: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var sets: Int
    var reps: Int
}

struct Template: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var exercises: [TemplateExercise]
}

struct SetEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var weight: Double? = nil
    var reps: Int? = nil
    var done = false
    var e1rm: Double { Session.e1rm(weight ?? 0, reps ?? 0) }
}

struct ExerciseEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var sets: [SetEntry]
    var volume: Double { sets.filter { $0.done }.reduce(0) { $0 + ($1.weight ?? 0) * Double($1.reps ?? 0) } }
    var best: Double { sets.filter { $0.done }.map { $0.e1rm }.max() ?? 0 }
}

struct Session: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var date = Date.now
    var minutes: Int = 0
    var exercises: [ExerciseEntry]
    var volume: Double { exercises.reduce(0) { $0 + $1.volume } }
    var setCount: Int { exercises.reduce(0) { $0 + $1.sets.filter { $0.done }.count } }

    /// Epley estimate.
    static func e1rm(_ w: Double, _ r: Int) -> Double {
        guard r > 0, w > 0 else { return 0 }
        return r == 1 ? w : w * (1 + Double(r) / 30)
    }
}

struct Record: Identifiable {
    var id: String { name }
    let name: String
    let e1rm: Double
    let bestWeight: Double
    let bestReps: Int
    let bestSetWeight: Double
    let bestSetReps: Int
    let date: Date
}

struct WeekVolume: Identifiable {
    var id: Date { start }
    let start: Date
    let volume: Double
    let current: Bool
}

struct ProgressPoint: Identifiable {
    var id: Date { date }
    let date: Date
    let e1rm: Double
    let top: Double
    let isPR: Bool
}

@Observable
final class Store {
    var templates: [Template] = []
    var sessions: [Session] = []
    var live: Session? = nil
    var liveStart: Date? = nil
    var unit: String = "kg"
    var restSeconds: Int = 90

    private var saveTask: Task<Void, Never>?
    private let url = URL.documentsDirectory.appending(path: "ironbook.json")

    struct Disk: Codable { var templates: [Template]; var sessions: [Session]; var live: Session?; var liveStart: Date?; var unit: String; var restSeconds: Int }

    init(demo: Bool) {
        if demo { Demo.fill(self); return }
        if let d = try? Data(contentsOf: url), let disk = try? JSONDecoder().decode(Disk.self, from: d) {
            templates = disk.templates; sessions = disk.sessions; live = disk.live; liveStart = disk.liveStart; unit = disk.unit; restSeconds = disk.restSeconds
        } else {
            templates = Store.starterTemplates
        }
    }

    static let starterTemplates: [Template] = [
        Template(name: "Upper A", exercises: [.init(name: "Bench press", sets: 4, reps: 6), .init(name: "Barbell row", sets: 4, reps: 8), .init(name: "Overhead press", sets: 3, reps: 8), .init(name: "Lat pulldown", sets: 3, reps: 10), .init(name: "Dumbbell curl", sets: 3, reps: 12)]),
        Template(name: "Lower A", exercises: [.init(name: "Squat", sets: 4, reps: 5), .init(name: "Romanian deadlift", sets: 3, reps: 8), .init(name: "Leg press", sets: 3, reps: 10), .init(name: "Leg curl", sets: 3, reps: 12), .init(name: "Calf raise", sets: 4, reps: 12)]),
        Template(name: "Full body", exercises: [.init(name: "Deadlift", sets: 3, reps: 5), .init(name: "Bench press", sets: 3, reps: 8), .init(name: "Squat", sets: 3, reps: 8), .init(name: "Pull-up", sets: 3, reps: 8), .init(name: "Plank", sets: 3, reps: 60)]),
    ]

    func save() {
        saveTask?.cancel()
        let disk = Disk(templates: templates, sessions: sessions, live: live, liveStart: liveStart, unit: unit, restSeconds: restSeconds)
        let u = url
        saveTask = Task.detached(priority: .utility) {
            try? await Task.sleep(for: .milliseconds(250))
            if Task.isCancelled { return }
            if let d = try? JSONEncoder().encode(disk) { try? d.write(to: u, options: .atomic) }
        }
    }

    // MARK: queries

    var exerciseNames: [String] {
        var seen: [String] = []
        for s in sessions.sorted(by: { $0.date > $1.date }) { for e in s.exercises where !seen.contains(e.name) && e.best > 0 { seen.append(e.name) } }
        for t in templates { for e in t.exercises where !seen.contains(e.name) { seen.append(e.name) } }
        return seen
    }

    /// Completed sets from the most recent session containing this exercise.
    func lastSets(_ name: String) -> [SetEntry] {
        for s in sessions.sorted(by: { $0.date > $1.date }) {
            if let e = s.exercises.first(where: { $0.name == name }) {
                let done = e.sets.filter { $0.done && $0.weight != nil }
                if !done.isEmpty { return done }
            }
        }
        return []
    }

    func bestE1RM(_ name: String, before: Date? = nil) -> Double {
        var best = 0.0
        for s in sessions {
            if let b = before, s.date >= b { continue }
            for e in s.exercises where e.name == name { best = max(best, e.best) }
        }
        return best
    }

    func progress(_ name: String) -> [ProgressPoint] {
        var out: [ProgressPoint] = []
        var running = 0.0
        for s in sessions.sorted(by: { $0.date < $1.date }) {
            guard let e = s.exercises.first(where: { $0.name == name }), e.best > 0 else { continue }
            let top = e.sets.filter { $0.done }.map { $0.weight ?? 0 }.max() ?? 0
            let pr = e.best > running + 0.01
            running = max(running, e.best)
            out.append(ProgressPoint(date: s.date, e1rm: e.best, top: top, isPR: pr))
        }
        return out
    }

    var records: [Record] {
        var out: [Record] = []
        for name in exerciseNames {
            var best: (Double, Double, Int, Date)? = nil
            var heavy: (Double, Int) = (0, 0)
            for s in sessions { for e in s.exercises where e.name == name { for st in e.sets where st.done {
                guard let w = st.weight, let r = st.reps, w > 0, r > 0 else { continue }
                let v = Session.e1rm(w, r)
                if best == nil || v > best!.0 { best = (v, w, r, s.date) }
                if w > heavy.0 { heavy = (w, r) }
            } } }
            if let b = best { out.append(Record(name: name, e1rm: b.0, bestWeight: b.1, bestReps: b.2, bestSetWeight: heavy.0, bestSetReps: heavy.1, date: b.3)) }
        }
        return out.sorted { $0.e1rm > $1.e1rm }
    }

    /// Volume per ISO week for the last n weeks, oldest first.
    func weeklyVolume(weeks n: Int = 10) -> [WeekVolume] {
        let cal = Calendar.current
        let thisWeek = cal.dateInterval(of: .weekOfYear, for: .now)!.start
        return (0..<n).reversed().map { i in
            let start = cal.date(byAdding: .weekOfYear, value: -i, to: thisWeek)!
            let end = cal.date(byAdding: .weekOfYear, value: 1, to: start)!
            let v = sessions.filter { $0.date >= start && $0.date < end }.reduce(0) { $0 + $1.volume }
            return WeekVolume(start: start, volume: v, current: i == 0)
        }
    }

    // MARK: live session

    func start(_ t: Template?) {
        let ex = (t?.exercises ?? []).map { e in ExerciseEntry(name: e.name, sets: (0..<e.sets).map { _ in SetEntry() }) }
        live = Session(name: t?.name ?? "Workout", exercises: ex)
        liveStart = .now
        save()
    }

    func repeatSession(_ s: Session) {
        live = Session(name: s.name, exercises: s.exercises.map { e in ExerciseEntry(name: e.name, sets: e.sets.map { _ in SetEntry() }) })
        liveStart = .now
        save()
    }

    /// Returns the names of exercises where a PR was set.
    @discardableResult
    func finish() -> [String] {
        guard var s = live else { return [] }
        var prs: [String] = []
        s.exercises = s.exercises.map { e in
            var e2 = e
            e2.sets = e.sets.filter { $0.done && ($0.weight ?? 0) > 0 && ($0.reps ?? 0) > 0 }
            return e2
        }.filter { !$0.sets.isEmpty }
        for e in s.exercises where e.best > bestE1RM(e.name) { prs.append(e.name) }
        s.minutes = max(1, Int((Date.now.timeIntervalSince(liveStart ?? .now)) / 60))
        s.date = .now
        if !s.exercises.isEmpty { sessions.append(s) }
        live = nil; liveStart = nil
        save()
        return prs
    }

    func discard() { live = nil; liveStart = nil; save() }
}

func fmtWeight(_ w: Double) -> String {
    w == w.rounded() ? String(Int(w)) : String(format: "%.1f", w)
}

func fmtVolume(_ v: Double) -> String {
    v >= 10000 ? String(format: "%.1fk", v / 1000) : String(Int(v.rounded()))
}
