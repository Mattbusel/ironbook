import SwiftUI

struct TrainView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro

    var body: some View {
        Page {
            HStack(alignment: .bottom) {
                PageHeader(tape: "Ironbook", title: "Train.")
                Spacer()
                Button { router.showSettings = true } label: {
                    Image(systemName: "gearshape.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(Chalk.dust)
                        .frame(width: 40, height: 40).background(Circle().fill(Chalk.slate)).overlay(Circle().strokeBorder(Chalk.line))
                }.buttonStyle(.plain).accessibilityLabel("Settings")
            }

            if let live = store.live {
                Button { router.showLive = true } label: {
                    HStack(spacing: 14) {
                        Circle().fill(Chalk.green).frame(width: 10, height: 10).shadow(color: Chalk.green, radius: 6)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("In progress").font(.chalk(11, .bold)).tracking(1.5).foregroundStyle(Chalk.dust)
                            Text(live.name).font(.slab(22)).italic().foregroundStyle(Chalk.white)
                        }
                        Spacer()
                        Text("\(live.setCount) sets").font(.digits(15)).foregroundStyle(Chalk.dust)
                        Image(systemName: "chevron.right").font(.system(size: 14, weight: .black)).foregroundStyle(Chalk.red)
                    }
                    .slate()
                }
                .buttonStyle(.plain)
            }

            WeekCard()
            if let s = store.shieldable { ShieldCard(week: s.week, lost: s.lost) }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Eyebrow("Templates"); Spacer()
                    GhostButton(title: "Programs", icon: pro.unlocked ? "books.vertical" : "lock.fill") { router.showPrograms = true }
                    GhostButton(title: "New", icon: "plus") { newTemplate() }
                }
                ForEach(store.templates) { t in TemplateRow(template: t) }
                GhostButton(title: "Start blank", icon: "square.dashed") { store.start(nil); router.showLive = true }
            }

            BlockCard()
            PlateCard()
            ProCard()
        }
    }

    func newTemplate() {
        let t = Template(name: "New template", exercises: [TemplateExercise(name: "Squat", sets: 3, reps: 5)])
        store.templates.append(t); store.save(); router.editingTemplate = t
    }
}

struct TemplateRow: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    let template: Template
    var body: some View {
        let t = template
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if t.block != nil { Image(systemName: "square.stack.3d.up.fill").font(.system(size: 11, weight: .black)).foregroundStyle(Chalk.gold) }
                    Text(t.name).font(.slab(t.block == nil ? 20 : 17)).italic().foregroundStyle(Chalk.white).lineLimit(1)
                }
                Text(t.exercises.map { e in e.target.map { "\(e.name) \(fmtWeight($0))" } ?? e.name }.joined(separator: " · "))
                    .font(.chalk(12, .medium)).foregroundStyle(Chalk.dust).lineLimit(2)
            }
            Spacer(minLength: 8)
            Button { router.editingTemplate = t } label: {
                Image(systemName: "pencil").font(.system(size: 14, weight: .bold)).foregroundStyle(Chalk.dust).frame(width: 36, height: 36).overlay(Circle().strokeBorder(Chalk.line))
            }.buttonStyle(.plain).accessibilityLabel("Edit \(t.name)")
            Button { store.start(t); router.showLive = true } label: {
                Text("START").font(.chalk(12, .black)).tracking(1.5).foregroundStyle(Chalk.onTape).padding(.horizontal, 14).padding(.vertical, 10).background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Chalk.red))
            }.buttonStyle(.plain)
        }
        .slate(padding: 14)
        .overlay(alignment: .leading) { if t.block != nil { Rectangle().fill(Chalk.gold).frame(width: 3).padding(.vertical, 14) } }
    }
}

/// This week against the goal, the days trained, and the run of weeks.
struct WeekCard: View {
    @Environment(Store.self) private var store
    var body: some View {
        let done = store.sessionsIn(weekOf: .now), goal = store.weeklyGoal, days = store.daysThisWeek
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Chalk.line, lineWidth: 7)
                Circle().trim(from: 0, to: min(1, Double(done) / Double(max(1, goal))))
                    .stroke(done >= goal ? Chalk.gold : Chalk.red, style: StrokeStyle(lineWidth: 7, lineCap: .round)).rotationEffect(.degrees(-90))
                VStack(spacing: -2) {
                    Text("\(done)/\(goal)").font(.digits(17, .black)).foregroundStyle(Chalk.white)
                    Text("WEEK").font(.chalk(8, .black)).tracking(1).foregroundStyle(Chalk.faint)
                }
            }.frame(width: 66, height: 66)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    ForEach(0..<7, id: \.self) { i in
                        VStack(spacing: 3) {
                            RoundedRectangle(cornerRadius: 4).fill(days[i] ? Chalk.red : Chalk.board).frame(height: 18)
                                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Chalk.line))
                            Text(["M", "T", "W", "T", "F", "S", "S"][i]).font(.chalk(9, .black)).foregroundStyle(Chalk.faint)
                        }
                    }
                }
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill").font(.system(size: 12, weight: .black)).foregroundStyle(store.streakWeeks > 0 ? Chalk.gold : Chalk.faint)
                    Text(store.streakWeeks > 0 ? "\(store.streakWeeks)-week streak" : done >= goal ? "Goal hit this week" : "\(goal - done) to go this week")
                        .font(.chalk(13, .black)).foregroundStyle(Chalk.white)
                }
            }
        }
        .slate(padding: 14)
    }
}

