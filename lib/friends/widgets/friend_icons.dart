import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';

/// 디자인 시안(16 친구 수정본)의 얇은 선 아이콘. 24×24 칸 기준 좌표를 그대로 옮겨, 시안과 같은 굵기로 그립니다.
enum FriendIconKind {
  /// 뒤로 '<'.
  back,

  /// 메뉴(가로줄 셋).
  menu,

  /// 보내기(위쪽 화살표).
  send,

  /// 함께 시작(채운 삼각형).
  play,

  /// 함께 달리기(사람 둘).
  people,

  /// 더 보기 '>'.
  chevronRight,

  /// 공지(확성기).
  notice,

  /// 더하기.
  plus,

  /// 나가기.
  leave,

  /// 알림 켜짐(종).
  bell,

  /// 알림 꺼짐(작대기 그어진 종).
  bellOff,
}

class FriendIcon extends StatelessWidget {
  const FriendIcon(
    this.kind, {
    super.key,
    this.size = 22,
    this.color,
    this.strokeWidth,
  });

  final FriendIconKind kind;
  final double size;

  /// 선 색. 없으면 주요 글자색입니다.
  final Color? color;

  /// 선 굵기(24칸 기준). 없으면 시안의 굵기(1.5~1.8)를 씁니다.
  final double? strokeWidth;

  /// 시안에서 아이콘마다 쓴 선 굵기.
  double get _defaultStroke => switch (kind) {
    FriendIconKind.back || FriendIconKind.menu => 1.5,
    FriendIconKind.plus => 1.8,
    _ => 1.6,
  };

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _FriendIconPainter(
        kind,
        color ?? AppColors.textPrimary,
        strokeWidth ?? _defaultStroke,
      ),
    ),
  );
}

class _FriendIconPainter extends CustomPainter {
  _FriendIconPainter(this.kind, this.color, this.stroke);

  final FriendIconKind kind;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final fill = Paint()..color = color;
    final p = Path();
    switch (kind) {
      case FriendIconKind.back:
        p
          ..moveTo(15, 5)
          ..lineTo(8, 12)
          ..lineTo(15, 19);
      case FriendIconKind.menu:
        for (final y in [7.0, 12.0, 17.0]) {
          p
            ..moveTo(4, y)
            ..lineTo(20, y);
        }
      case FriendIconKind.send:
        p
          ..moveTo(12, 19)
          ..lineTo(12, 5)
          ..moveTo(6, 11)
          ..lineTo(12, 5)
          ..lineTo(18, 11);
      case FriendIconKind.play:
        canvas.drawPath(
          Path()
            ..moveTo(8, 5.5)
            ..lineTo(8, 18.5)
            ..lineTo(18.5, 12)
            ..close(),
          fill,
        );
        return;
      case FriendIconKind.people:
        p
          ..addOval(Rect.fromCircle(center: const Offset(9, 8.5), radius: 3.25))
          ..moveTo(3, 19.5)
          ..cubicTo(3.7, 16.4, 6, 14.6, 9, 14.6)
          ..cubicTo(12, 14.6, 14.3, 16.4, 15, 19.5)
          ..moveTo(15.5, 5.6)
          ..arcToPoint(const Offset(15.5, 11.4), radius: const Radius.circular(3))
          ..moveTo(17.5, 14.9)
          ..cubicTo(19.3, 15.4, 20.5, 16.8, 21, 19.5);
      case FriendIconKind.chevronRight:
        p
          ..moveTo(9.5, 6)
          ..lineTo(15.5, 12)
          ..lineTo(9.5, 18);
      case FriendIconKind.notice:
        p
          ..moveTo(4, 10)
          ..lineTo(4, 14)
          ..lineTo(7, 14)
          ..lineTo(13, 18)
          ..lineTo(13, 6)
          ..lineTo(7, 10)
          ..close()
          ..moveTo(16.5, 9)
          ..arcToPoint(const Offset(16.5, 15), radius: const Radius.circular(4));
      case FriendIconKind.plus:
        p
          ..moveTo(12, 7)
          ..lineTo(12, 17)
          ..moveTo(7, 12)
          ..lineTo(17, 12);
      case FriendIconKind.leave:
        p
          ..moveTo(14, 4)
          ..lineTo(18, 4)
          ..arcToPoint(const Offset(20, 6), radius: const Radius.circular(2))
          ..lineTo(20, 18)
          ..arcToPoint(const Offset(18, 20), radius: const Radius.circular(2))
          ..lineTo(14, 20)
          ..moveTo(10, 16)
          ..lineTo(6, 12)
          ..lineTo(10, 8)
          ..moveTo(6, 12)
          ..lineTo(16, 12);
      case FriendIconKind.bell || FriendIconKind.bellOff:
        p
          ..moveTo(6, 16)
          ..lineTo(6, 11)
          ..arcToPoint(const Offset(18, 11), radius: const Radius.circular(6))
          ..lineTo(18, 16)
          ..lineTo(19.5, 18)
          ..lineTo(4.5, 18)
          ..close()
          ..moveTo(10, 20.5)
          ..arcToPoint(
            const Offset(14, 20.5),
            radius: const Radius.circular(2),
            clockwise: false,
          );
        if (kind == FriendIconKind.bellOff) {
          p
            ..moveTo(4, 4)
            ..lineTo(20, 20);
        }
    }
    canvas.drawPath(p, line);
  }

  @override
  bool shouldRepaint(_FriendIconPainter old) =>
      old.kind != kind || old.color != color || old.stroke != stroke;
}

/// 시안의 둥근 아이콘 버튼(44×44, 투명 바탕).
class FriendIconButton extends StatelessWidget {
  const FriendIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 22,
  });

  final FriendIconKind icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    constraints: const BoxConstraints.tightFor(width: 44, height: 44),
    padding: EdgeInsets.zero,
    icon: FriendIcon(icon, size: size),
  );
}
