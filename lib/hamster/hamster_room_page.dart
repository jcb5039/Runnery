import 'package:flutter/material.dart';

import '../record/data/running_record_store.dart';
import 'hamster_level.dart';

/// 캐릭터 탭('룸메이트') 미리보기. 폰에서 어떻게 보이는지 보려고 시안 그림을 잘라
/// 그대로 보여 줍니다(맨 위 제목은 그림에서 지웠습니다). Lv은 그림에 들어 있어 바뀌지 않고, EXP 막대는
/// 그림 속 막대 위에 코드로 같은 모양을 덮어 그립니다. 'Lv. 1' 부분도 코드로 덮어 진짜 레벨을 보여 줍니다.
/// 레벨·경험치는 저장된 러닝 기록의 총 거리로 계산합니다([HamsterLevel]). 진짜 화면은 배경·캐릭터 그림을 따로 받아 다시 만듭니다.
///
/// 햄스터는 시안에서 떼어 낸 그림을 배경 속 햄스터 자리에 겹쳐, 천천히 부풀었다 가라앉으며 숨 쉬게 합니다.
class HamsterRoomPage extends StatefulWidget {
  const HamsterRoomPage({super.key, this.records});

  /// 기본값은 RunningRecordStore.instance.
  final RunningRecordStore? records;

  @override
  State<HamsterRoomPage> createState() => _HamsterRoomPageState();
}

class _HamsterRoomPageState extends State<HamsterRoomPage>
    with SingleTickerProviderStateMixin {
  /// 시안 맨 위(제목 칸) 색. 상태 표시줄 뒤를 같은 색으로 채웁니다.
  static const _topColor = Color(0xFFFCF2EA);

  /// 배경 그림(room_preview.png) 크기와, 그 안에서 햄스터 그림(hamster_preview.png)을 잘라 낸 자리.
  static const _roomSize = Size(816, 1450);
  static const _hamsterRect = Rect.fromLTWH(260, 655, 295, 330);

  /// 배경 그림 속 EXP 막대(바깥 둥근 칸) 자리. 코드로 그린 막대를 정확히 겹칩니다.
  static const _expRect = Rect.fromLTRB(36, 1368, 778, 1432);

  /// 배경 그림 속 'Lv. 1' 진한 칸 자리. 코드로 그린 레벨 칸을 겹칩니다.
  static const _lvRect = Rect.fromLTRB(272, 558, 383, 603);

  late final RunningRecordStore _records =
      widget.records ?? RunningRecordStore.instance;
  HamsterLevel _level = HamsterLevel.fromExp(0);

  @override
  void initState() {
    super.initState();
    // 러닝을 저장하거나 기록을 지우면 다시 계산합니다.
    _records.addListener(_reload);
    _reload();
  }

  Future<void> _reload() async {
    try {
      final records = await _records.load();
      final km = records.fold<double>(0, (sum, r) => sum + r.distanceKm);
      if (mounted) setState(() => _level = HamsterLevel.fromKm(km));
    } catch (_) {
      // 기록을 못 읽으면 지금 레벨을 그대로 둡니다.
    }
  }

  /// 숨 한 번(들이쉬기 → 내쉬기 → 잠깐 멈춤)에 걸리는 시간.
  static const _breath = Duration(milliseconds: 3200);

  /// 숨 한 번 안에서 들이쉬기가 끝나는 지점과 내쉬기가 끝나는 지점(나머지는 멈춤).
  /// 실제 숨처럼 들이쉬기가 내쉬기보다 조금 빠릅니다.
  static const _inhaleEnd = 0.38, _exhaleEnd = 0.85;

  /// 지금 얼마나 들이쉬었는지(0 = 평소, 1 = 다 들이쉼). 들이쉬기·내쉬기 모두 천천히 시작해 천천히 끝납니다.
  static double _breathAmount(double t) {
    if (t < _inhaleEnd) return Curves.easeInOut.transform(t / _inhaleEnd);
    if (t < _exhaleEnd) {
      return 1 -
          Curves.easeInOut.transform(
            (t - _inhaleEnd) / (_exhaleEnd - _inhaleEnd),
          );
    }
    return 0;
  }

  /// 들이쉴 때 커지는 정도. 픽셀 한 칸(그림에서 약 9.5px) 만큼 키가 커지고 옆으로 조금 넓어집니다.
  /// 배경에 원래 햄스터가 있어서 줄어들지는 않고 커지기만 합니다(줄면 뒤의 햄스터가 비칩니다).
  /// [_breathSize]로 크기를 조절합니다(1 = 픽셀 한 칸, 사용자 요청으로 70%).
  static const _breathSize = 0.7;
  static const _inhaleScaleY = 1 + 9.5 / 300 * _breathSize;
  static const _inhaleScaleX = 1 + 4.75 / 280 * _breathSize;

  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: _breath,
  )..repeat();

  @override
  void dispose() {
    _records.removeListener(_reload);
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: _topColor,
    child: SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, box) {
          // 배경을 BoxFit.cover·가운데 맞춤으로 그릴 때의 배율과 위치를 그대로 계산해 햄스터를 겹칩니다.
          final scale = [
            box.maxWidth / _roomSize.width,
            box.maxHeight / _roomSize.height,
          ].reduce((a, b) => a > b ? a : b);
          final dx = (box.maxWidth - _roomSize.width * scale) / 2;
          final dy = (box.maxHeight - _roomSize.height * scale) / 2;
          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/hamster/room_preview.png',
                  fit: BoxFit.cover,
                  // 픽셀 그림이 뭉개지지 않게 가장 가까운 픽셀로 늘립니다.
                  filterQuality: FilterQuality.none,
                ),
              ),
              Positioned(
                left: dx + _hamsterRect.left * scale,
                top: dy + _hamsterRect.top * scale,
                width: _hamsterRect.width * scale,
                height: _hamsterRect.height * scale,
                child: AnimatedBuilder(
                  animation: _clock,
                  builder: (context, child) {
                    final a = _breathAmount(_clock.value);
                    return Transform(
                      alignment: Alignment.bottomCenter,
                      transform: Matrix4.diagonal3Values(
                        1 + (_inhaleScaleX - 1) * a,
                        1 + (_inhaleScaleY - 1) * a,
                        1,
                      ),
                      child: child,
                    );
                  },
                  child: Image.asset(
                    'assets/hamster/hamster_preview.png',
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.none,
                  ),
                ),
              ),
              Positioned(
                left: dx + _expRect.left * scale,
                top: dy + _expRect.top * scale,
                width: _expRect.width * scale,
                height: _expRect.height * scale,
                child: _ExpBar(level: _level, scale: scale),
              ),
              Positioned(
                left: dx + _lvRect.left * scale,
                top: dy + _lvRect.top * scale,
                width: _lvRect.width * scale,
                height: _lvRect.height * scale,
                child: _LevelChip(level: _level.level, scale: scale),
              ),
            ],
          );
        },
      ),
    ),
  );
}