/// Last week fell short of the goal: a Week Shield keeps the run going.
struct ShieldCard: View {
    @Environment(Store.self) private var store
    @Environment(Pro.self) private var pro
    let week: Date
    let lost: Int
    @State private var done = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "shield.lefthalf.filled").font(.system(size: 18, weight: .black)).foregroundStyle(Chalk.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text(done ? "Shielded. The streak holds." : "Last week came up short.").font(.slab(17)).italic().foregroundStyle(Chalk.white)
                    Text(done ? "\(lost + 1) weeks and counting." : "\(store.sessionsIn(weekOf: week)) of \(store.weeklyGoal) sessions. A shield keeps your \(lost)-week streak alive.")
                        .font(.chalk(12, .medium)).foregroundStyle(Chalk.dust).fixedSize(horizontal: false, vertical: true)
                }
            }
            if !done {
                HStack(spacing: 10) {
                    if store.freeShieldLeft || store.shieldCredits > 0 {
                        TapeButton(title: store.freeShieldLeft ? "Use this month's free shield" : "Use a shield (\(store.shieldCredits) left)", icon: "shield.fill", fill: Chalk.gold) {
                            if store.shield(week) { withAnimation(.spring) { done = true } }
                        }
                    } else {
                        TapeButton(title: "Week Shield · \(pro.price(Pro.shieldID))", icon: "shield.fill", fill: Chalk.gold) {
                            Task { if await pro.buy(Pro.shieldID), store.shield(week) { withAnimation(.spring) { done = true } } }
                        }
                    }
                }
                if let m = pro.message { Text(m).font(.chalk(11.5, .semibold)).foregroundStyle(Chalk.gold) }
            }
        }
        .slate()
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Chalk.gold.opacity(0.5), lineWidth: 1.2))
    }
}

/// Next Block: four weeks of a template with target loads from the person's own numbers.
struct BlockCard: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    var body: some View {
        Button { router.showBlock = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Chalk.gold).frame(width: 44, height: 44)
                    Image(systemName: "square.stack.3d.up.fill").font(.system(size: 19, weight: .black)).foregroundStyle(Chalk.board)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Next Block").font(.slab(19)).italic().foregroundStyle(Chalk.white)
                    Text("Four weeks of targets worked out from your own lifts. Volume, build, heavy, deload.")
                        .font(.chalk(12, .medium)).foregroundStyle(Chalk.dust).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                if store.blockCredits > 0 {
                    Text("\(store.blockCredits)").font(.digits(15, .black)).foregroundStyle(Chalk.board).frame(width: 30, height: 30).background(Circle().fill(Chalk.gold))
                } else {
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .black)).foregroundStyle(Chalk.gold)
                }
            }
            .slate()
        }.buttonStyle(.plain)
    }
}

/// Plate maths, free: type the load, see the bar loaded.
struct PlateCard: View {
    @Environment(Store.self) private var store
    @State private var load = ""
    @State private var bar: Double? = nil
    var body: some View {
        let lb = store.unit == "lb"
        let barW = bar ?? (lb ? 45 : 20)
        let plates = PlateCard.solve(Double(load) ?? 0, bar: barW, lb: lb)
        VStack(alignment: .leading, spacing: 12) {
            HStack { Eyebrow("Plate maths"); Spacer(); Text("per side").font(.chalk(10, .black)).foregroundStyle(Chalk.faint) }
            HStack(spacing: 10) {
                TextField("load", text: $load).keyboardType(.decimalPad).font(.digits(22)).foregroundStyle(Chalk.white)
                    .padding(.horizontal, 12).frame(height: 46).background(RoundedRectangle(cornerRadius: 10).fill(Chalk.board)).overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Chalk.line))
                Text(store.unit).font(.chalk(14, .black)).foregroundStyle(Chalk.dust)
                Picker("Bar", selection: Binding(get: { barW }, set: { bar = $0 })) {
                    if lb { Text("45 lb bar").tag(45.0); Text("35 lb bar").tag(35.0) } else { Text("20 kg bar").tag(20.0); Text("15 kg bar").tag(15.0) }
                }.pickerStyle(.menu).tint(Chalk.dust)
            }
            BarDrawing(plates: plates.list, lb: lb).frame(height: 86)
            Text(plates.text).font(.mono(13)).foregroundStyle(Chalk.dust)
        }
        .slate()
    }

    static func solve(_ w: Double, bar: Double, lb: Bool) -> (list: [Double], text: String) {
        guard w > 0 else { return ([], "Type a weight and this works out the plates per side.") }
        let set: [Double] = lb ? [45, 35, 25, 10, 5, 2.5] : [25, 20, 15, 10, 5, 2.5, 1.25]
        var side = (w - bar) / 2
        if side < 0 { return ([], "Lighter than the bar.") }
        var out: [Double] = []
        for p in set { while side >= p - 0.0001 { out.append(p); side -= p } }
        let rest = side > 0.01 ? String(format: "  (%.2f short)", side) : ""
        return (out, out.isEmpty ? "Just the bar." : out.map(fmtWeight).joined(separator: " + ") + rest)
    }
}

