import CoreLocation
import Foundation
import WatchConnectivity

/// 폰 러닝 화면에서 받은 상태. 워치는 기록하지 않고 보여 주기만 해요.
final class WatchModel: NSObject, ObservableObject, WCSessionDelegate {
  static let shared = WatchModel()

  enum Phase { case idle, running, paused, ended }

  @Published private(set) var phase: Phase = .idle
  @Published private(set) var autoPaused = false
  /// 폰에 종료 확인 창이 떠 있는 중.
  @Published private(set) var ending = false
  @Published private(set) var meters: Double = 0
  /// 초/km. 모르면 nil.
  @Published private(set) var pace: Double?
  @Published private(set) var averagePace: Double?
  @Published private(set) var speedKmh: Double = 0
  /// 1km마다 걸린 시간(초).
  @Published private(set) var splits: [Int] = []
  @Published private(set) var voice = true
  @Published private(set) var route: [CLLocationCoordinate2D] = []
  /// 러너리 자체 화면 잠금. 버튼이 눌리지 않고, 길게 눌러야 풀려요.
  @Published var locked = false

  /// 폰이 마지막으로 보낸 운동 시간과 그 시각. 달리는 중이면 워치가 이어서 흐르게 해요.
  private var elapsed: TimeInterval = 0
  private var sentAt = Date()
  private var endedTask: Task<Void, Never>?

  func activate() {
    guard WCSession.isSupported() else { return }
    WCSession.default.delegate = self
    WCSession.default.activate()
  }

  /// [date] 시점의 운동 시간.
  func elapsed(at date: Date) -> TimeInterval {
    phase == .running ? elapsed + max(0, date.timeIntervalSince(sentAt)) : elapsed
  }

  // MARK: 버튼

  func send(_ action: String) {
    // 누르자마자 화면이 바뀌게 먼저 반영하고, 폰 상태가 오면 그 값으로 맞춰요.
    switch action {
    case "pause" where phase == .running:
      elapsed = elapsed(at: Date())
      phase = .paused
    case "resume" where phase == .paused:
      sentAt = Date()
      phase = .running
    case "voice":
      voice.toggle()
    default: break
    }
    guard WCSession.default.activationState == .activated, WCSession.default.isReachable else {
      return
    }
    WCSession.default.sendMessage(["action": action], replyHandler: nil, errorHandler: nil)
  }

  // MARK: 받기

  /// 폰 상태를 반영하고, 지금 가진 경로 점 수를 돌려줘요.
  @discardableResult
  private func apply(_ message: [String: Any]) -> Int {
    let state = message["state"] as? String ?? "idle"
    endedTask?.cancel()
    switch state {
    case "running", "paused":
      phase = state == "running" ? .running : .paused
      // 달리는 중에는 워치를 운동 중 상태로 둬서 시계 화면으로 돌아가지 않게 해요.
      WorkoutManager.shared.start()
    case "ended":
      WorkoutManager.shared.end()
      locked = false
      if phase != .idle { phase = .ended }
      route = []
      splits = []
      // 잠깐 '수고했어요'를 보여 준 뒤 기본 화면으로 돌아가요.
      endedTask = Task { @MainActor [weak self] in
        try? await Task.sleep(for: .seconds(4))
        guard !Task.isCancelled, self?.phase == .ended else { return }
        self?.phase = .idle
      }
      return 0
    default:
      phase = .idle
      return route.count
    }
    autoPaused = message["autoPaused"] as? Bool ?? false
    ending = message["ending"] as? Bool ?? false
    elapsed = message["elapsed"] as? Double ?? 0
    if let sent = message["sentAt"] as? Double {
      // 폰과 워치 시계가 조금 달라도 미래 시각이면 지금으로 봐요.
      sentAt = min(Date(timeIntervalSince1970: sent), Date())
    }
    meters = message["distance"] as? Double ?? 0
    pace = (message["pace"] as? Double).flatMap { $0 > 0 ? $0 : nil }
    averagePace = (message["avgPace"] as? Double).flatMap { $0 > 0 ? $0 : nil }
    speedKmh = message["speed"] as? Double ?? 0
    splits = message["splits"] as? [Int] ?? []
    voice = message["voice"] as? Bool ?? voice
    if let from = message["routeFrom"] as? Int, let flat = message["route"] as? [Double] {
      mergeRoute(from: from, flat: flat)
    }
    return route.count
  }

  /// 폰이 [from]번째 점부터 보낸 경로를 이어 붙여요. 0부터 오면 처음부터 다시 받는 거예요.
  private func mergeRoute(from: Int, flat: [Double]) {
    var points: [CLLocationCoordinate2D] = []
    points.reserveCapacity(flat.count / 2)
    var i = 0
    while i + 1 < flat.count {
      points.append(.init(latitude: flat[i], longitude: flat[i + 1]))
      i += 2
    }
    if from == 0 {
      route = points
    } else if from == route.count {
      route += points
    } else if from < route.count {
      let overlap = route.count - from
      if overlap < points.count { route += points[overlap...] }
    }
    // from이 더 크면 중간이 빠진 거라 버려요. 답장으로 받은 개수를 알려 주면 폰이 다시 보내요.
  }

  // MARK: WCSessionDelegate

  func session(
    _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    let context = session.receivedApplicationContext
    guard !context.isEmpty else { return }
    DispatchQueue.main.async { self.apply(context) }
  }

  func session(
    _ session: WCSession, didReceiveMessage message: [String: Any],
    replyHandler: @escaping ([String: Any]) -> Void
  ) {
    let count = DispatchQueue.main.sync { apply(message) }
    replyHandler(["routeCount": count])
  }

  func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
    DispatchQueue.main.async { self.apply(context) }
  }
}
