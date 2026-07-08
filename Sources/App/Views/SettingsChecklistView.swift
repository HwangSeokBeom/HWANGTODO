import HWANGTODOCore
import HWANGTODODesign
import SwiftUI
import WidgetKit

/// 설정 tab — 표면별 사용 가능 여부를 보여주는 체크리스트 (spec §13):
/// "이 기능이 있습니다"가 아니라 "지금 이 기능을 사용할 수 있는지".
struct SettingsChecklistView: View {
    @Environment(SurfaceStatusService.self) private var surfaceStatus
    @Environment(TodoRepository.self) private var repository
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase

    /// 하루 점검 time as minutes since midnight (default 21:00).
    /// NotificationManager reads this key when (re)scheduling the daily review.
    @AppStorage("dailyReviewMinutes") private var dailyReviewMinutes = 21 * 60
    #if DEBUG
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @State private var isConfirmingWipe = false
    #endif

    @State private var presentedSurface: SettingsSurface?
    /// Set by the Live Matrix sheet; the 집중 sheet launches only after the
    /// detail sheet is fully gone so the presentations never collide.
    @State private var launchFocusAfterDismiss = false

    var body: some View {
        NavigationStack {
            List {
                Section { headerCard }
                Section("기록 통로") {
                    ForEach(SettingsSurface.captureGroup) { row($0) }
                }
                Section("확인과 연결") {
                    ForEach(SettingsSurface.glanceGroup) { row($0) }
                }
                dailyReviewSection
                infoSection
                #if DEBUG
                developerSection
                #endif
            }
            .navigationTitle(Terminology.tabSettings)
        }
        .task { await surfaceStatus.refresh() }
        .onChange(of: scenePhase) { _, phase in
            // Re-probe on foreground: the user may have just granted a
            // permission or placed a widget outside the app.
            guard phase == .active else { return }
            Task { await surfaceStatus.refresh() }
        }
        .sheet(item: $presentedSurface, onDismiss: handleSheetDismiss) { surface in
            SurfaceDetailSheet(surface: surface, launchFocusOnDismiss: $launchFocusAfterDismiss)
        }
    }

    // MARK: - Header

    private var availableCount: Int {
        SettingsSurface.allCases.count { $0.state(in: surfaceStatus) == .available }
    }

    private var headerCard: some View {
        HStack(spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("시스템 표면 설정")
                    .font(Theme.Typography.sectionTitle)
                Text("\(Terminology.captureWithoutOpening)하는 통로를 한눈에 점검해요")
                    .font(Theme.Typography.meta)
                    .foregroundStyle(.secondary)
                Text("\(SettingsSurface.allCases.count)개 중 \(availableCount)개 사용 가능")
                    .font(Theme.Typography.badge)
                    .foregroundStyle(Color.hwangAccent)
            }
            Spacer(minLength: Theme.Spacing.s)
            ZStack {
                ProgressRing(progress: Double(availableCount) / Double(SettingsSurface.allCases.count))
                Text("\(availableCount)")
                    .font(Theme.Typography.number)
                    .foregroundStyle(Color.hwangAccent)
            }
            .frame(width: 52, height: 52)
        }
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Rows

    private func row(_ surface: SettingsSurface) -> some View {
        Button {
            presentedSurface = surface
        } label: {
            SurfaceChecklistRow(surface: surface, state: surface.state(in: surfaceStatus))
        }
        .buttonStyle(.plain)
    }

    private func handleSheetDismiss() {
        guard launchFocusAfterDismiss else { return }
        launchFocusAfterDismiss = false
        router.presentedSheet = .focus
    }

    // MARK: - 하루 점검

    private var dailyReviewSection: some View {
        Section {
            DatePicker("알림 시간", selection: dailyReviewTimeBinding, displayedComponents: .hourAndMinute)
        } header: {
            Text("하루 점검")
        } footer: {
            Text("매일 이 시간에 하루를 돌아보는 알림이 와요. 알림이 켜져 있어야 도착해요.")
        }
    }

    /// Bridges minutes-since-midnight storage ↔ the time picker. Only the
    /// hour/minute components round-trip; the day is irrelevant.
    private var dailyReviewTimeBinding: Binding<Date> {
        Binding {
            let calendar = Calendar.current
            return calendar.date(
                bySettingHour: dailyReviewMinutes / 60,
                minute: dailyReviewMinutes % 60,
                second: 0,
                of: .now
            ) ?? .now
        } set: { date in
            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
            // Route through NotificationManager (same UserDefaults key) so the
            // daily-review notification reschedules immediately, not at next launch.
            NotificationManager.shared.dailyReviewMinutes = (components.hour ?? 21) * 60 + (components.minute ?? 0)
        }
    }

    // MARK: - 정보

    private var infoSection: some View {
        Section("정보") {
            LabeledContent("버전", value: appVersion)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("개인정보")
                    .font(Theme.Typography.cardTitle)
                Text("할 일·루틴·메모는 iCloud나 외부 서버가 아닌 이 기기 안에만 저장돼요. 위젯과 앱이 같은 저장 공간을 함께 써요.")
                    .font(Theme.Typography.meta)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, Theme.Spacing.xs)
        }
    }

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        return build.map { "\(short) (\($0))" } ?? short
    }

    // MARK: - 개발자 (DEBUG only)

    #if DEBUG
    private var developerSection: some View {
        Section {
            Button("샘플 데이터 넣기") {
                DebugSeeder.seed()
                repository.reload()
                WidgetCenter.shared.reloadAllTimelines()
            }
            Button("모든 데이터 삭제", role: .destructive) {
                isConfirmingWipe = true
            }
            .confirmationDialog(
                "모든 데이터를 삭제할까요?",
                isPresented: $isConfirmingWipe,
                titleVisibility: .visible
            ) {
                Button("모두 삭제", role: .destructive) {
                    DebugSeeder.wipeAll()
                    repository.reload()
                    WidgetCenter.shared.reloadAllTimelines()
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("할 일, 루틴, 채팅 기록이 모두 지워져요. 되돌릴 수 없어요.")
            }
            Button("온보딩 다시 보기") {
                hasCompletedOnboarding = false
            }
        } header: {
            Text("개발자")
        } footer: {
            Text("이 구역은 개발 빌드에서만 보여요.")
        }
    }
    #endif
}

#Preview {
    SettingsChecklistView()
        .environment(TodoRepository())
        .environment(AppRouter())
        .environment(SurfaceStatusService())
}
