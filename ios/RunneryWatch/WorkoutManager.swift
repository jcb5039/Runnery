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
    guard !isActive, !starting else { return }
    starting = true
    let config = configuration ?? {
      let c = HKWorkoutConfiguration()
      c.activityType = .running
      c.locationType = .outdoor
      return c
    }()
    Task { @MainActor in
      defer { starting = false }
      guard await requestAuthorization(), !isActive else { return }
      do {
        let session = try HKWorkoutSession(healthStore: store, configuration: config)
        session.delegate = self
        self.session = session
        session.startActivity(with: Date())
      } catch {
        self.session = nil
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
    if toState == .ended {
      DispatchQueue.main.async { [weak self] in
        if self?.session === workoutSession { self?.session = nil }
      }
    }
  }

  func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
    DispatchQueue.main.async { [weak self] in
      if self?.session === workoutSession { self?.session = nil }
    }
  }
}

/// 폰이 `startWatchApp`으로 워치 앱을 깨우면 여기로 운동 설정이 와요.
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
  func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
    WorkoutManager.shared.start(workoutConfiguration)
  }
}
