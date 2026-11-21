import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../design_system/app_colors.dart';
import '../../../design_system/app_component_metrics.dart';
import '../../../design_system/app_radius.dart';
import '../../../design_system/app_spacing.dart';
import '../../../design_system/app_text_styles.dart';
import '../running_home_page.dart';
import '../running_start_page.dart' show WhiteButton, runningNumberStyle;
import 'stretch_figure.dart';

/// 스트레칭 동작 하나.
class StretchMove {
  const StretchMove({
    required this.name,
    required this.summary,
    required this.description,
    required this.seconds,
    this.side = '',
    this.tip = '',
  });

  final String name;

  /// 안내 화면 목록의 짧은 설명.
  final String summary;

  /// 따라 하기 화면의 설명.
  final String description;
  final int seconds;

  /// 양쪽을 번갈아 하는 부위(발목·다리). 비어 있으면 한 번에 하는 동작입니다.
  final String side;

  /// 한 번에 하는 동작의 요령 한 줄.
  final String tip;

  bool get sided => side.isNotEmpty;
}

/// 30 스트레칭: 달리기 전 5개 동작, 약 3분.
const stretchMoves = [
  StretchMove(
    name: '발목 돌리기',
    summary: '양쪽 15초씩 천천히',
    description: '발끝을 바닥에 대고 발목으로 천천히 원을 그려요',
    seconds: 30,
    side: '발목',
  ),
  StretchMove(
    name: '레그 스윙',
    summary: '양쪽 20초씩 앞뒤로',
    description: '벽을 짚고 한쪽 다리를 앞뒤로 크게 흔들어요',
    seconds: 40,
    side: '다리',
  ),
  StretchMove(
    name: '워킹 런지',
    summary: '걸으며 무릎 굽혔다 펴기',
    description: '한 걸음 크게 내딛고 무릎을 굽혔다 펴며 앞으로 가요',
    seconds: 40,
    tip: '상체는 곧게 세우고 천천히 내디뎌요',
  ),
  StretchMove(
    name: '하이 니',
    summary: '무릎을 허리 높이로',
    description: '제자리에서 무릎을 허리 높이까지 번갈아 올려요',
    seconds: 30,
    tip: '팔도 함께 앞뒤로 흔들어요',
  ),
  StretchMove(
    name: '버트 킥',
    summary: '뒤꿈치로 엉덩이 차기',
    description: '뒤꿈치가 엉덩이에 닿도록 제자리에서 가볍게 뛰어요',
    seconds: 30,
    tip: '상체는 곧게, 착지는 가볍게',
  ),
];

/// 스트레칭 화면들의 경로 이름. 러닝 화면으로 넘어갈 때 이 화면들을 한꺼번에 닫습니다.
const _stretchRouteName = 'stretch';

/// 홈의 '러닝'에서 여는 스트레칭 안내 화면 경로.
Route<void> stretchIntroRoute() => PageRouteBuilder(
  settings: const RouteSettings(name: _stretchRouteName),
  // 홈→러닝 시작: 애니메이션 없이 바로 전환.
  transitionDuration: Duration.zero,
  reverseTransitionDuration: Duration.zero,
  pageBuilder: (_, _, _) => const StretchIntroPage(),
);

/// 스트레칭 없이 바로 여는 러닝 목표 설정 화면 경로(설정에서 스트레칭 안내를 끈 경우).
Route<void> runningHomeRoute() => PageRouteBuilder(
  transitionDuration: Duration.zero,
  reverseTransitionDuration: Duration.zero,
  pageBuilder: (_, _, _) => const RunningHomePage(),
);

Route<void> _stretchRoute(Widget page) => MaterialPageRoute(
  settings: const RouteSettings(name: _stretchRouteName),
  builder: (_) => page,
);

/// 스트레칭 화면을 모두 닫고 러닝 목표 설정 화면(05 러닝 시작)으로 갑니다.
void _goRun(BuildContext context) => Navigator.of(context).pushAndRemoveUntil(
  MaterialPageRoute<void>(builder: (_) => const RunningHomePage()),
  (route) => route.settings.name != _stretchRouteName,
);

/// 스트레칭 화면을 모두 닫고 홈으로 돌아갑니다.
void _closeAll(BuildContext context) =>
    Navigator.of(context)
        .popUntil((route) => route.settings.name != _stretchRouteName);

String _two(int n) => n.toString().padLeft(2, '0');

