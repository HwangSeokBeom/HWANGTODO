import SwiftUI

/// A small badge showing where a task was captured from (Korean labels).
struct SourceBadge: View {
    let source: CaptureSource
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: source.symbol)
            Text(source.label)
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.tertiarySystemFill), in: Capsule())
    }
}

/// A clean, glanceable task card used in the Inbox and quadrant detail.
struct TaskCardView: View {
    let task: MatrixTask
    var showQuadrant: Bool = false
    var onToggleDone: (() -> Void)? = nil

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .abbreviated
        f.locale = Locale(identifier: "ko_KR"); return f
    }()

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            if let onToggleDone {
                Button(action: onToggleDone) {
                    Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(task.status == .done ? Color.green : .secondary)
                }
                .buttonStyle(.plain)
            } else if task.priority == .high {
                Capsule().fill(MatrixQuadrant.urgentImportant.accent).frame(width: 3)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    SourceBadge(source: task.source)
                    if showQuadrant, task.quadrant != .unassigned {
                        Label(task.quadrant.actionLabel, systemImage: task.quadrant.symbol)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(task.quadrant.accent)
                    }
                    if task.isPinned { Image(systemName: "pin.fill").font(.caption2).foregroundStyle(.orange) }
                }
                Text(task.title)
                    .font(.body)
                    .foregroundStyle(task.status == .done ? .secondary : .primary)
                    .strikethrough(task.status == .done)
                    .lineLimit(2)
                metadata
            }
            Spacer(minLength: 0)
        }
        .cardSurface()
    }

    private var metadata: some View {
        HStack(spacing: 10) {
            Text(Self.relative.localizedString(for: task.createdAt, relativeTo: .now))
            if let due = task.dueDate {
                Label(due.formatted(.dateTime.locale(Locale(identifier: "ko_KR")).month().day()),
                      systemImage: "calendar")
            }
            if task.reminderDate != nil { Image(systemName: "bell.fill") }
            if task.hasCalendarEvent { Image(systemName: "calendar.badge.checkmark") }
            if task.hasNote { Image(systemName: "note.text") }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}
