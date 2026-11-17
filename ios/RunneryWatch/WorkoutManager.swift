import HealthKit
import WatchKit

/// 워치를 '운동 중' 상태로 둬요. 손목을 내려도 시계 화면으로 돌아가지 않아요.
/// 기록은 폰이 하므로 건강 앱에 운동을 저장하지 않아요.
final class WorkoutManager: NSObject, HKWorkoutSessionDelegate {
  static let shared = WorkoutManager()

  private let store = HKHealthStore()
  private var session: HKWorkoutSession?
  /// 권한을 묻는 동안 1초마다 오는 상태 때문에 여러 번 시작하지 않게 막아요.
  private var starting = false

  /// 시작했고 아직 끝나지 않은 운동이 있는지(시작 직후 준비 중일 때도 포함).
  var isActive: Bool { session != nil }

  /// 처음 한 번 건강 권한을 물어요. 운동을 시작하려면 '운동 쓰기' 권한이 필요해요.
  func requestAuthorization() async -> Bool {
    guard HKHealthStore.isHealthDataAvailable() else { return false }
    do {
      try await store.requestAuthorization(
        toShare: [HKObjectType.workoutType()],
        read: [HKQuantityType(.heartRate)])
      return true
    } catch {
      return false
    }
  }

  /// 폰이 러닝을 시작해 워치 앱을 깨웠거나, 달리는 중에 워치 앱을 열었을 때.
  func start(_ configuration: HKWorkoutConfiguration? = nil) {
    guard !isActive, !starting else {
      // 폰이 깨웠는데 이미 운동 중이라고 보고 건너뛴 경우만 남겨요(1초마다 오는 상태는 남기지 않아요).
      if configuration != nil {
        WatchModel.shared.log("workoutSkipped", ["active": isActive, "starting": starting])
      }
      return
    }
    starting = true
    let config = configuration ?? {
      let c = HKWorkoutConfiguration()
      c.activityType = .running
      c.locationType = .outdoor
      return c
    }()
    Task { @MainActor in
      defer { starting = false }
      let asked = await requestAuthorization()
      WatchModel.shared.log(
        "workoutAuth",
        ["asked": asked, "status": Self.name(store.authorizationStatus(for: .workoutType()))])
      guard asked, !isActive else { return }
      do {
        let session = try HKWorkoutSession(healthStore: store, configuration: config)
        session.delegate = self
        self.session = session
        session.startActivity(with: Date())
      } catch {
        self.session = nil
        WatchModel.shared.log("workoutStartFailed", ["error": "\(error)"])
      }
    }
  }

  /// 러닝이 끝나면 운동 상태를 풀어 시계가 평소대로 돌아가게 해요.
  func end() {
    guard let session, isActive else { return }
    session.end()
  }

  // MARK: HKWorkoutSessionDelegate

  func workoutSession(
    _ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
    from fromState: HKWorkoutSessionState, date: Date
  ) {
    WatchModel.shared.log("workoutState", ["from": Self.name(fromState), "to": Self.name(toState)])
    if toState == .ended {
      DispatchQueue.main.async { [weak self] in
        if self?.session === workoutSession { self?.session = nil }
      }
    }
  }

  func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
    WatchModel.shared.log("workoutFailed", ["error": "\(error)"])
    DispatchQueue.main.async { [weak self] in
      if self?.session === workoutSession { self?.session = nil }
    }
  }

  // MARK: 진단 기록용 이름

  private static func name(_ state: HKWorkoutSessionState) -> String {
    switch state {
    case .notStarted: "notStarted"
    case .running: "running"
    case .ended: "ended"
    case .paused: "paused"
    case .prepared: "prepared"
    case .stopped: "stopped"
    @unknown default: "unknown"
    }
  }

  private static func name(_ status: HKAuthorizationStatus) -> String {
    switch status {
    case .notDetermined: "notDetermined"
    case .sharingDenied: "denied"
    case .sharingAuthorized: "authorized"
    @unknown default: "unknown"
    }
  }
}

/// 폰이 `startWatchApp`으로 워치 앱을 깨우면 여기로 운동 설정이 와요.
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
  func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
    WatchModel.shared.log("launchedByPhone")
    WorkoutManager.shared.start(workoutConfiguration)
  }
}
