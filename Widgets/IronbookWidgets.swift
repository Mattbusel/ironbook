import ActivityKit
import SwiftUI
import WidgetKit

@main
struct IronbookWidgetBundle: WidgetBundle {
    var body: some Widget {
        WeekWidget()
        RestLive()
    }
}

struct WeekEntry: TimelineEntry {
    let date: Date
    let snap: WeekSnapshot
}

struct WeekProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeekEntry { WeekEntry(date: .now, snap: .sample) }
    func getSnapshot(in context: Context, completion: @escaping (WeekEntry) -> Void) {
        TapePalette.reload()
        completion(WeekEntry(date: .now, snap: context.isPreview ? .sample : WeekSnapshot.load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WeekEntry>) -> Void) {
        TapePalette.reload()
        // The week turns over on Monday; refresh at midnight so the day strip moves on.
        let midnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
        completion(Timeline(entries: [WeekEntry(date: .now, snap: WeekSnapshot.load())], policy: .after(midnight)))
    }
}

struct WeekWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "week", provider: WeekProvider()) { e in
            WeekFamilyView(snap: e.snap).containerBackground(Chalk.board, for: .widget)
        }
        .configurationDisplayName("This week")
        .description("Sessions against your weekly goal and your streak. The bigger one adds your latest PR and what's next.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct WeekFamilyView: View {
    @Environment(\.widgetFamily) private var family
    let snap: WeekSnapshot
    var body: some View {
        if family == .systemMedium {
            if snap.pro { WeekMediumView(snap: snap) } else {
                HStack(spacing: 14) {
                    WeekSmallView(snap: snap, tape: false).frame(width: 120)
                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: "lock.fill").font(.system(size: 15, weight: .black)).foregroundStyle(Chalk.gold)
                        Text("Ironbook Pro").font(.chalk(15, .black)).italic().foregroundStyle(Chalk.white)
                        Text("Unlocks your latest PR and what's next here. The small widget is free.").font(.chalk(11, .semibold)).foregroundStyle(Chalk.dust)
                    }
                }
            }
        } else {
            WeekSmallView(snap: snap)
        }
    }
}

struct RestLive: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestAttributes.self) { ctx in
            RestLockView(workout: ctx.attributes.workout, state: ctx.state)
                .activityBackgroundTint(Chalk.board)
                .activitySystemActionForegroundColor(Chalk.white)
        } dynamicIsland: { ctx in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("REST").font(.chalk(11, .black)).tracking(1.5).foregroundStyle(Chalk.red)
                        Text(ctx.state.next.isEmpty ? ctx.attributes.workout : ctx.state.next).font(.chalk(13, .bold)).foregroundStyle(Chalk.white).lineLimit(1)
                    }.padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date.now...max(Date.now, ctx.state.end), countsDown: true)
                        .font(.digits(28, .black)).foregroundStyle(Chalk.white).multilineTextAlignment(.trailing).frame(maxWidth: 100, alignment: .trailing).padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(timerInterval: ctx.state.start...max(ctx.state.start.addingTimeInterval(1), ctx.state.end), countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                        .tint(Chalk.red).padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill").font(.system(size: 12, weight: .black)).foregroundStyle(Chalk.red)
            } compactTrailing: {
                Text(timerInterval: Date.now...max(Date.now, ctx.state.end), countsDown: true)
                    .font(.digits(14, .black)).foregroundStyle(Chalk.white).frame(maxWidth: 48)
            } minimal: {
                Image(systemName: "timer").font(.system(size: 12, weight: .black)).foregroundStyle(Chalk.red)
            }
            .keylineTint(Chalk.red)
        }
    }
}
