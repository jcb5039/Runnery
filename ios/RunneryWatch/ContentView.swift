import SwiftUI

/// 러닝 전 기본 화면.
struct ContentView: View {
  /// 앱의 주황(#FF7A00). 경로·현재 위치·시작에만 써요.
  static let orange = Color(red: 1, green: 0.48, blue: 0)

  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: "figure.run")
        .font(.system(size: 34, weight: .semibold))
        .foregroundStyle(Self.orange)
      Text("러너리")
        .font(.system(size: 20, weight: .bold))
      Text("폰에서 러닝을 시작하면\n여기에 기록이 보여요")
        .font(.system(size: 13))
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)
    }
    .padding()
  }
}

#Preview {
  ContentView()
}
