import 'dart:math' as math;

/// 지도에 그릴 때만 쓰는 경로 다듬기. 저장된 기록·거리 계산은 그대로 둡니다.
///
/// GPS는 서 있어도 몇 m씩 흔들려, 점을 그대로 이으면 곧은 길도 톱니처럼 삐뚤빼뚤합니다.
/// 각 점을 앞뒤로 [sigmaMeters] 안팎의 이웃 점과 거리에 따라 가중 평균합니다(가우스).
/// 처음과 마지막 점은 출발·도착 마커와 맞도록 옮기지 않습니다.
const routeSmoothingSigmaMeters = 10.0;

List<(double, double)> smoothRoute(
  List<(double, double)> points, {
  double sigmaMeters = routeSmoothingSigmaMeters,
}) {
  if (points.length < 3) return points;
  // 경로를 따라 잰 누적 거리(m). 짧은 거리라 평면 근사로 충분합니다.
  final along = List<double>.filled(points.length, 0);
  for (var i = 1; i < points.length; i++) {
    along[i] = along[i - 1] + _meters(points[i - 1], points[i]);
  }
  final reach = sigmaMeters * 2;
  final twoSigma2 = 2 * sigmaMeters * sigmaMeters;
  return [
    points.first,
    for (var i = 1; i < points.length - 1; i++)
      _average(points, along, i, reach, twoSigma2),
    points.last,
  ];
}

(double, double) _average(
  List<(double, double)> points,
  List<double> along,
  int i,
  double reach,
  double twoSigma2,
) {
  var lat = 0.0, lng = 0.0, total = 0.0;
  void add(int j) {
    final d = along[j] - along[i];
    final w = math.exp(-d * d / twoSigma2);
    lat += points[j].$1 * w;
    lng += points[j].$2 * w;
    total += w;
  }

  add(i);
  for (var j = i - 1; j >= 0 && along[i] - along[j] <= reach; j--) {
    add(j);
  }
  for (var j = i + 1; j < points.length && along[j] - along[i] <= reach; j++) {
    add(j);
  }
  return (lat / total, lng / total);
}

double _meters((double, double) a, (double, double) b) {
  const metersPerDegree = 111320.0;
  final dy = (b.$1 - a.$1) * metersPerDegree;
  final dx = (b.$2 - a.$2) * metersPerDegree * math.cos(a.$1 * math.pi / 180);
  return math.sqrt(dx * dx + dy * dy);
}
