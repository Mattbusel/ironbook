import Foundation
import Observation

struct TemplateExercise: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var sets: Int
    var reps: Int
    /// A target load for every working set, written by Next Block. Nil for ordinary templates.
    var target: Double? = nil
}

extension TemplateExercise {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        sets = try c.decodeIfPresent(Int.self, forKey: .sets) ?? 3
        reps = try c.decodeIfPresent(Int.self, forKey: .reps) ?? 8
        target = try c.decodeIfPresent(Double.self, forKey: .target)
    }
}

struct Template: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var exercises: [TemplateExercise]
    /// Set on the four templates a Next Block writes, so they can be grouped and cleared.
    var block: String? = nil
}

extension Template {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        exercises = try c.decodeIfPresent([TemplateExercise].self, forKey: .exercises) ?? []
        block = try c.decodeIfPresent(String.self, forKey: .block)
    }
}

struct SetEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var weight: Double? = nil
    var reps: Int? = nil
    var done = false
    /// Warm-up sets are logged but never count toward volume or records.
    var warmup = false
    var e1rm: Double { warmup ? 0 : Session.e1rm(weight ?? 0, reps ?? 0) }
}

extension SetEntry {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        weight = try c.decodeIfPresent(Double.self, forKey: .weight)
        reps = try c.decodeIfPresent(Int.self, forKey: .reps)
        done = try c.decodeIfPresent(Bool.self, forKey: .done) ?? false
        warmup = try c.decodeIfPresent(Bool.self, forKey: .warmup) ?? false
    }
}

struct ExerciseEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var sets: [SetEntry]
    var note: String = ""
    var work: [SetEntry] { sets.filter { $0.done && !$0.warmup } }
    var volume: Double { work.reduce(0) { $0 + ($1.weight ?? 0) * Double($1.reps ?? 0) } }
    var best: Double { work.map { $0.e1rm }.max() ?? 0 }
}

extension ExerciseEntry {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        sets = try c.decodeIfPresent([SetEntry].self, forKey: .sets) ?? []
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
}

struct Session: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var date = Date.now
    var minutes: Int = 0
    var exercises: [ExerciseEntry]
    var note: String = ""
    var volume: Double { exercises.reduce(0) { $0 + $1.volume } }
    var setCount: Int { exercises.reduce(0) { $0 + $1.work.count } }

    /// Epley estimate.
    static func e1rm(_ w: Double, _ r: Int) -> Double {
        guard r > 0, w > 0 else { return 0 }
        return r == 1 ? w : w * (1 + Double(r) / 30)
    }
}

extension Session {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Workout"
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? .now
        minutes = try c.decodeIfPresent(Int.self, forKey: .minutes) ?? 0
        exercises = try c.decodeIfPresent([ExerciseEntry].self, forKey: .exercises) ?? []
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
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

/// A PR set at the end of a workout: what the finish sheet and the posters show.
struct PRHit: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let weight: Double
    let reps: Int
    let e1rm: Double
    let gain: Double
}

@Observable
final class Store {
    var templates: [Template] = []
    var sessions: [Session] = []
    var live: Session? = nil
    var liveStart: Date? = nil
    var unit: String = "kg"
    var restSeconds: Int = 90
    var weeklyGoal: Int = 3
    /// Week starts (yyyy-MM-dd) a Week Shield covered.
    var shields: [String] = []
    /// Months (yyyy-MM) the free monthly shield was used.
    var freeShieldMonths: [String] = []
    var shieldCredits = 0
    var blockCredits = 0
    var posterCredits = 0
    var healthOn = false
    @ObservationIgnored var didSave: (() -> Void)?

    private var saveTask: Task<Void, Never>?
    private let url = URL.documentsDirectory.appending(path: "ironbook.json")
    private let demo: Bool

    struct Disk: Codable {
        var templates: [Template]
        var sessions: [Session]
        var live: Session?
        var liveStart: Date?
        var unit: String
        var restSeconds: Int
        var weeklyGoal: Int? = nil
        var shields: [String]? = nil
        var freeShieldMonths: [String]? = nil
        var shieldCredits: Int? = nil
        var blockCredits: Int? = nil
        var posterCredits: Int? = nil
        var healthOn: Bool? = nil
    }

