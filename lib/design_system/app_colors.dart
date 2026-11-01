import 'package:flutter/material.dart';

/// 한 화면 모드의 색 한 벌. 다크는 '03 컬러', 라이트는 '03-1 라이트 모드 컬러'에서 옮겼습니다.
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.primary,
    required this.primaryPressed,
    required this.primarySoft,
    required this.primaryText,
    required this.background,
    required this.surface,
    required this.card,
    required this.surfacePressed,
    required this.divider,
    required this.borderDefault,
    required this.borderControl,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.onInverse,
    required this.error,
    required this.scrim,
    required this.mapLand,
    required this.mapBuilding,
    required this.mapPark,
    required this.mapWater,
    required this.mapRoad,
    required this.mapRoadLight,
    required this.mapRoadDark,
    required this.mapButtonBase,
    required this.mapButtonOpacity,
    required this.mapButtonBorder,
  });

  final Brightness brightness;
  final Color primary;
  final Color primaryPressed;
  final Color primarySoft;
  final Color primaryText;
  final Color background;
  final Color surface;
  final Color card;
  final Color surfacePressed;
  final Color divider;
  final Color borderDefault;
  final Color borderControl;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color onInverse;
  final Color error;
  final Color scrim;
  final Color mapLand;
  final Color mapBuilding;
  final Color mapPark;
  final Color mapWater;
  final Color mapRoad;
  final Color mapRoadLight;
  final Color mapRoadDark;
  final Color mapButtonBase;
  final double mapButtonOpacity;
  final Color mapButtonBorder;
}

/// 앱 색. 화면 모드에 따라 [current]가 바뀌고, 각 색은 지금 모드의 값을 돌려줍니다.
/// 모드가 바뀌면 앱 전체를 다시 그려야 하므로 상수(const)가 아닙니다.
abstract final class AppColors {
  static const dark = AppPalette(
    brightness: Brightness.dark,
    primary: Color(0xFFFF7A00), // #FF7A00: 러닝 행동·경로·현재 위치.
    primaryPressed: Color(0xFFE06B00), // #E06B00: 주황 버튼 눌림.
    primarySoft: Color.fromRGBO(255, 122, 0, 0.16), // GPS 오차·방향.
    primaryText: Color(0xFFFF7A00), // 바탕 위 주황 글자.
    background: Color(0xFF0B0B0B), // #0B0B0B: 앱 배경.
    surface: Color(0xFF111111), // #111111: 노드·보조 면.
    card: Color(0xFF151515), // #151515: 햇반 카드·종료 확인 시트.
    surfacePressed: Color(0xFF1B1D20), // #1B1D20: 목록 눌림.
    divider: Color(0xFF22272C), // #22272C: 목록·표 구분선.
    borderDefault: Color(0xFF3A434C), // #3A434C: 섹션 선·테두리 버튼.
    borderControl: Color(0xFF5C6771), // #5C6771: 입력 밑줄·아바타.
    textPrimary: Color(0xFFFFFFFF), // #FFFFFF: 숫자·제목·주요 버튼 배경.
    textSecondary: Color(0xFFA0A0A0), // #A0A0A0: 라벨·설명·단위.
    textTertiary: Color(0xFF7D8791), // #7D8791: 캡션·비활성 탭·지명.
    onInverse: Color(0xFF000000), // 흰 주요 버튼·선택 칩 위 글자.
    error: Color(0xFFFF5A4F), // #FF5A4F: 입력 오류에만 사용.
    scrim: Color(0x80000000), // 시트 뒤 화면 50% 검정.
    mapLand: Color(0xFF1D2331), // #1D2331: 지도 바탕.
    mapBuilding: Color(0xFF28303F), // #28303F: 건물.
    mapPark: Color(0xFF1C4A31), // #1C4A31: 공원.
    mapWater: Color(0xFF153A5C), // #153A5C: 강·하천.
    mapRoad: Color(0xFF4A5467), // #4A5467: 도로 기본 토큰.
    mapRoadLight: Color(0xFF5C6882), // #5C6882: 지도 예시 도로 밝은 끝값.
    mapRoadDark: Color(0xFF2F3746), // #2F3746: 지도 예시 도로 어두운 끝값.
    mapButtonBase: Color(0xFF0E0F11), // #0E0F11: 지도 버튼 바탕, opacity 별도.
    mapButtonOpacity: 0.94, // 지도 버튼 바탕 94%.
    mapButtonBorder: Color(0xFF2C3238), // #2C3238: 지도 버튼 테두리.
  );

