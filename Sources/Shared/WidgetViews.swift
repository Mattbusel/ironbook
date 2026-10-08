import SwiftUI

/// Small week widget (free): the ring, the days, the streak.
struct WeekSmallView: View {
    let snap: WeekSnapshot
    var tape = true
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                ZStack {
                    Circle().stroke(Chalk.line, lineWidth: 6)
                    Circle().trim(from: 0, to: min(1, Double(snap.done) / Double(max(1, snap.goal))))
                        .stroke(snap.done >= snap.goal ? Chalk.gold : Chalk.red, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90))
                    Text("\(snap.done)/\(snap.goal)").font(.digits(14, .black)).foregroundStyle(Chalk.white)
                }.frame(width: 54, height: 54)
                Spacer()
                if tape {
                    Text("IRONBOOK").font(.chalk(8, .black)).tracking(1.5).foregroundStyle(Chalk.onTape).fixedSize()
                        .padding(.horizontal, 5).padding(.vertical, 3).background(Rectangle().fill(Chalk.red)).rotationEffect(.degrees(4))
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 3) {
                ForEach(0..<7, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3).fill(snap.days[safe: i] == true ? Chalk.red : Chalk.slateHi).frame(height: 12)
                }
            }
            HStack(spacing: 4) {
                Image(systemName: "flame.fill").font(.system(size: 11, weight: .black)).foregroundStyle(snap.streakWeeks > 0 ? Chalk.gold : Chalk.faint)
                Text(snap.streakWeeks > 0 ? "\(snap.streakWeeks)-week streak" : "\(max(0, snap.goal - snap.done)) to go").font(.chalk(12, .black)).foregroundStyle(Chalk.white)
            }
        }
    }
}

/// Medium week widget (Pro): the week, the streak, the latest PR and what's next.
struct WeekMediumView: View {
    let snap: WeekSnapshot
    var body: some View {
        HStack(spacing: 14) {
            WeekSmallView(snap: snap, tape: false).frame(width: 120)
            Rectangle().fill(Chalk.line).frame(width: 1)
            VStack(alignment: .leading, spacing: 8) {
                if !snap.lastPR.isEmpty {
                    HStack(spacing: 6) {
                        ZStack { Star(points: 12, inner: 0.72).fill(Chalk.gold); Text("PR").font(.chalk(7, .black)).foregroundStyle(Chalk.board) }.frame(width: 22, height: 22)
                        Text("LATEST PR").font(.chalk(9, .black)).tracking(1.2).foregroundStyle(Chalk.faint)
                    }
                    Text(snap.lastPR).font(.chalk(14, .black)).italic().foregroundStyle(Chalk.white).lineLimit(1)
                    Text("\(snap.lastPRValue) \(snap.unit) est. 1RM").font(.digits(12, .bold)).foregroundStyle(Chalk.gold)
                } else {
                    Text("PRs land here.").font(.chalk(14, .black)).foregroundStyle(Chalk.dust)
                }
                Spacer(minLength: 0)
                Text("NEXT UP").font(.chalk(9, .black)).tracking(1.2).foregroundStyle(Chalk.faint)
                Text(snap.nextTemplate).font(.chalk(14, .black)).foregroundStyle(Chalk.white).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}

/// The rest timer on the Lock Screen.
struct RestLockView: View {
    let workout: String
    let state: RestAttributes.ContentState
    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("REST · \(workout.uppercased())").font(.chalk(10, .black)).tracking(1.4).foregroundStyle(Chalk.onTape)
                    .padding(.horizontal, 6).padding(.vertical, 3).background(Rectangle().fill(Chalk.red)).rotationEffect(.degrees(-2))
                Text(state.next.isEmpty ? "Next set" : "Next: \(state.next)").font(.chalk(14, .bold)).foregroundStyle(Chalk.white).lineLimit(1)
                ProgressView(timerInterval: state.start...max(state.start.addingTimeInterval(1), state.end), countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                    .tint(Chalk.red)
            }
            Spacer(minLength: 6)
            Text(timerInterval: Date.now...max(Date.now, state.end), countsDown: true)
                .font(.digits(38, .black)).foregroundStyle(Chalk.white).multilineTextAlignment(.trailing).frame(maxWidth: 120, alignment: .trailing)
        }
        .padding(16)
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
