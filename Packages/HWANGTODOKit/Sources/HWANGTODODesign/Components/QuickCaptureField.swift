import HWANGTODOCore
import SwiftUI

/// The signature quick-capture input — a glass capsule with a single job:
/// get the thought out of the user's head in under a second (spec §5).
/// Used in the tab-bar bottom accessory and on the 기록 home.
public struct QuickCaptureField: View {
    @Binding var text: String
    var prompt: String
    var onSubmit: (String) -> Void
    @FocusState private var isFocused: Bool

    public init(
        text: Binding<String>,
        prompt: String = Terminology.quickCapturePlaceholder,
        onSubmit: @escaping (String) -> Void
    ) {
        _text = text
        self.prompt = prompt
        self.onSubmit = onSubmit
    }

    public var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(Color.hwangAccent)
                .font(.title3)
            TextField(prompt, text: $text)
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit(submit)
            if !text.isEmpty {
                Button(action: submit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.hwangAccent)
                }
                .accessibilityLabel("기록하기")
            }
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
    }

    /// Programmatic keyboard focus (deep links bump a token to re-focus).
    public func focused(_ focused: Bool) -> some View {
        onAppear { isFocused = focused }
    }

    private func submit() {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        onSubmit(value)
        text = ""
        isFocused = true
    }
}
