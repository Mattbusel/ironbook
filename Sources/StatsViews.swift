import SwiftUI
import Charts

struct HistoryView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        let ss = store.sessions.sorted { $0.date > $1.date }
        let week = ss.filter { $0.date > Date.now.addingTimeInterval(-7 * 86400) }.count
        let month = ss.filter { $0.date > Date.now.addingTimeInterval(-30 * 86400) }.count
        Page {
            PageHeader(tape: "The book", title: "History.")
            HStack(spacing: 10) {
                stat("\(ss.count)", "logged")
                stat("\(week)", "this week")
                stat("\(month)", "30 days")
            }
            if ss.isEmpty {
                Text("Nothing in the book yet. Start a template on the Train tab.").font(.chalk(14, .medium)).foregroundStyle(Chalk.dust).slate()
            }
            ForEach(ss) { s in
                Button { router.viewing = s } label: {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.date.formatted(.dateTime.day().month(.abbreviated))).font(.digits(15, .black)).foregroundStyle(Chalk.white)
                            Text(s.date.formatted(.dateTime.weekday(.wide))).font(.chalk(11, .bold)).foregroundStyle(Chalk.faint)
                        }
                        .frame(width: 64, alignment: .leading)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(s.name).font(.slab(18)).italic().foregroundStyle(Chalk.white)
                            Text(s.exercises.map { "\($0.name) \($0.sets.count)×" }.joined(separator: " · ")).font(.chalk(11.5, .medium)).foregroundStyle(Chalk.dust).lineLimit(2)
                        }
                        Spacer(minLength: 6)
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(fmtVolume(s.volume)).font(.digits(15, .black)).foregroundStyle(Chalk.white)
                            Text("\(store.unit) · \(s.minutes) min").font(.chalk(10.5, .bold)).foregroundStyle(Chalk.faint)
                        }
                    }
                    .slate(padding: 14)
                }
                .buttonStyle(.plain)
            }
        }
    }

    func stat(_ v: String, _ l: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(v).font(.digits(26, .black)).foregroundStyle(Chalk.white)
            Text(l.uppercased()).font(.chalk(10, .black)).tracking(1.2).foregroundStyle(Chalk.faint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .slate(padding: 14, radius: 14)
    }
}

struct ProgressTab: View {
    @Environment(Store.self) private var store
    @State private var picked: String? = nil

