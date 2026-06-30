import SwiftUI
import EventKit

/// 캘린더 — answers "오늘 뭐가 남았지?" at a glance. Today's tasks, routines, overdue,
/// upcoming, and (with permission) today's calendar blocks. Never writes silently.
struct CalendarView: View {
    @Environment(TaskModel.self) private var model
    @State private var calendar = CalendarService.shared
    @State private var organizeTask: MatrixTask?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.m) {
                    todaySummary
                    if !calendar.isAuthorized { permissionCard }
                    if !model.overdueTasks().isEmpty { overdueSection }
                    scheduleSection
                    if calendar.isAuthorized { blocksSection }
                    if !model.upcomingTasks().isEmpty { upcomingSection }
                }
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.top, Theme.Spacing.s)
            }
            .background(Theme.screenBackground)
            .navigationTitle("캘린더")
            .tabBarSafeBottomPadding()
            .sheet(item: $organizeTask) { OrganizeSheet(task: $0) }
            .task { calendar.refreshStatus() }
        }
    }

    private var todaySummary: some View {
        let progress = model.dailyProgress()
        let ratio = progress.total == 0 ? 0 : Double(progress.done) / Double(progress.total)
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(Date.now.formatted(.dateTime.locale(Locale(identifier: "ko_KR")).month().day().weekday(.wide)))
                .font(.headline)
            ProgressView(value: ratio).tint(MatrixQuadrant.importantNotUrgent.accent)
            Text(progress.total == 0 ? "오늘 예정된 할 일과 루틴이 없어요."
                                     : "오늘 \(progress.total)개 중 \(progress.done)개 완료 · 남은 \(progress.total - progress.done)개")
                .font(.subheadline).foregroundStyle(.secondary)
            if !model.todayRoutines.isEmpty {
                let done = model.todayRoutines.filter { $0.isCompleted(on: .now) }.count
                Label("오늘 루틴 \(done)/\(model.todayRoutines.count)", systemImage: "repeat")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Label("Apple 캘린더 연결", systemImage: "calendar.badge.exclamationmark")
                .font(.subheadline.weight(.semibold))
            Text(statusText).font(.footnote).foregroundStyle(.secondary)
            if calendar.authorizationStatus == .denied {
                Button("설정 열기") { openSettings() }
            } else {
                Button("캘린더 접근 허용") { Task { await calendar.requestAccess() } }
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    private var statusText: String {
        switch calendar.authorizationStatus {
        case .denied: return "접근이 거부되었어요. 설정에서 HWANGTODO의 캘린더 권한을 허용하면 일정을 잡고 오늘 일정을 볼 수 있어요."
        case .restricted: return "이 기기에서는 캘린더 접근이 제한되어 있어요."
        default: return "중요한 일을 일정으로 잡고 오늘 일정을 보려면 접근을 허용하세요."
        }
    }

    private var overdueSection: some View {
        section("지난 일정", "exclamationmark.circle", MatrixQuadrant.urgentImportant.accent) {
            ForEach(model.overdueTasks().prefix(4)) { taskRow($0, trailing: "지남") }
        }
    }

    private var scheduleSection: some View {
        section("일정 잡기", "calendar", MatrixQuadrant.importantNotUrgent.accent) {
            let tasks = model.tasks(in: .importantNotUrgent)
            if tasks.isEmpty { emptyRow("일정 잡을 항목이 없어요.") }
            else { ForEach(tasks.prefix(6)) { taskRow($0, trailing: $0.hasCalendarEvent ? "연결됨" : "일정") } }
        }
    }

    private var upcomingSection: some View {
        section("다가오는 일정", "clock.arrow.circlepath", .secondary) {
            ForEach(model.upcomingTasks().prefix(5)) { taskRow($0, trailing: nil) }
        }
    }

    private var blocksSection: some View {
        section("오늘 일정", "clock", .secondary) {
            let events = calendar.todaysEvents()
            if events.isEmpty { emptyRow("오늘 등록된 캘린더 일정이 없어요.") }
            else {
                ForEach(events.prefix(8), id: \.eventIdentifier) { event in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title ?? "일정").font(.subheadline).lineLimit(1)
                            Text(timeRange(event)).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, _ symbol: String, _ accent: Color,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Label(title, systemImage: symbol).font(.headline).foregroundStyle(accent)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    private func taskRow(_ task: MatrixTask, trailing: String?) -> some View {
        Button { organizeTask = task } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title).font(.subheadline).foregroundStyle(.primary).lineLimit(1)
                    if let due = task.dueDate {
                        Text(due.formatted(.dateTime.locale(Locale(identifier: "ko_KR")).month().day()))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let trailing {
                    Text(trailing).font(.caption.weight(.medium))
                        .foregroundStyle(task.hasCalendarEvent ? .secondary : Color.accentColor)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text).font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 4)
    }

    private func timeRange(_ event: EKEvent) -> String {
        if event.isAllDay { return "종일" }
        let s = event.startDate.formatted(date: .omitted, time: .shortened)
        let e = event.endDate.formatted(date: .omitted, time: .shortened)
        return "\(s) – \(e)"
    }

    private func openSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        #endif
    }
}
