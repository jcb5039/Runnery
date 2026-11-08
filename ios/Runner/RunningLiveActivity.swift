import ActivityKit
import Flutter
import Foundation

/// Flutter에서 러닝 상태를 받아 다이내믹 아일랜드·잠금 화면의 라이브 액티비티를 켜고 끕니다.
enum RunningLiveActivityChannel {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "runnery/live_activity", binaryMessenger: messenger)
    // 잠금 화면 버튼(PauseRunIntent·ResumeRunIntent)을 누르면 러닝 화면에 전합니다.
    NotificationCenter.default.addObserver(
      forName: .runneryRunControl, object: nil, queue: .main
    ) { note in
      guard let action = note.object as? String else { return }
      channel.invokeMethod("control", arguments: action)
    }
    channel.setMethodCallHandler { call, result in
      guard #available(iOS 16.2, *) else { return result(false) }
      let args = call.arguments as? [String: Any] ?? [:]
      Task {
        switch call.method {
        case "start": result(await start(state(from: args)))
        case "update": await update(state(from: args)); result(nil)
        case "end": await endAll(); result(nil)
        default: result(FlutterMethodNotImplemented)
        }
      }
    }
  }

  @available(iOS 16.2, *)
  private static func state(from args: [String: Any]) -> RunningActivityAttributes.ContentState {
    let elapsed = args["elapsedSeconds"] as? Int ?? 0
    return .init(
      distanceKm: args["distanceKm"] as? Double ?? 0,
      pace: args["pace"] as? String ?? "-′--″",
      elapsedSeconds: elapsed,
      timerStart: Date().addingTimeInterval(-Double(elapsed)),
      paused: args["paused"] as? Bool ?? false,
      goal: args["goal"] as? String,
      showTime: args["showTime"] as? Bool ?? false
    )
  }

  /// 앱이 강제 종료돼 남은 이전 러닝 표시는 지우고 새로 켭니다.
  @available(iOS 16.2, *)
  private static func start(_ state: RunningActivityAttributes.ContentState) async -> Bool {
    await endAll()
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }
    do {
      _ = try Activity.request(
        attributes: RunningActivityAttributes(),
        content: .init(state: state, staleDate: nil)
      )
      return true
    } catch {
      return false
    }
  }

  @available(iOS 16.2, *)
  private static func update(_ state: RunningActivityAttributes.ContentState) async {
    for activity in Activity<RunningActivityAttributes>.activities {
      await activity.update(.init(state: state, staleDate: nil))
    }
  }

  @available(iOS 16.2, *)
  private static func endAll() async {
    for activity in Activity<RunningActivityAttributes>.activities {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
  }
}
