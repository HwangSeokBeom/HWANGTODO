import SwiftUI

/// 루틴 — todo mate–style habits. Today's routines are checkable; completion
/// contributes to daily progress. Minimal, friendly, not an enterprise scheduler.
struct RoutineView: View {
    @Environment(TaskModel.self) private var model
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.m) {
                    todaySection
                    allSection
                }
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.top, Theme.Spacing.s)
            }
            .background(Theme.screenBackground)
            .navigationTitle("루틴")
            .tabBarSafeBottomPadding()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) { AddRoutineSheet() }
        }
    }

    private var todaySection: some View {
        let today = model.todayRoutines
        let done = today.filter { $0.isCompleted(on: .now) }.count
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Text("오늘 루틴").font(.headline)
                Spacer()
                Text(today.isEmpty ? "없음" : "\(done)/\(today.count)").foregroundStyle(.secondary)
            }
            if today.isEmpty {
                Text("오늘 예정된 루틴이 없어요.").font(.footnote).foregroundStyle(.secondary)
            } else {
                ForEach(today) { routine in
                    Button { withAnimation { model.toggleRoutine(routine) } } label: {
                        HStack(spacing: Theme.Spacing.s) {
                            Image(systemName: routine.isCompleted(on: .now) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(routine.isCompleted(on: .now) ? Color.green : .secondary)
                            Text(routine.title)
                                .strikethrough(routine.isCompleted(on: .now))
                                .foregroundStyle(routine.isCompleted(on: .now) ? .secondary : .primary)
                            Spacer()
                            Text(routine.cycleDescription).font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var allSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("모든 루틴").font(.headline)
            if model.routines.isEmpty {
                Text("아직 루틴이 없어요. ‘물 마시기’, ‘운동하기’처럼 반복하고 싶은 일을 추가해 보세요.")
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                ForEach(model.routines) { routine in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(routine.title).font(.subheadline)
                            Text(routine.cycleDescription + (routine.isActive ? "" : " · 비활성"))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let q = routine.defaultQuadrant {
                            Image(systemName: q.symbol).font(.caption).foregroundStyle(q.accent)
                        }
                    }
                    .padding(.vertical, 6)
                    .contextMenu {
                        Button(role: .destructive) { model.deleteRoutine(routine) } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}

/// Simple routine creation — title, weekday selection, optional default quadrant.
private struct AddRoutineSheet: View {
    @Environment(TaskModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var everyDay = true
    @State private var weekdays: Set<Int> = []
    @State private var useQuadrant = false
    @State private var quadrant: MatrixQuadrant = .importantNotUrgent

    private let weekdayNames = [(1, "일"), (2, "월"), (3, "화"), (4, "수"), (5, "목"), (6, "금"), (7, "토")]

    var body: some View {
        NavigationStack {
            Form {
                Section("루틴 이름") {
                    TextField("예: 물 마시기, 운동하기", text: $title)
                }
                Section("반복") {
                    Toggle("매일", isOn: $everyDay.animation())
                    if !everyDay {
                        HStack(spacing: 6) {
                            ForEach(weekdayNames, id: \.0) { day in
                                let on = weekdays.contains(day.0)
                                Button {
                                    if on { weekdays.remove(day.0) } else { weekdays.insert(day.0) }
                                } label: {
                                    Text(day.1)
                                        .frame(width: 34, height: 34)
                                        .background(on ? Color.accentColor : Color(.tertiarySystemFill), in: Circle())
                                        .foregroundStyle(on ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                Section {
                    Toggle("기본 사분면 지정", isOn: $useQuadrant.animation())
                    if useQuadrant {
                        Picker("사분면", selection: $quadrant) {
                            ForEach(MatrixQuadrant.assignable) { Text($0.title).tag($0) }
                        }
                    }
                } footer: {
                    Text("빠른 기록에는 사분면이 필요하지 않아요. 원할 때만 지정하세요.")
                }
            }
            .navigationTitle("루틴 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") {
                        model.addRoutine(title: title,
                                         weekdays: everyDay ? [] : Array(weekdays),
                                         defaultQuadrant: useQuadrant ? quadrant : nil)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
