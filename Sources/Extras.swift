import ActivityKit
import HealthKit
import SwiftUI
import UserNotifications
import WidgetKit

// MARK: - Exercise picker

/// Pick a lift from the common ones, the person's own, or type a new one.
struct ExercisePicker: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let pick: (String) -> Void
    @State private var query = ""
    static let common: [(String, [String])] = [
        ("Push", ["Bench press", "Incline bench press", "Overhead press", "Dumbbell bench press", "Incline dumbbell press", "Dip", "Push-up", "Lateral raise", "Triceps pushdown", "Skull crusher"]),
        ("Pull", ["Deadlift", "Barbell row", "Pull-up", "Chin-up", "Lat pulldown", "Seated cable row", "One-arm row", "Face pull", "Dumbbell curl", "Hammer curl"]),
        ("Legs", ["Squat", "Front squat", "Romanian deadlift", "Leg press", "Bulgarian split squat", "Walking lunge", "Hip thrust", "Leg curl", "Leg extension", "Calf raise"]),
        ("Core", ["Plank", "Hanging leg raise", "Cable crunch", "Ab wheel"]),
    ]
    var body: some View {
        NavigationStack {
            ZStack {
                BoardBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        TextField("Search or type a new lift", text: $query).font(.chalk(17, .bold)).foregroundStyle(Chalk.white)
                            .padding(14).background(RoundedRectangle(cornerRadius: 12).fill(Chalk.slate)).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Chalk.line))
                            .submitLabel(.done).onSubmit { choose(query) }
                        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
                        let mine = store.exerciseNames.filter { q.isEmpty || $0.lowercased().contains(q) }
                        if !q.isEmpty && !(mine + ExercisePicker.common.flatMap(\.1)).contains(where: { $0.lowercased() == q }) {
                            Button { choose(query) } label: { Label("Add \"\(query)\"", systemImage: "plus").font(.chalk(15, .black)).foregroundStyle(Chalk.red) }.buttonStyle(.plain)
                        }
                        if !mine.isEmpty { section("Your lifts", mine) }
                        ForEach(ExercisePicker.common, id: \.0) { g in
                            let hits = g.1.filter { (q.isEmpty || $0.lowercased().contains(q)) && !mine.contains($0) }
                            if !hits.isEmpty { section(g.0, hits) }
                        }
                    }.padding(18)
                }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.foregroundStyle(Chalk.dust) } }
        }
    }
    func section(_ title: String, _ names: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(title)
            FlowRow(names: names) { choose($0) }
        }
    }
    func choose(_ n: String) {
        let name = n.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        pick(name); dismiss()
    }
}

/// Chalk chips that wrap.
struct FlowRow: View {
    let names: [String]
    let tap: (String) -> Void
    var body: some View {
        Wrap(spacing: 8) {
            ForEach(names, id: \.self) { n in
                Button { tap(n) } label: {
                    Text(n).font(.chalk(13, .bold)).foregroundStyle(Chalk.white).padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Capsule().fill(Chalk.slate)).overlay(Capsule().strokeBorder(Chalk.line))
                }.buttonStyle(.plain)
            }
        }
    }
}

struct Wrap: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? 360
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for s in subviews {
            let d = s.sizeThatFits(.unspecified)
            if x + d.width > w && x > 0 { x = 0; y += row + spacing; row = 0 }
            x += d.width + spacing; row = max(row, d.height)
        }
        return CGSize(width: w, height: y + row)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for s in subviews {
            let d = s.sizeThatFits(.unspecified)
            if x + d.width > bounds.maxX && x > bounds.minX { x = bounds.minX; y += row + spacing; row = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(d))
            x += d.width + spacing; row = max(row, d.height)
        }
    }
}

// MARK: - Settings