/// EXP 막대. 시안 막대와 같은 모양(흰 테두리의 연한 살구색 칸, 갈색 글자, 회색 길에 주황 채움)이고,
/// 치수는 배경 그림 픽셀 기준에 [scale]을 곱해 그림과 같은 크기로 그립니다.
class _ExpBar extends StatelessWidget {
  const _ExpBar({required this.level, required this.scale});

  final HamsterLevel level;
  final double scale;

  // 시안에서 잰 색.
  static const _fill = Color(0xFFFCE7D7);
  static const _border = Color(0xFFFFF6F0);
  static const _text = Color(0xFF774015);
  static const _track = Color(0xFFD3D8E1);
  static const _progress = Color(0xFFFFA301);

  @override
  Widget build(BuildContext context) {
    final ratio = level.ratio.clamp(0.0, 1.0);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _fill,
        borderRadius: BorderRadius.circular(32 * scale),
        border: Border.all(color: _border, width: 3 * scale),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(29 * scale, 0, 28 * scale, 0),
        child: Row(
          children: [
            SizedBox(
              width: 200 * scale,
              child: Text(
                level.isMax ? 'EXP MAX' : 'EXP ${level.exp} / ${level.expMax}',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 22 * scale,
                  fontWeight: FontWeight.w700,
                  color: _text,
                ),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13 * scale),
                child: SizedBox(
                  height: 26 * scale,
                  child: Stack(
                    children: [
                      const Positioned.fill(child: ColoredBox(color: _track)),
                      FractionallySizedBox(
                        widthFactor: ratio,
                        heightFactor: 1,
                        child: const ColoredBox(color: _progress),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 'Lv. N' 칸. 1~5레벨은 회색입니다.
class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.level, required this.scale});

  final int level;
  final double scale;

  static const _gray = Color(0xFF8E8E93);

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: _gray,
      borderRadius: BorderRadius.circular(22 * scale),
    ),
    child: Center(
      child: Text(
        'Lv. $level',
        maxLines: 1,
        style: TextStyle(
          fontSize: 24 * scale,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    ),
  );
}
