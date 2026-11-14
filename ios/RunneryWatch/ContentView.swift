import SwiftUI

/// 폰 러닝 상태에 따라 화면을 바꿔요: 기다림 → 달리는 중 → 일시정지 → 끝.
struct ContentView: View {
  @ObservedObject var model = WatchModel.shared

  var body: some View {
    GeometryReader { geo in
      let scale = min(1, geo.size.width / WatchTheme.baseWidth)
      Group {
        switch model.phase {
        case .idle: IdleView()
        case .running: RunningPager(scale: scale)
        case .paused: PausedView(scale: scale)
        case .ended: EndedView()
        }
      }
      .frame(width: geo.size.width, height: geo.size.height)
    }
    .background(Color.black)
  }
}

/// 러닝 전 기본 화면.
struct IdleView: View {
  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: "figure.run")
        .font(.system(size: 34, weight: .semibold))
        .foregroundStyle(WatchTheme.orange)
      Text("러너리")
        .font(WatchTheme.title(20))
      Text("폰에서 러닝을 시작하면\n여기에 기록이 보여요")
        .font(WatchTheme.label(13))
        .multilineTextAlignment(.center)
        .foregroundStyle(WatchTheme.label)
    }
    .padding()
  }
}

/// 러닝을 저장한 직후 잠깐 보여 줘요.
struct EndedView: View {
  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 34))
        .foregroundStyle(WatchTheme.orange)
      Text("수고했어요")
        .font(WatchTheme.title(18))
      Text("기록은 폰에서 볼 수 있어요")
        .font(WatchTheme.label(12))
        .foregroundStyle(WatchTheme.label)
    }
  }
}

#Preview {
  ContentView()
}
