import SwiftUI
import WidgetKit
#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(ActivityKit)
/// "라이브 매트릭스" Live Activity — Lock Screen card + Dynamic Island. Glanceable
/// status only (task, quadrant, timer, next action, progress). No text input.
@available(iOS 16.1, *)
struct FocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            HStack(spacing: 12) {
                Image(systemName: context.state.quadrant.symbol)
                    .font(.title3).foregroundStyle(context.state.quadrant.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.taskTitle).font(.headline).lineLimit(1)
                    Text("\(context.state.quadrant.shortTitle) · \(context.state.nextAction) · \(context.state.progressText)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(context.state.startedAt, style: .timer)
                    .font(.title3.monospacedDigit()).frame(width: 64)
            }
            .padding()
            .activityBackgroundTint(Color(.systemBackground))
            .widgetURL(URL(string: "hwangtodo://matrix"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.quadrant.symbol).foregroundStyle(context.state.quadrant.accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startedAt, style: .timer).monospacedDigit().frame(width: 56)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.taskTitle).font(.headline).lineLimit(1)
                        Text("\(context.state.quadrant.shortTitle) · \(context.state.progressText)")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: "square.grid.2x2").foregroundStyle(context.state.quadrant.accent)
            } compactTrailing: {
                Text(context.state.startedAt, style: .timer).monospacedDigit().frame(width: 44)
            } minimal: {
                Image(systemName: "square.grid.2x2").foregroundStyle(context.state.quadrant.accent)
            }
            .widgetURL(URL(string: "hwangtodo://focus"))
        }
    }
}
#endif
