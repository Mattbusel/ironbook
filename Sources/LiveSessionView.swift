import SwiftUI

/// The workout in progress. Every set shows what you did last time so you know what to beat.
struct LiveSessionView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var restEnd: Date? = nil
    @State private var now = Date.now
    @State private var addingExercise = false
    @State private var newName = ""
    @State private var finished: [String]? = nil
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        @Bindable var store = store
        ZStack {
            BoardBackground()
            if store.live != nil {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        ForEach(Array((store.live?.exercises ?? []).enumerated()), id: \.element.id) { ei, ex in
                            exerciseCard(ei, ex)
                        }
                        GhostButton(title: "Add exercise", icon: "plus") { newName = ""; addingExercise = true }
                        HStack(spacing: 10) {
                            GhostButton(title: "Discard", icon: "trash") { store.discard(); dismiss() }
                            TapeButton(title: "Finish workout", icon: "flag.checkered", fill: Chalk.gold) {
                                let prs = store.finish(); finished = prs
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding(18).padding(.bottom, 120)
                }
            }
            if router.showTimer || restEnd != nil { restOverlay }
        }
        .onReceive(clock) { now = $0 }
        .onAppear { if router.showTimer && restEnd == nil { restEnd = Date.now.addingTimeInterval(67) } }
        .alert("Add exercise", isPresented: $addingExercise) {
            TextField("Name", text: $newName)
            Button("Add") { if !newName.isEmpty { store.live?.exercises.append(ExerciseEntry(name: newName, sets: [SetEntry(), SetEntry(), SetEntry()])); store.save() } }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Saved", isPresented: Binding(get: { finished != nil }, set: { if !$0 { finished = nil; dismiss() } })) {
            Button("Done") { finished = nil; dismiss() }
        } message: {
            Text((finished ?? []).isEmpty ? "Workout logged." : "PR on " + (finished ?? []).joined(separator: ", ") + "!")
        }
        .cueSink { cue in handle(cue) }
    }

    var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Tape(text: elapsed, tilt: -1)
                TextField("Name", text: Binding(get: { store.live?.name ?? "" }, set: { store.live?.name = $0 })).font(.slab(32)).italic().foregroundStyle(Chalk.white)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "chevron.down").font(.system(size: 15, weight: .black)).foregroundStyle(Chalk.dust).frame(width: 38, height: 38).background(Circle().fill(Chalk.slate)).overlay(Circle().strokeBorder(Chalk.line))
            }.buttonStyle(.plain)
        }
        .padding(.top, 6)
    }

    var elapsed: String {
        let s = Int(now.timeIntervalSince(store.liveStart ?? now))
        return String(format: "%d:%02d elapsed", s / 60, s % 60)
    }

    func exerciseCard(_ ei: Int, _ ex: ExerciseEntry) -> some View {
        let last = store.lastSets(ex.name)
        let best = store.bestE1RM(ex.name)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(ex.name).font(.slab(21)).italic().foregroundStyle(Chalk.white)
                Spacer()
                if last.isEmpty { Text("first time").font(.chalk(11, .bold)).foregroundStyle(Chalk.faint) }
                else { Text("last " + last.map { "\(fmtWeight($0.weight ?? 0))×\($0.reps ?? 0)" }.joined(separator: " ")).font(.mono(11)).foregroundStyle(Chalk.faint).lineLimit(1) }
            }
            HStack(spacing: 8) {
                Text("SET").frame(width: 30, alignment: .leading)
                Text("LAST").frame(width: 68, alignment: .leading)
                Text(store.unit.uppercased()).frame(maxWidth: .infinity)
                Text("REPS").frame(width: 66)
                Text("").frame(width: 44)
            }
            .font(.chalk(10, .black)).tracking(1.2).foregroundStyle(Chalk.faint)
            ForEach(Array(ex.sets.enumerated()), id: \.element.id) { si, st in
                setRow(ei, si, st, last: si < last.count ? last[si] : nil, best: best)
            }
            HStack {
                Button { store.live?.exercises[ei].sets.append(SetEntry()); store.save() } label: {
                    Label("Set", systemImage: "plus").font(.chalk(12, .black)).foregroundStyle(Chalk.dust)
                }.buttonStyle(.plain)
                Spacer()
                Button { store.live?.exercises.remove(at: ei); store.save() } label: {
                    Text("remove").font(.chalk(11, .bold)).foregroundStyle(Chalk.faint)
                }.buttonStyle(.plain)
            }
        }
        .slate()
    }

    func setRow(_ ei: Int, _ si: Int, _ st: SetEntry, last: SetEntry?, best: Double) -> some View {
        let isPR = st.done && st.e1rm > best && st.e1rm > 0
        return HStack(spacing: 8) {
            Text("\(si + 1)").font(.digits(15)).foregroundStyle(Chalk.faint).frame(width: 30, alignment: .leading)
            Text(last.map { "\(fmtWeight($0.weight ?? 0)) × \($0.reps ?? 0)" } ?? "—").font(.mono(12)).foregroundStyle(Chalk.faint).frame(width: 68, alignment: .leading)
            numberField(placeholder: last.map { fmtWeight($0.weight ?? 0) } ?? "", value: Binding(
                get: { store.live?.exercises[ei].sets[si].weight },
                set: { store.live?.exercises[ei].sets[si].weight = $0; store.save() }))
            intField(placeholder: last.map { "\($0.reps ?? 0)" } ?? "", value: Binding(
                get: { store.live?.exercises[ei].sets[si].reps },
                set: { store.live?.exercises[ei].sets[si].reps = $0; store.save() }))
                .frame(width: 66)
            Button { toggle(ei, si, last: last) } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(st.done ? Chalk.green : Chalk.board)
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(st.done ? Chalk.green : Chalk.faint, lineWidth: 1.2))
                    if isPR { PRBadge().scaleEffect(0.8) } else { Image(systemName: "checkmark").font(.system(size: 15, weight: .black)).foregroundStyle(st.done ? Chalk.board : Chalk.faint) }
                }
                .frame(width: 44, height: 40)
            }.buttonStyle(.plain)
        }
    }

    func numberField(placeholder: String, value: Binding<Double?>) -> some View {
        TextField(placeholder, text: Binding(get: { value.wrappedValue.map { fmtWeight($0) } ?? "" }, set: { value.wrappedValue = Double($0) }))
            .keyboardType(.decimalPad).multilineTextAlignment(.center).font(.digits(17)).foregroundStyle(Chalk.white)
            .frame(height: 40).background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Chalk.board))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Chalk.line))
    }

    func intField(placeholder: String, value: Binding<Int?>) -> some View {
        TextField(placeholder, text: Binding(get: { value.wrappedValue.map { "\($0)" } ?? "" }, set: { value.wrappedValue = Int($0) }))
            .keyboardType(.numberPad).multilineTextAlignment(.center).font(.digits(17)).foregroundStyle(Chalk.white)
            .frame(height: 40).background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Chalk.board))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Chalk.line))
    }

    func toggle(_ ei: Int, _ si: Int, last: SetEntry?) {
        guard var s = store.live else { return }
        var st = s.exercises[ei].sets[si]
        if !st.done {
            if st.weight == nil { st.weight = last?.weight }
            if st.reps == nil { st.reps = last?.reps }
        }
        st.done.toggle()
        s.exercises[ei].sets[si] = st
        store.live = s; store.save()
        if st.done {
            restEnd = Date.now.addingTimeInterval(TimeInterval(store.restSeconds))
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    // MARK: rest timer

    var restOverlay: some View {
        let left = max(0, Int((restEnd ?? now).timeIntervalSince(now).rounded()))
        let total = Double(store.restSeconds)
        let frac = restEnd == nil ? 0 : min(1, Double(left) / total)
        return VStack {
            Spacer()
            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(Chalk.line, lineWidth: 5)
                    Circle().trim(from: 0, to: frac).stroke(left == 0 ? Chalk.green : Chalk.red, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90))
                    Text(left == 0 ? "GO" : String(format: "%d:%02d", left / 60, left % 60)).font(.digits(15, .black)).foregroundStyle(Chalk.white)
                }
                .frame(width: 58, height: 58)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rest").font(.chalk(11, .black)).tracking(1.5).foregroundStyle(Chalk.dust)
                    HStack(spacing: 6) {
                        ForEach([60, 90, 120, 180], id: \.self) { s in
                            Button { store.restSeconds = s; store.save(); restEnd = Date.now.addingTimeInterval(TimeInterval(s)) } label: {
                                Text(String(format: "%d:%02d", s / 60, s % 60)).font(.digits(12)).foregroundStyle(store.restSeconds == s ? Chalk.board : Chalk.dust)
                                    .padding(.horizontal, 8).padding(.vertical, 5).background(RoundedRectangle(cornerRadius: 7).fill(store.restSeconds == s ? Chalk.white : Chalk.board))
                            }.buttonStyle(.plain)
                        }
                    }
                }
                Spacer()
                Button { restEnd = nil; router.showTimer = false } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .black)).foregroundStyle(Chalk.dust).frame(width: 34, height: 34).background(Circle().fill(Chalk.board))
                }.buttonStyle(.plain)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Chalk.slateHi).shadow(color: .black.opacity(0.6), radius: 24, y: 10))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Chalk.line))
            .padding(.horizontal, 18).padding(.bottom, 24)
        }
        .onChange(of: left) { if left == 0 && restEnd != nil { UINotificationFeedbackGenerator().notificationOccurred(.success) } }
    }

    // MARK: autopilot cues

    func handle(_ cue: String) {
        guard var s = store.live else { return }
        let parts = cue.split(separator: ".").map(String.init)
        guard parts.count >= 2, parts[0] == "live" else { return }
        switch parts[1] {
        case "tick":
            let ei = Int(parts[2]) ?? 0, si = Int(parts[3]) ?? 0
            guard ei < s.exercises.count, si < s.exercises[ei].sets.count else { return }
            let last = store.lastSets(s.exercises[ei].name)
            let l = si < last.count ? last[si] : nil
            s.exercises[ei].sets[si].weight = (l?.weight ?? 40) + (parts.count > 4 ? Double(parts[4]) ?? 0 : 0)
            s.exercises[ei].sets[si].reps = l?.reps ?? 8
            store.live = s
            toggle(ei, si, last: l)
        case "finish":
            finished = store.finish()
        default: break
        }
    }
}

