import AppIntents
import HWANGTODOCore
import HWANGTODODesign
import SwiftUI
import WidgetKit

// MARK: - Small: 다음 할 일

/// systemSmall (spec §6.6). systemSmall gets no `Link` — the whole widget is
/// one `widgetURL` tap target: the next task's detail, or quick capture when
/// nothing is queued.
struct NextTaskWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.homeSmall, provider: GlanceProvider()) { entry in
            NextTaskView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("다음 할 일")
        .description("지금 가장 먼저 할 일 하나와 오늘 남은 개수를 보여 줘요.")
        .supportedFamilies([.systemSmall])
    }
}

private struct NextTaskView: View {
    let snapshot: GlanceSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Label("다음 할 일", systemImage: "bolt.fill")
                .font(Theme.Typography.badge)
                .foregroundStyle(Color.hwangAccent)
                .lineLimit(1)
            Spacer(minLength: 0)
            if let next = snapshot.nextTask {
                Text(next.title)
                    .font(Theme.Typography.cardTitle)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                QuadrantTag(next.quadrant, compact: true)
            } else {
                Text("모두 정리했어요")
                    .font(Theme.Typography.cardTitle)
                    .foregroundStyle(.secondary)
                Text("떠오른 일을 남겨 보세요")
                    .font(Theme.Typography.meta)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            Spacer(minLength: 0)
            Text("오늘 \(snapshot.todayOpenCount) · 급함 \(snapshot.urgentCount)")
                .font(Theme.Typography.meta.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(Theme.cardBackground, for: .widget)
        .widgetURL(destination.url)
    }

    private var destination: DeepLink {
        snapshot.nextTask.map { DeepLink.task($0.id) } ?? .capture(source: .homeWidget)
    }
}

// MARK: - Medium: 정리 매트릭스

/// systemMedium (spec §6.6): 2×2 quadrant summary. Each cell deep-links to
/// its quadrant on the 정리 tab; the footer opens 정리 전 on the 기록 home.
struct MatrixOverviewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.homeMedium, provider: GlanceProvider()) { entry in
            MatrixOverviewView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("정리 매트릭스")
        .description("네 분면의 할 일 개수와 대표 할 일을 한눈에 봐요.")
        .supportedFamilies([.systemMedium])
    }
}

private struct MatrixOverviewView: View {
    let snapshot: GlanceSnapshot

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Grid(horizontalSpacing: Theme.Spacing.xs, verticalSpacing: Theme.Spacing.xs) {
                GridRow {
                    cell(.urgentImportant)
                    cell(.importantNotUrgent)
                }
                GridRow {
                    cell(.urgentNotImportant)
                    cell(.notUrgentNotImportant)
                }
            }
            footer
        }
        .containerBackground(Theme.cardBackground, for: .widget)
    }

    private func cell(_ quadrant: Quadrant) -> some View {
        Link(destination: DeepLink.organize(quadrant: quadrant).url) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: quadrant.symbol)
                        .font(Theme.Typography.badge)
                    Text(quadrant.title)
                        .font(Theme.Typography.badge)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    Text("\(snapshot.quadrantCounts[quadrant] ?? 0)")
                        .font(Theme.Typography.badge.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(quadrant.accent)
                Text(snapshot.topTasks[quadrant]?.first?.title ?? "비어 있어요")
                    .font(Theme.Typography.meta)
                    .foregroundStyle(snapshot.topTasks[quadrant]?.first == nil ? .tertiary : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(Theme.Spacing.xs)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(
                quadrant.accent.opacity(0.08),
                in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
            )
        }
    }

    private var footer: some View {
        Link(destination: DeepLink.captureHome(showCompleted: false).url) {
            HStack(spacing: 4) {
                Image(systemName: "tray.and.arrow.down")
                Text("정리 전 \(snapshot.inboxCount)건")
                    .monospacedDigit()
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
            }
            .font(Theme.Typography.meta)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }
}

// MARK: - Large: 오늘

/// systemLarge (spec §6.6): 오늘 진행 요약 + 다음 할 일 히어로 + 바로 완료
/// 체크(인터랙티브 버튼) + 매트릭스 개수 + 루틴 진행률 + 일정 연결 항목.
struct TodayOverviewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.homeLarge, provider: GlanceProvider()) { entry in
            TodayOverviewView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("오늘")
        .description("오늘의 할 일과 루틴 진행률을 보고, 위젯에서 바로 완료할 수 있어요.")
        .supportedFamilies([.systemLarge])
    }
}

