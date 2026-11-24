import 'package:flutter/foundation.dart';

/// 캐릭터 레벨과 경험치. 경험치는 지금까지 달린 총 거리 100m당 1이고, 저장된 러닝 기록에서 그때그때
/// 계산합니다(따로 저장하지 않으므로 기록을 지우면 줄어듭니다).
///
/// 레벨마다 채워야 하는 경험치(경험치통)가 다르고, 다 채우면 다음 레벨에서 0부터 다시 채웁니다.
/// 첫 버전 만렙은 5레벨이고, 만렙이면 MAX로 보여 줍니다.
///
/// | 레벨 | 경험치통 | 이 레벨이 되는 총 거리 |
/// |---|---|---|
/// | 1 | 50 | 0km |
/// | 2 | 80 | 5km |
/// | 3 | 150 | 13km |
/// | 4 | 250 | 28km |
/// | 5 (만렙) | - | 53km |
@immutable
class HamsterLevel {
  const HamsterLevel._(this.level, this.exp, this.expMax);

  /// 1레벨부터 차례로, 그 레벨에서 다음 레벨까지 채워야 하는 경험치.
  static const expPerLevel = [50, 80, 150, 250];

  /// 만렙.
  static int get maxLevel => expPerLevel.length + 1;

  /// 경험치 1에 해당하는 거리(m).
  static const metersPerExp = 100;

  /// 지금 레벨(1부터).
  final int level;

  /// 이 레벨에서 채운 경험치. 만렙이면 0.
  final int exp;

  /// 이 레벨의 경험치통. 만렙이면 0.
  final int expMax;

  bool get isMax => level >= maxLevel;

  /// 막대를 채울 비율(0~1). 만렙이면 1.
  double get ratio => isMax ? 1 : exp / expMax;

  /// 총 경험치에서 레벨을 구합니다.
  factory HamsterLevel.fromExp(int totalExp) {
    var left = totalExp < 0 ? 0 : totalExp;
    for (var i = 0; i < expPerLevel.length; i++) {
      if (left < expPerLevel[i]) {
        return HamsterLevel._(i + 1, left, expPerLevel[i]);
      }
      left -= expPerLevel[i];
    }
    return HamsterLevel._(maxLevel, 0, 0);
  }

  /// 총 거리(km)에서 레벨을 구합니다. 100m가 다 차야 경험치 1이 됩니다(내림).
  factory HamsterLevel.fromKm(double totalKm) =>
      HamsterLevel.fromExp(expForKm(totalKm));

  /// 총 거리(km)의 경험치. 소수 계산 오차로 1이 모자라지 않게 아주 작은 값을 더해 내림합니다.
  static int expForKm(double totalKm) =>
      (totalKm * 1000 / metersPerExp + 1e-9).floor();
}
