import Foundation

/// Sixteen weeks of believable training, used for screenshots and the review recording.
enum Demo {
    static func fill(_ s: Store) {
        s.templates = Store.starterTemplates
        s.unit = "kg"
        var seed: UInt64 = 11
        func rnd() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double(seed >> 33 % 1000) / 1000 }
        let base: [String: Double] = ["Squat": 90, "Bench press": 70, "Deadlift": 120, "Barbell row": 60, "Overhead press": 42.5, "Romanian deadlift": 80, "Lat pulldown": 55, "Leg press": 160, "Dumbbell curl": 14, "Leg curl": 40, "Calf raise": 60, "Pull-up": 0, "Plank": 0]
        let cal = Calendar.current
        var sessions: [Session] = []
        for w in stride(from: 16, through: 1, by: -1) {
            for (ti, off) in [(0, 0), (1, 2), (2, 4)] {
                let t = s.templates[ti]
                let date = cal.date(byAdding: .day, value: -(w * 7 - off), to: cal.date(bySettingHour: 18, minute: 5, second: 0, of: .now)!)!
                let prog = Double(16 - w) * 1.25
                let ex = t.exercises.map { e -> ExerciseEntry in
                    let b = base[e.name] ?? 0
                    let sets = (0..<e.sets).map { i -> SetEntry in
                        let heavy = b > 50
                        let wt = b > 0 ? ((b + prog * (heavy ? 2 : 1) - Double(i) * (heavy ? 2.5 : 0)) / 2.5).rounded() * 2.5 : 0
                        var reps = e.reps + (rnd() < 0.3 ? 1 : 0)
                        if i == e.sets - 1 && rnd() < 0.3 { reps -= 1 }
                        return SetEntry(weight: wt, reps: reps, done: true)
                    }
                    return ExerciseEntry(name: e.name, sets: sets)
                }
                sessions.append(Session(name: t.name, date: date, minutes: 50 + Int(rnd() * 20), exercises: ex))
            }
        }
        s.sessions = sessions
        // A workout in progress, two sets in, beating last week.
        var live = Session(name: "Upper A", exercises: s.templates[0].exercises.map { e in ExerciseEntry(name: e.name, sets: (0..<e.sets).map { _ in SetEntry() }) })
        live.exercises[0].sets = [SetEntry(weight: 110, reps: 6, done: true), SetEntry(weight: 110, reps: 6, done: true), SetEntry(weight: 107.5, reps: 6, done: false), SetEntry()]
        live.exercises[1].sets[0] = SetEntry(weight: 100, reps: 8, done: true)
        s.live = live
        s.liveStart = cal.date(byAdding: .minute, value: -22, to: .now)
    }
}
