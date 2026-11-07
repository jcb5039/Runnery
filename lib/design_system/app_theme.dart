import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_component_metrics.dart';
import 'app_text_styles.dart';

/// 확인된 전역 값만 설정. 나머지 Flutter 기본값은 가이드의 확정값이 아닙니다.
/// 버튼 종류별 색·높이·모서리는 달라서 전역 버튼 테마를 임의로 만들지 않습니다.
/// 색은 [AppColors.current]를 따르므로, 모드를 바꾼 뒤 다시 만들어 씁니다.
abstract final class AppTheme {
  /// 지금 화면 모드의 테마.
  static ThemeData get current => _build(AppColors.current);

  /// 다크 색으로 만든 테마. 위젯 안의 색은 [AppColors.current]를 따릅니다.
  static ThemeData get dark => _build(AppColors.dark);
  static ThemeData get light => _build(AppColors.light);

  static ThemeData _build(AppPalette p) => ThemeData(
    // 화면 전환 애니메이션 없이 바로 넘어갑니다. 모든 플랫폼 공통.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _NoTransitionsBuilder(),
        TargetPlatform.iOS: _NoTransitionsBuilder(),
        TargetPlatform.fuchsia: _NoTransitionsBuilder(),
        TargetPlatform.linux: _NoTransitionsBuilder(),
        TargetPlatform.macOS: _NoTransitionsBuilder(),
        TargetPlatform.windows: _NoTransitionsBuilder(),
      },
    ),
    brightness: p.brightness,
    // 다크는 예전과 같게 Flutter 기본 색 구성을 쓰고, 라이트만 흰 바탕·검정 강조로 맞춥니다.
    colorScheme: p.brightness == Brightness.dark
        ? null
        : ColorScheme.fromSeed(
            seedColor: p.primary,
            brightness: p.brightness,
            surface: p.background,
            onSurface: p.textPrimary,
            primary: p.textPrimary,
            onPrimary: p.onInverse,
            error: p.error,
          ).copyWith(
            surfaceContainerLowest: p.background,
            surfaceContainerLow: p.background,
            surfaceContainer: p.background,
            surfaceContainerHigh: p.background,
            surfaceContainerHighest: p.card,
            surfaceTint: Colors.transparent,
          ),
    primaryColor: p.primary,
    scaffoldBackgroundColor: p.background,
    canvasColor: p.background,
    cardColor: p.card,
    dividerColor: p.divider,
    fontFamily: AppTextStyles.bodyFontFamily,
    appBarTheme: p.brightness == Brightness.dark
        ? null
        : AppBarTheme(
            backgroundColor: p.background,
            foregroundColor: p.textPrimary,
            surfaceTintColor: Colors.transparent,
          ),
    iconTheme: IconThemeData(
      color: p.textPrimary,
      size: AppComponentMetrics.iconSize,
    ),
    dividerTheme: DividerThemeData(
      color: p.divider,
      thickness: AppComponentMetrics.dividerWidth,
    ),
    textSelectionTheme: p.brightness == Brightness.dark
        ? null
        : TextSelectionThemeData(cursorColor: p.textPrimary),
  );
}

/// 화면을 효과 없이 그대로 보여 주는 전환.
class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
