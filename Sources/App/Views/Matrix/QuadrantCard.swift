import SwiftUI

/// One quadrant tile in the 2×2 grid. Color is a thin accent; typography leads.
struct QuadrantCard: View {
    let quadrant: MatrixQuadrant
    let count: Int
    let topTasks: [MatrixTask]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(spacing: 6) {
                Image(systemName: quadrant.symbol).foregroundStyle(quadrant.accent)
                Spacer()
                Text("\(count)").font(.title3.weight(.semibold)).monospacedDigit()
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(quadrant.title)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(quadrant.actionLabel)
                    .font(.caption)
                    .foregroundStyle(quadrant.accent)
            }

            if topTasks.isEmpty {
                Text("비어 있음")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(topTasks.prefix(3)) { task in
                        HStack(spacing: 5) {
                            Circle().fill(.secondary).frame(width: 3, height: 3)
                            Text(task.title).font(.caption).lineLimit(1).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .cardSurface()
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(quadrant.accent.opacity(0.85))
                .frame(width: 3)
                .padding(.vertical, Theme.Spacing.m)
        }
    }
}