struct SettingsSheet: View {
    @Environment(Store.self) private var store
    @Environment(Pro.self) private var pro
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var csv: URL? = nil
    var body: some View {
        @Bindable var store = store
        NavigationStack {
            ZStack {
                BoardBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Tape(text: "Settings")
                        VStack(alignment: .leading, spacing: 14) {
                            HStack { Eyebrow("Units"); Spacer()
                                Picker("Unit", selection: $store.unit) { Text("kg").tag("kg"); Text("lb").tag("lb") }.pickerStyle(.segmented).frame(width: 140)
                            }
                            Stepper("Weekly goal: \(store.weeklyGoal) sessions", value: $store.weeklyGoal, in: 1...7).font(.chalk(15, .bold)).foregroundStyle(Chalk.white)
                            Stepper("Default rest: \(store.restSeconds / 60):\(String(format: "%02d", store.restSeconds % 60))", value: $store.restSeconds, in: 30...300, step: 15).font(.chalk(15, .bold)).foregroundStyle(Chalk.white)
                        }.slate()
                        .onChange(of: store.unit) { store.save() }
                        .onChange(of: store.weeklyGoal) { store.save() }
                        .onChange(of: store.restSeconds) { store.save() }

                        Button { dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { router.showShop = true } } label: {
                            HStack(spacing: 12) {
                                HStack(spacing: 3) { ForEach(TapePalette.all) { p in Rectangle().fill(p.tape).frame(width: 10, height: 28) } }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Tape, blocks and extras").font(.slab(17)).italic().foregroundStyle(Chalk.white)
                                    Text("Next Block \(store.blockCredits) · posters \(store.posterCredits) · shields \(store.shieldCredits)").font(.chalk(12, .medium)).foregroundStyle(Chalk.dust)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 13, weight: .black)).foregroundStyle(Chalk.red)
                            }.slate(padding: 14)
                        }.buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 14) {
                            HStack { Eyebrow("Pro"); Spacer(); if !pro.unlocked { Tape(text: "Pro", tilt: 3) } }
                            Toggle(isOn: Binding(get: { store.healthOn }, set: { on in
                                guard pro.unlocked else { dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { pro.ask(.health) }; return }
                                if on { Task { if await HealthLog.authorize() { store.healthOn = true; store.save() } } } else { store.healthOn = false; store.save() }
                            })) { Text("Save workouts to Apple Health").font(.chalk(15, .bold)).foregroundStyle(Chalk.white) }.tint(Chalk.red)
                            Text("Each finished workout is written to Health as traditional strength training, with its start and end time. Ironbook reads nothing from Health.").font(.chalk(11.5, .medium)).foregroundStyle(Chalk.faint)
                            if pro.unlocked, let csv {
                                ShareLink(item: csv) { Label("Export every set as CSV", systemImage: "tablecells").font(.chalk(14, .black)).foregroundStyle(Chalk.red) }
                            } else if !pro.unlocked {
                                Button { dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { pro.ask(.export) } } label: { Label("Export every set as CSV", systemImage: "tablecells").font(.chalk(14, .black)).foregroundStyle(Chalk.dust) }.buttonStyle(.plain)
                            }
                        }.slate()

                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow("Widgets and the rest timer")
                            Text("Touch and hold the Home Screen, tap Edit, then Add Widget, and pick Ironbook. The small week widget is free; the bigger one comes with Pro. The rest timer shows on the Lock Screen and in the Dynamic Island while it runs.").font(.chalk(13, .medium)).foregroundStyle(Chalk.dust)
                        }.slate()

                        ProCard()
                        Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") · No account, no ads, no tracking.").font(.chalk(11, .bold)).foregroundStyle(Chalk.faint)
                    }.padding(18)
                }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() }.foregroundStyle(Chalk.dust) } }
        }
        .task {
            let u = URL.temporaryDirectory.appending(path: "Ironbook export.csv")
            try? store.exportCSV().write(to: u, atomically: true, encoding: .utf8)
            csv = u
        }
    }
}

// MARK: - Shop