/// One side of a loaded bar, plates in competition colours.
struct BarDrawing: View {
    let plates: [Double]
    let lb: Bool
    func color(_ p: Double) -> Color {
        if lb { switch p { case 45: return Color(red: 0.85, green: 0.2, blue: 0.2); case 35: return Color(red: 0.95, green: 0.8, blue: 0.2); case 25: return Color(red: 0.25, green: 0.65, blue: 0.3); case 10: return Chalk.white; default: return Chalk.dust } }
        switch p { case 25: return Color(red: 0.85, green: 0.2, blue: 0.2); case 20: return Color(red: 0.2, green: 0.45, blue: 0.9); case 15: return Color(red: 0.95, green: 0.8, blue: 0.2); case 10: return Color(red: 0.25, green: 0.65, blue: 0.3); case 5: return Chalk.white; default: return Chalk.dust }
    }
    var body: some View {
        Canvas { ctx, size in
            let mid = size.height / 2
            ctx.fill(Path(roundedRect: CGRect(x: 0, y: mid - 5, width: size.width, height: 10), cornerRadius: 3), with: .color(Chalk.dust.opacity(0.6)))
            ctx.fill(Path(roundedRect: CGRect(x: 24, y: mid - 14, width: 10, height: 28), cornerRadius: 2), with: .color(Chalk.dust))
            var x: CGFloat = 38
            let top = plates.max() ?? 1
            for p in plates {
                let h = max(26, size.height * CGFloat(0.42 + 0.58 * p / top))
                let w: CGFloat = p >= 10 ? 15 : 9
                ctx.fill(Path(roundedRect: CGRect(x: x, y: mid - h / 2, width: w, height: h), cornerRadius: 3), with: .color(color(p)))
                x += w + 2
            }
            if !plates.isEmpty { ctx.fill(Path(roundedRect: CGRect(x: x, y: mid - 9, width: 8, height: 18), cornerRadius: 2), with: .color(Chalk.faint)) }
        }
    }
}

struct TemplateEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var template: Template
    @State private var picking = false

    var body: some View {
        NavigationStack {
            ZStack {
                BoardBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        TextField("Template name", text: $template.name).font(.slab(26)).italic().foregroundStyle(Chalk.white)
                        Eyebrow("Exercises")
                        ForEach($template.exercises) { $e in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    TextField("Exercise", text: $e.name).font(.chalk(15, .bold)).foregroundStyle(Chalk.white)
                                    Button { template.exercises.removeAll { $0.id == e.id } } label: { Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Chalk.faint) }.buttonStyle(.plain).accessibilityLabel("Remove \(e.name)")
                                }
                                HStack(spacing: 12) {
                                    Stepper("\(e.sets) sets", value: $e.sets, in: 1...10).font(.digits(14)).foregroundStyle(Chalk.dust)
                                    Stepper("\(e.reps) reps", value: $e.reps, in: 1...100).font(.digits(14)).foregroundStyle(Chalk.dust)
                                }
                                if let t = e.target { Text("Target \(fmtWeight(t)) \(store.unit)").font(.chalk(11, .black)).foregroundStyle(Chalk.gold) }
                            }
                            .slate(padding: 12, radius: 12)
                        }
                        GhostButton(title: "Add exercise", icon: "plus") { picking = true }
                        Spacer(minLength: 20)
                        HStack(spacing: 10) {
                            GhostButton(title: "Delete", icon: "trash") { store.templates.removeAll { $0.id == template.id }; store.save(); dismiss() }
                            TapeButton(title: "Save") {
                                if let i = store.templates.firstIndex(where: { $0.id == template.id }) { store.templates[i] = template } else { store.templates.append(template) }
                                store.save(); dismiss()
                            }
                        }
                    }
                    .padding(18)
                }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.foregroundStyle(Chalk.dust) } }
            .sheet(isPresented: $picking) {
                ExercisePicker { name in template.exercises.append(TemplateExercise(name: name, sets: 3, reps: 8)) }.presentationBackground(Chalk.board)
            }
        }
    }
}
