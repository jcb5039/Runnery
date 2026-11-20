import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../design_system/app_colors.dart';

part 'stretch_figure_data.dart';

/// 그림 색 이름. 화면 모드에 따라 디자인의 다크·라이트 색으로 바뀝니다.
enum FigInk {
  /// 앞쪽 팔·다리·몸.
  near,

  /// 뒤쪽 팔·다리(옅게).
  far,

  /// 늘어나는 근육 표시.
  accent,

  /// 바닥 선.
  ground,

  /// 발목 돌리기의 회전 화살표.
  arrow,

  /// 팔다리 사이를 떼어 보이게 하는 바탕색 테두리.
  outline;

  Color get color => switch (this) {
    near => AppColors.textSecondary,
    far => AppColors.borderControl,
    accent => AppColors.primary,
    ground => AppColors.borderDefault,
    arrow => AppColors.textTertiary,
    outline => AppColors.background,
  };
}

/// 한 부분의 자세: 점([cx], [cy])을 중심으로 [angle]도 돌리거나, ([dx], [dy])만큼 옮깁니다.
class FigPose {
  const FigPose.rotate(this.angle, this.cx, this.cy) : dx = 0, dy = 0;
  const FigPose.translate(this.dx, this.dy) : angle = null, cx = 0, cy = 0;

  final double? angle;
  final double cx, cy, dx, dy;

  void apply(Canvas canvas) {
    final a = angle;
    if (a == null) {
      canvas.translate(dx, dy);
    } else {
      canvas
        ..translate(cx, cy)
        ..rotate(a * math.pi / 180)
        ..translate(-cx, -cy);
    }
  }

  /// 같은 종류의 두 자세 사이. [t]는 0~1.
  static FigPose lerp(FigPose a, FigPose b, double t) {
    double mix(double x, double y) => x + (y - x) * t;
    final aa = a.angle, ba = b.angle;
    if (aa != null && ba != null) {
      return FigPose.rotate(mix(aa, ba), mix(a.cx, b.cx), mix(a.cy, b.cy));
    }
    return FigPose.translate(mix(a.dx, b.dx), mix(a.dy, b.dy));
  }
}

/// 움직임의 한 시점. [at]은 한 바퀴 중 0~1 위치.
class FigKey {
  const FigKey(this.at, this.pose);
  final double at;
  final FigPose pose;
}

/// 한 부분의 반복 움직임. [seconds]마다 처음으로 돌아갑니다.
class FigMotion {
  const FigMotion(this.seconds, this.keys);
  final double seconds;
  final List<FigKey> keys;

  FigPose poseAt(double time) {
    final p = (time % seconds) / seconds;
    for (var i = 0; i < keys.length - 1; i++) {
      final a = keys[i], b = keys[i + 1];
      if (p <= b.at) {
        final span = b.at - a.at;
        return FigPose.lerp(a.pose, b.pose, span <= 0 ? 0 : (p - a.at) / span);
      }
    }
    return keys.last.pose;
  }
}

sealed class FigNode {
  const FigNode();
}

/// 함께 움직이는 부분 묶음. [motion]이 있으면 움직이는 동안 [pose] 대신 그 움직임을 씁니다.
class FigGroup extends FigNode {
  const FigGroup({this.pose, this.motion, required this.children});
  final FigPose? pose;
  final String? motion;
  final List<FigNode> children;
}

/// 모양 하나(경로 또는 원). 테두리를 먼저, 그 위에 채우기를 그립니다.
class FigShape extends FigNode {
  const FigShape.path(
    String this.d, {
    this.fill,
    this.stroke,
    this.strokeWidth = 0,
    this.opacity = 1,
  }) : cx = 0,
       cy = 0,
       r = 0;
  const FigShape.circle(
    this.cx,
    this.cy,
    this.r, {
    this.fill,
    this.stroke,
    this.strokeWidth = 0,
    this.opacity = 1,
  }) : d = null;

  final String? d;
  final double cx, cy, r;
  final FigInk? fill, stroke;
  final double strokeWidth, opacity;
}

/// 스트레칭 동작 그림. [playing]이면 움직이고, 멈추면 그 자세로 섭니다.
/// 기기에서 '동작 줄이기'를 켰으면 움직이지 않습니다.
class StretchFigure extends StatefulWidget {
  const StretchFigure({
    super.key,
    required this.index,
    required this.playing,
    this.size = 176,
  });

  /// 0 발목 돌리기 ~ 4 버트 킥.
  final int index;
  final bool playing;
  final double size;