/// The 99-cent corner. Next Block, PR Posters and Week Shields get used up; tape colours and Fireworks are for good.
struct ShopSheet: View {
    @Environment(Store.self) private var store
    @Environment(Pro.self) private var pro
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var current = TapePalette.current.id
    @State private var burst = 0
    var body: some View {
        NavigationStack {
            ZStack {
                BoardBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Tape(text: "The extras shelf")
                        Text("Small things, \(pro.price(Pro.blockID)) each.").font(.slab(30)).italic().foregroundStyle(Chalk.white)
                        Eyebrow("Used up as you go")
                        credit(icon: "square.stack.3d.up.fill", title: "Next Block", detail: "Four weeks of a template with a target on every lift, worked out from your own best numbers. One credit, one block.", have: store.blockCredits, id: Pro.blockID)
                        credit(icon: "photo.artframe", title: "PR Posters ×3", detail: "A gold chalkboard poster of a new PR, made to share. Three per pack.", have: store.posterCredits, id: Pro.posterID)
                        credit(icon: "shield.lefthalf.filled", title: "Week Shield", detail: "Keeps your weekly streak when a week comes up short. One free every month; this is for the extra.", have: store.shieldCredits, id: Pro.shieldID)
                        Eyebrow("Yours for good")
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(TapePalette.all) { p in tapeCard(p) }
                        }
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles").font(.system(size: 18, weight: .black)).foregroundStyle(Chalk.gold)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("PR Fireworks").font(.slab(18)).italic().foregroundStyle(Chalk.white)
                                Text("Gold fireworks over every PR. Chalk dust stays free.").font(.chalk(12, .medium)).foregroundStyle(Chalk.dust)
                            }
                            Spacer()
                            if pro.ownsFireworks { Button { burst += 1 } label: { Text("Try").font(.chalk(12, .black)).foregroundStyle(Chalk.gold) }.buttonStyle(.plain) }
                            else { priceTag(Pro.fireworksID) { burst += 1 } }
                        }.slate()
                        if let m = pro.message { Text(m).font(.chalk(12, .semibold)).foregroundStyle(Chalk.gold) }
                        Text("Credits never expire. Everything restores from Settings, except credits already used.").font(.chalk(11, .medium)).foregroundStyle(Chalk.faint)
                    }.padding(18)
                }
                Celebration(trigger: burst, fireworks: pro.ownsFireworks).allowsHitTesting(false).ignoresSafeArea()
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() }.foregroundStyle(Chalk.dust) } }
        }
        .task { await pro.loadProducts() }
    }

    func credit(icon: String, title: String, detail: String, have: Int, id: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 17, weight: .black)).foregroundStyle(Chalk.board)
                .frame(width: 40, height: 40).background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Chalk.gold))
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(title).font(.slab(18)).italic().foregroundStyle(Chalk.white)
                    if have > 0 { Text("\(have) left").font(.chalk(10, .black)).foregroundStyle(Chalk.gold) }
                }
                Text(detail).font(.chalk(12, .medium)).foregroundStyle(Chalk.dust).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            priceTag(id) {}
        }.slate()
    }

    func priceTag(_ id: String, after: @escaping () -> Void) -> some View {
        Button { Task { if await pro.buy(id) { after() } } } label: {
            Group { if pro.busyID == id { ProgressView().tint(Chalk.board) } else { Text(pro.price(id)).font(.chalk(13, .black)) } }
                .foregroundStyle(Chalk.board).padding(.horizontal, 12).padding(.vertical, 8).background(Capsule().fill(Chalk.gold))
        }.buttonStyle(.plain).disabled(pro.busy)
    }

    func tapeCard(_ p: TapePalette) -> some View {
        let owned = pro.ownsTheme(p.id), on = current == p.id
        return Button {
            if owned { use(p) } else { Task { if await pro.buy(Pro.themeID(p.id)) { use(p) } } }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text("IRONBOOK").font(.chalk(12, .black)).tracking(2).foregroundStyle(p.id == "bone" ? Chalk.board : Chalk.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Rectangle().fill(LinearGradient(colors: [p.tape, p.deep], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .rotationEffect(.degrees(-3))
                HStack {
                    Text(p.name).font(.slab(17)).italic().foregroundStyle(Chalk.white)
                    Spacer()
                    if on { Image(systemName: "checkmark.circle.fill").foregroundStyle(p.tape) }
                    else if owned { Text("Use").font(.chalk(12, .black)).foregroundStyle(p.tape) }
                    else if pro.busyID == Pro.themeID(p.id) { ProgressView().tint(p.tape) }
                    else { Text(pro.price(Pro.themeID(p.id))).font(.chalk(11, .black)).foregroundStyle(Chalk.board).padding(.horizontal, 8).padding(.vertical, 4).background(Capsule().fill(Chalk.gold)) }
                }
                Text(p.blurb).font(.chalk(11, .medium)).foregroundStyle(Chalk.dust).lineLimit(1)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Chalk.slate))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(on ? p.tape : Chalk.line, lineWidth: on ? 2 : 1))
        }.buttonStyle(.plain).disabled(pro.busy)
    }

    func use(_ p: TapePalette) {
        TapePalette.apply(p.id)
        current = p.id
        if !router.demo, UIApplication.shared.supportsAlternateIcons, UIApplication.shared.alternateIconName != p.icon {
            UIApplication.shared.setAlternateIconName(p.icon)
        }
        WidgetCenter.shared.reloadAllTimelines()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        router.themeTick += 1
    }
}