  /// 라이트: 다크의 역할을 그대로 뒤집습니다. 흰 바탕 위 검정 글자, 주요 버튼·선택은 검정.
  static const light = AppPalette(
    brightness: Brightness.light,
    primary: Color(0xFFFF7A00), // route/orange: 경로·현재 위치·러닝 버튼(그대로).
    primaryPressed: Color(0xFFE06B00),
    primarySoft: Color.fromRGBO(255, 122, 0, 0.16),
    primaryText: Color(0xFFB94B00), // text/orange: 흰 바탕 위 주황 글자(5.2:1).
    background: Color(0xFFFFFFFF), // bg/base: 앱 전체 배경·시트.
    surface: Color(0xFFF7F8FA), // bg/surface: 보조 면.
    card: Color(0xFFF3F4F6), // bg/card: 햇반 카드·아이콘 원.
    surfacePressed: Color(0xFFEEF0F3), // bg/pressed: 눌림·선택된 목록.
    divider: Color(0xFFE9ECEF), // line/divider: 목록·표 구분선.
    borderDefault: Color(0xFFCDD3D9), // line/border: 섹션 선·테두리 버튼.
    borderControl: Color(0xFF8C96A0), // line/control: 입력 밑줄·아바타.
    textPrimary: Color(0xFF0B0B0B), // text/primary: 숫자·제목·주요 버튼.
    textSecondary: Color(0xFF4F5761), // text/secondary: 라벨·설명·단위.
    textTertiary: Color(0xFF646D77), // text/tertiary: 캡션·비활성 탭·지명.
    onInverse: Color(0xFFFFFFFF), // 검정 주요 버튼·선택 칩 위 글자.
    error: Color(0xFFD93A30), // signal/error: 입력 오류에만.
    scrim: Color(0x73000000), // 시트 뒤 화면 45% 검정.
    mapLand: Color(0xFFEEF1F4), // map/land
    mapBuilding: Color(0xFFDEE3E9), // map/building
    mapPark: Color(0xFFD4EBDA), // map/park
    mapWater: Color(0xFFC4DDF3), // map/water
    mapRoad: Color(0xFFFFFFFF), // map/road
    mapRoadLight: Color(0xFFFFFFFF),
    mapRoadDark: Color(0xFFD2D8DF), // 길 테두리.
    mapButtonBase: Color(0xFFFFFFFF), // 지도 위 버튼·카드: 반투명 흰색.
    mapButtonOpacity: 0.96,
    mapButtonBorder: Color(0xFFE9ECEF),
  );

  /// 지금 화면 모드의 색. 앱 시작과 설정 변경 때 [AppThemeController]가 바꿉니다.
  static AppPalette current = light;

  static bool get isDark => current.brightness == Brightness.dark;

  /// 화면 모드에 따라 고릅니다. 다크 화면을 예전과 똑같이 두려고, 직접 적어 둔 색을 바꿀 때 씁니다.
  static Color pick(Color dark, Color light) => isDark ? dark : light;

  static Color get primary => current.primary;
  static Color get primaryPressed => current.primaryPressed;
  static Color get primarySoft => current.primarySoft;

  /// 바탕 위 주황 글자. 라이트에서는 읽기 쉽게 진한 주황입니다. 주황 면·경로에는 [primary]를 씁니다.
  static Color get primaryText => current.primaryText;
  static Color get background => current.background;
  static Color get surface => current.surface;
  static Color get card => current.card;
  static Color get surfacePressed => current.surfacePressed;
  static Color get divider => current.divider;
  static Color get borderDefault => current.borderDefault;
  static Color get borderControl => current.borderControl;
  static Color get textPrimary => current.textPrimary;
  static Color get textSecondary => current.textSecondary;
  static Color get textTertiary => current.textTertiary;

  /// [textPrimary]로 칠한 면(주요 버튼·선택 칩·켜진 토글) 위 글자·아이콘.
  static Color get onInverse => current.onInverse;
  static Color get error => current.error;

  /// 바텀 시트·대화창 바탕. 다크는 #151515, 라이트는 흰색입니다.
  static Color get sheet => isDark ? current.card : current.background;

  /// 시트 뒤를 어둡게 덮는 색.
  static Color get scrim => current.scrim;
  static Color get mapLand => current.mapLand;
  static Color get mapBuilding => current.mapBuilding;
  static Color get mapPark => current.mapPark;
  static Color get mapWater => current.mapWater;
  static Color get mapRoad => current.mapRoad;
  static Color get mapRoadLight => current.mapRoadLight;
  static Color get mapRoadDark => current.mapRoadDark;
  static Color get mapButtonBase => current.mapButtonBase;
  static double get mapButtonOpacity => current.mapButtonOpacity;
  static Color get mapButtonBorder => current.mapButtonBorder;
}
