import SwiftUI

/// 정리 — assign quadrant, due date, reminder, calendar link, memo, priority, pin.
/// Lightweight on purpose; capture never required any of this.
struct OrganizeSheet: View {
    let task: MatrixTask

    @Environment(TaskModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var quadrant: MatrixQuadrant = .unassigned
    @State private var priority: MatrixPriority = .none
    @State private var hasDue = false
    @State private var due = Date.now
    @State private var hasReminder = false
    @State private var reminder = Date.now.addingTimeInterval(3600)
    @State private var noteLink = ""
    @State private var noteBody = ""
    @State private var isPinned = false
    @State private var calendarMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("할 일") {
                    TextField("제목", text: $title, axis: .vertical).lineLimit(1...4)
                }
                Section {
                    Picker("사분면", selection: $quadrant) {
                        Text("정리 전").tag(MatrixQuadrant.unassigned)
                        ForEach(MatrixQuadrant.assignable) { q in
                            Text("\(q.title) · \(q.actionLabel)").tag(q)
                        }
                    }
                    .pickerStyle(.inline).labelsHidden()
                } header: { Text("매트릭스") } footer: {
                    Text(quadrant == .unassigned ? "정할 때까지 받은함에 남아 있어요." : quadrant.actionLabel)
                }
                Section("일정") {
                    Toggle("마감일", isOn: $hasDue.animation())
                    if hasDue { DatePicker("마감", selection: $due, displayedComponents: [.date]) }
                    Toggle("알림", isOn: $hasReminder.animation())
                    if hasReminder { DatePicker("알림 시각", selection: $reminder) }
                    Button { scheduleOnCalendar() } label: {
                        Label(task.hasCalendarEvent ? "캘린더 일정 연결됨" : "캘린더에 일정 잡기",
                              systemImage: "calendar.badge.plus")
                    }
                    .disabled(!hasDue)
                    if let calendarMessage {
                        Text(calendarMessage).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section("메모") {
                    TextField("메모 링크 (URL)", text: $noteLink)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    TextField("내부 메모", text: $noteBody, axis: .vertical).lineLimit(1...5)
                }
                Section("세부") {
                    Picker("중요도", selection: $priority) {
                        ForEach(MatrixPriority.allCases) { Text($0.displayName).tag($0) }
                    }.pickerStyle(.segmented)
                    Toggle("상단 고정", isOn: $isPinned)
                }
            }
            .navigationTitle("정리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("저장") { save() }.fontWeight(.semibold) }
            }
            .onAppear(perform: load)
        }
        .presentationDetents([.large])
    }

    private func load() {
        title = task.title
        quadrant = task.quadrant
        priority = task.priority
        isPinned = task.isPinned
        noteLink = task.noteLinkURL ?? ""
        noteBody = task.body ?? ""
        if let d = task.dueDate { hasDue = true; due = d }
        if let r = task.reminderDate { hasReminder = true; reminder = r }
        if task.hasCalendarEvent { calendarMessage = "캘린더 일정에 연결되어 있어요." }
    }

    private func scheduleOnCalendar() {
        Task {
            let service = CalendarService.shared
            if !service.isAuthorized {
                let granted = await service.requestAccess()
                if !granted { calendarMessage = "캘린더 접근 권한이 필요해요. 캘린더 탭에서 허용해 주세요."; return }
            }
            if let id = service.createEvent(title: title, start: due, notes: noteBody.isEmpty ? nil : noteBody) {
                var updated = currentEdited(); updated.calendarEventIdentifier = id
                model.update(updated)
                let day = due.formatted(.dateTime.locale(Locale(identifier: "ko_KR")).month().day())
                calendarMessage = "\(day)에 일정을 만들었어요."
            } else {
                calendarMessage = "일정을 만들지 못했어요."
            }
        }
    }

    private func currentEdited() -> MatrixTask {
        var t = task
        t.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        t.quadrant = quadrant
        t.status = quadrant == .unassigned ? (t.status == .done || t.status == .archived ? t.status : .inbox) : .active
        t.priority = priority
        t.isPinned = isPinned
        t.noteLinkURL = noteLink.isEmpty ? nil : noteLink
        t.body = noteBody.isEmpty ? nil : noteBody
        t.dueDate = hasDue ? due : nil
        t.reminderDate = hasReminder ? reminder : nil
        t.updatedAt = .now
        return t
    }

    private func save() {
        let previousReminder = task.reminderDate
        let updated = currentEdited()
        model.update(updated)
        if hasReminder {
            Task { await NotificationManager.shared.scheduleReminder(id: updated.id, title: updated.title, date: reminder) }
        } else if previousReminder != nil {
            NotificationManager.shared.cancelReminder(id: updated.id)
        }
        dismiss()
    }
}
