import SwiftUI

/// Lightweight, skippable first-run onboarding (4 pages, Korean).
struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private struct Page: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let subtitle: String
    }

    private let pages: [Page] = [
        .init(symbol: "bolt.fill", title: "앱을 열지 않고 기록",
              subtitle: "Siri·액션 버튼·잠금화면·제어센터·위젯으로 할 일을 바로 남기세요. 앱을 열 필요가 없어요."),
        .init(symbol: "tray.full", title: "받은함에 모으기",
              subtitle: "어디서 남겼든 모든 할 일은 받은함 한 곳으로 안전하게 모입니다."),
        .init(symbol: "square.grid.2x2", title: "매트릭스로 정리",
              subtitle: "나중에 급함과 중요도로 정리하세요. 지금 하기·일정 잡기·맡기기·줄이기."),
        .init(symbol: "calendar", title: "캘린더와 위젯으로 실행",
              subtitle: "중요한 일은 캘린더에 일정으로 잡고, 위젯과 라이브 매트릭스로 한눈에 확인하세요.")
    ]

    var body: some View {
        ZStack {
            Theme.screenBackground.ignoresSafeArea()
            VStack(spacing: Theme.Spacing.l) {
                HStack {
                    Spacer()
                    Button("건너뛰기", action: onFinish).font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.horizontal, Theme.Spacing.m)

                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, p in
                        VStack(spacing: Theme.Spacing.l) {
                            Spacer()
                            Image(systemName: p.symbol)
                                .font(.system(size: 64, weight: .regular))
                                .foregroundStyle(MatrixQuadrant.importantNotUrgent.accent)
                            VStack(spacing: Theme.Spacing.s) {
                                Text(p.title).font(.title.weight(.bold)).multilineTextAlignment(.center)
                                Text(p.subtitle).font(.body).foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, Theme.Spacing.xl)
                            Spacer()
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Button(action: next) {
                    Text(page == pages.count - 1 ? "시작하기" : "다음")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.bottom, Theme.Spacing.l)
            }
        }
    }

    private func next() {
        if page < pages.count - 1 { withAnimation { page += 1 } } else { onFinish() }
    }
}