// MARK: - Next Block

struct BlockSheet: View {
    @Environment(Store.self) private var store
    @Environment(Pro.self) private var pro
    @Environment(\.dismiss) private var dismiss
    @State private var chosen: UUID? = nil
    @State private var built = false
    var body: some View {
        let bases = store.templates.filter { $0.block == nil && store.canBuildBlock($0) }
        let base = bases.first { $0.id == chosen } ?? bases.first
        NavigationStack {
            ZStack {
                BoardBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Tape(text: "Next Block")
                        Text(built ? "Four weeks, on the board." : "Four weeks of targets,\nfrom your own numbers.").font(.slab(28)).italic().foregroundStyle(Chalk.white).fixedSize(horizontal: false, vertical: true)
                        if bases.isEmpty {
                            Text("Log a template once with weights and reps. Next Block works from your best estimated one-rep max on each lift, so it needs a number to start from.")
                                .font(.chalk(14, .medium)).foregroundStyle(Chalk.dust).slate()
                        } else if let base {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(bases) { t in
                                        Button { chosen = t.id; built = false } label: {
                                            Text(t.name).font(.chalk(13, .black)).foregroundStyle(t.id == base.id ? Chalk.board : Chalk.dust)
                                                .padding(.horizontal, 14).padding(.vertical, 9).background(Capsule().fill(t.id == base.id ? Chalk.white : Chalk.slate))
                                        }.buttonStyle(.plain)
                                    }
                                }
                            }
                            let weeks = store.blockPreview(base)
                            ForEach(Array(weeks.enumerated()), id: \.offset) { i, w in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(Store.blockWeeks[i].name.uppercased()).font(.chalk(11, .black)).tracking(1.5).foregroundStyle(i == 3 ? Chalk.green : Chalk.gold)
                                        Spacer()
                                        Text("\(Int(Store.blockWeeks[i].pct * 100))% of est. 1RM").font(.mono(10)).foregroundStyle(Chalk.faint)
                                    }
                                    ForEach(w.exercises) { e in
                                        HStack {
                                            Text(e.name).font(.chalk(13, .bold)).foregroundStyle(Chalk.white)
                                            Spacer()
                                            Text("\(e.sets)×\(e.reps)" + (e.target.map { " @ \(fmtWeight($0)) \(store.unit)" } ?? "")).font(.mono(12)).foregroundStyle(e.target == nil ? Chalk.faint : Chalk.dust)
                                        }
                                    }
                                }
                                .slate(padding: 14)
                                .blur(radius: built || store.blockCredits > 0 || i == 0 ? 0 : 4)
                            }
                            if built {
                                TapeButton(title: "Done", icon: "checkmark") { dismiss() }
                            } else if store.blockCredits > 0 {
                                TapeButton(title: "Put it on the board (\(store.blockCredits) credit\(store.blockCredits == 1 ? "" : "s"))", icon: "square.stack.3d.up.fill", fill: Chalk.gold) {
                                    if store.buildBlock(base) { UINotificationFeedbackGenerator().notificationOccurred(.success); withAnimation(.spring) { built = true } }
                                }
                            } else {
                                TapeButton(title: "Build it · \(pro.price(Pro.blockID))", icon: "square.stack.3d.up.fill", fill: Chalk.gold) {
                                    Task { if await pro.buy(Pro.blockID), store.buildBlock(base) { withAnimation(.spring) { built = true } } }
                                }
                                Text("Week one is the preview. One credit puts all four weeks in your templates, each lift loaded. Lifts you haven't logged yet keep their plain sets.").font(.chalk(11.5, .medium)).foregroundStyle(Chalk.faint)
                            }
                            if let m = pro.message { Text(m).font(.chalk(12, .semibold)).foregroundStyle(Chalk.gold) }
                        }
                    }.padding(18)
                }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.foregroundStyle(Chalk.dust) } }
        }
        .task { await pro.loadProducts() }
    }
}

// MARK: - Finish

