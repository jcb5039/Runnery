import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/hamster/hamster_level.dart';

void main() {
  test('100m당 경험치 1, 100m가 다 차야 1이 됩니다', () {
    expect(HamsterLevel.expForKm(0), 0);
    expect(HamsterLevel.expForKm(0.099), 0);
    expect(HamsterLevel.expForKm(0.1), 1);
    expect(HamsterLevel.expForKm(12.37), 123);
    // 소수 계산 오차(0.3 * 10 = 2.9999…)로 하나 모자라지 않습니다.
    expect(HamsterLevel.expForKm(0.3), 3);
  });

  test('레벨별 경험치통 50 · 80 · 150 · 250, 다 채우면 다음 레벨에서 0부터', () {
    void check(double km, int level, int exp, int max) {
      final l = HamsterLevel.fromKm(km);
      expect((l.level, l.exp, l.expMax), (level, exp, max), reason: '$km km');
    }

    check(0, 1, 0, 50);
    check(4.9, 1, 49, 50);
    check(5, 2, 0, 80);
    check(7, 2, 20, 80);
    check(12.9, 2, 79, 80);
    check(13, 3, 0, 150);
    check(27.9, 3, 149, 150);
    check(28, 4, 0, 250);
    check(52.9, 4, 249, 250);
  });

  test('만렙은 5레벨이고 MAX입니다', () {
    for (final km in [53.0, 100.0, 1000.0]) {
      final l = HamsterLevel.fromKm(km);
      expect(l.level, 5);
      expect(l.isMax, isTrue);
      expect(l.ratio, 1);
    }
    expect(HamsterLevel.fromKm(52.9).isMax, isFalse);
  });
}
