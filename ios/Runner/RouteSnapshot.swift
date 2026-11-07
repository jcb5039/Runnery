import Flutter
import MapLibre
import UIKit

/// 기록 목록 썸네일용 지도 사진. 지도를 화면에 띄우지 않고 이미지로만 그려
/// 여러 장을 보여 줘도 지도 잔상이 생기지 않습니다.
enum RouteSnapshotChannel {
  /// 끝나기 전에 해제되지 않도록 진행 중인 스냅샷을 붙잡아 둡니다.
  private static var running = Set<MLNMapSnapshotter>()

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "runnery/route_snapshot", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "snapshot",
        let args = call.arguments as? [String: Any],
        let style = args["style"] as? String,
        let lats = args["lat"] as? [Double],
        let lngs = args["lng"] as? [Double],
        let starts = args["starts"] as? [Bool],
        let size = args["size"] as? Double,
        let output = args["output"] as? String,
        lats.count == lngs.count, lats.count == starts.count, !lats.isEmpty
      else { return result(FlutterMethodNotImplemented) }
      // 라이트 모드면 경로 아래 테두리를 흰색으로 그립니다(없으면 다크).
      let light = args["light"] as? Bool ?? false
      snapshot(
        style: style,
        light: light,
        points: zip(lats, lngs).map { CLLocationCoordinate2D(latitude: $0, longitude: $1) },
        starts: starts,
        size: CGSize(width: size, height: size),
        output: URL(fileURLWithPath: output),
        done: { result($0) }
      )
    }
  }

  private static func snapshot(
    style: String,
    light: Bool,
    points: [CLLocationCoordinate2D],
    starts: [Bool],
    size: CGSize,
    output: URL,
    done: @escaping (Bool) -> Void
  ) {
    let styleURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("runnery_snapshot_style.json")
    guard (try? style.write(to: styleURL, atomically: true, encoding: .utf8)) != nil else {
      return done(false)
    }
    let options = MLNMapSnapshotOptions(styleURL: styleURL, camera: MLNMapCamera(), size: size)
    options.coordinateBounds = bounds(of: points)
    options.scale = UIScreen.main.scale
    // 88pt 칸에서는 출처 문구가 사진을 회색 띠로 덮습니다. 출처는 앱의 실제 지도 화면에 표시합니다.
    options.showsLogo = false
    options.showsAttribution = false
    let snapshotter = MLNMapSnapshotter(options: options)
    running.insert(snapshotter)
    snapshotter.start { snapshot, _ in
      running.remove(snapshotter)
      guard let snapshot else { return done(false) }
      let image = drawRoute(on: snapshot, points: points, starts: starts, light: light)
      do {
        try image.pngData()?.write(to: output, options: .atomic)
        done(true)
      } catch {
        done(false)
      }
    }
  }

  /// 경로가 칸 안쪽에 들어오도록 여유를 두고, 짧은 경로도 너무 확대되지 않게 최소 약 300m 범위를 둡니다.
  private static func bounds(of points: [CLLocationCoordinate2D]) -> MLNCoordinateBounds {
    var minLat = points.map(\.latitude).min()!, maxLat = points.map(\.latitude).max()!
    var minLng = points.map(\.longitude).min()!, maxLng = points.map(\.longitude).max()!
    let minSpan = 0.003
    func widen(_ low: inout Double, _ high: inout Double) {
      let span = max(high - low, minSpan) * 1.4
      let center = (low + high) / 2
      low = center - span / 2
      high = center + span / 2
    }
    widen(&minLat, &maxLat)
    widen(&minLng, &maxLng)
    return MLNCoordinateBounds(
      sw: CLLocationCoordinate2D(latitude: minLat, longitude: minLng),
      ne: CLLocationCoordinate2D(latitude: maxLat, longitude: maxLng)
    )
  }

  /// 앱 지도와 같은 주황 경로(어두운 테두리)와 출발·도착 점을 지도 사진 위에 그립니다.
  private static func drawRoute(
    on snapshot: MLNMapSnapshot,
    points: [CLLocationCoordinate2D],
    starts: [Bool],
    light: Bool
  ) -> UIImage {
    let base = snapshot.image
    let format = UIGraphicsImageRendererFormat()
    format.scale = base.scale
    return UIGraphicsImageRenderer(size: base.size, format: format).image { context in
      base.draw(at: .zero)
      let cg = context.cgContext
      let path = UIBezierPath()
      for (i, point) in points.enumerated() {
        let p = snapshot.point(for: point)
        if starts[i] || i == 0 { path.move(to: p) } else { path.addLine(to: p) }
      }
      path.lineCapStyle = .round
      path.lineJoinStyle = .round
      (light ? UIColor(white: 1, alpha: 0.9) : UIColor(white: 0, alpha: 0.55)).setStroke()
      path.lineWidth = 5
      path.stroke()
      UIColor(red: 1, green: 0.478, blue: 0, alpha: 1).setStroke()
      path.lineWidth = 3
      path.stroke()

      func dot(_ coordinate: CLLocationCoordinate2D, fill: UIColor) {
        let p = snapshot.point(for: coordinate)
        let rect = CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)
        cg.setFillColor(fill.cgColor)
        cg.fillEllipse(in: rect)
        cg.setStrokeColor(UIColor.black.cgColor)
        cg.setLineWidth(1.5)
        cg.strokeEllipse(in: rect)
      }
      dot(points.last!, fill: UIColor(red: 1, green: 0.478, blue: 0, alpha: 1))
      dot(points.first!, fill: .white)
    }
  }
}
