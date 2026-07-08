import HWANGTODOCore
import HWANGTODODesign
import SwiftUI
import WidgetKit

// MARK: - accessoryCircular

/// 잠금화면 원형 (spec §6.1): 오늘 남은 개수를 크게, 급한 일이 있으면 번개를
/// 함께 보여 준다. Lock-screen widgets take no text input (iOS policy) —
/// the tap opens quick capture instead.
struct LockCircularWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.lockCircular, provider: GlanceProvider()) { entry in
            LockCircularView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("오늘 남은 할 일")
        .description("오늘 남은 개수를 보여 줘요. 탭하면 빠른 기록을 열어요.")
        .supportedFamilies([.accessoryCircular])
    }
}

private struct LockCircularView: View {
    let snapshot: GlanceSnapshot

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                if snapshot.urgentCount > 0 {
                    Image(systemName: "bolt.fill")
                        .font(Theme.Typography.badge)
                        .widgetAccentable()
                } else {
                    Text("오늘")
                        .font(Theme.Typography.badge)
                        .foregroundStyle(.secondary)
                }
                Text("\(snapshot.todayOpenCount)")
                    .font(Theme.Typography.number)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .containerBackground(.clear, for: .widget)
        .widgetURL(DeepLink.capture(source: .lockScreenWidget).url)
        .accessibilityElement()
        .accessibilityLabel("오늘 남은 할 일 \(snapshot.todayOpenCount)개, 급함 \(snapshot.urgentCount)개. 탭하면 빠른 기록을 열어요.")
    }
}

// MARK: - accessoryRectangular

/// 잠금화면 직사각형 (spec §6.1): 다음 할 일 한 줄 + 오늘·급함·정리 전 개수.
/// 탭하면 그 할 일로, 비어 있으면 빠른 기록으로 간다.
struct LockRectangularWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.lockRectangular, provider: GlanceProvider()) { entry in
            LockRectangularView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("다음 할 일")
        .description("다음 할 일과 오늘 상황을 한 줄씩 보여 줘요. 탭하면 해당 할 일로 이동해요.")
        .supportedFamilies([.accessoryRectangular])
    }
}

private struct LockRectangularView: View {
    let snapshot: GlanceSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Label("다음 할 일", systemImage: "bolt.fill")
                .font(Theme.Typography.badge)
                .foregroundStyle(.secondary)
                .widgetAccentable()
                .lineLimit(1)
            Text(snapshot.nextTask?.title ?? "떠오른 일을 남겨 보세요")
                .font(Theme.Typography.cardTitle)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text("오늘 \(snapshot.todayOpenCount) · 급함 \(snapshot.urgentCount) · 정리 전 \(snapshot.inboxCount)")
                .font(Theme.Typography.badge.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.clear, for: .widget)
        .widgetURL(destination.url)
    }

    private var destination: DeepLink {
        snapshot.nextTask.map { DeepLink.task($0.id) } ?? .capture(source: .lockScreenWidget)
    }
}

// MARK: - accessoryInline

/// 잠금화면 한 줄 (spec §6.1): 시계 위 자리에 오늘·급함 개수만 간결하게.
struct LockInlineWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.lockInline, provider: GlanceProvider()) { entry in
            LockInlineView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("오늘 한 줄 요약")
        .description("오늘 남은 할 일과 급한 일 개수를 한 줄로 보여 줘요.")
        .supportedFamilies([.accessoryInline])
    }
}

private struct LockInlineView: View {
    let snapshot: GlanceSnapshot

    var body: some View {
        Text("오늘 \(snapshot.todayOpenCount)개 · 급함 \(snapshot.urgentCount)개")
            .containerBackground(.clear, for: .widget)
            .widgetURL(DeepLink.captureHome(showCompleted: false).url)
    }
}

// MARK: - Previews

#Preview("원형", as: .accessoryCircular) {
    LockCircularWidget()
} timeline: {
    GlanceEntry(date: .now, snapshot: .placeholder)
}

#Preview("직사각형", as: .accessoryRectangular) {
    LockRectangularWidget()
} timeline: {
    GlanceEntry(date: .now, snapshot: .placeholder)
}

#Preview("한 줄", as: .accessoryInline) {
    LockInlineWidget()
} timeline: {
    GlanceEntry(date: .now, snapshot: .placeholder)
}