TextStyle get _title => TextStyle(
  fontSize: 30,
  fontWeight: FontWeight.w700,
  height: 1.3,
  letterSpacing: -0.75,
  color: AppColors.textPrimary,
);

TextStyle get _body => TextStyle(
  fontSize: 15,
  height: 1.5,
  letterSpacing: -0.15,
  color: AppColors.textSecondary,
);

TextStyle _number(double size, {Color? color}) =>
    runningNumberStyle(size, weight: FontWeight.w600, color: color);

/// 화면 위 52 높이 줄의 X 버튼.
Widget _closeButton(String tooltip, VoidCallback onPressed) => IconButton(
  tooltip: tooltip,
  onPressed: onPressed,
  icon: Icon(Icons.close, size: 22, color: AppColors.textPrimary),
);

/// 글자만 있는 회색 버튼: 건너뛰기·다시 하기.
Widget _textButton(String label, VoidCallback onPressed) => TextButton(
  onPressed: onPressed,
  style: TextButton.styleFrom(
    minimumSize: const Size(0, 44),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space2),
    foregroundColor: AppColors.textSecondary,
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  ),
  child: Text(label),
);

// ─────────────────────────────────────────────────────
// 30-1 안내
// ─────────────────────────────────────────────────────

/// 30-1 스트레칭 안내: 동작 목록과 시작·건너뛰기.
class StretchIntroPage extends StatelessWidget {
  const StretchIntroPage({super.key});

  @override
  Widget build(BuildContext context) {
    final total = stretchMoves.fold<int>(0, (sum, m) => sum + m.seconds);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 52,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space3,
                ),
                child: _closeButton('닫기', () => Navigator.of(context).pop()),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.space4,
                  AppSpacing.screenHorizontal,
                  AppSpacing.space4,
                ),
                children: [
                  Text(
                    'WARM UP',
                    style: AppTextStyles.authLabel.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space3),
                  Text(
                    '달리기 전에\n몸을 풀어요',
                    style: _title.copyWith(fontSize: 28, letterSpacing: -0.7),
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.schedule,
                        label: '약 ${(total / 60).round()}분',
                      ),
                      const SizedBox(width: AppSpacing.space2),
                      _InfoChip(
                        icon: Icons.format_list_bulleted,
                        label: '${stretchMoves.length}개 동작',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space6),
                  Divider(height: 1, color: AppColors.divider),
                  for (final (i, m) in stretchMoves.indexed) ...[
                    _MoveRow(number: i + 1, move: m),
                    Divider(height: 1, color: AppColors.divider),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '통증이 느껴지면 바로 멈추고 쉬어 주세요',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.space4,
                AppSpacing.screenHorizontal,
                AppSpacing.space2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WhiteButton(
                    label: '스트레칭 시작',
                    icon: Icons.play_arrow_rounded,
                    onPressed: () =>
                        Navigator.of(context)
                            .push(_stretchRoute(const StretchDoingPage())),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: _textButton('건너뛰고 바로 달리기', () => _goRun(context)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    height: AppComponentMetrics.chipHeights.last,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space3),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.borderDefault),
      borderRadius: AppRadius.pillBorder,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textPrimary),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    ),
  );
}

class _MoveRow extends StatelessWidget {
  const _MoveRow({required this.number, required this.move});

