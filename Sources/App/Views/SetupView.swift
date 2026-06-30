import SwiftUI
import UserNotifications

/// 설정 — honest activation hub. Explains each system surface, shows status where
/// detectable, offers test actions. No impossible-capability claims.
struct SetupView: View {
    @Environment(TaskModel.self) private var model
    @StateObject private var notifications = NotificationManager.shared
    @State private var calendar = CalendarService.shared
    @State private var focus = FocusSessionManager.shared

    @AppStorage("dailyReviewEnabled") private var dailyReviewEnabled = false
    @State private var showReset = false

    var body: some View {
        NavigationStack {
            List {
                surfacesSection
                notificationsSection
                calendarSection
                liveActivitySection
                dataSection
                aboutSection
            }
            .navigationTitle("설정")
            .task {
                await notifications.refreshAuthorizationStatus()
                calendar.refreshStatus()
                focus.refresh()
            }
            .confirmationDialog("샘플 데이터를 초기화할까요?", isPresented: $showReset, titleVisibility: .visible) {
                Button("초기화", role: .destructive) { model.resetSampleData() }
                Button("취소", role: .cancel) {}
            } message: { Text("모든 할 일·루틴·채팅이 기본 샘플로 대체돼요.") }
        }
    }

    private var surfacesSection: some View {
        Section {
            row("lock.iphone", "잠금화면 위젯",
                "오늘 개수·집중 상태를 보여주고 빠른 기록이나 매트릭스를 열어요. 잠금화면에서는 글자를 직접 입력할 수 없어요 — iOS 제약이에요.")
            row("rectangle.3.group", "홈 화면 매트릭스 위젯",
                "2×2 사분면 개수를 한눈에 보고 각 사분면으로 바로 이동해요.")
            row("button.horizontal.top.press", "액션 버튼",
                "설정 → 액션 버튼 → 단축어 → ‘HWANGTODO에 추가’를 지정하면 앱을 열지 않고 기록해요.")
            row("mic.fill", "Siri / 단축어",
                "“HWANGTODO에 추가”라고 말하면 Siri가 내용을 묻고 받은함에 저장해요.")
            row("switch.2", "제어센터",
                "iOS 18 이상에서 HWANGTODO 컨트롤을 추가하세요. 컨트롤은 빠른 기록을 열 수 있어요 — 전체 편집기는 불가능해요.")
            row("note.text", "메모 연결",
                "할 일에 메모 URL을 붙이거나 내부 메모를 적을 수 있어요. (Apple 메모 비공개 DB에는 접근하지 않아요.)")
        } header: {
            Text("시스템 곳곳에서 기록")
        } footer: {
            Text("HWANGTODO는 앱을 열지 않고 기록하도록 만들었어요. 앱은 정리·검토·계획을 위한 공간이에요.")
        }
    }

    private func row(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.title3).frame(width: 28).foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var notificationsSection: some View {
        Section("알림") {
            HStack { Text("권한"); Spacer(); Text(notifLabel).foregroundStyle(.secondary) }
            if notifications.authorizationStatus != .authorized {
                Button("권한 요청") { Task { await notifications.requestAuthorization() } }
            }
            Button("테스트 알림 보내기") { Task { await notifications.scheduleTestNotification() } }
            Toggle("매일 정리 알림 (오후 9시)", isOn: $dailyReviewEnabled)
                .onChange(of: dailyReviewEnabled) { _, on in
                    Task {
                        if on { await notifications.scheduleDailyReview(hour: 21, minute: 0) }
                        else { notifications.cancelDailyReview() }
                    }
                }
        }
    }

    private var notifLabel: String {
        switch notifications.authorizationStatus {
        case .authorized: return "허용됨"
        case .denied: return "거부됨"
        case .provisional: return "임시"
        case .ephemeral: return "임시"
        case .notDetermined: return "미설정"
        @unknown default: return "알 수 없음"
        }
    }

    private var calendarSection: some View {
        Section {
            HStack { Text("Apple 캘린더"); Spacer(); Text(calLabel).foregroundStyle(.secondary) }
            if !calendar.isAuthorized {
                Button("캘린더 접근 허용") { Task { await calendar.requestAccess() } }
            }
        } header: {
            Text("캘린더")
        } footer: {
            Text("‘중요하지만 급하지 않음’ 할 일을 일정으로 잡고 오늘 일정을 봅니다. 일정은 요청할 때만 만들어져요.")
        }
    }

    private var calLabel: String {
        if calendar.isAuthorized { return "허용됨" }
        switch calendar.authorizationStatus {
        case .denied: return "거부됨"
        case .restricted: return "제한됨"
        default: return "미설정"
        }
    }

    private var liveActivitySection: some View {
        Section {
            HStack {
                Text("라이브 매트릭스")
                Spacer()
                Text(focus.isSupported ? (focus.isRunning ? "실행 중" : "준비됨") : "사용 불가")
                    .foregroundStyle(.secondary)
            }
            if focus.isRunning { Button("집중 종료") { focus.stop() } }
        } header: {
            Text("라이브 액티비티")
        } footer: {
            Text("잠금화면·다이내믹 아일랜드에 현재 집중 할 일·사분면·경과 시간·진행도를 보여줘요. 할 일을 편집하는 기능은 아니에요 — 글자 입력은 불가능해요. 할 일의 ‘집중 시작’에서 켤 수 있어요.")
        }
    }

    private var dataSection: some View {
        Section("데이터") {
            Button("샘플 데이터 초기화") { showReset = true }
        }
    }

    private var aboutSection: some View {
        Section("정보") {
            LabeledContent("앱", value: "HWANGTODO")
            LabeledContent("버전", value: "0.4")
            Text("빠르게 기록하고 나중에 정리하세요. 앱을 열지 않아도 할 일을 남길 수 있어요. 로컬 우선 · 계정 없음 · 동기화 없음.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}