/// After Finish workout: the numbers, the PRs, and a poster for the best one.
struct FinishSheet: View {
    @Environment(Store.self) private var store
    @Environment(Pro.self) private var pro
    @Environment(\.dismiss) private var dismiss
    let session: Session?
    let prs: [PRHit]
    @State private var poster: UIImage? = nil
    @State private var burst = 0
    var body: some View {
        ZStack {
            BoardBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Tape(text: prs.isEmpty ? "Logged" : "New PR", tilt: -2).padding(.top, 30)
                    Text(prs.isEmpty ? "In the book." : prs.count == 1 ? "A new best." : "\(prs.count) new bests.").font(.slab(40)).italic().foregroundStyle(Chalk.white)
                    if let s = session {
                        HStack(spacing: 18) {
                            Figure(value: "\(s.setCount)", unit: "sets", size: 26)
                            Figure(value: fmtVolume(s.volume), unit: store.unit, size: 26)
                            Figure(value: "\(s.minutes)", unit: "min", size: 26)
                        }
                    }
                    ForEach(prs) { p in
                        HStack(spacing: 14) {
                            PRBadge().scaleEffect(1.3).frame(width: 40, height: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name).font(.slab(19)).italic().foregroundStyle(Chalk.white)
                                Text("\(fmtWeight(p.weight)) × \(p.reps) · est. 1RM \(fmtWeight(p.e1rm.rounded())) \(store.unit)" + (p.gain > 0 ? " · +\(fmtWeight(p.gain.rounded()))" : "")).font(.mono(12)).foregroundStyle(Chalk.dust)
                            }
                        }.slate(padding: 14)
                    }
                    let goalLeft = store.weeklyGoal - store.sessionsIn(weekOf: .now)
                    Text(goalLeft > 0 ? "\(goalLeft) more this week for the goal." : "Weekly goal hit. \(store.streakWeeks)-week streak.").font(.chalk(14, .black)).foregroundStyle(goalLeft > 0 ? Chalk.dust : Chalk.gold)
                    if let top = prs.first {
                        if let poster {
                            Image(uiImage: poster).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 14)).shadow(color: Chalk.gold.opacity(0.3), radius: 20)
                            ShareLink(item: Image(uiImage: poster), preview: SharePreview("\(top.name) PR", image: Image(uiImage: poster))) {
                                Label("Share the poster", systemImage: "square.and.arrow.up").font(.chalk(14, .black)).tracking(1).foregroundStyle(Chalk.board)
                                    .frame(maxWidth: .infinity).padding(.vertical, 15).background(RoundedRectangle(cornerRadius: 12).fill(Chalk.gold))
                            }
                        } else {
                            TapeButton(title: store.posterCredits > 0 ? "Make a PR poster (\(store.posterCredits) left)" : "PR poster ×3 · \(pro.price(Pro.posterID))", icon: "photo.artframe", fill: Chalk.gold) {
                                Task {
                                    if store.posterCredits == 0 { guard await pro.buy(Pro.posterID) else { return } }
                                    guard store.posterCredits > 0 else { return }
                                    store.posterCredits -= 1; store.save()
                                    poster = PosterView.render(pr: top, unit: store.unit)
                                }
                            }
                            if let m = pro.message { Text(m).font(.chalk(12, .semibold)).foregroundStyle(Chalk.gold) }
                        }
                    }
                    GhostButton(title: "Done", icon: "checkmark") { dismiss() }
                }.padding(20)
            }
            Celebration(trigger: burst, fireworks: pro.ownsFireworks).allowsHitTesting(false).ignoresSafeArea()
        }
        .onAppear {
            if !prs.isEmpty { UINotificationFeedbackGenerator().notificationOccurred(.success); burst += 1 }
            if ProcessInfo.processInfo.arguments.contains("poster"), let p = prs.first { poster = PosterView.render(pr: p, unit: store.unit) }
        }
    }
}