  final int number;
  final StretchMove move;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 60,
    child: Row(
      children: [
        SizedBox(
          width: 22,
          child: Text(
            _two(number),
            style: _number(16, color: AppColors.textTertiary),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                move.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                move.summary,
                style: TextStyle(
                  fontSize: 13,
                  height: 1,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        _Seconds(seconds: move.seconds, size: 22, unitSize: 13),
      ],
    ),
  );
}

/// '30초'처럼 숫자는 크게, 단위는 작게.
class _Seconds extends StatelessWidget {
  const _Seconds({
    required this.seconds,
    required this.size,
    required this.unitSize,
  });

  final int seconds;
  final double size, unitSize;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Text('$seconds', style: _number(size)),
      const SizedBox(width: 2),
      Text(
        '초',
        style: TextStyle(
          fontSize: unitSize,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────
// 30-2 따라 하기
// ─────────────────────────────────────────────────────

/// 30-2 스트레칭 따라 하기: 동작마다 남은 시간을 세고, 다 되면 다음 동작으로 넘어갑니다.
class StretchDoingPage extends StatefulWidget {
  const StretchDoingPage({super.key});

  @override
  State<StretchDoingPage> createState() => _StretchDoingPageState();
}

class _StretchDoingPageState extends State<StretchDoingPage> {
  int _index = 0;
  late int _remain = stretchMoves.first.seconds;
  bool _paused = false;
  Timer? _timer;

  /// 시간을 끝까지 채운 동작. 출발 화면의 '완료한 동작'입니다.
  final _done = <int>{};

  /// 멈춘 시간을 뺀 실제 스트레칭 시간.
  final _clock = Stopwatch();

  StretchMove get _move => stretchMoves[_index];
  bool get _last => _index == stretchMoves.length - 1;

  @override
  void initState() {
    super.initState();
    // 스트레칭하는 동안 화면이 꺼지지 않게 합니다(못 켜도 스트레칭은 그대로).
    WakelockPlus.enable().catchError((Object _) {});
    _clock.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WakelockPlus.disable().catchError((Object _) {});
    super.dispose();
  }

  void _tick() {
    if (_paused) return;
    if (_remain > 1) {
      setState(() => _remain--);
      return;
    }
    _done.add(_index);
    if (_last) {
      _finish();
    } else {
      _show(_index + 1);
    }
  }

  void _show(int index) => setState(() {
    _index = index;
    _remain = stretchMoves[index].seconds;
    _paused = false;
    _clock.start();
  });

  void _togglePause() => setState(() {
    _paused = !_paused;
    _paused ? _clock.stop() : _clock.start();
  });

  void _finish() {
    _timer?.cancel();
    _clock.stop();
    Navigator.of(context).pushReplacement(
      _stretchRoute(
        StretchDonePage(done: _done.length, elapsed: _clock.elapsed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = _move;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space3,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 104,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _closeButton(
                          '스트레칭 그만하기',
                          () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: '${_index + 1}'),
                            TextSpan(
                              text: ' / ${stretchMoves.length}',
                              style: TextStyle(color: AppColors.borderControl),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        style: _number(20),
                      ),
                    ),
                    SizedBox(
                      width: 104,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _textButton('건너뛰기', () => _goRun(context)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.space1,
                AppSpacing.screenHorizontal,
                0,
              ),
              child: _Progress(
                index: _index,
                fraction: (m.seconds - _remain) / m.seconds,
              ),
            ),
            const SizedBox(height: AppSpacing.space7),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              child: Column(
                children: [
                  Text(m.name, style: _title, textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  Text(
                    m.description,
                    style: _body,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            // 남는 높이에 맞춰 원을 줄입니다(작은 화면).
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.space4,
                ),
                child: FittedBox(
                  child: _Ring(
                    index: _index,
                    remain: _remain,
                    total: m.seconds,
                    paused: _paused,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 72,
              child: m.sided
                  ? _SideSwitch(move: m, remain: _remain)
                  : _Tip(m.tip),
            ),
            const SizedBox(height: AppSpacing.space4),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              child: _NextCard(next: _last ? null : stretchMoves[_index + 1]),
            ),
            const SizedBox(height: AppSpacing.space5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RoundButton(
                  tooltip: '이전 동작',
                  icon: Icons.skip_previous_rounded,
                  onPressed: _index > 0 ? () => _show(_index - 1) : null,
                ),
                const SizedBox(width: 28),
                _RoundButton(
                  tooltip: _paused ? '계속하기' : '일시정지',
                  icon: _paused ? Icons.play_arrow_rounded : Icons.pause,
                  filled: true,
                  onPressed: _togglePause,
                ),
                const SizedBox(width: 28),
                _last
                    ? _RoundButton(
                        tooltip: '스트레칭 마치기',
                        icon: Icons.check,
                        onPressed: () {
                          _done.add(_index);
                          _finish();
                        },
                      )
                    : _RoundButton(
                        tooltip: '다음 동작',
                        icon: Icons.skip_next_rounded,
                        onPressed: () => _show(_index + 1),
                      ),
              ],
            ),
            const SizedBox(height: AppSpacing.space4),
          ],
        ),
      ),
    );
  }
}

/// 동작 5칸 진행 막대. 지난 동작은 꽉, 지금 동작은 지난 시간만큼 채웁니다.
class _Progress extends StatelessWidget {
  const _Progress({required this.index, required this.fraction});

  final int index;
  final double fraction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var k = 0; k < stretchMoves.length; k++) ...[
        if (k > 0) const SizedBox(width: AppSpacing.space1),
        Expanded(
          child: ClipRRect(
            borderRadius: AppRadius.pillBorder,
            child: SizedBox(
              height: 4,
              child: LinearProgressIndicator(
                value: k < index ? 1 : (k == index ? fraction : 0),
                backgroundColor: AppColors.divider,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    ],
  );
}

/// 272 원: 남은 시간 링, 사람 그림, 남은 초.
class _Ring extends StatelessWidget {
  const _Ring({
    required this.index,
    required this.remain,
    required this.total,
    required this.paused,
  });

  final int index, remain, total;
  final bool paused;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 272,
    child: Stack(
      children: [
        Positioned.fill(
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: remain / total),
            duration: const Duration(milliseconds: 400),
            curve: Curves.ease,
            builder: (context, value, _) => CustomPaint(
              painter: _RingPainter(
                value: value,
                track: AppColors.divider,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        Positioned(
          left: 48,
          top: 30,
          child: Semantics(
            label: '${stretchMoves[index].name} 자세',
            image: true,
            child: StretchFigure(index: index, playing: !paused),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 214,
          child: Semantics(
            liveRegion: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$remain', style: _number(40)),
                const SizedBox(width: 6),
                Text(
                  paused ? '초 · 일시정지됨' : '초 남음',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: paused ? FontWeight.w700 : FontWeight.w600,
                    color: paused
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.track, required this.color});

  final double value;
  final Color track, color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const radius = 132.0;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = track,
    );
    if (value <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5707963267948966,
      6.283185307179586 * value.clamp(0, 1),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.track != track || old.color != color;
}

/// 양쪽 동작: 지금 하는 쪽 표시와 바꿀 때까지 남은 시간.
class _SideSwitch extends StatelessWidget {
  const _SideSwitch({required this.move, required this.remain});

  final StretchMove move;
  final int remain;

  @override
  Widget build(BuildContext context) {
    final half = move.seconds ~/ 2;
    final left = remain > half;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SideChip(label: '왼쪽 ${move.side}', on: left),
            const SizedBox(width: AppSpacing.space2),
            _SideChip(label: '오른쪽 ${move.side}', on: !left),
          ],
        ),
        const SizedBox(height: AppSpacing.space3),
        Text(
          left
              ? '${remain - half}초 뒤 오른쪽으로 바꿔요'
              : '오른쪽 ${move.side} · 마지막 $remain초',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _SideChip extends StatelessWidget {
  const _SideChip({required this.label, required this.on});

  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: on,
    child: Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: on ? AppColors.textPrimary : null,
        border: on ? null : Border.all(color: AppColors.borderDefault),
        borderRadius: AppRadius.pillBorder,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: on ? FontWeight.w700 : FontWeight.w500,
          color: on ? AppColors.onInverse : AppColors.textSecondary,
        ),
      ),
    ),
  );
}

/// 한 번에 하는 동작의 요령 한 줄.
class _Tip extends StatelessWidget {
  const _Tip(this.tip);

  final String tip;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: Container(
      height: 36,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: AppRadius.pillBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.tips_and_updates_outlined,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            tip,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 다음 동작 카드. 마지막 동작이면 끝나면 바로 달릴 수 있다고 알려 줍니다.
class _NextCard extends StatelessWidget {
  const _NextCard({required this.next});

  final StretchMove? next;

  @override
  Widget build(BuildContext context) {
    final n = next;
    final name = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      color: AppColors.textPrimary,
    );
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Text(
            n == null ? '마지막' : '다음',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              n == null ? '끝나면 바로 달릴 수 있어요' : n.name,
              style: name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (n != null) _Seconds(seconds: n.seconds, size: 18, unitSize: 12),
        ],
      ),
    );
  }
}

/// 아래 둥근 버튼: 이전·다음은 테두리 56, 일시정지는 꽉 찬 72.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final size = filled ? 72.0 : 56.0;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled ? AppColors.textPrimary : Colors.transparent,
        shape: CircleBorder(
          side: filled
              ? BorderSide.none
              : BorderSide(
                  color: enabled ? AppColors.borderDefault : AppColors.divider,
                ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: size,
            child: Icon(
              icon,
              size: filled ? 32 : 26,
              color: filled
                  ? AppColors.onInverse
                  : (enabled ? AppColors.textPrimary : AppColors.borderControl),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// 30-3 출발
// ─────────────────────────────────────────────────────

/// 30-3 스트레칭 출발: 완료한 동작·시간과 러닝 시작.
class StretchDonePage extends StatefulWidget {
  const StretchDonePage({
    super.key,
    required this.done,
    required this.elapsed,
    this.checkLocation = _checkGps,
  });

  final int done;
  final Duration elapsed;

  /// GPS 상태 문구를 정합니다. 테스트에서는 가짜를 넣습니다.
  final Future<String> Function() checkLocation;

  @override
  State<StretchDonePage> createState() => _StretchDonePageState();
}

/// 위치 권한·서비스와 마지막 위치의 정확도로 GPS 문구를 정합니다.
Future<String> _checkGps() async {
  try {
    final state = await checkRunningLocation();
    switch (state) {
      case RunningLocationState.serviceDisabled:
        return '위치 서비스가 꺼져 있어요';
      case RunningLocationState.denied || RunningLocationState.deniedForever:
        return '위치 권한이 필요해요';
      case RunningLocationState.checking:
        return 'GPS 신호를 찾고 있어요';
      case RunningLocationState.ready:
        final accuracy = (await Geolocator.getLastKnownPosition())?.accuracy;
        if (accuracy == null) return 'GPS 신호를 찾고 있어요';
        if (accuracy <= 25) return 'GPS 신호 양호 · 바로 시작할 수 있어요';
        return 'GPS 신호 약함 · 넓은 곳에서 시작해 보세요';
    }
  } catch (_) {
    return 'GPS 신호를 찾고 있어요';
  }
}

class _StretchDonePageState extends State<StretchDonePage>
    with SingleTickerProviderStateMixin {
  String _gps = 'GPS 신호를 찾고 있어요';

  late final _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward();

  @override
  void initState() {
    super.initState();
    widget.checkLocation().then((text) {
      if (mounted) setState(() => _gps = text);
    });
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = widget.elapsed.inSeconds;
    final time = '${seconds ~/ 60}:${_two(seconds % 60)}';
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space3,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _closeButton('닫기', () => _closeAll(context)),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenHorizontal,
                  ),
                  child: Column(
                    children: [
                      ScaleTransition(
                        scale: CurvedAnimation(
                          parent: _pop,
                          curve: const Cubic(0.2, 0.8, 0.2, 1),
                        ).drive(Tween(begin: 0.8, end: 1)),
                        child: FadeTransition(
                          opacity: _pop,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.borderDefault,
                              ),
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: 34,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space6),
                      Text(
                        '몸이 다 풀렸어요\n이제 달려볼까요?',
                        style: _title,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.space3),
                      Text(
                        '첫 1 km는 천천히 시작해 보세요',
                        style: _body,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.divider),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            children: [
                              _Stat(
                                label: '완료한 동작',
                                value: '${widget.done}',
                                unit: '/ ${stretchMoves.length}',
                              ),
                              VerticalDivider(
                                width: 1,
                                color: AppColors.divider,
                              ),
                              _Stat(label: '스트레칭 시간', value: time),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              child: _StartSlab(gps: _gps, onPressed: () => _goRun(context)),
            ),
            const SizedBox(height: AppSpacing.space2),
            _textButton(
              '스트레칭 다시 하기',
              () =>
                  Navigator.of(context)
                      .pushReplacement(_stretchRoute(const StretchDoingPage())),
            ),
            const SizedBox(height: AppSpacing.space2),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.unit});

  final String label, value;
  final String? unit;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.space3),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: _number(36)),
            if (unit != null) ...[
              const SizedBox(width: AppSpacing.space1),
              Text(
                unit!,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

/// 주황 시작 슬래브(높이 88): '러닝 시작', GPS 상태, 오른쪽 검정 원 재생 버튼.
/// 주황 위 글자는 두 모드 모두 검정입니다.
class _StartSlab extends StatelessWidget {
  const _StartSlab({required this.gps, required this.onPressed});

  final String gps;
  final VoidCallback onPressed;

  static const _ink = Color(0xFF0B0B0B);
  static const _soft = Color(0xB80B0B0B); // 72% 검정.

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.primary,
    borderRadius: AppRadius.sheetBorder,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onPressed,
      highlightColor: AppColors.primaryPressed,
      child: SizedBox(
        height: AppComponentMetrics.startSlabHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space6,
            0,
            AppSpacing.startSlabRight,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '러닝 시작',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        letterSpacing: -0.72,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space2),
                    Row(
                      children: [
                        const Icon(
                          Icons.signal_cellular_alt,
                          size: 14,
                          color: _soft,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            gps,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1,
                              color: _soft,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: _ink,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 28,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
