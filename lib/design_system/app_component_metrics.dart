import 'package:flutter/material.dart';

/// 출처: 02 레이아웃, 05 아이콘, 06 컴포넌트.
abstract final class AppComponentMetrics {
  static const baseFrame = Size(390, 844);
  static const compactFrame = Size(375, 667);
  static const largeFrame = Size(430, 932);
  static const androidFrame = Size(360, 800);
  static const compactHeightThreshold = 700.0; // 이 값 '미만'.
  static const compactMapVisibleRatioMin = 0.65;
  static const minimumTouchTarget = 44.0;
  static const tabBarHeight = 56.0; // 하단 안전 영역 별도.
  static const dividerWidth = 1.0;
  static const borderWidth = 1.0;
  static const inputUnderlineWidth = 1.0;
  static const inputActiveUnderlineWidth = 2.0;
  static const splitBarWidth = 2.0;
  static const fastestSplitBarWidth = 4.0;
  static const routeWidth = 4.0;
  static const timelineWidth = 2.0;
  static const iconSize = 24.0;
  static const iconStrokeWidth = 1.5;
  static const buttonIconSize = 18.0;
  static const mapButtonSize = 44.0;
  static const mapButtonIconSize = 22.0;
  static const currentLocationBorderWidth = 3.0;
  static const startMarkerLarge = 22.0;
  static const startMarkerMedium = 15.0;
  static const startMarkerSmall = 7.0;
  static const finishMarkerLarge = 22.0;
  static const finishMarkerMedium = 15.0;
  static const finishMarkerSmall = 8.0;
  static const startSlabHeight = 88.0;
  static const primaryButtonLargeHeight = 64.0;
  static const primaryButtonMediumHeight = 60.0;
  static const whiteButtonMediumHeight = 56.0;
  static const whiteButtonSmallHeight = 52.0;
  static const runningCardButtonHeight = 54.0; // 레이아웃 제약 조건의 별도 값.
  static const runningEndButtonWidth = 120.0;
  static const runningControlButtonSize = 64.0; // 러닝 중 아래 종료·일시정지 원형 버튼.
  static const runningEdgeSwipeWidth = 24.0; // 러닝 중 지도 오른쪽 끝, 밀면 크게 보기로 넘어가는 폭.
  static const textButtonHeight = 40.0; // 최소 터치 영역 44와 차이, 문서 참고.
  static const segmentHeights = <double>[40, 44, 48];
  static const toggleSize = Size(50, 30);
  static const chipHeights = <double>[32, 34];
  static const recordThumbnailSize = 88.0;
  static const mapPreviewSize = Size(342, 200);
  static const appIconExportSizes = <int>[1024, 180, 120];
}
