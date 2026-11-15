import CoreText
import SwiftUI

/// 워치 가이드(14 애플워치)의 색과 글꼴. 숫자는 Archivo(폭 75), 글자는 Pretendard.
enum WatchTheme {
  /// 앱의 주황(#FF7A00). 경로·현재 위치·시작과 지금 상태 강조에만 써요.
  static let orange = Color(red: 1, green: 0.478, blue: 0)
  /// 라벨·단위 회색.
  static let label = Color(white: 0.56)
  static let divider = Color(white: 1, opacity: 0.16)
  /// 조작 버튼 바탕.
  static let button = Color(white: 0.17)

  /// 가이드 기준 화면 폭(46mm, 208pt). 작은 워치는 이 비율로 줄여요.
  static let baseWidth: CGFloat = 208

  // MARK: 글꼴

  /// Archivo 숫자. 가이드: 거리 64 · 페이스 56 · 보조 숫자 20–28.
  static func number(_ size: CGFloat, weight: CGFloat = 700) -> Font {
    font(file: "Archivo-Variable", ext: "ttf", size: size, variation: [wdth: 75, wght: weight])
      ?? .system(size: size, weight: .bold, design: .rounded)
  }

  /// Pretendard 제목(Bold 14).
  static func title(_ size: CGFloat) -> Font {
    font(file: "Pretendard-Bold", ext: "otf", size: size) ?? .system(size: size, weight: .bold)
  }

  /// Pretendard 라벨·단위(SemiBold 11–12).
  static func label(_ size: CGFloat) -> Font {
    font(file: "Pretendard-SemiBold", ext: "otf", size: size)
      ?? .system(size: size, weight: .semibold)
  }

  private static let wdth = 0x7764_7468  // 'wdth'
  private static let wght = 0x7767_6874  // 'wght'
  private static var descriptors: [String: CTFontDescriptor] = [:]

  /// 앱 안에 넣은 글꼴 파일을 바로 읽어요(시스템에 등록하지 않음).
  private static func font(
    file: String, ext: String, size: CGFloat, variation: [Int: CGFloat] = [:]
  ) -> Font? {
    var descriptor = descriptors[file]
    if descriptor == nil,
      let url = Bundle.main.url(forResource: file, withExtension: ext),
      let list = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
      let first = list.first
    {
      descriptor = first
      descriptors[file] = first
    }
    guard var d = descriptor else { return nil }
    for (axis, value) in variation {
      d = CTFontDescriptorCreateCopyWithVariation(d, axis as CFNumber, value)
    }
    return Font(CTFontCreateWithFontDescriptor(d, size, nil))
  }
}

/// 숫자 표시 형식. 폰 러닝 화면과 같게 맞춰요.
enum WatchFormat {
  /// 5.24
  static func km(_ meters: Double) -> String { String(format: "%.2f", meters / 1000) }

  /// 6'12" (모르면 -'--")
  static func pace(_ secondsPerKm: Double?) -> String {
    guard let s = secondsPerKm, s.isFinite, s > 0 else { return "-'--\"" }
    let t = Int(s.rounded())
    return String(format: "%d'%02d\"", t / 60, t % 60)
  }

  /// 32:15, 1:02:15
  static func clock(_ seconds: TimeInterval) -> String {
    let t = Int(seconds)
    let h = t / 3600, m = t / 60 % 60, s = t % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
  }
}
