import Flutter
import Foundation
import WatchConnectivity

/// 러닝 화면(Flutter)과 애플워치 앱을 잇습니다.
/// 폰 → 워치: 1초마다 러닝 상태. 워치가 앱을 열어 두면 바로 보내고(sendMessage),
/// 아니면 마지막 상태만 맡겨 두어(applicationContext) 워치 앱을 열 때 바로 보이게 합니다.
/// 워치 → 폰: 일시정지·다시 시작·종료·음성 안내 버튼.
final class WatchLinkChannel: NSObject, WCSessionDelegate {
  private static let shared = WatchLinkChannel()
  private var channel: FlutterMethodChannel?

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "runnery/watch", binaryMessenger: messenger)
    shared.channel = channel
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "send":
        shared.send(call.arguments as? [String: Any] ?? [:], result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    if WCSession.isSupported() {
      WCSession.default.delegate = shared
      WCSession.default.activate()
    }
  }

  /// 결과: 워치가 받은 경로 점 개수(워치가 앱을 열어 두지 않았으면 nil).
  private func send(_ state: [String: Any], result: @escaping FlutterResult) {
    guard WCSession.isSupported() else { return result(nil) }
    let session = WCSession.default
    guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled
    else { return result(nil) }
    if session.isReachable {
      session.sendMessage(
        state,
        replyHandler: { reply in
          DispatchQueue.main.async { result(reply["routeCount"] as? Int) }
        },
        errorHandler: { _ in
          DispatchQueue.main.async { result(nil) }
        })
    } else {
      // 맡겨 두는 상태는 작게: 경로는 워치 앱이 열리면 다시 받습니다.
      var context = state
      context.removeValue(forKey: "route")
      context.removeValue(forKey: "routeFrom")
      try? session.updateApplicationContext(context)
      result(nil)
    }
  }

  // MARK: 워치에서 온 버튼

  func session(
    _ session: WCSession, didReceiveMessage message: [String: Any],
    replyHandler: @escaping ([String: Any]) -> Void
  ) {
    replyHandler([:])
    forward(message)
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    forward(message)
  }

  private func forward(_ message: [String: Any]) {
    guard let action = message["action"] as? String else { return }
    DispatchQueue.main.async { [weak self] in
      self?.channel?.invokeMethod("control", arguments: action)
    }
  }

  // MARK: WCSessionDelegate

  func session(
    _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {}

  func sessionDidBecomeInactive(_ session: WCSession) {}

  /// 다른 워치로 바꾸면 새 워치와 다시 연결합니다.
  func sessionDidDeactivate(_ session: WCSession) {
    WCSession.default.activate()
  }
}
