import Flutter
import MapLibre
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 지도의 기본 내 위치 표시를 앱 주황색(#FF7A00)으로 맞춥니다.
    MLNMapView.appearance().tintColor = UIColor(red: 1, green: 0.478, blue: 0, alpha: 1)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RunningLiveActivity") {
      RunningLiveActivityChannel.register(with: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RouteSnapshot") {
      RouteSnapshotChannel.register(with: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VoiceGuide") {
      VoiceGuideChannel.register(with: registrar.messenger())
    }
  }
}
