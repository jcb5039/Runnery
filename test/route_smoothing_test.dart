import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/record/data/route_smoothing.dart';

void main() {
  test('smoothing flattens GPS zigzag but keeps the ends', () {
    // 북쪽으로 10m 간격, 좌우로 ±4m씩 번갈아 튀는 경로.
    const lngPerMeter = 1 / 88000;
    final zigzag = [
      for (var i = 0; i < 40; i++)
        (37.5 + i * 10 / 111320, 127.0 + (i.isEven ? 4 : -4) * lngPerMeter),
    ];
    final smooth = smoothRoute(zigzag);
    expect(smooth, hasLength(zigzag.length));
    expect(smooth.first, zigzag.first);
    expect(smooth.last, zigzag.last);
    for (var i = 5; i < 35; i++) {
      final sideMeters = (smooth[i].$2 - 127.0).abs() / lngPerMeter;
      expect(sideMeters, lessThan(1.5));
    }
  });

  test('short routes stay as they are', () {
    final two = [(37.5, 127.0), (37.501, 127.0)];
    expect(smoothRoute(two), two);
  });
}