/// The PR poster: gold starburst on a chalkboard, the lift and the number.
struct PosterView: View {
    let pr: PRHit
    let unit: String
    var body: some View {
        ZStack {
            BoardBackground()
            Star(points: 18, inner: 0.82).fill(Chalk.gold.opacity(0.14)).frame(width: 520, height: 520).offset(x: 120, y: -170)
            VStack(alignment: .leading, spacing: 16) {
                Tape(text: "Personal record", tilt: -3)
                Text(pr.name).font(.system(size: 46, weight: .black, design: .rounded)).italic().foregroundStyle(Chalk.white).lineLimit(2).minimumScaleFactor(0.6)
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(fmtWeight(pr.weight)).font(.system(size: 120, weight: .black, design: .rounded)).foregroundStyle(Chalk.gold)
                    Text("\(unit) × \(pr.reps)").font(.system(size: 34, weight: .black, design: .rounded)).foregroundStyle(Chalk.white)
                }
                Text("est. one-rep max \(fmtWeight(pr.e1rm.rounded())) \(unit)" + (pr.gain > 0 ? "   +\(fmtWeight(pr.gain.rounded())) on the old best" : "")).font(.system(size: 18, weight: .bold, design: .monospaced)).foregroundStyle(Chalk.dust)
                Spacer()
                HStack {
                    Text(Date.now.formatted(date: .long, time: .omitted)).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(Chalk.faint)
                    Spacer()
                    Text("IRONBOOK").font(.system(size: 14, weight: .black, design: .rounded)).tracking(3).foregroundStyle(Chalk.faint)
                }
            }.padding(44)
            PRBadge().scaleEffect(3.2).position(x: 520, y: 120)
        }
        .frame(width: 600, height: 750)
    }
    @MainActor static func render(pr: PRHit, unit: String) -> UIImage? {
        let r = ImageRenderer(content: PosterView(pr: pr, unit: unit))
        r.scale = 2
        return r.uiImage
    }
}

/// Chalk dust bursts on a PR, free. The Fireworks pack adds gold fireworks.
struct Celebration: View {
    let trigger: Int
    let fireworks: Bool
    @State private var start: Date? = nil
    var body: some View {
        TimelineView(.animation(paused: start == nil)) { tl in
            Canvas { ctx, size in
                guard let start else { return }
                let t = tl.date.timeIntervalSince(start)
                guard t < 2.6 else { return }
                var seed: UInt64 = 9
                func r() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double((seed >> 33) % 10_000) / 10_000 }
                if fireworks {
                    for b in 0..<5 {
                        let cx = size.width * (0.15 + r() * 0.7), cy = size.height * (0.12 + r() * 0.35)
                        let lt = t - Double(b) * 0.22
                        guard lt > 0 else { continue }
                        let col: Color = b % 2 == 0 ? Chalk.gold : Chalk.red
                        for _ in 0..<36 {
                            let a = r() * .pi * 2, sp = 110 + r() * 170
                            let x = cx + cos(a) * sp * lt, y = cy + sin(a) * sp * lt + 100 * lt * lt
                            var c = ctx; c.opacity = max(0, 1 - lt / 1.7)
                            c.fill(Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6)), with: .color(col))
                        }
                    }
                } else {
                    // A clap of chalk: dust puffs from the bottom and drifts.
                    for _ in 0..<140 {
                        let x0 = size.width * (0.3 + r() * 0.4), a = -.pi / 2 + (r() - 0.5) * 2.2, sp = 160 + r() * 360
                        let x = x0 + cos(a) * sp * t, y = size.height * 0.92 + sin(a) * sp * t + 220 * t * t
                        let s = 2 + r() * 5
                        var c = ctx; c.opacity = max(0, 0.8 - t / 2.6)
                        c.fill(Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)), with: .color(Chalk.white))
                    }
                }
            }
        }
        .onChange(of: trigger) { _, _ in start = .now; DispatchQueue.main.asyncAfter(deadline: .now() + 2.7) { start = nil } }
    }
}

// MARK: - Lift history (Pro)

struct LiftHistorySheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let name: String
    var body: some View {
        let rows = store.history(name)
        NavigationStack {
            ZStack {
                BoardBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Tape(text: "Every session")
                        Text(name).font(.slab(32)).italic().foregroundStyle(Chalk.white)
                        Text("\(rows.count) sessions · best est. 1RM \(fmtWeight(store.bestE1RM(name).rounded())) \(store.unit)").font(.chalk(13, .bold)).foregroundStyle(Chalk.dust)
                        ForEach(rows, id: \.0.id) { s, e in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(s.date.formatted(.dateTime.day().month(.abbreviated).year())).font(.digits(14, .black)).foregroundStyle(Chalk.white)
                                    Spacer()
                                    Text("est. \(fmtWeight(e.best.rounded()))").font(.mono(11)).foregroundStyle(Chalk.faint)
                                }
                                Text(e.work.map { "\(fmtWeight($0.weight ?? 0))×\($0.reps ?? 0)" }.joined(separator: "  ")).font(.mono(13)).foregroundStyle(Chalk.dust)
                                if !e.note.isEmpty { Text(e.note).font(.chalk(12, .medium)).italic().foregroundStyle(Chalk.dust) }
                            }.slate(padding: 12, radius: 12)
                        }
                    }.padding(18)
                }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.foregroundStyle(Chalk.dust) } }
        }
    }
}

