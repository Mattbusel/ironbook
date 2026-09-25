import SwiftUI

struct TrainView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro
    @State private var plateWeight: String = ""
    @State private var bar: Double = 20

    var body: some View {
        Page {
            PageHeader(tape: "Ironbook", title: "Train.")

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

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Eyebrow("Templates"); Spacer()
                    GhostButton(title: "Programs", icon: pro.unlocked ? "books.vertical" : "lock.fill") { router.showPrograms = true }
                    GhostButton(title: "New", icon: "plus") { newTemplate() }
                }
                ForEach(store.templates) { t in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(t.name).font(.slab(20)).italic().foregroundStyle(Chalk.white)
                            Text(t.exercises.map { $0.name }.joined(separator: " · ")).font(.chalk(12, .medium)).foregroundStyle(Chalk.dust).lineLimit(2)
                        }
                        Spacer(minLength: 8)
                        Button { router.editingTemplate = t } label: {
                            Image(systemName: "pencil").font(.system(size: 14, weight: .bold)).foregroundStyle(Chalk.dust).frame(width: 36, height: 36).overlay(Circle().strokeBorder(Chalk.line))
                        }.buttonStyle(.plain)
                        Button { store.start(t); router.showLive = true } label: {
                            Text("START").font(.chalk(12, .black)).tracking(1.5).foregroundStyle(Chalk.white).padding(.horizontal, 14).padding(.vertical, 10).background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Chalk.red))
                        }.buttonStyle(.plain)
                    }
                    .slate(padding: 14)
                }
                GhostButton(title: "Start blank", icon: "square.dashed") { store.start(nil); router.showLive = true }
            }

            if pro.unlocked { plateCard } else {
                Button { pro.ask(.plates) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "circle.grid.cross.fill").font(.system(size: 18, weight: .black)).foregroundStyle(Chalk.gold)
                        VStack(alignment: .leading, spacing: 3) {
                            Eyebrow("Plate maths")
                            Text("Type the load, get the plates per side.").font(.chalk(14, .medium)).foregroundStyle(Chalk.dust)
                        }
                        Spacer()
                        Tape(text: "Pro", tilt: 3)
                    }
                    .slate()
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Eyebrow("Units")
                Spacer()
                Picker("Unit", selection: Bindable(store).unit) { Text("kg").tag("kg"); Text("lb").tag("lb") }
                    .pickerStyle(.segmented).frame(width: 140)
                    .onChange(of: store.unit) { store.save() }
            }
            .slate(padding: 12)

            ProCard()
        }
    }

    var plateCard: some View {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow("Plate maths")
                HStack(spacing: 10) {
                    TextField("bar load", text: $plateWeight).keyboardType(.decimalPad).font(.digits(20)).foregroundStyle(Chalk.white)
                        .padding(.horizontal, 12).frame(height: 44).background(RoundedRectangle(cornerRadius: 10).fill(Chalk.board)).overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Chalk.line))
                    Picker("Bar", selection: $bar) {
                        Text("20 kg").tag(20.0); Text("15 kg").tag(15.0); Text("45 lb").tag(45.0); Text("35 lb").tag(35.0)
                    }.pickerStyle(.menu).tint(Chalk.dust)
                }
                Text(plates).font(.mono(14)).foregroundStyle(Chalk.dust)
            }
            .slate()
    }

    var plates: String {
        guard let w = Double(plateWeight), w > 0 else { return "Type a weight and this works out the plates per side." }
        let lb = bar == 45 || bar == 35
        let set: [Double] = lb ? [45, 35, 25, 10, 5, 2.5] : [25, 20, 15, 10, 5, 2.5, 1.25]
        var side = (w - bar) / 2
        if side < 0 { return "Lighter than the bar." }
        var out: [String] = []
        for p in set { while side >= p - 0.0001 { out.append(fmtWeight(p)); side -= p } }
        let rest = side > 0.01 ? String(format: "  (%.2f short)", side) : ""
        return "Per side: " + (out.isEmpty ? "nothing" : out.joined(separator: " + ")) + rest
    }

    func newTemplate() {
        let t = Template(name: "New template", exercises: [TemplateExercise(name: "Squat", sets: 3, reps: 5)])
        store.templates.append(t); store.save(); router.editingTemplate = t
    }
}

struct TemplateEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var template: Template

    var body: some View {
        NavigationStack {
            ZStack {
                BoardBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        TextField("Template name", text: $template.name).font(.slab(26)).italic().foregroundStyle(Chalk.white)
                        Eyebrow("Exercises")
                        ForEach($template.exercises) { $e in
                            HStack(spacing: 8) {
                                TextField("Exercise", text: $e.name).font(.chalk(15, .bold)).foregroundStyle(Chalk.white)
                                Stepper("\(e.sets)×", value: $e.sets, in: 1...10).font(.digits(14)).foregroundStyle(Chalk.dust).labelsHidden()
                                Text("\(e.sets) × \(e.reps)").font(.digits(14)).foregroundStyle(Chalk.dust).frame(width: 60)
                                Stepper("", value: $e.reps, in: 1...100).labelsHidden()
                                Button { template.exercises.removeAll { $0.id == e.id } } label: { Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Chalk.faint) }.buttonStyle(.plain)
                            }
                            .slate(padding: 12, radius: 12)
                        }
                        GhostButton(title: "Add exercise", icon: "plus") { template.exercises.append(TemplateExercise(name: "", sets: 3, reps: 8)) }
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
        }
    }
}
