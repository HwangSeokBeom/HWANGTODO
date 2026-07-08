import HWANGTODOCore
import HWANGTODODesign
import SwiftUI

/// First-run story (spec §2, §5, §14): the app's promise is capture *outside*
/// the app — so onboarding sells the entry points, not the task list.
/// Four pages: 앱을 열지 않고 기록 → 기록 진입점 → 정리는 나중에 → 시작.
/// Skippable at any point; `onFinish` persists the completion flag upstream.
struct OnboardingView: View {
    var onFinish: () -> Void

    @State private var page = 0
    private static let lastPage = 3

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                capturePage.tag(0)
                surfacesPage.tag(1)
                organizePage.tag(2)
                startPage.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            pageDots
                .padding(.bottom, Theme.Spacing.l)

            primaryButton
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.l)
        }
        .background(Theme.screenBackground.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            if page < Self.lastPage {
                Button("건너뛰기", action: onFinish)
                    .font(Theme.Typography.meta)
                    .foregroundStyle(.secondary)
                    .padding(Theme.Spacing.l)
            }
        }
    }

    // MARK: - Pages

    /// Page 1 — the core promise (spec §2): capture without opening the app.
    private var capturePage: some View {
        OnboardingPageLayout(
            title: Terminology.captureWithoutOpening,
            message: Terminology.tagline
        ) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(Color.hwangAccent)
                .frame(width: 108, height: 108)
                .glassEffect(in: .circle)
                .accessibilityHidden(true)
        }
    }

    /// Page 2 — the real entry points (spec §6): where 1-second capture lives.
    private var surfacesPage: some View {
        OnboardingPageLayout(
            title: "어디서든 1초 만에",
            message: "잠금화면, Siri, 액션 버튼, 단축어, 제어센터, 홈 위젯 — 떠오른 순간 바로 남길 수 있어요."
        ) {
            surfaceGrid
        }
    }

    /// Page 3 — the matrix is an organization layer, never a capture gate (spec §8).
    private var organizePage: some View {
        OnboardingPageLayout(
            title: "정리는 나중에",
            message: "기록할 때는 아무것도 고민하지 마세요. 쌓인 일은 시간이 날 때 네 칸으로 나누면 충분해요."
        ) {
            quadrantGrid
        }
    }

    /// Page 4 — hand-off into the app.
    private var startPage: some View {
        OnboardingPageLayout(
            title: "이제 시작해 볼까요?",
            message: "지금 떠오른 일 하나부터 남겨 보세요. 나머지는 하나씩 정리하면 돼요."
        ) {
            ZStack {
                ProgressRing(progress: 1, lineWidth: 6)
                    .frame(width: 96, height: 96)
                Image(systemName: "checkmark")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.hwangAccent)
            }
            .accessibilityHidden(true)
        }
    }

    // MARK: - Page visuals

    /// The capture entry points, in spec §5 badge vocabulary — icons and names
    /// come from `CaptureSource` so onboarding never drifts from the real badges.
    private var surfaceGrid: some View {
        let sources: [CaptureSource] = [
            .siri, .lockScreenWidget, .actionButton,
            .shortcut, .controlCenter, .homeWidget,
        ]
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.s), count: 3),
            spacing: Theme.Spacing.s
        ) {
            ForEach(sources) { source in
                VStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: source.symbol)
                        .font(.title3)
                        .foregroundStyle(Color.hwangAccent)
                    Text(source.label)
                        .font(Theme.Typography.meta)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.m)
                .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous))
            }
        }
        .frame(maxWidth: 420)
    }

    /// The four quadrants as a quiet 2×2 — names from `Quadrant.title` (spec §8).
    private var quadrantGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.s), count: 2),
            spacing: Theme.Spacing.s
        ) {
            ForEach(Quadrant.assignable) { quadrant in
                VStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: quadrant.symbol)
                        .font(.title3)
                        .foregroundStyle(quadrant.accent)
                    Text(quadrant.title)
                        .font(Theme.Typography.cardTitle)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.m)
                .background(quadrant.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous))
            }
        }
        .frame(maxWidth: 420)
    }

    // MARK: - Controls

    private var pageDots: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(0...Self.lastPage, id: \.self) { index in
                Capsule()
                    .fill(index == page ? Color.hwangAccent : Color(.tertiarySystemFill))
                    .frame(width: index == page ? 22 : 7, height: 7)
            }
        }
        .animation(.hwangSnappy, value: page)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Self.lastPage + 1)장 중 \(page + 1)장")
    }

    /// 다음 on pages 1–3, 시작하기 on the last — the one glass hero element here.
    private var primaryButton: some View {
        Button {
            if page < Self.lastPage {
                withAnimation(.hwangSnappy) { page += 1 }
            } else {
                onFinish()
            }
        } label: {
            Text(page == Self.lastPage ? "시작하기" : "다음")
                .font(Theme.Typography.cardTitle)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xs)
        }
        .buttonStyle(.glassProminent)
        .tint(Color.hwangAccent)
    }
}

/// Shared page skeleton: visual, then title + message, vertically centered with
/// generous margins (spec §15 — wide spacing, clear typographic hierarchy).
private struct OnboardingPageLayout<Visual: View>: View {
    let title: String
    let message: String
    @ViewBuilder var visual: Visual

    init(title: String, message: String, @ViewBuilder visual: () -> Visual) {
        self.title = title
        self.message = message
        self.visual = visual()
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer(minLength: 0)
            visual
            VStack(spacing: Theme.Spacing.m) {
                Text(title)
                    .font(Theme.Typography.hero)
                Text(message)
                    .font(Theme.Typography.cardTitle)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }
            .multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }
}

#Preview {
    OnboardingView {}
}

#Preview("다크 모드") {
    OnboardingView {}
        .preferredColorScheme(.dark)
}
