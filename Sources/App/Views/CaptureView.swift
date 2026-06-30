import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// 빠른 기록 — the in-app fallback. The real speed lives on the system surfaces,
/// which this screen points to. The text field here is a fallback only.
struct CaptureView: View {
    @Environment(TaskModel.self) private var model
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var saved = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("빠른 기록").font(.largeTitle.weight(.bold))
                        Text("가장 빠른 입력은 앱 밖에 있어요.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    surfacesCard
                    fallbackField
                    secondaryActions
                }
                .padding(Theme.Spacing.m)
            }
            .background(Theme.screenBackground)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() } } }
            .onAppear { focused = true }
        }
    }

    private var surfacesCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Label("Siri · 액션 버튼 · 잠금화면 · 위젯에서 바로 기록", systemImage: "lock.iphone")
                .font(.subheadline.weight(.semibold))
            Text("앱을 열지 않아도 할 일을 남길 수 있어요. 남긴 할 일은 모두 받은함으로 모입니다.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.m)
        .background(MatrixQuadrant.importantNotUrgent.accent.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private var fallbackField: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("직접 입력").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            TextField("할 일을 입력하세요…", text: $text, axis: .vertical)
                .font(.title3).focused($focused).lineLimit(1...5).cardSurface()
            Button(action: save) {
                Label("받은함에 저장", systemImage: "tray.and.arrow.down.fill")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            if saved {
                Label("받은함에 저장됨", systemImage: "checkmark.circle.fill")
                    .font(.footnote).foregroundStyle(.green)
            }
        }
    }

    private var secondaryActions: some View {
        VStack(spacing: Theme.Spacing.s) {
            row("매트릭스 열기", "square.grid.2x2") { dismiss(); router.selectedTab = .matrix }
            row("설정 열기", "gearshape") { dismiss(); router.selectedTab = .setup }
            row("단축어 캡처 테스트", "square.stack.3d.up") {
                model.capture("단축어 캡처 테스트", source: .shortcut); saved = true
            }
        }
    }

    private func row(_ title: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .font(.subheadline).cardSurface()
        }
        .buttonStyle(.plain)
    }

    private func save() {
        guard model.capture(text, source: .app) != nil else { return }
        text = ""; saved = true; focused = true
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}