private struct TodayOverviewView: View {
    let snapshot: GlanceSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            header
            hero
            if !checkableTasks.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    ForEach(checkableTasks) { task in
                        taskRow(task)
                    }
                }
            }
            matrixRow
            if snapshot.routineTodayTotal > 0 {
                routineRow
            }
            calendarRows
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(Theme.cardBackground, for: .widget)
    }

    /// Up to three open tasks worth completing right here: 지금 할 일 first,
    /// then anything due today — the hero has its own checkmark, so it is
    /// excluded to avoid showing the same title twice.
    private var checkableTasks: [GlanceSnapshot.TaskSummary] {
        var seen: Set<UUID> = snapshot.nextTask.map { [$0.id] } ?? []
        var result: [GlanceSnapshot.TaskSummary] = []
        let urgent = snapshot.topTasks[.urgentImportant] ?? []
        let dueToday = Quadrant.allCases
            .flatMap { snapshot.topTasks[$0] ?? [] }
            .filter(\.isDueToday)
        for task in urgent + dueToday where seen.insert(task.id).inserted {
            result.append(task)
            if result.count == 3 { break }
        }
        return result
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(snapshot.date, format: .dateTime.month().day().weekday(.wide))
                .font(Theme.Typography.sectionTitle)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            Text("남음 \(snapshot.todayOpenCount) · 완료 \(snapshot.todayDoneCount)")
                .font(Theme.Typography.meta.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    @ViewBuilder
    private var hero: some View {
        if let next = snapshot.nextTask {
            HStack(spacing: Theme.Spacing.s) {
                completeButton(for: next)
                Link(destination: DeepLink.task(next.id).url) {
                    HStack(spacing: Theme.Spacing.s) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("다음 할 일")
                                .font(Theme.Typography.badge)
                                .foregroundStyle(Color.hwangAccent)
                            Text(next.title)
                                .font(Theme.Typography.cardTitle)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        Spacer(minLength: 0)
                        QuadrantTag(next.quadrant, compact: true)
                    }
                }
            }
            .padding(Theme.Spacing.s)
            .background(
                Color.hwangAccent.opacity(0.08),
                in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
            )
        } else {
            Link(destination: DeepLink.capture(source: .homeWidget).url) {
                HStack(spacing: Theme.Spacing.s) {
                    Image(systemName: "plus.circle.fill")
                        .font(Theme.Typography.sectionTitle)
                        .foregroundStyle(Color.hwangAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("모두 정리했어요")
                            .font(Theme.Typography.cardTitle)
                        Text(Terminology.quickCapturePlaceholder)
                            .font(Theme.Typography.meta)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    Spacer(minLength: 0)
                }
                .padding(Theme.Spacing.s)
                .background(
                    Color.hwangAccent.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                )
            }
        }
    }

    private func taskRow(_ task: GlanceSnapshot.TaskSummary) -> some View {
        HStack(spacing: Theme.Spacing.s) {
            completeButton(for: task)
            Link(destination: DeepLink.task(task.id).url) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(task.title)
                        .font(Theme.Typography.meta)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if task.isDueToday {
                        Text("오늘")
                            .font(Theme.Typography.badge)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    /// Interactive completion (iOS 17+ widget buttons): performs in the widget
    /// process and reloads timelines, no app launch.
    private func completeButton(for task: GlanceSnapshot.TaskSummary) -> some View {
        Button(intent: CompleteTaskIntent(id: task.id)) {
            Image(systemName: "circle")
                .font(Theme.Typography.sectionTitle)
                .foregroundStyle(task.quadrant.accent)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(task.title) 완료")
        .invalidatableContent()
    }

    private var matrixRow: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(Quadrant.assignable) { quadrant in
                Link(destination: DeepLink.organize(quadrant: quadrant).url) {
                    VStack(spacing: 1) {
                        Text(quadrant.shortTitle)
                            .font(Theme.Typography.badge)
                            .foregroundStyle(quadrant.accent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("\(snapshot.quadrantCounts[quadrant] ?? 0)")
                            .font(Theme.Typography.meta.monospacedDigit().weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(
                        quadrant.accent.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                    )
                }
            }
        }
    }

    private var routineRow: some View {
        Link(destination: DeepLink.routines.url) {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: "repeat")
                    .font(Theme.Typography.badge)
                    .foregroundStyle(Color.hwangAccent)
                ProgressView(value: snapshot.routineProgress)
                    .tint(Color.hwangAccent)
                Text("루틴 \(snapshot.routineTodayDone)/\(snapshot.routineTodayTotal)")
                    .font(Theme.Typography.meta.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityLabel("루틴 \(snapshot.routineTodayTotal)개 중 \(snapshot.routineTodayDone)개 완료")
    }

    @ViewBuilder
    private var calendarRows: some View {
        ForEach(Array(snapshot.calendarLinkedToday.prefix(2))) { task in
            Link(destination: DeepLink.task(task.id).url) {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "calendar")
                        .font(Theme.Typography.badge)
                        .foregroundStyle(task.quadrant.accent)
                    Text(task.title)
                        .font(Theme.Typography.meta)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text("일정 연결")
                        .font(Theme.Typography.badge)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("다음 할 일", as: .systemSmall) {
    NextTaskWidget()
} timeline: {
    GlanceEntry(date: .now, snapshot: .placeholder)
}

#Preview("정리 매트릭스", as: .systemMedium) {
    MatrixOverviewWidget()
} timeline: {
    GlanceEntry(date: .now, snapshot: .placeholder)
}

#Preview("오늘", as: .systemLarge) {
    TodayOverviewWidget()
} timeline: {
    GlanceEntry(date: .now, snapshot: .placeholder)
}
