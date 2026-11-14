import SwiftUI

/// 러너리 애플워치 앱. 폰에서 달리는 러닝을 손목에서 보고, 일시정지·종료를 눌러요.
@main
struct RunneryWatchApp: App {
  init() {
    WatchModel.shared.activate()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
