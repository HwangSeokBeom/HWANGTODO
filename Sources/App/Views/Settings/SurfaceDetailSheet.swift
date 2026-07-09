import HWANGTODOCore
import HWANGTODODesign
import SwiftUI
import UIKit

/// Detail sheet for one 설정 checklist entry: current status, honest iOS
/// constraints, setup steps, and the state-appropriate action (spec §13 —
/// 설정 방법 보기 / 테스트하기 / 열기).
struct SurfaceDetailSheet: View {
    let surface: SettingsSurface
    /// The 집중 sheet must launch *after* this sheet is gone — two sheets can't
    /// share one presentation. The presenting view reads this in `onDismiss`.
    @Binding var launchFocusOnDismiss: Bool

    @Environment(SurfaceStatusService.self) private var surfaceStatus
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    /// Bumped when a permission request is granted — success haptic.
    @State private var grantPulse = 0
    @State private var didSendTestNotification = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    statusHeader
                    content
                }
                .padding(Theme.Spacing.m)
            }
            .background(Theme.screenBackground)
            .navigationTitle(surface.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.success, trigger: grantPulse)
    }

    private var state: SurfaceState { surface.state(in: surfaceStatus) }

    // MARK: - Status header

    private var statusHeader: some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: surface.symbol)
                .font(Theme.Typography.sectionTitle)
                .foregroundStyle(Color.hwangAccent)
                .frame(width: 44, height: 44)
                .background(
                    Color.hwangAccent.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                )
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                SurfaceStateChip(state: state)
                Text(statusExplanation)
                    .font(Theme.Typography.meta)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var statusExplanation: String {
        switch state {
        case .available: "지금 바로 사용할 수 있어요."
        case .needsSetup: "한 번만 설정하면 바로 쓸 수 있어요."
        case .checkManually: "iOS가 설정 여부를 알려주지 않아서 직접 확인이 필요해요."
        case .denied: "권한이 꺼져 있어요. 설정 앱에서 켤 수 있어요."
        case .iosLimited: "iOS 정책상 제한이 있는 기능이에요."
        }
    }

    // MARK: - Per-surface content

    @ViewBuilder
    private var content: some View {
        switch surface {
        case .lockWidget: lockWidgetContent
        case .homeWidget: homeWidgetContent
        case .actionButton: actionButtonContent
        case .siriShortcuts: siriContent
        case .controlCenter: controlCenterContent
        case .notifications: notificationsContent
        case .calendar: calendarContent
        case .liveMatrix: liveMatrixContent
        case .noteLink: noteLinkContent
        }
    }

    private var lockWidgetContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            card("설정 방법") {
                SurfaceSetupSteps(steps: [
                    "잠금화면을 길게 눌러요.",
                    "\u{201C}사용자화\u{201D}를 누르고 잠금화면을 골라요.",
                    "위젯 영역을 누른 뒤 HWANGTODO 위젯을 추가해요.",
                ])
            }
            if !installedLockWidgets.isEmpty {
                card("추가된 위젯") { installedWidgetList(installedLockWidgets) }
            }
            // 정직한 안내 (spec §6.1): 잠금화면 위젯은 확인·진입용이다.
            honestNote("잠금화면 위젯 안에서는 직접 글자를 입력할 수 없어요. 대신 위젯으로 바로 열거나, Siri·단축어·액션 버튼으로 앱을 열지 않고 기록할 수 있어요.")
        }
    }

    private var homeWidgetContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            card("추가된 위젯") {
                if installedHomeWidgets.isEmpty {
                    Text("아직 추가된 홈 화면 위젯이 없어요.")
                        .font(Theme.Typography.meta)
                        .foregroundStyle(.secondary)
                } else {
                    installedWidgetList(installedHomeWidgets)
                }
            }
            card("설정 방법") {
                SurfaceSetupSteps(steps: [
                    "홈 화면의 빈 곳을 길게 눌러요.",
                    "왼쪽 위 \u{201C}편집\u{201D}에서 \u{201C}위젯 추가\u{201D}를 눌러요.",
                    "HWANGTODO를 검색해 원하는 크기로 추가해요.",
                ])
            }
            bodyText("위젯을 누르면 빠른 기록, 정리, 일정 등 관련 화면으로 바로 이동해요.")
        }
    }

    private var actionButtonContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            card("설정 방법") {
                SurfaceSetupSteps(steps: [
                    "설정 앱에서 \u{201C}액션 버튼\u{201D}을 열어요.",
                    "\u{201C}단축어\u{201D}를 골라요.",
                    "HWANGTODO의 빠른 기록을 지정해요.",
                ])
            }
            secondaryButton("설정 열기", systemImage: "gear") { openSystemSettings() }
            // iOS 제약 정직 안내 (spec §6.2): 지정 여부는 앱이 알 수 없다.
            honestNote(
                "iOS는 액션 버튼에 어떤 기능이 연결됐는지 앱에게 알려주지 않아요. "
                    + "그래서 여기서는 항상 \u{201C}확인 필요\u{201D}로 보여요. "
                    + "설정 열기를 누르면 설정 앱으로 이동하니, 첫 화면에서 \u{201C}액션 버튼\u{201D}을 찾아 주세요."
            )
        }
    }

    private var siriContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            card("이렇게 말해 보세요") {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    ForEach(Self.siriPhrases, id: \.self) { phrase in
                        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                            Image(systemName: "mic.fill")
                                .font(Theme.Typography.badge)
                                .foregroundStyle(Color.hwangAccent)
                            Text("\u{201C}\(phrase)\u{201D}")
                                .font(Theme.Typography.cardTitle)
                        }
                    }
                }
            }
            secondaryButton("단축어 앱 열기", systemImage: "square.stack.3d.up") {
                guard let url = URL(string: "shortcuts://") else { return }
                openURL(url)
            }
            honestNote("Siri 사용 준비 여부는 앱이 확인할 수 없어요. 위 문구가 동작하지 않으면 설정 앱에서 Siri가 켜져 있는지 확인해 주세요.")
        }
    }

    private var controlCenterContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            card("설정 방법") {
                SurfaceSetupSteps(steps: [
                    "화면 오른쪽 위에서 아래로 쓸어내려 제어센터를 열어요.",
                    "빈 곳을 길게 누르거나 왼쪽 위 \u{201C}+\u{201D}를 눌러 편집을 시작해요.",
                    "\u{201C}컨트롤 추가\u{201D}에서 HWANGTODO 빠른 기록을 추가해요.",
                ])
            }
            // 정직한 안내 (spec §6.5): 제어센터 컨트롤은 진입점이다.
            honestNote("제어센터 안에서 전체 편집기는 안 돼요 — 빠른 기록 화면으로 연결돼요.")
        }
    }

    private var notificationsContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            card("이런 알림이 와요") {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    infoRow("checkmark.circle", "할 일 알림", "미리 정해 둔 시간에 할 일을 알려줘요.")
                    infoRow("repeat", "루틴 알림", "루틴 시간에 맞춰 알려줘요.")
                    infoRow("moon.stars", "하루 점검", "매일 정한 시간에 하루를 돌아봐요.")
                    infoRow("bolt.circle", "집중 알림", "실시간 현황을 켤 수 없을 때 집중 중임을 알려줘요.")
                }
            }
            switch state {
            case .needsSetup:
                primaryButton("알림 켜기", systemImage: "bell.badge") {
                    Task {
                        let granted = await NotificationManager.shared.requestAuthorization()
                        if granted { grantPulse += 1 }
                        await surfaceStatus.refresh()
                    }
                }
            case .denied:
                secondaryButton("설정 열기", systemImage: "gear") { openSystemSettings() }
                bodyText("알림 권한이 꺼져 있어요. 설정 앱의 알림에서 켜 주세요.")
            case .available:
                primaryButton("테스트하기", systemImage: "paperplane") {
                    NotificationManager.shared.sendTestNotification()
                    didSendTestNotification = true
                }
                if didSendTestNotification {
                    bodyText("잠시 후 알림이 도착해요. 잠금화면이나 알림 센터에서 확인해 보세요.")
                }
            default:
                EmptyView()
            }
        }
    }

    private var calendarContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            // spec §9: 캘린더 연동은 실제 생산성 기능처럼 동작해야 한다.
            card {
                bodyText(
                    "할 일에 날짜를 잡으면 Apple 캘린더 이벤트로 만들 수 있어요. "
                        + "만든 이벤트는 할 일과 연결되고, 일정 화면에서 함께 보여요. "
                        + "캘린더에서 이벤트가 지워져도 할 일은 안전하게 남아요."
                )
            }
            switch state {
            case .needsSetup:
                primaryButton("캘린더 연결하기", systemImage: "calendar.badge.plus") {
                    Task {
                        let granted = await CalendarService.shared.requestAccess()
                        if granted { grantPulse += 1 }
                        CalendarService.shared.refreshStatus()
                        await surfaceStatus.refresh()
                    }
                }
            case .denied:
                secondaryButton("설정 열기", systemImage: "gear") { openSystemSettings() }
                bodyText("캘린더 권한이 꺼져 있어요. 설정 앱에서 캘린더 접근을 켜 주세요.")
            case .available:
                bodyText("캘린더가 연결되어 있어요. \(Terminology.scheduleIt)에서 바로 이벤트를 만들 수 있어요.")
            default:
                EmptyView()
            }
        }
    }

    private var liveMatrixContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            card {
                bodyText("집중을 시작하면 잠금화면과 Dynamic Island에서 지금 집중할 일, 경과 시간, 진행률(예: 1/4)을 바로 확인할 수 있어요.")
            }
            switch state {
            case .available:
                primaryButton("집중 시작해 보기", systemImage: "play.fill") {
                    launchFocusOnDismiss = true
                    dismiss()
                }
            case .denied:
                secondaryButton("설정 열기", systemImage: "gear") { openSystemSettings() }
                bodyText("실시간 현황 표시가 꺼져 있어요. 설정 앱에서 HWANGTODO의 \u{201C}실시간 현황\u{201D}을 켜 주세요.")
            default:
                EmptyView()
            }
            // spec §7: Live Activity는 전체 편집기가 아니다.
            honestNote("잠금화면과 Dynamic Island에서는 확인·완료·이동까지만 돼요. 글자 입력 같은 전체 편집은 iOS가 허용하지 않아요.")
        }
    }

    private var noteLinkContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            card {
                bodyText("각 할 일에 메모를 남기거나 외부 메모 링크를 연결할 수 있어요. Apple 메모 앱의 링크를 붙여 넣으면 할 일에서 바로 열려요. 업무일지, 회의 메모, 아이디어 정리에 좋아요.")
            }
            // 정직한 제한 안내 (spec §11): 비공개 메모 DB에는 접근하지 않는다.
            honestNote("Apple은 메모 앱의 내용을 다른 앱이 읽는 것을 허용하지 않아요. 그래서 HWANGTODO는 메모 원문을 가져오지 않고, 링크로 여는 것까지만 지원해요.")
        }
    }

    // MARK: - Installed widgets

    private static let homeKinds: Set<String> = [
        WidgetKind.homeSmall, WidgetKind.homeMedium, WidgetKind.homeLarge,
    ]
    private static let lockKinds: Set<String> = [
        WidgetKind.lockCircular, WidgetKind.lockRectangular, WidgetKind.lockInline,
    ]

    /// `SurfaceStatusService.installedWidgets` entries are "kind#family".
    private func installedNames(matching kinds: Set<String>) -> [String] {
        surfaceStatus.installedWidgets.compactMap { entry in
            let kind = String(entry.split(separator: "#").first ?? "")
            guard kinds.contains(kind) else { return nil }
            return Self.widgetDisplayName(kind: kind)
        }
    }

    private var installedHomeWidgets: [String] { installedNames(matching: Self.homeKinds) }
    private var installedLockWidgets: [String] { installedNames(matching: Self.lockKinds) }

    private static func widgetDisplayName(kind: String) -> String {
        switch kind {
        case WidgetKind.homeSmall: "홈 화면 · 작게"
        case WidgetKind.homeMedium: "홈 화면 · 중간"
        case WidgetKind.homeLarge: "홈 화면 · 크게"
        case WidgetKind.lockCircular: "잠금화면 · 원형"
        case WidgetKind.lockRectangular: "잠금화면 · 사각형"
        case WidgetKind.lockInline: "잠금화면 · 한 줄"
        case WidgetKind.captureControl: "제어센터 · 빠른 기록"
        default: kind
        }
    }

    private func installedWidgetList(_ names: [String]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ForEach(aggregated(names), id: \.name) { entry in
                HStack(spacing: Theme.Spacing.s) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(Theme.Typography.meta)
                        .foregroundStyle(.green)
                    Text(entry.count > 1 ? "\(entry.name) \(entry.count)개" : entry.name)
                        .font(Theme.Typography.meta)
                }
            }
        }
    }

    /// Same widget placed twice shows once with a count, order preserved.
    private func aggregated(_ names: [String]) -> [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        var order: [String] = []
        for name in names {
            if counts[name] == nil { order.append(name) }
            counts[name, default: 0] += 1
        }
        return order.map { (name: $0, count: counts[$0] ?? 1) }
    }

    // MARK: - Building blocks

    /// 실제 등록된 AppShortcuts 문구 (Intents/AppShortcuts.swift와 동일해야
    /// 한다). iOS 정책상 모든 문구에 앱 이름이 들어간다 — 앱 이름 없는
    /// "할 일 추가" 단독 호출은 불가능하다 (spec §6.3, iOS Limited).
    private static let siriPhrases = [
        "HWANGTODO에 추가",
        "HWANGTODO 할 일 추가",
        "HWANGTODO 빠른 기록",
        "HWANGTODO 빠른 기록 추가",
        "HWANGTODO에 나중에 정리할 일 추가",
    ]

    private func card(_ title: String? = nil, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if let title {
                Text(title).font(Theme.Typography.cardTitle)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private func honestNote(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
            Image(systemName: "info.circle.fill")
                .font(Theme.Typography.meta)
                .foregroundStyle(Color.hwangAccent)
            Text(text)
                .font(Theme.Typography.meta)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typography.meta)
            .foregroundStyle(.secondary)
    }

    private func infoRow(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
            Image(systemName: symbol)
                .font(Theme.Typography.meta)
                .foregroundStyle(Color.hwangAccent)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.Typography.cardTitle)
                Text(detail)
                    .font(Theme.Typography.meta)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func primaryButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(Theme.Typography.cardTitle)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.hwangAccent)
        .controlSize(.large)
    }

    private func secondaryButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(Theme.Typography.cardTitle)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

/// Numbered how-to steps — the "설정 방법 보기" body (spec §13).
struct SurfaceSetupSteps: View {
    let steps: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                    Text("\(index + 1)")
                        .font(Theme.Typography.badge)
                        .frame(width: 22, height: 22)
                        .background(Color.hwangAccent.opacity(0.12), in: Circle())
                        .foregroundStyle(Color.hwangAccent)
                    Text(step)
                        .font(Theme.Typography.meta)
                }
            }
        }
    }
}

#Preview("잠금화면 위젯") {
    SurfaceDetailSheet(surface: .lockWidget, launchFocusOnDismiss: .constant(false))
        .environment(SurfaceStatusService())
}

#Preview("알림") {
    SurfaceDetailSheet(surface: .notifications, launchFocusOnDismiss: .constant(false))
        .environment(SurfaceStatusService())
}