  @override
  State<StretchFigure> createState() => _StretchFigureState();
}

class _StretchFigureState extends State<StretchFigure>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);

  /// 멈추기 전까지 흐른 시간(초)과, 지금 움직이는 동안 흐른 시간.
  double _held = 0;
  double _time = 0;

  void _tick(Duration elapsed) =>
      setState(() => _time = _held + elapsed.inMicroseconds / 1e6);

  void _sync() {
    final run = widget.playing && !_reduceMotion;
    if (run && !_ticker.isActive) {
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
      _held = _time;
    }
  }

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(StretchFigure old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      // 다음 동작은 처음 자세부터 시작합니다.
      _ticker.stop();
      _held = 0;
      _time = 0;
    }
    _sync();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size,
    child: CustomPaint(
      painter: _FigurePainter(
        figure: stretchFigures[widget.index],
        // 동작 줄이기면 움직임 없이 기본 자세를 그립니다.
        time: _reduceMotion ? null : _time,
        dark: AppColors.isDark,
      ),
    ),
  );
}

class _FigurePainter extends CustomPainter {
  _FigurePainter({
    required this.figure,
    required this.time,
    required this.dark,
  });

  final FigGroup figure;
  final double? time;
  final bool dark;

  static final _paths = <String, Path>{};

  @override
  void paint(Canvas canvas, Size size) {
    // 디자인 좌표는 200×200입니다.
    canvas.scale(size.width / 200, size.height / 200);
    _node(canvas, figure);
  }

  void _node(Canvas canvas, FigNode node) {
    switch (node) {
      case FigGroup():
        canvas.save();
        final motion = node.motion == null ? null : stretchMotions[node.motion];
        final t = time;
        final pose = motion != null && t != null ? motion.poseAt(t) : node.pose;
        pose?.apply(canvas);
        for (final child in node.children) {
          _node(canvas, child);
        }
        canvas.restore();
      case FigShape():
        final d = node.d;
        final path = d == null
            ? (Path()..addOval(
                Rect.fromCircle(
                  center: Offset(node.cx, node.cy),
                  radius: node.r,
                ),
              ))
            : _paths.putIfAbsent(d, () => parseSvgPath(d));
        final stroke = node.stroke;
        if (stroke != null) {
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = node.strokeWidth
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..color = stroke.color.withValues(alpha: node.opacity),
          );
        }
        final fill = node.fill;
        if (fill != null) {
          canvas.drawPath(
            path,
            Paint()..color = fill.color.withValues(alpha: node.opacity),
          );
        }
    }
  }

  @override
  bool shouldRepaint(_FigurePainter old) =>
      old.figure != figure || old.time != time || old.dark != dark;
}

/// 디자인 그림에 쓰인 SVG 경로 명령(M, L, H, V, C, A, Z, 절대 좌표)을 Flutter 경로로 바꿉니다.
Path parseSvgPath(String d) {
  final path = Path();
  final tokens = RegExp(r'[MLHVCAZ]|-?(?:\d+\.?\d*|\.\d+)')
      .allMatches(d)
      .map((m) => m.group(0)!)
      .toList();
  var i = 0;
  var command = 'M';
  var x = 0.0, y = 0.0;
  double next() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    if (RegExp(r'^[A-Z]$').hasMatch(tokens[i])) command = tokens[i++];
    switch (command) {
      case 'M':
        x = next();
        y = next();
        path.moveTo(x, y);
        // M 뒤에 이어지는 좌표는 선(L)입니다.
        command = 'L';
      case 'L':
        x = next();
        y = next();
        path.lineTo(x, y);
      case 'H':
        x = next();
        path.lineTo(x, y);
      case 'V':
        y = next();
        path.lineTo(x, y);
      case 'C':
        final x1 = next(), y1 = next(), x2 = next(), y2 = next();
        x = next();
        y = next();
        path.cubicTo(x1, y1, x2, y2, x, y);
      case 'A':
        final rx = next(), ry = next(), rotation = next();
        final largeArc = next() != 0, sweep = next() != 0;
        x = next();
        y = next();
        path.arcToPoint(
          Offset(x, y),
          radius: Radius.elliptical(rx, ry),
          rotation: rotation,
          largeArc: largeArc,
          clockwise: sweep,
        );
      case 'Z':
        path.close();
      default:
        throw FormatException('지원하지 않는 경로 명령: $command');
    }
  }
  return path;
}
