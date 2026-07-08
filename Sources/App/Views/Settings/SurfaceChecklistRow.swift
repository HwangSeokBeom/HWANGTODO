import HWANGTODOCore
import HWANGTODODesign
import SwiftUI

/// One 설정 checklist row: 기능명 + 한 줄 설명 + live 상태 칩 (spec §13).
struct SurfaceChecklistRow: View {
    let surface: SettingsSurface
    let state: SurfaceState

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: surface.symbol)
                .font(Theme.Typography.cardTitle)
                .foregroundStyle(Color.hwangAccent)
                .frame(width: 32, height: 32)
                .background(
                    Color.hwangAccent.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                )
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(surface.name)
                        .font(Theme.Typography.cardTitle)
                        .foregroundStyle(.primary)
                    Spacer(minLength: Theme.Spacing.s)
                    SurfaceStateChip(state: state)
                }
                Text(surface.blurb)
                    .font(Theme.Typography.meta)
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(Theme.Typography.badge)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, Theme.Spacing.xs)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("자세한 설정 방법 보기")
    }
}

/// Live status chip. Colors follow spec §13: 사용 가능=초록, 설정 필요=주황,
/// 권한 꺼짐=빨강, 확인 필요·iOS 제한=중립 — system colors, so dark mode holds.
struct SurfaceStateChip: View {
    let state: SurfaceState

    var body: some View {
        Label(state.label, systemImage: state.symbol)
            .font(Theme.Typography.badge)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(background, in: Capsule())
            .foregroundStyle(foreground)
    }

    /// nil for the neutral states (iOS gives us no signal — no false colors).
    private var tint: Color? {
        switch state {
        case .available: .green
        case .needsSetup: .orange
        case .denied: .red
        case .checkManually, .iosLimited: nil
        }
    }

    private var background: Color {
        tint?.opacity(0.15) ?? Color(.tertiarySystemFill)
    }

    private var foreground: Color {
        tint ?? .secondary
    }
}

#Preview("상태 칩") {
    VStack(spacing: Theme.Spacing.s) {
        SurfaceStateChip(state: .available)
        SurfaceStateChip(state: .needsSetup)
        SurfaceStateChip(state: .denied)
        SurfaceStateChip(state: .checkManually)
        SurfaceStateChip(state: .iosLimited)
    }
    .padding()
}