struct SessionDetailView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    let session: Session
    var body: some View {
        ZStack {
            BoardBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Tape(text: session.date.formatted(date: .abbreviated, time: .omitted))
                    Text(session.name).font(.slab(32)).italic().foregroundStyle(Chalk.white)
                    HStack(spacing: 18) {
                        Figure(value: "\(session.setCount)", unit: "sets", size: 24)
                        Figure(value: fmtVolume(session.volume), unit: store.unit, size: 24)
                        Figure(value: "\(session.minutes)", unit: "min", size: 24)
                    }
                    ForEach(session.exercises) { e in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(e.name).font(.chalk(16, .black)).foregroundStyle(Chalk.white)
                            Text(e.sets.map { "\(fmtWeight($0.weight ?? 0)) × \($0.reps ?? 0)" }.joined(separator: "   ")).font(.mono(13)).foregroundStyle(Chalk.dust)
                        }
                        .slate(padding: 12, radius: 12)
                    }
                    HStack(spacing: 10) {
                        GhostButton(title: "Delete", icon: "trash") { store.sessions.removeAll { $0.id == session.id }; store.save(); dismiss() }
                        TapeButton(title: "Repeat this workout", icon: "arrow.counterclockwise") { store.repeatSession(session); dismiss(); router.tab = .train; router.showLive = true }
                    }
                }
                .padding(18)
            }
        }
    }
}
