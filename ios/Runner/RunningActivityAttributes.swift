import ActivityKit
import AppIntents
import Foundation

/// 앱(Runner)과 라이브 액티비티 위젯이 함께 쓰는 러닝 상태. 두 타깃에 모두 들어갑니다.
@available(iOS 16.2, *)
struct RunningActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var distanceKm: Double
    var pace: String
    /// 일시정지 중 표시할 운동 시간(초).
    var elapsedSeconds: Int
    /// 달리는 중 시간이 저절로 흐르도록 기준이 되는 시각(지금 - 운동 시간).
    var timerStart: Date
    var paused: Bool
    /// 목표 문구. 자유 러닝이면 nil.
    var goal: String?
    /// 다이내믹 아일랜드 작은 칸에 거리 대신 달리는 시간을 보일지.
    var showTime: Bool
  }
}

/// 잠금 화면·다이내믹 아일랜드의 일시정지·재개 버튼. 위젯과 앱 양쪽에 들어가지만,
/// 버튼을 누르면 iOS가 앱 쪽에서 실행하고 앱이 Flutter 러닝 화면에 알립니다.
extension Notification.Name {
  static let runneryRunControl = Notification.Name("runnery.runControl")
}

@available(iOS 17.0, *)
struct PauseRunIntent: LiveActivityIntent {
  static let title: LocalizedStringResource = "러닝 일시정지"

  func perform() async throws -> some IntentResult {
    NotificationCenter.default.post(name: .runneryRunControl, object: "pause")
    return .result()
  }
}

@available(iOS 17.0, *)
struct ResumeRunIntent: LiveActivityIntent {
  static let title: LocalizedStringResource = "러닝 다시 시작"

  func perform() async throws -> some IntentResult {
    NotificationCenter.default.post(name: .runneryRunControl, object: "resume")
    return .result()
  }
}