    var body: some View {
        let names = store.exerciseNames.filter { !store.progress($0).isEmpty }
        let name = picked ?? names.first ?? ""
        let pts = store.progress(name)
        Page {
            PageHeader(tape: "Line going up", title: "Progress.")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(names, id: \.self) { n in
                        Button { picked = n } label: {
                            Text(n).font(.chalk(13, .black)).foregroundStyle(n == name ? Chalk.board : Chalk.dust)
                                .padding(.horizontal, 14).padding(.vertical, 9)
                                .background(Capsule().fill(n == name ? Chalk.white : Chalk.slate))
                                .overlay(Capsule().strokeBorder(Chalk.line))
                        }.buttonStyle(.plain)
                    }
                }
            }
            if let first = pts.first, let last = pts.last {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Figure(value: fmtWeight(last.e1rm.rounded()), unit: store.unit, color: Chalk.red, size: 30)
                        Eyebrow("est. 1RM now")
                    }.frame(maxWidth: .infinity, alignment: .leading).slate(padding: 14, radius: 14)
                    VStack(alignment: .leading, spacing: 2) {
                        Figure(value: (last.e1rm - first.e1rm >= 0 ? "+" : "") + fmtWeight((last.e1rm - first.e1rm).rounded()), unit: store.unit, color: Chalk.green, size: 30)
                        Eyebrow("since first log")
                    }.frame(maxWidth: .infinity, alignment: .leading).slate(padding: 14, radius: 14)
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Eyebrow("Estimated one-rep max"); Spacer(); HStack(spacing: 4) { Circle().fill(Chalk.gold).frame(width: 8, height: 8); Text("PR session").font(.chalk(10, .bold)).foregroundStyle(Chalk.faint) } }
                    Chart {
                        ForEach(pts) { p in
                            AreaMark(x: .value("Date", p.date), y: .value("1RM", p.e1rm)).foregroundStyle(LinearGradient(colors: [Chalk.red.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom)).interpolationMethod(.monotone)
                            LineMark(x: .value("Date", p.date), y: .value("1RM", p.e1rm)).foregroundStyle(Chalk.red).lineStyle(StrokeStyle(lineWidth: 2.5)).interpolationMethod(.monotone)
                            PointMark(x: .value("Date", p.date), y: .value("1RM", p.e1rm)).foregroundStyle(p.isPR ? Chalk.gold : Chalk.red).symbolSize(p.isPR ? 70 : 30)
                        }
                    }
                    .chartYScale(domain: (pts.map { $0.e1rm }.min() ?? 0) * 0.92...(pts.map { $0.e1rm }.max() ?? 1) * 1.05)
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisGridLine().foregroundStyle(Chalk.line); AxisValueLabel().foregroundStyle(Chalk.faint).font(.chalk(10, .bold)) } }
                    .chartYAxis { AxisMarks(position: .leading) { _ in AxisGridLine().foregroundStyle(Chalk.line); AxisValueLabel().foregroundStyle(Chalk.faint).font(.mono(10)) } }
                    .frame(height: 220)
                }
                .slate()
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow("Heaviest set per session")
                    Chart(pts) { p in
                        BarMark(x: .value("Date", p.date, unit: .day), y: .value("Top", p.top)).foregroundStyle(Chalk.white.opacity(0.7)).cornerRadius(3)
                    }
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisValueLabel().foregroundStyle(Chalk.faint).font(.chalk(10, .bold)) } }
                    .chartYAxis { AxisMarks(position: .leading) { _ in AxisGridLine().foregroundStyle(Chalk.line); AxisValueLabel().foregroundStyle(Chalk.faint).font(.mono(10)) } }
                    .frame(height: 140)
                }
                .slate()
            } else {
                Text("Log a few sessions with weights and the line appears.").font(.chalk(14, .medium)).foregroundStyle(Chalk.dust).slate()
            }
            let wv = store.weeklyVolume()
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow("Weekly volume, everything")
                Chart(wv) { w in
                    BarMark(x: .value("Week", w.start, unit: .weekOfYear), y: .value("Volume", w.volume)).foregroundStyle(w.current ? Chalk.red : Chalk.slateHi).cornerRadius(4)
                }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated).day()).foregroundStyle(Chalk.faint).font(.chalk(10, .bold)) } }
                .chartYAxis { AxisMarks(position: .leading) { v in AxisGridLine().foregroundStyle(Chalk.line); AxisValueLabel { if let d = v.as(Double.self) { Text(fmtVolume(d)).font(.mono(10)).foregroundStyle(Chalk.faint) } } } }
                .frame(height: 150)
            }
            .slate()
        }
    }
}

struct RecordsView: View {
    @Environment(Store.self) private var store
    var body: some View {
        let recs = store.records
        Page {
            PageHeader(tape: "Wall of fame", title: "Records.")
            if recs.isEmpty {
                Text("Records appear once you have logged sets with weight and reps.").font(.chalk(14, .medium)).foregroundStyle(Chalk.dust).slate()
            }
            ForEach(Array(recs.enumerated()), id: \.element.id) { i, r in
                HStack(spacing: 14) {
                    ZStack {
                        Star(points: 12, inner: 0.74).fill(i == 0 ? Chalk.gold : Chalk.slateHi)
                        Text("\(i + 1)").font(.digits(14, .black)).foregroundStyle(i == 0 ? Chalk.board : Chalk.dust)
                    }
                    .frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(r.name).font(.slab(18)).italic().foregroundStyle(Chalk.white)
                        Text("best set \(fmtWeight(r.bestWeight)) × \(r.bestReps) · heaviest \(fmtWeight(r.bestSetWeight)) × \(r.bestSetReps)").font(.mono(11)).foregroundStyle(Chalk.dust)
                        Text(r.date.formatted(date: .abbreviated, time: .omitted)).font(.chalk(10.5, .bold)).foregroundStyle(Chalk.faint)
                    }
                    Spacer(minLength: 6)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(fmtWeight(r.e1rm.rounded())).font(.digits(26, .black)).foregroundStyle(i == 0 ? Chalk.gold : Chalk.white)
                        Text("est. 1RM \(store.unit)").font(.chalk(10, .bold)).foregroundStyle(Chalk.faint)
                    }
                }
                .slate(padding: 14)
            }
        }
    }
}
