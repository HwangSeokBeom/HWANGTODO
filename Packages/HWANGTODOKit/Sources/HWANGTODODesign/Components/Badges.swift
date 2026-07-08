import HWANGTODOCore
import SwiftUI

/// Where-was-this-captured badge (Siri, 잠금화면, 액션 버튼 … spec §5).
public struct SourceBadge: View {
    let source: CaptureSource

    public init(_ source: CaptureSource) {
        self.source = source
    }

    public var body: some View {
        Label(source.label, systemImage: source.symbol)
            .font(Theme.Typography.badge)
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color(.tertiarySystemFill), in: Capsule())
            .foregroundStyle(.secondary)
    }
}

/// Small quadrant tag (지금 할 일 / 계획할 일 …).
public struct QuadrantTag: View {
    let quadrant: Quadrant
    var compact = false

    public init(_ quadrant: Quadrant, compact: Bool = false) {
        self.quadrant = quadrant
        self.compact = compact
    }

    public var body: some View {
        Label(compact ? quadrant.shortTitle : quadrant.title, systemImage: quadrant.symbol)
            .font(Theme.Typography.badge)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(quadrant.accent.opacity(0.14), in: Capsule())
            .foregroundStyle(quadrant.accent)
    }
}
