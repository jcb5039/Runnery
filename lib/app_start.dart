import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_system/app_colors.dart';
import 'design_system/app_motion.dart';
import 'design_system/app_text_styles.dart';
import 'login/login.dart';

/// main.dart의 첫 화면입니다. 다음 화면 미지정 시 홈으로 이동합니다.
/// 인증 연결 전까지 로그인 화면을 건너뜁니다. 추후 nextPageBuilder로 연결합니다.
class AppStartPage extends StatefulWidget {
  const AppStartPage({
    super.key,
    this.lastRunDistanceKm,
    this.nextPageBuilder,
    this.autoNavigate = true,
  }) : assert(
         lastRunDistanceKm == null ||
             (lastRunDistanceKm >= 0 && lastRunDistanceKm < double.infinity),
       );

  /// 실제 최근 기록. 기록이 없으면 샘플 5.24 대신 — 표시.
  final double? lastRunDistanceKm;
  final WidgetBuilder? nextPageBuilder;

  /// 디자인 미리보기에서는 false로 설정합니다.
  final bool autoNavigate;

  @override
  State<AppStartPage> createState() => _AppStartPageState();
}

class _AppStartPageState extends State<AppStartPage>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _exit;
  Timer? _timer;

  // 등장 순서(시작 화면 시안 영상): 가로선 → 로고가 선 뒤에서 올라옴 → 러너리 → 속도선 → 하단 정보.
  late final _divider = _part(0, .2, Curves.easeOut);
  late final _wordmark = _part(.15, .45, Curves.easeOutCubic);
  late final _subtitle = _part(.4, .6, Curves.easeOut);
  late final _speedLines = _part(.5, .92, Curves.linear);
  late final _footer = _part(.75, 1, Curves.easeOut);

  Animation<double> _part(double begin, double end, Curve curve) =>
      CurvedAnimation(
        parent: _intro,
        curve: Interval(begin, end, curve: curve),
      );

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: AppMotion.splashIntro);
    _exit = AnimationController(
      vsync: this,
      duration: AppMotion.splashTransition,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _intro.value = 1;
      } else {
        _intro.forward();
      }
    });
    if (widget.autoNavigate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _timer = Timer(AppMotion.splashDelay, _openNextPage);
      });
    }
  }

  Future<void> _openNextPage() async {
    if (!mounted) return;
    if (!MediaQuery.disableAnimationsOf(context)) {
      try {
        await _exit.forward().orCancel;
      } on TickerCanceled {
        return;
      }
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement<void, void>(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            widget.nextPageBuilder?.call(context) ?? const AuthGate(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _intro.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value:
        (AppColors.isDark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark)
            .copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: AppColors.background,
              systemNavigationBarDividerColor: AppColors.background,
            ),
    child: Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedBuilder(
        animation: _exit,
        builder: (context, child) => Opacity(
          opacity: 1 - _exit.value,
          child: Transform.scale(
            scale: 1 + (AppMotion.splashScale - 1) * _exit.value,
            child: child,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => AnimatedBuilder(
            animation: _intro,
            builder: (context, _) => _content(context, constraints),
          ),
        ),
      ),
    ),
  );

  Widget _content(BuildContext context, BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    final scale = math.min(width / 390, height / 844);
    final bottom = math.max(
      54 * scale,
      MediaQuery.paddingOf(context).bottom + 16,
    );
    return Stack(
      children: [
        // 시안의 다섯 구간 선: 왼쪽 화면 끝에서 시작합니다.
        Positioned(
          left: 0,
          top: height * 237 / 844,
          child: CustomPaint(
            size: Size(width * 285 / 390, 72 * scale),
            painter: _StartLinesPainter(
              scale: scale,
              progress: _speedLines.value,
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: height * 400 / 844,
          child: Column(
            children: [
              // 선 아래는 잘라서 로고가 선 뒤에서 솟아오르는 것처럼 보이게 합니다.
              ClipRect(
                child: FractionalTranslation(
                  translation: Offset(0, 1.2 * (1 - _wordmark.value)),
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: width * 40 / 390,
                      right: width * 40 / 390,
                      bottom: 8 * scale,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'RUNNERY',
                        style: AppTextStyles.wordmark.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 44 * scale,
                          height: 1,
                          letterSpacing:
                              44 *
                              scale *
                              AppTextStyles.wordmarkLetterSpacingRatio,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // 왼쪽 끝에서 오른쪽으로 그어지는 가로선.
              Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: _divider.value,
                  child: SizedBox(
                    height: 1,
                    child: ColoredBox(color: AppColors.textSecondary),
                  ),
                ),
              ),
              SizedBox(height: 16 * scale),
              Opacity(
                opacity: _subtitle.value,
                child: Text(
                  '러너리',
                  style: TextStyle(
                    fontFamily: AppTextStyles.bodyFontFamily,
                    fontSize: 12 * scale,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4 * scale,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 24 * scale,
          right: 24 * scale,
          bottom: bottom,
          child: Opacity(
            opacity: _footer.value,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Semantics(
                  label: widget.lastRunDistanceKm == null
                      ? '최근 러닝 기록 없음'
                      : '최근 러닝 ${widget.lastRunDistanceKm!.toStringAsFixed(2)} 킬로미터',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LAST RUN',
                        style: AppTextStyles.authLabel.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 10 * scale,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4 * scale),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text:
                                  widget.lastRunDistanceKm?.toStringAsFixed(
                                    2,
                                  ) ??
                                  '—',
                              style: AppTextStyles.statValue.copyWith(
                                fontSize: 22 * scale,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                height: 1,
                              ),
                            ),
                            TextSpan(
                              text: ' KM',
                              style: AppTextStyles.authLabel.copyWith(
                                fontSize: 10 * scale,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'KM BY KM',
                  style: AppTextStyles.authLabel.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 11 * scale,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StartLinesPainter extends CustomPainter {
  const _StartLinesPainter({required this.scale, required this.progress});
  final double scale;

  /// 0이면 선이 없고 1이면 다 그려집니다. 선마다 조금씩 늦게 왼쪽에서 뻗어 나옵니다.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textPrimary
      ..strokeWidth = 2 * scale;
    const lengths = [200.0, 230.0, 245.0, 220.0, 285.0];
    const stagger = .1;
    const span = 1 - stagger * 4;
    for (var i = 0; i < lengths.length; i++) {
      final t = Curves.easeOutCubic.transform(
        ((progress - i * stagger) / span).clamp(0.0, 1.0),
      );
      if (t == 0) continue;
      final y = i * size.height / 4;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width * lengths[i] / 285 * t, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StartLinesPainter oldDelegate) =>
      oldDelegate.scale != scale || oldDelegate.progress != progress;
}