    init(demo: Bool) {
        self.demo = demo
        if demo { Demo.fill(self); return }
        if let d = try? Data(contentsOf: url), let disk = try? JSONDecoder().decode(Disk.self, from: d) {
            templates = disk.templates; sessions = disk.sessions; live = disk.live; liveStart = disk.liveStart; unit = disk.unit; restSeconds = disk.restSeconds
            weeklyGoal = disk.weeklyGoal ?? 3; shields = disk.shields ?? []; freeShieldMonths = disk.freeShieldMonths ?? []
            shieldCredits = disk.shieldCredits ?? 0; blockCredits = disk.blockCredits ?? 0; posterCredits = disk.posterCredits ?? 0
            healthOn = disk.healthOn ?? false
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
        guard !demo else { didSave?(); return }
        saveTask?.cancel()
        let disk = Disk(templates: templates, sessions: sessions, live: live, liveStart: liveStart, unit: unit, restSeconds: restSeconds,
                        weeklyGoal: weeklyGoal, shields: shields, freeShieldMonths: freeShieldMonths, shieldCredits: shieldCredits,
                        blockCredits: blockCredits, posterCredits: posterCredits, healthOn: healthOn)
        let u = url
        saveTask = Task.detached(priority: .utility) { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            if Task.isCancelled { return }
            if let d = try? JSONEncoder().encode(disk) { try? d.write(to: u, options: .atomic) }
            await MainActor.run { self?.didSave?() }
        }
    }

    func exportCSV() -> String {
        var rows = ["date,workout,exercise,set,weight,reps,warmup,unit,note"]
        let df = ISO8601DateFormatter()
        for s in sessions.sorted(by: { $0.date < $1.date }) {
            for e in s.exercises {
                for (i, st) in e.sets.enumerated() {
                    let esc = { (t: String) in "\"" + t.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
                    rows.append([df.string(from: s.date), esc(s.name), esc(e.name), "\(i + 1)", st.weight.map(fmtWeight) ?? "", st.reps.map(String.init) ?? "", st.warmup ? "1" : "", unit, esc(e.note)].joined(separator: ","))
                }
            }
        }
        return rows.joined(separator: "\n")
    }

    // MARK: queries

    var exerciseNames: [String] {
        var seen: [String] = []
        for s in sessions.sorted(by: { $0.date > $1.date }) { for e in s.exercises where !seen.contains(e.name) && e.best > 0 { seen.append(e.name) } }
        for t in templates { for e in t.exercises where !seen.contains(e.name) { seen.append(e.name) } }
        return seen
    }

    /// Completed working sets from the most recent session containing this exercise.
    func lastSets(_ name: String) -> [SetEntry] {
        for s in sessions.sorted(by: { $0.date > $1.date }) {
            if let e = s.exercises.first(where: { $0.name == name }) {
                let done = e.work.filter { $0.weight != nil }
                if !done.isEmpty { return done }
            }
        }
        return []
    }

    func lastNote(_ name: String) -> String {
        for s in sessions.sorted(by: { $0.date > $1.date }) {
            if let e = s.exercises.first(where: { $0.name == name }), !e.note.isEmpty { return e.note }
        }
        return ""
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
            let top = e.work.map { $0.weight ?? 0 }.max() ?? 0
            let pr = e.best > running + 0.01
            running = max(running, e.best)
            out.append(ProgressPoint(date: s.date, e1rm: e.best, top: top, isPR: pr))
        }
        return out
    }

    /// Every session with this exercise, newest first.
    func history(_ name: String) -> [(Session, ExerciseEntry)] {
        sessions.sorted { $0.date > $1.date }.compactMap { s in s.exercises.first { $0.name == name && !$0.work.isEmpty }.map { (s, $0) } }
    }

    var records: [Record] {
        var out: [Record] = []
        for name in exerciseNames {
            var best: (Double, Double, Int, Date)? = nil
            var heavy: (Double, Int) = (0, 0)
            for s in sessions { for e in s.exercises where e.name == name { for st in e.work {
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

    // MARK: weeks, streaks and shields

    static let iso: Calendar = { var c = Calendar(identifier: .iso8601); c.timeZone = .current; return c }()
    static let dayKey: DateFormatter = { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.calendar = iso; f.locale = Locale(identifier: "en_US_POSIX"); return f }()
    func weekStart(_ d: Date) -> Date { Store.iso.dateInterval(of: .weekOfYear, for: d)!.start }
    func weekKey(_ d: Date) -> String { Store.dayKey.string(from: weekStart(d)) }
    func sessionsIn(weekOf d: Date) -> Int {
        let s = weekStart(d), e = Store.iso.date(byAdding: .weekOfYear, value: 1, to: s)!
        return sessions.filter { $0.date >= s && $0.date < e }.count
    }
    func weekMet(_ d: Date) -> Bool { sessionsIn(weekOf: d) >= weeklyGoal || shields.contains(weekKey(d)) }
    /// Weeks in a row the goal was met (or shielded). The current week counts once it is met.
    var streakWeeks: Int {
        var n = weekMet(.now) ? 1 : 0
        var d = Store.iso.date(byAdding: .weekOfYear, value: -1, to: .now)!
        let first = sessions.map(\.date).min() ?? .now
        while d >= weekStart(first) && weekMet(d) { n += 1; d = Store.iso.date(byAdding: .weekOfYear, value: -1, to: d)! }
        return n
    }
    /// Monday first: which days this week had a session.
    var daysThisWeek: [Bool] {
        let s = weekStart(.now)
        return (0..<7).map { i in
            let a = Store.iso.date(byAdding: .day, value: i, to: s)!, b = Store.iso.date(byAdding: .day, value: 1, to: a)!
            return sessions.contains { $0.date >= a && $0.date < b }
        }
    }
    /// Last week fell short, and the run before it is worth keeping: a shield can save it.
    var shieldable: (week: Date, lost: Int)? {
        let last = Store.iso.date(byAdding: .weekOfYear, value: -1, to: .now)!
        guard !weekMet(last), sessionsIn(weekOf: last) > 0 || !sessions.isEmpty else { return nil }
        var n = 0
        var d = Store.iso.date(byAdding: .weekOfYear, value: -2, to: .now)!
        let first = sessions.map(\.date).min() ?? .now
        while d >= weekStart(first) && weekMet(d) { n += 1; d = Store.iso.date(byAdding: .weekOfYear, value: -1, to: d)! }
        return n >= 2 ? (last, n) : nil
    }
    var monthKey: String { String(Store.dayKey.string(from: .now).prefix(7)) }
    var freeShieldLeft: Bool { !freeShieldMonths.contains(monthKey) }
    /// Uses the month's free shield first, then a bought one. False if there is neither.
    @discardableResult func shield(_ week: Date) -> Bool {
        if freeShieldLeft { freeShieldMonths.append(monthKey) } else if shieldCredits > 0 { shieldCredits -= 1 } else { return false }
        shields.append(weekKey(week)); save()
        return true
    }

    // MARK: Next Block

    /// Four weeks of the chosen template with a target load on every lift, worked out from the person's own
    /// best estimated one-rep max: volume, then intensity, then a heavy week, then a deload.
    static let blockWeeks: [(name: String, sets: Int, reps: Int, pct: Double)] = [
        ("Week 1 · volume", 4, 8, 0.70), ("Week 2 · build", 4, 6, 0.76), ("Week 3 · heavy", 5, 4, 0.83), ("Week 4 · deload", 3, 5, 0.60),
    ]
    func roundLoad(_ w: Double) -> Double {
        let step = unit == "lb" ? 5.0 : 2.5
        return max(step, (w / step).rounded() * step)
    }
    func blockPreview(_ t: Template) -> [Template] {
        let tag = UUID().uuidString
        return Store.blockWeeks.map { wk in
            Template(name: "\(t.name) · \(wk.name)", exercises: t.exercises.map { e in
                let best = bestE1RM(e.name)
                return TemplateExercise(name: e.name, sets: best > 0 ? wk.sets : e.sets, reps: best > 0 ? wk.reps : e.reps,
                                        target: best > 0 ? roundLoad(best * wk.pct) : nil)
            }, block: tag)
        }
    }
    func canBuildBlock(_ t: Template) -> Bool { t.exercises.contains { bestE1RM($0.name) > 0 } }
    @discardableResult func buildBlock(_ t: Template) -> Bool {
        guard blockCredits > 0, canBuildBlock(t) else { return false }
        blockCredits -= 1
        templates.insert(contentsOf: blockPreview(t), at: 0)
        save()
        return true
    }

    // MARK: live session

    func start(_ t: Template?) {
        let ex = (t?.exercises ?? []).map { e in ExerciseEntry(name: e.name, sets: (0..<e.sets).map { _ in SetEntry(weight: e.target, reps: e.target == nil ? nil : e.reps) }) }
        live = Session(name: t?.name ?? "Workout", exercises: ex)
        liveStart = .now
        save()
    }

    func repeatSession(_ s: Session) {
        live = Session(name: s.name, exercises: s.exercises.map { e in ExerciseEntry(name: e.name, sets: e.work.map { _ in SetEntry() }) })
        liveStart = .now
        save()
    }

    /// Warm-up sets ahead of the working weight: empty bar, then 40, 60 and 80 percent.
    func warmups(for working: Double) -> [SetEntry] {
        let bar = unit == "lb" ? 45.0 : 20.0
        guard working > bar * 1.5 else { return [SetEntry(weight: bar, reps: 10, warmup: true)] }
        var out = [SetEntry(weight: bar, reps: 10, warmup: true)]
        for (p, r) in [(0.4, 5), (0.6, 3), (0.8, 2)] {
            let w = roundLoad(working * p)
            if w > (out.last?.weight ?? 0) && w < working { out.append(SetEntry(weight: w, reps: r, warmup: true)) }
        }
        return out
    }

    /// The PRs in the live session, against everything logged before it.
    func livePRs() -> [PRHit] {
        guard let s = live else { return [] }
        return s.exercises.compactMap { e in
            let before = bestE1RM(e.name)
            guard e.best > before + 0.01, let top = e.work.max(by: { $0.e1rm < $1.e1rm }) else { return nil }
            return PRHit(name: e.name, weight: top.weight ?? 0, reps: top.reps ?? 0, e1rm: e.best, gain: before > 0 ? e.best - before : 0)
        }
    }

    /// Saves the workout. Returns the PRs it set and the saved session.
    @discardableResult
    func finish() -> (prs: [PRHit], session: Session?) {
        guard var s = live else { return ([], nil) }
        let prs = livePRs()
        s.exercises = s.exercises.map { e in
            var e2 = e
            e2.sets = e.sets.filter { $0.done && ($0.weight ?? 0) > 0 && ($0.reps ?? 0) > 0 }
            return e2
        }.filter { !$0.sets.isEmpty }
        s.minutes = max(1, Int((Date.now.timeIntervalSince(liveStart ?? .now)) / 60))
        s.date = .now
        let saved = s.exercises.isEmpty ? nil : s
        if let saved { sessions.append(saved) }
        live = nil; liveStart = nil
        save()
        return (prs, saved)
    }

    func discard() { live = nil; liveStart = nil; save() }

    /// The summary the widgets draw.
    func snapshot(pro: Bool) -> WeekSnapshot {
        let lastPR = sessions.sorted { $0.date > $1.date }.lazy.compactMap { s -> (String, Double)? in
            for e in s.exercises where e.best > 0 && e.best >= self.bestE1RM(e.name, before: s.date) + 0.01 && self.bestE1RM(e.name, before: s.date) > 0 { return (e.name, e.best) }
            return nil
        }.first
        let recent = sessions.max { $0.date < $1.date }?.name
        let next = templates.first { $0.name != recent }?.name ?? templates.first?.name ?? "Start blank"
        return WeekSnapshot(goal: weeklyGoal, done: sessionsIn(weekOf: .now), days: daysThisWeek, streakWeeks: streakWeeks, nextTemplate: next,
                            lastPR: lastPR?.0 ?? "", lastPRValue: lastPR.map { fmtWeight($0.1.rounded()) } ?? "", unit: unit, pro: pro, updated: .now)
    }
}

func fmtWeight(_ w: Double) -> String {
    w == w.rounded() ? String(Int(w)) : String(format: "%.1f", w)
}

func fmtVolume(_ v: Double) -> String {
    v >= 10000 ? String(format: "%.1fk", v / 1000) : String(Int(v.rounded()))
}