// MARK: - Apple Health

/// Write-only: a finished workout becomes a strength-training workout in Health. Nothing is read.
@MainActor
enum HealthLog {
    static let store = HKHealthStore()
    static func authorize() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        do { try await store.requestAuthorization(toShare: [HKObjectType.workoutType()], read: []); return true } catch { return false }
    }
    static func save(_ s: Session) async {
        guard HKHealthStore.isHealthDataAvailable(), store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        let b = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        let end = s.date, start = end.addingTimeInterval(-Double(max(1, s.minutes)) * 60)
        do {
            try await b.beginCollection(at: start)
            try await b.addMetadata([HKMetadataKeyWorkoutBrandName: "Ironbook"])
            try await b.endCollection(at: end)
            _ = try await b.finishWorkout()
        } catch {}
    }
}

// MARK: - Rest timer off screen

/// The rest timer on the Lock Screen and in the Dynamic Island, and a buzz when it's up.
@MainActor
enum RestLive {
    static func start(end: Date, workout: String, next: String) {
        let state = RestAttributes.ContentState(end: end, start: .now, next: next)
        if let a = Activity<RestAttributes>.activities.first {
            Task { await a.update(ActivityContent(state: state, staleDate: end.addingTimeInterval(60))) }
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            _ = try? Activity<RestAttributes>.request(attributes: RestAttributes(workout: workout), content: ActivityContent(state: state, staleDate: end.addingTimeInterval(60)), pushType: nil)
        }
        let c = UNUserNotificationCenter.current()
        c.removePendingNotificationRequests(withIdentifiers: ["rest"])
        c.getNotificationSettings { s in
            guard s.authorizationStatus == .authorized else { return }
            let n = UNMutableNotificationContent()
            n.title = "Rest's up"
            n.body = next.isEmpty ? "Next set." : "Next: \(next)"
            n.sound = .default
            c.add(UNNotificationRequest(identifier: "rest", content: n, trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, end.timeIntervalSinceNow), repeats: false)))
        }
    }
    static func stop() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rest"])
        for a in Activity<RestAttributes>.activities { Task { await a.end(nil, dismissalPolicy: .immediate) } }
    }
    /// Asked once, the first time a rest timer starts.
    static func askOnce() {
        guard !UserDefaults.standard.bool(forKey: "ironbook.askedNotify") else { return }
        UserDefaults.standard.set(true, forKey: "ironbook.askedNotify")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}

// MARK: - Screenshot only

/// The widgets on a home screen, for the store screenshot. The real widgets draw the same views.
struct WidgetShowcase: View {
    @Environment(Store.self) private var store
    var body: some View {
        let snap = store.snapshot(pro: true)
        ZStack {
            LinearGradient(colors: [Chalk.redDeep, Color(red: 0.07, green: 0.06, blue: 0.06), Chalk.board], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            VStack(spacing: 24) {
                VStack(spacing: 2) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day())).font(.chalk(17, .semibold)).foregroundStyle(.white.opacity(0.8))
                    Text("9:41").font(.system(size: 84, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.9))
                }.padding(.top, 50)
                RestLockPreview().padding(.horizontal, 18)
                HStack(spacing: 22) {
                    tile(WeekSmallView(snap: snap), w: 170, h: 170)
                    VStack(spacing: 14) {
                        ForEach(0..<2, id: \.self) { _ in HStack(spacing: 14) { ForEach(0..<2, id: \.self) { _ in RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.12)).frame(width: 64, height: 64) } } }
                    }
                }
                tile(WeekMediumView(snap: snap), w: 364, h: 170)
                Spacer()
            }
        }
    }
    func tile<V: View>(_ v: V, w: CGFloat, h: CGFloat) -> some View {
        v.padding(16).frame(width: w, height: h, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Chalk.board))
            .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
    }
}

/// What the rest Live Activity looks like on the Lock Screen, drawn in-app for the screenshot.
struct RestLockPreview: View {
    var body: some View {
        RestLockView(workout: "Upper A", state: RestAttributes.ContentState(end: .now.addingTimeInterval(74), start: .now.addingTimeInterval(-16), next: "Bench press, set 3"))
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Chalk.slate.opacity(0.92)))
    }
}
