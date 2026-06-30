import WidgetKit
import SwiftUI

/// A compact 2×2 grid of quadrant counts used by Home Screen widgets.
private struct MiniMatrix: View {
    let entry: MatrixEntry
    var showTitles: Bool = false

    var body: some View {
        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            GridRow {
                cell(.urgentImportant, entry.urgentImportant)
                cell(.importantNotUrgent, entry.importantNotUrgent)
            }
            GridRow {
                cell(.urgentNotImportant, entry.urgentNotImportant)
                cell(.notUrgentNotImportant, entry.notUrgentNotImportant)
            }
        }
    }

    private func cell(_ quadrant: MatrixQuadrant, _ count: Int) -> some View {
        Link(destination: DeepLink.quadrant(quadrant)) {
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Image(systemName: quadrant.symbol).font(.system(size: 9)).foregroundStyle(quadrant.accent)
                    Spacer()
                    Text("\(count)").font(.system(size: 15, weight: .bold)).monospacedDigit()
                }
                if showTitles {
                    Text(quadrant.shortTitle).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .padding(7)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(quadrant.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
    }
}

/// Small: today + urgent counts and a quick-capture link.
struct HomeMatrixSmall: Widget {
    let kind = "HWANGTODOHomeSmall"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MatrixProvider()) { entry in
            VStack(alignment: .leading, spacing: 4) {
                Label("오늘", systemImage: "bolt.fill").font(.caption2.weight(.bold))
                Text("\(entry.todayCount)").font(.system(size: 34, weight: .bold)).monospacedDigit()
                Text("지금 할 일 \(entry.urgentCount)").font(.caption2).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Link(destination: DeepLink.capture) {
                    Label("기록", systemImage: "plus.circle.fill").font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("오늘 (작게)")
        .description("오늘·지금 할 일 개수와 빠른 기록.")
        .supportedFamilies([.systemSmall])
    }
}

/// Medium: 2×2 summary with next task + quick capture.
struct HomeMatrixMedium: Widget {
    let kind = "HWANGTODOHomeMedium"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MatrixProvider()) { entry in
            HStack(spacing: 12) {
                MiniMatrix(entry: entry, showTitles: true).frame(width: 150)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("매트릭스", systemImage: "square.grid.2x2").font(.caption2.weight(.bold))
                        Spacer()
                        Link(destination: DeepLink.inbox) {
                            Text("정리 전 \(entry.inboxCount)").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Divider()
                    if let next = entry.nextTask {
                        Text("다음 할 일").font(.caption2).foregroundStyle(.secondary)
                        HStack(spacing: 5) {
                            Image(systemName: "bolt.fill").font(.system(size: 9))
                                .foregroundStyle(MatrixQuadrant.urgentImportant.accent)
                            Text(next).font(.caption).lineLimit(2)
                        }
                    } else {
                        Text("받은함이 비어 있어요").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Link(destination: DeepLink.capture) {
                        Label("빠른 기록", systemImage: "plus.circle.fill").font(.caption2.weight(.semibold))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("매트릭스 (중간)")
        .description("2×2 요약과 다음 할 일, 빠른 기록.")
        .supportedFamilies([.systemMedium])
    }
}

/// Large: today overview + matrix + next task.
struct HomeMatrixLarge: Widget {
    let kind = "HWANGTODOHomeLarge"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MatrixProvider()) { entry in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("오늘 \(entry.todayCount)", systemImage: "bolt.fill").font(.subheadline.weight(.bold))
                    Spacer()
                    Link(destination: DeepLink.inbox) {
                        Text("정리 전 \(entry.inboxCount)").font(.caption).foregroundStyle(.secondary)
                    }
                }
                MiniMatrix(entry: entry, showTitles: true).frame(maxHeight: .infinity)
                if let next = entry.nextTask {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill").font(.caption2)
                            .foregroundStyle(MatrixQuadrant.urgentImportant.accent)
                        Text(next).font(.caption).lineLimit(1)
                        Spacer()
                        Link(destination: DeepLink.capture) {
                            Image(systemName: "plus.circle.fill").foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("매트릭스 (크게)")
        .description("오늘 개요·매트릭스·다음 할 일.")
        .supportedFamilies([.systemLarge])
    }
}
