import SwiftUI

/// Compact completion ring (todo mate-style 완료감). Value is 0…1.
public struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat
    var tint: Color

    public init(progress: Double, lineWidth: CGFloat = 5, tint: Color = .hwangAccent) {
        self.progress = progress.isFinite ? min(max(progress, 0), 1) : 0
        self.lineWidth = lineWidth
        self.tint = tint
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.hwangSnappy, value: progress)
        }
        .accessibilityElement()
        .accessibilityLabel("진행률")
        .accessibilityValue("\(Int(progress * 100))퍼센트")
    }
}
