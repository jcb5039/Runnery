import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../account/account_store.dart';
import '../../design_system/app_colors.dart';
import '../auth_ui/auth_ui.dart';
import 'basic_info.dart';

/// 브랜드 색(각 회사 로그인 버튼 가이드). 화면 모드와 상관없이 같습니다.
const _kakaoYellow = Color(0xFFFEE500);
const _kakaoText = Color(0xFF191919);
const _naverGreen = Color(0xFF03C75A);

/// 회원가입 첫 화면: 가입 방법(Apple·카카오·네이버·Google·이메일)을 고릅니다.
/// 이메일 가입을 마치면 받은 가입 정보를 앞 화면(로그인)에 돌려줍니다.
class SignUpChoicePage extends StatelessWidget {
  const SignUpChoicePage({super.key, this.store});

  /// 기본값은 AccountStore.instance. 이메일 가입 화면에 그대로 넘깁니다.
  final AccountStore? store;

  /// 소셜 로그인은 아직 연결 전이라 안내만 띄웁니다.
  void _notReady(BuildContext context, String name) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$name 로그인은 준비 중이에요')));

  Future<void> _email(BuildContext context) async {
    final result = await Navigator.push<RegistrationData>(
      context,
      MaterialPageRoute(builder: (_) => BasicInfoPage(store: store)),
    );
    if (context.mounted && result != null) Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) => AuthFrame(
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.zero,
            tooltip: '뒤로',
            icon: Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: AppColors.textPrimary,
            ),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        const SizedBox(height: 40),
        Text('SIGN UP', style: authLabelStyle),
        const SizedBox(height: 12),
        Text(
          'JOIN\nRUNNERY',
          style: TextStyle(
            fontFamily: 'Archivo',
            fontVariations: [FontVariation('wdth', 125)],
            fontSize: 28,
            height: 1.04,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '자주 쓰는 계정으로 빠르게 시작해요',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ],
    ),
    actions: Builder(
      // 안내 메시지를 띄울 때 이 화면의 Scaffold를 찾도록 안쪽 context를 씁니다.
      builder: (inner) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SocialButton(
            label: 'Apple로 시작하기',
            icon: Icon(Icons.apple, size: 20, color: AppColors.textPrimary),
            onPressed: () => _notReady(inner, 'Apple'),
          ),
          const SizedBox(height: 12),
          _SocialButton(
            label: '카카오로 시작하기',
            icon: const Icon(Icons.chat_bubble, size: 18, color: _kakaoText),
            background: _kakaoYellow,
            foreground: _kakaoText,
            onPressed: () => _notReady(inner, '카카오'),
          ),
          const SizedBox(height: 12),
          _SocialButton(
            label: '네이버로 시작하기',
            icon: const Text(
              'N',
              style: TextStyle(
                fontFamily: 'Archivo',
                fontSize: 18,
                height: 1,
                fontWeight: FontWeight.w900,
                color: _naverGreen,
              ),
            ),
            onPressed: () => _notReady(inner, '네이버'),
          ),
          const SizedBox(height: 12),
          _SocialButton(
            label: 'Google로 시작하기',
            icon: const CustomPaint(size: Size(18, 18), painter: _GoogleLogo()),
            onPressed: () => _notReady(inner, 'Google'),
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: () => _email(inner),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
              child: const Text(
                '이메일로 가입하기',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 둥근 가입 버튼. 바탕색을 주지 않으면 화면 바탕에 회색 테두리입니다.
class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.background,
    this.foreground,
  });
  final String label;
  final Widget icon;
  final VoidCallback onPressed;
  final Color? background, foreground;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: TextButton(
      style: TextButton.styleFrom(
        backgroundColor: background ?? Colors.transparent,
        foregroundColor: foreground ?? AppColors.textPrimary,
        shape: const StadiumBorder(),
        side: background == null
            ? BorderSide(color: AppColors.borderDefault)
            : BorderSide.none,
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 20, height: 20, child: Center(child: icon)),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

/// Google 4색 G 로고를 선으로 그립니다(그림 파일 없이).
class _GoogleLogo extends CustomPainter {
  const _GoogleLogo();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.2;
    final center = size.center(Offset.zero);
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    Paint paint(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    double deg(double d) => d * math.pi / 180;

    // 0도는 3시 방향, 시계 방향으로 커집니다. 오른쪽 위(-45~0도)가 비어 있습니다.
    canvas.drawArc(
      rect,
      deg(0),
      deg(45),
      false,
      paint(const Color(0xFF4285F4)),
    );
    canvas.drawArc(
      rect,
      deg(45),
      deg(90),
      false,
      paint(const Color(0xFF34A853)),
    );
    canvas.drawArc(
      rect,
      deg(135),
      deg(80),
      false,
      paint(const Color(0xFFFBBC05)),
    );
    canvas.drawArc(
      rect,
      deg(215),
      deg(100),
      false,
      paint(const Color(0xFFEA4335)),
    );
    // 가운데로 들어오는 파란 가로선.
    canvas.drawRect(
      Rect.fromLTWH(center.dx, center.dy - stroke / 2, size.width / 2, stroke),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant _GoogleLogo oldDelegate) => false;
}
