import WidgetKit
import SwiftUI

// Lock Screen accessory widgets — GLANCEABLE + TRIGGER only. iOS does not allow
// a text field on the Lock Screen, so taps deep-link into the smallest relevant
// surface (capture / a quadrant), not the generic app root.

/// Circular: today count, taps into quick capture.
struct LockMatrixCircular: Widget {
    let kind = "HWANGTODOLockCircular"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MatrixProvider()) { entry in
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "bolt.fill").font(.system(size: 10, weight: .semibold))
                    Text("\(entry.todayCount)").font(.system(size: 16, weight: .bold))
                }
            }
            .widgetURL(DeepLink.capture)
            .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("오늘 개수")
        .description("오늘 할 일 개수. 탭하면 빠른 기록이 열려요.")
        .supportedFamilies([.accessoryCircular])
    }
}

/// Rectangular: "지금 X · 오늘 Y" + next task, taps into "지금 하기".
struct LockMatrixRectangular: Widget {
    let kind = "HWANGTODOLockRectangular"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MatrixProvider()) { entry in
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "square.grid.2x2").font(.caption2)
                    Text("HWANGTODO").font(.caption2.weight(.bold))
                }
                Text("지금 \(entry.urgentCount) · 오늘 \(entry.todayCount)").font(.headline)
                Text(entry.nextTask ?? "받은함이 비어 있어요")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(DeepLink.quadrant(.urgentImportant))
            .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("매트릭스 상태")
        .description("지금 할 일·오늘 개수와 다음 할 일. 탭하면 ‘지금 하기’가 열려요.")
        .supportedFamilies([.accessoryRectangular])
    }
}
