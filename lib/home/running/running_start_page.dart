import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../account/account_store.dart';
import '../../design_system/app_colors.dart';
import '../../design_system/app_component_metrics.dart';
import '../../design_system/app_motion.dart';
import '../../design_system/app_radius.dart';
import '../../design_system/app_spacing.dart';
import '../../design_system/app_text_styles.dart';
import 'calorie_quest.dart';
import 'running_home_page.dart';
import 'running_live_activity.dart';
import 'running_voice.dart';
import 'running_result_page.dart';
import '../../friends/data/record_share.dart';
import '../../friends/data/together_live.dart';
import '../../friends/data/together_store.dart';
import '../../record/data/record_from_session.dart';
import '../../record/data/record_places.dart';
import '../../record/data/route_thumbnails.dart';
import '../../record/data/running_record_store.dart';

// ═════════════════════════════════════════════════════
// 기준값 · 계산 · 표기
// ═════════════════════════════════════════════════════

/// 러닝 계산 기준값. 값 조정은 여기서만 합니다.
abstract final class RunningConfig {
  /// 햇반 1개(210g) 칼로리.
  static const hetbahnKcal = 315.0;

  /// 체중 입력 화면이 생기기 전까지 쓰는 기본 체중.
  static const defaultWeightKg = 65.0;

  /// 정확도 반경이 이보다 큰 좌표는 거리에서 제외합니다.
  static const maxAccuracyMeters = 25.0;

  /// 이보다 짧은 이동은 제자리 GPS 흔들림으로 보고 누적을 미룹니다.
  static const minSegmentMeters = 3.0;

  /// GPS 오차가 클수록 점 사이 간격을 넓힙니다(오차의 절반, 최대 10m). 오차 ±14m에서 3m마다 점을 찍으면
  /// 흔들림이 그대로 지그재그 경로가 됩니다.
  static const maxSegmentMeters = 10.0;
  static double segmentMetersFor(double accuracy) =>
      (accuracy / 2).clamp(minSegmentMeters, maxSegmentMeters);

  /// 이보다 빠른 이동(약 43km/h)은 좌표 튐으로 보고 제외합니다.
  static const maxSpeedMetersPerSecond = 12.0;

  /// 튄 좌표가 이만큼 연속되면 신호 복구로 보고 기준점만 옮깁니다.
  static const maxConsecutiveOutliers = 3;

  /// 이 거리 미만에서는 페이스를 표시하지 않습니다.
  static const minDistanceForPaceMeters = 10.0;

  /// 속도 계산 구간. 몇 m씩 흔들리는 GPS 오차가 그래프·최고 속도·칼로리를 튀게 하지 않도록 묶습니다.
  static const speedWindow = Duration(seconds: 10);

  /// 자동 일시정지: 이만큼 움직임이 없으면 운동 시간을 멈춥니다.
  static const autoPauseAfter = Duration(seconds: 10);

  /// 정확한 좌표가 이 안에 들어왔을 때만 '신호가 좋다'고 보고 자동 일시정지를 판단합니다.
  /// 실내처럼 GPS가 안 잡히면 멈춘 건지 알 수 없으므로 시간을 계속 잽니다.
  static const goodSignalWithin = Duration(seconds: 5);

  /// 이 속도(m/s, 약 시속 1.8km) 이상으로 움직인 좌표를 '움직임'으로 봅니다. 천천히 걷기도 포함됩니다.
  static const movingMetersPerSecond = 0.5;

  /// 자동 일시정지 중 이 속도 이상이거나 멈춘 곳에서 이만큼 벗어나면 다시 시간을 잽니다.
  static const autoResumeMetersPerSecond = 0.8;

  /// 아이폰이 현재 속도를 주지 않을 때(시뮬레이터 등)만 쓰는 거리 기준.
  /// 서 있어도 GPS가 10m 넘게 흔들릴 수 있어, 속도를 알 때는 쓰지 않습니다.
  static const autoResumeMeters = 10.0;

  /// 자동 일시정지 중 움직임이 이만큼 이어져야 다시 잽니다. 한 발짝 움직였다 멈추면 다시 재지 않습니다.
  static const autoResumeAfter = Duration(seconds: 5);

  /// 이 속도(분속 134m ≈ 시속 8km) 미만은 걷기, 이상은 달리기 공식으로 칼로리를 계산합니다.
  static const walkRunThresholdMetersPerMinute = 134.0;

  /// 함께 달리기: 친구가 이 거리 안에 있을 때만 지도에 점·지나간 길을 그립니다. 그보다 멀면
  /// 러닝 중 지도(확대 고정)에서는 어차피 화면 밖이라, 친구 칩에 떨어진 거리만 적습니다.
  static const friendMapRadiusMeters = 1000.0;
}

/// 칼로리·페이스·햇반 환산. 의료용이 아닌 운동 참고용 추정값입니다.
abstract final class RunningCalc {
  /// 한 구간의 활동 칼로리. 기초대사량(안정 시 3.5ml/kg/min)은 넣지 않습니다.
  /// ACSM 수평 이동분만 씁니다: 걷기 0.1ml/kg/m, 달리기 0.2ml/kg/m, 산소 1L ≈ 5kcal.
  /// 걷기·달리기 구분은 [windowMetersPerMinute]로 묶은 속도를 씁니다.
  static double segmentCalories({
    required double weightKg,
    required double meters,
    required double metersPerMinute,
  }) {
    if (meters <= 0) return 0;
    final oxygenMlPerKgPerMeter =
        metersPerMinute < RunningConfig.walkRunThresholdMetersPerMinute
        ? 0.1
        : 0.2;
    return oxygenMlPerKgPerMeter * meters * weightKg / 1000 * 5;
  }

  /// [i]번째 좌표까지 최근 [RunningConfig.speedWindow] 동안의 분속(m/min).
  /// 구간이 그보다 짧으면 구간 처음부터 계산합니다.
  static double windowMetersPerMinute(List<TrackPoint> segment, int i) {
    var j = i - 1;
    while (j > 0 &&
        segment[i].moving - segment[j].moving < RunningConfig.speedWindow) {
      j--;
    }
    final minutes =
        (segment[i].moving - segment[j].moving).inMilliseconds /
        Duration.millisecondsPerMinute;
    return minutes > 0 ? (segment[i].meters - segment[j].meters) / minutes : 0;
  }

  /// 좌표 사이마다 최근 속도를 보고 걷기·달리기 공식을 골라 더한 활동 칼로리.
  static double activeCalories(
    List<List<TrackPoint>> segments,
    double weightKg,
  ) {
    var kcal = 0.0;
    for (final segment in segments) {
      for (var i = 1; i < segment.length; i++) {
        kcal += segmentCalories(
          weightKg: weightKg,
          meters: segment[i].meters - segment[i - 1].meters,
          metersPerMinute: windowMetersPerMinute(segment, i),
        );
      }
    }
    return kcal;
  }

  /// 1km당 걸린 초. 거리가 너무 짧으면 null.
  static double? paceSecondsPerKm(double meters, Duration duration) {
    if (meters < RunningConfig.minDistanceForPaceMeters) return null;
    return duration.inMilliseconds / 1000 / (meters / 1000);
  }

  static double hetbahnCount(double kcal) => kcal / RunningConfig.hetbahnKcal;
}

/// 디자인 가이드 'UX 문구·표기' 규칙.
abstract final class RunningFormat {
  static const _weekdays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// 5.24
  static String km(double meters) => (meters / 1000).toStringAsFixed(2);

  /// 러닝 중 초시계: 32:15, 1:02:15
  static String clock(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${_two(m)}:${_two(s)}' : '$m:${_two(s)}';
  }

  /// 쉬는 시간: 00:48
  static String timer(Duration d) =>
      '${_two(d.inMinutes)}:${_two(d.inSeconds.remainder(60))}';

  /// 32분 15초, 1시간 2분 15초
  static String koreanDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h시간 $m분 $s초' : '$m분 $s초';
  }

  /// [('32','분'), ('15','초')] — 숫자와 단위를 다른 크기로 그릴 때.
  static List<(String, String)> durationParts(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return [
      if (h > 0) ('$h', '시간'),
      (h > 0 ? _two(m) : '$m', '분'),
      (_two(s), '초'),
    ];
  }

  /// 러닝 중 페이스: 6′12″
  static String livePace(double? secondsPerKm) {
    if (secondsPerKm == null || !secondsPerKm.isFinite) return '-′--″';
    final t = secondsPerKm.round();
    return '${t ~/ 60}′${_two(t % 60)}″';
  }

  /// 결과·기록 페이스: [('6','분'), ('09','초')]
  static List<(String, String)> paceParts(double? secondsPerKm) {
    if (secondsPerKm == null || !secondsPerKm.isFinite) return [('-', '')];
    final t = secondsPerKm.round();
    return [('${t ~/ 60}', '분'), (_two(t % 60), '초')];
  }

  /// 315
  static String kcal(double kcal) => kcal.round().toString();

  /// 9.7
  static String speed(double kmh) => kmh.toStringAsFixed(1);

  /// 1.0
  static String hetbahn(double count) => count.toStringAsFixed(1);

  /// 오후 7:42
  static String time(DateTime t) {
    final period = t.hour < 12 ? '오전' : '오후';
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$period $h:${_two(t.minute)}';
  }

  /// 오후 7:42 – 8:16 (같은 오전/오후면 뒤쪽은 생략)
  static String timeRange(DateTime a, DateTime b, {bool repeatPeriod = false}) {
    final end = time(b);
    final samePeriod = (a.hour < 12) == (b.hour < 12);
    return '${time(a)} – ${samePeriod && !repeatPeriod ? end.substring(3) : end}';
  }

  /// 9월 28일 월요일
  static String monthDay(DateTime d) =>
      '${d.month}월 ${d.day}일 ${_weekdays[d.weekday - 1]}';

  /// 2026년 9월 28일 월요일
  static String fullDate(DateTime d) => '${d.year}년 ${monthDay(d)}';
}

// ═════════════════════════════════════════════════════
// 기록 데이터
// ═════════════════════════════════════════════════════

/// 거리에 반영된 GPS 좌표 하나.
class TrackPoint {
  const TrackPoint({
    required this.latLng,
    required this.time,
    required this.moving,
    required this.meters,
    required this.accuracy,
  });

  final LatLng latLng;
  final DateTime time;

  /// 이 좌표까지의 운동 시간(일시정지 제외).
  final Duration moving;

  /// 이 좌표까지의 누적 거리.
  final double meters;
  final double accuracy;
}

class SpeedSample {
  const SpeedSample(this.km, this.kmh);
  final double km;
  final double kmh;
}

class RunningSplit {
  const RunningSplit({
    required this.index,
    required this.meters,
    required this.duration,
  });

  /// 1부터 시작하는 km 번호.
  final int index;
  final double meters;
  final Duration duration;

  bool get isFull => meters >= 1000;
  double get paceSecondsPerKm => duration.inMilliseconds / meters;
}

class RunningPlaces {
  const RunningPlaces({this.start, this.end, this.area});
  final String? start;
  final String? end;

  /// 출발지 동네 이름. 예: 여의도
  final String? area;
}

/// 끝난 러닝 한 번. 결과·상세 화면이 함께 씁니다.
class RunningRecord {
  RunningRecord({
    required this.startedAt,
    required this.endedAt,
    required this.distanceMeters,
    required this.movingDuration,
    required this.weightKg,
    required this.segments,
    required this.pausePoints,
    this.diagnostics,
  });

  /// 진단 기록([RunningDiagnostics.toJson]). 저장 파일에 그대로 들어갑니다.
  final Map<String, Object?>? diagnostics;

  final DateTime startedAt;
  final DateTime endedAt;
  final double distanceMeters;
  final Duration movingDuration;
  final double weightKg;

  /// 일시정지마다 나뉜 경로.
  final List<List<TrackPoint>> segments;

  /// 일시정지한 위치와 그때까지의 거리.
  final List<TrackPoint> pausePoints;

  late final List<TrackPoint> points = [for (final s in segments) ...s];

  Duration get totalDuration => endedAt.difference(startedAt);

  Duration get pausedDuration {
    final paused = totalDuration - movingDuration;
    return paused.isNegative ? Duration.zero : paused;
  }

  /// 활동 칼로리(기초대사량 제외).
  late final double calories = RunningCalc.activeCalories(segments, weightKg);

  double get hetbahnCount => RunningCalc.hetbahnCount(calories);

  double? get paceSecondsPerKm =>
      RunningCalc.paceSecondsPerKm(distanceMeters, movingDuration);

  double get averageSpeedKmh {
    final hours = movingDuration.inMilliseconds / Duration.millisecondsPerHour;
    return hours == 0 ? 0 : distanceMeters / 1000 / hours;
  }

  double? get averageAccuracy => points.isEmpty
      ? null
      : points.map((p) => p.accuracy).reduce((a, b) => a + b) / points.length;

  /// 구간마다 [RunningConfig.speedWindow] 이상 묶어 계산한 속도.
  late final List<SpeedSample> speedSamples = () {
    final samples = <SpeedSample>[];
    for (final segment in segments) {
      var j = 0;
      for (var i = 1; i < segment.length; i++) {
        // i에서 speedWindow 이상 떨어진 가장 가까운 이전 좌표 j를 찾습니다.
        while (j < i - 1 &&
            segment[i].moving - segment[j + 1].moving >=
                RunningConfig.speedWindow) {
          j++;
        }
        final elapsed = segment[i].moving - segment[j].moving;
        if (elapsed < RunningConfig.speedWindow) continue;
        // 10초 묶음 안의 점과 점 사이 속도 중 가운데 값. GPS가 한 번 튄 구간이 묶음 전체 속도를
        // 끌어올려 최고 속도·그래프가 뻥튀기되지 않게 합니다.
        final pairSpeeds = [
          for (var k = j + 1; k <= i; k++)
            if (segment[k].moving > segment[k - 1].moving)
              (segment[k].meters - segment[k - 1].meters) /
                  ((segment[k].moving - segment[k - 1].moving).inMilliseconds /
                      1000),
        ];
        if (pairSpeeds.isEmpty) continue;
        samples.add(
          SpeedSample(segment[i].meters / 1000, _median(pairSpeeds) * 3.6),
        );
      }
    }
    return samples;
  }();

  static double _median(List<double> values) {
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  double? get maxSpeedKmh => speedSamples.isEmpty
      ? null
      : speedSamples.map((s) => s.kmh).reduce(math.max);

  double? get bestPaceSecondsPerKm {
    final max = maxSpeedKmh;
    return max == null || max <= 0 ? null : 3600 / max;
  }

  /// 1km마다 걸린 시간. 마지막 남은 거리는 isFull이 false.
  late final List<RunningSplit> splits = () {
    final result = <RunningSplit>[];
    if (points.isEmpty) return result;
    var previous = Duration.zero;
    for (var km = 1; km * 1000 <= distanceMeters; km++) {
      final at = _movingAt(km * 1000.0);
      result.add(
        RunningSplit(index: km, meters: 1000, duration: at - previous),
      );
      previous = at;
    }
    final rest = distanceMeters - result.length * 1000;
    if (rest >= RunningConfig.minDistanceForPaceMeters) {
      result.add(
        RunningSplit(
          index: result.length + 1,
          meters: rest,
          duration: movingDuration - previous,
        ),
      );
    }
    return result;
  }();

  /// 누적 거리 [meters] 지점의 운동 시간(좌표 사이 보간).
  Duration _movingAt(double meters) {
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      if (b.meters >= meters) {
        final t = b.meters == a.meters
            ? 1.0
            : (meters - a.meters) / (b.meters - a.meters);
        return a.moving + (b.moving - a.moving) * t;
      }
    }
    return movingDuration;
  }

  /// 출발·도착 지명. 결과·상세 화면이 같은 결과를 씁니다.
  late final Future<RunningPlaces> places = points.isEmpty
      ? Future.value(const RunningPlaces())
      : resolveRunningPlaces(points.first.latLng, points.last.latLng);
}

/// 출발·도착 좌표의 지명과 출발지 동네 이름. 인터넷이 없거나 찾지 못하면 비어 있는 값입니다.
Future<RunningPlaces> resolveRunningPlaces(
  LatLng startPoint,
  LatLng endPoint,
) async {
  Future<Placemark?> lookup(LatLng p) async {
    try {
      final list = await Geocoding().placemarkFromCoordinates(
        p.latitude,
        p.longitude,
      );
      return list.firstOrNull;
    } catch (_) {
      return null;
    }
  }

  String? nameOf(Placemark? p) => [
    p?.name,
    p?.thoroughfare,
    p?.subLocality,
  ].firstWhere((s) => s != null && s.isNotEmpty, orElse: () => null);

  final start = await lookup(startPoint);
  final end = await lookup(endPoint);
  return RunningPlaces(
    start: nameOf(start),
    end: nameOf(end),
    area: [
      start?.subLocality,
      start?.locality,
    ].firstWhere((s) => s != null && s.isNotEmpty, orElse: () => null),
  );
}

// ═════════════════════════════════════════════════════
// 러닝 세션
// ═════════════════════════════════════════════════════

enum RunningStatus { idle, running, paused, finished }

/// 경로가 빠지거나 거리가 안 늘 때 원인을 가리기 위한 진단 기록. 화면에는 보이지 않고 기록 파일에만 저장됩니다.
class RunningDiagnostics {
  /// 위치가 이보다 오래 안 들어오면 '공백'으로 남깁니다.
  static const gap = Duration(seconds: 15);

  /// 파일이 너무 커지지 않도록 사건은 이만큼만 남깁니다.
  static const maxEvents = 300;

  int received = 0;
  int droppedAccuracy = 0;
  int droppedStale = 0;
  int droppedOutlier = 0;
  int recoveries = 0;
  double? worstAccuracy;
  final events = <Map<String, Object?>>[];

  /// 정확도로 연달아 버리는 중일 때 그 시작 시각과 버린 수.
  DateTime? _accuracyLostAt;
  int _accuracyStreak = 0;
  double _accuracyStreakWorst = 0;
  DateTime? _lastReceivedAt;

  void event(String type, [Map<String, Object?> extra = const {}]) {
    if (events.length >= maxEvents) return;
    events.add({
      'type': type,
      'at': DateTime.now().toIso8601String(),
      ...extra,
    });
  }

  void positionReceived() {
    received++;
    final now = DateTime.now();
    final last = _lastReceivedAt;
    if (last != null && now.difference(last) > gap) {
      event('gap', {'seconds': now.difference(last).inSeconds});
    }
    _lastReceivedAt = now;
  }

  void accuracyDropped(double accuracy) {
    droppedAccuracy++;
    if (worstAccuracy == null || accuracy > worstAccuracy!) {
      worstAccuracy = accuracy;
    }
    if (_accuracyStreak++ == 0) _accuracyLostAt = DateTime.now();
    if (accuracy > _accuracyStreakWorst) _accuracyStreakWorst = accuracy;
  }

  /// 정확도 좋은 좌표가 다시 들어왔을 때. 5개 이상 연달아 버렸던 구간만 남깁니다.
  void accuracyOk() {
    if (_accuracyStreak >= 5) {
      event('accuracyLost', {
        'from': _accuracyLostAt?.toIso8601String(),
        'dropped': _accuracyStreak,
        'worstMeters': _accuracyStreakWorst.round(),
      });
    }
    _accuracyStreak = 0;
    _accuracyStreakWorst = 0;
  }

  Map<String, Object?> toJson() {
    // 끝날 때까지 정확도가 돌아오지 않았다면 그 구간도 남깁니다.
    accuracyOk();
    return {
      'received': received,
      'droppedAccuracy': droppedAccuracy,
      'droppedStale': droppedStale,
      'droppedOutlier': droppedOutlier,
      'recoveries': recoveries,
      'worstAccuracyMeters': worstAccuracy?.round(),
      'events': List.of(events),
    };
  }
}

/// 진행 중인 러닝. GPS 좌표를 걸러 거리를 누적하고 운동 시간을 잽니다.
class RunningSession extends ChangeNotifier {
  RunningSession({
    required this.weightKg,
    this.autoPause = false,
    @visibleForTesting DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  final double weightKg;

  /// 멈춰 서 있는 동안 운동 시간만 자동으로 멈춥니다. 위치·거리 기록은 그대로 이어집니다.
  final bool autoPause;
  final _stopwatch = Stopwatch();
  final List<List<TrackPoint>> _segments = [[]];
  final List<TrackPoint> _pausePoints = [];

  StreamSubscription<Position>? _subscription;
  Timer? _ticker;
  RunningStatus _status = RunningStatus.idle;
  DateTime? _startedAt;
  DateTime? _pausedAt;
  Position? _lastPosition;
  Position? _anchor;
  int _outliers = 0;
  double _meters = 0;
  double _activeKcal = 0;
  Object? _gpsError;
  bool _autoPaused = false;
  late DateTime _lastMovedAt = _now();

  /// 마지막으로 정확도 기준을 통과한 좌표의 시각과 그 순간 속도(m/s, 모르면 null).
  DateTime? _lastGoodFixAt;

  /// 자동 일시정지 중 움직임이 처음 잡힌 시각과 마지막으로 잡힌 시각. 움직임이 끊기면 지웁니다.
  DateTime? _movingSince;
  DateTime? _movingLastAt;
  double? _lastGoodSpeed;

  /// 경로 문제 원인을 가리기 위한 진단 기록(기록 파일에만 저장).
  final diagnostics = RunningDiagnostics();

  RunningStatus get status => _status;

  /// 자동 일시정지 중인지. 이때 [status]는 running 그대로이고 운동 시간만 멈춰 있습니다.
  bool get autoPaused => _autoPaused;
  DateTime? get startedAt => _startedAt;

  /// 정확도와 무관한 최신 좌표. 지도·GPS 칩용.
  Position? get lastPosition => _lastPosition;

  /// 위치 서비스가 꺼지는 등 스트림 오류. 다음 좌표가 오면 지워집니다.
  Object? get gpsError => _gpsError;

  double get distanceMeters => _meters;
  Duration get elapsed => _stopwatch.elapsed;
  List<List<TrackPoint>> get segments => _segments;
  TrackPoint? get currentPausePoint =>
      _status == RunningStatus.paused ? _pausePoints.lastOrNull : null;

  Duration get pauseElapsed =>
      _pausedAt == null ? Duration.zero : DateTime.now().difference(_pausedAt!);

  double? get paceSecondsPerKm =>
      RunningCalc.paceSecondsPerKm(_meters, elapsed);

  /// 활동 칼로리(기초대사량 제외). 좌표가 거리에 더해질 때마다 누적합니다.
  double get calories => _activeKcal;

  /// 권한은 시작 화면에서 확인했다고 보고 바로 GPS를 켭니다.
  void start() {
    if (_status != RunningStatus.idle) return;
    _startedAt = DateTime.now();
    _subscription =
        Geolocator.getPositionStream(
          locationSettings: runningLocationSettings(background: true),
        ).listen(
          _onPosition,
          onError: _onError,
          // 러닝 중에 위치 스트림이 스스로 끝나면 이후 거리가 늘지 않으므로 기록해 둡니다.
          onDone: () => diagnostics.event('streamClosed'),
        );
    _stopwatch.start();
    _lastMovedAt = _now();
    // 초 단위 표시가 건너뛰지 않도록 1초보다 짧게 갱신합니다.
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _checkAutoPause();
      notifyListeners();
    });
    _status = RunningStatus.running;
  }

  /// 테스트용: GPS 없이 달리는 중 상태로 만들고 좌표를 직접 넣습니다.
  @visibleForTesting
  void startWithoutGps() {
    _startedAt = _now();
    _stopwatch.start();
    _lastMovedAt = _now();
    _status = RunningStatus.running;
  }

  @visibleForTesting
  void addPosition(Position p) => _onPosition(p);

  @visibleForTesting
  void checkAutoPause() => _checkAutoPause();

  /// 움직임 없이 [RunningConfig.autoPauseAfter]가 지나면 운동 시간을 멈춥니다.
  /// 위치가 아예 안 들어오는 동안(터널 등)도 멈췄다가, 다시 움직임이 잡히면 이어서 잽니다.
  void _checkAutoPause() {
    if (!autoPause || _status != RunningStatus.running) return;
    final goodFix = _lastGoodFixAt;
    final signalGood =
        goodFix != null &&
        _now().difference(goodFix) <= RunningConfig.goodSignalWithin;
    if (_autoPaused) {
      // 멈춘 사이 신호가 끊겼으면 멈춰 있는지 알 수 없으니 다시 시간을 잽니다.
      if (!signalGood) _autoResume();
      return;
    }
    // 신호가 좋고, 좌표가 멈춰 있음을 보여 줄 때만 멈춥니다(실내 등 신호가 나쁘면 멈추지 않음).
    if (!signalGood ||
        (_lastGoodSpeed ?? 0) >= RunningConfig.movingMetersPerSecond ||
        _now().difference(_lastMovedAt) < RunningConfig.autoPauseAfter) {
      return;
    }
    _stopwatch.stop();
    _autoPaused = true;
    _movingSince = _movingLastAt = null;
    diagnostics.event('autoPause');
  }

  void _autoResume() {
    _autoPaused = false;
    _movingSince = _movingLastAt = null;
    // 다시 움직인 순간부터 10초를 새로 셉니다. 안 그러면 멈춰 있던 시간 때문에 곧바로 다시 멈춥니다.
    _lastMovedAt = _now();
    _stopwatch.start();
    diagnostics.event('autoResume');
  }

  void pause() {
    if (_status != RunningStatus.running) return;
    _autoPaused = false;
    _stopwatch.stop();
    _pausedAt = DateTime.now();
    final p = _lastPosition;
    if (p != null) _pausePoints.add(_trackPoint(p));
    diagnostics.event('pause');
    _status = RunningStatus.paused;
    notifyListeners();
  }

  void resume() {
    if (_status != RunningStatus.paused) return;
    // 멈춘 동안 움직인 거리는 더하지 않고 새 구간으로 시작합니다.
    _anchor = null;
    _outliers = 0;
    if (_segments.last.isNotEmpty) _segments.add([]);
    _pausedAt = null;
    _stopwatch.start();
    _lastMovedAt = _now();
    diagnostics.event('resume');
    _status = RunningStatus.running;
    notifyListeners();
  }

  /// GPS를 끄고 최종 기록을 돌려줍니다.
  RunningRecord finish() {
    _stop();
    _status = RunningStatus.finished;
    return RunningRecord(
      startedAt: _startedAt ?? DateTime.now(),
      endedAt: DateTime.now(),
      distanceMeters: _meters,
      movingDuration: elapsed,
      weightKg: weightKg,
      segments: [
        for (final s in _segments)
          if (s.isNotEmpty) List.unmodifiable(s),
      ],
      pausePoints: List.unmodifiable(_pausePoints),
      diagnostics: diagnostics.toJson(),
    );
  }

  void _onPosition(Position position) {
    diagnostics.positionReceived();
    _lastPosition = position;
    _gpsError = null;
    // 일시정지 중에도 GPS는 켜 두어 재개 직후 바로 위치를 잡습니다.
    if (_status == RunningStatus.running) _track(position);
    notifyListeners();
  }

  void _onError(Object error) {
    diagnostics.event('gpsError', {'message': '$error'});
    _gpsError = error;
    notifyListeners();
  }

  /// 정확도가 낮거나 비정상적으로 튀는 좌표는 거리에서 뺍니다.
  void _track(Position p) {
    if (p.accuracy <= 0 || p.accuracy > RunningConfig.maxAccuracyMeters) {
      return diagnostics.accuracyDropped(p.accuracy);
    }
    diagnostics.accuracyOk();
    _lastGoodFixAt = _now();
    _lastGoodSpeed = p.speed >= 0 ? p.speed : null;
    // 아이폰이 알려 주는 현재 속도가 걷는 속도 이상이면, 위치 변화가 굼떠도 움직이는 중으로 봅니다.
    // (천천히 걷거나 모퉁이를 돌 때 위치가 3m씩 안 바뀌어 걷는 중에 멈추던 문제)
    if (!_autoPaused &&
        (_lastGoodSpeed ?? 0) >= RunningConfig.movingMetersPerSecond) {
      _lastMovedAt = _now();
    }
    final anchor = _anchor;
    if (anchor == null) return _setAnchor(p);

    final seconds =
        p.timestamp.difference(anchor.timestamp).inMilliseconds / 1000;
    if (seconds <= 0) {
      diagnostics.droppedStale++;
      return;
    }
    final meters = Geolocator.distanceBetween(
      anchor.latitude,
      anchor.longitude,
      p.latitude,
      p.longitude,
    );
    // 자동 일시정지 중에는 제자리 흔들림을 거리로 더하지 않고, 움직임이 3초 이어질 때만 다시 시간을 잽니다.
    // 기준점(멈춘 곳)은 그대로 두므로 다시 움직이면 멈춘 곳부터 거리가 이어집니다.
    // 3m 미만 좌표도 '멈췄다'는 신호이므로 거리 기준보다 먼저 봅니다.
    final doppler = p.speed >= 0 ? p.speed : null;
    if (_autoPaused) {
      final moving = doppler != null
          ? doppler >= RunningConfig.autoResumeMetersPerSecond
          : meters >= RunningConfig.autoResumeMeters;
      if (!moving) {
        _movingSince = _movingLastAt = null;
        return;
      }
      // 움직임 사이에 좌표가 한동안 안 왔으면 이어진 움직임으로 보지 않고 다시 셉니다.
      final last = _movingLastAt;
      if (last == null ||
          _now().difference(last) > RunningConfig.autoResumeAfter) {
        _movingSince = _now();
      }
      _movingLastAt = _now();
      if (_now().difference(_movingSince!) < RunningConfig.autoResumeAfter) {
        return;
      }
      _autoResume();
    }

    // 기준점을 유지하므로 천천히 움직여도 3m를 넘는 순간 한꺼번에 더해집니다.
    if (meters < RunningConfig.segmentMetersFor(p.accuracy)) return;
    if ((doppler ?? meters / seconds) >= RunningConfig.movingMetersPerSecond ||
        meters / seconds >= RunningConfig.movingMetersPerSecond) {
      _lastMovedAt = _now();
    }

    if (meters / seconds > RunningConfig.maxSpeedMetersPerSecond) {
      diagnostics.droppedOutlier++;
      if (++_outliers >= RunningConfig.maxConsecutiveOutliers) {
        diagnostics.recoveries++;
        diagnostics.event('recovered', {'jumpMeters': meters.round()});
        // 계속 새 위치를 가리키면 신호 복구로 보고, 거리 없이 새 구간을 시작합니다.
        if (_segments.last.isNotEmpty) _segments.add([]);
        _setAnchor(p);
      }
      return;
    }
    _meters += meters;
    _setAnchor(p);
    // 기록(RunningRecord.calories)과 같은 방식으로 방금 더한 거리의 칼로리를 계산합니다.
    final segment = _segments.last;
    _activeKcal += RunningCalc.segmentCalories(
      weightKg: weightKg,
      meters: meters,
      metersPerMinute: RunningCalc.windowMetersPerMinute(
        segment,
        segment.length - 1,
      ),
    );
  }

  void _setAnchor(Position p) {
    _anchor = p;
    _outliers = 0;
    _segments.last.add(_trackPoint(p));
  }

  TrackPoint _trackPoint(Position p) => TrackPoint(
    latLng: LatLng(p.latitude, p.longitude),
    time: p.timestamp,
    moving: _stopwatch.elapsed,
    meters: _meters,
    accuracy: p.accuracy,
  );

  void _stop() {
    _subscription?.cancel();
    _subscription = null;
    _ticker?.cancel();
    _ticker = null;
    _stopwatch.stop();
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }
}

// ═════════════════════════════════════════════════════
// 06 실시간 러닝 · 06-3 접힌 카드 · 07 일시정지 · 08 종료 확인
// ═════════════════════════════════════════════════════

enum _EndAction { save, keepRunning, discard }

class RunningStartPage extends StatefulWidget {
  const RunningStartPage({
    super.key,
    required this.options,
    this.initialCenter,
    this.togetherId,
  });

  final RunningStartOptions options;

  /// 함께 달리기 대기실에서 시작했으면 그 약속 번호. 저장한 뒤 결과를 약속에 올립니다.
  final String? togetherId;

  /// 시작 화면에서 마지막으로 잡힌 위치. 지도가 엉뚱한 곳에서 시작하지 않게 합니다.
  final LatLng? initialCenter;

  @override
  State<RunningStartPage> createState() => _RunningStartPageState();
}

class _RunningStartPageState extends State<RunningStartPage> {
  static const _zoom = MapZoom.running;

  late final _session = RunningSession(
    autoPause: widget.options.autoPause,
    weightKg:
        AccountStore.instance.current?.weightKg ??
        RunningConfig.defaultWeightKg,
  );
  final _map = RunneryMapController();
  bool _followUser = true;
  bool _showMapLabels = true;
  bool _collapsed = false;
  bool _ending = false;
  bool _goalReached = false;

  /// 달성을 알린 칼로리 퀘스트 단계 수.
  int _questShown = 0;
  bool _questSheetOpen = false;
  final _liveActivity = RunningLiveActivity();

  final _voice = RunningVoice();

  /// 마지막으로 읽어 준 km. 1km를 넘을 때마다 한 번씩 안내합니다.
  int _spokenKm = 0;

  /// 앱이 백그라운드로 가고 돌아온 시각을 진단 기록에 남깁니다.
  late final AppLifecycleListener _lifecycle;
  Position? _followedPosition;

  /// 함께 달리기면 친구들과 거리·위치·지나간 길을 주고받습니다.
  TogetherLive? _live;

  @override
  void initState() {
    super.initState();
    // 달리는 중 기록을 보기 쉽도록 러닝 화면에서는 화면이 자동으로 꺼지지 않게 합니다.
    // (화면을 직접 꺼도 위치는 계속 받습니다.)
    WakelockPlus.enable();
    _session
      ..addListener(_followCamera)
      ..addListener(_checkGoal)
      ..addListener(_checkQuest)
      ..addListener(_updateLiveActivity)
      ..addListener(_announceKm)
      ..addListener(_announceAutoPause)
      ..start();
    if (widget.togetherId case final id?) {
      _live = TogetherLive(id)..start();
      _session.addListener(_shareLive);
    }
    // '5킬로미터예요', '30분이에요': 거리는 받침이 없고 시간은 받침이 있습니다.
    final goal = _goalText;
    _say(
      goal == null
          ? '러닝을 시작합니다.'
          : '러닝을 시작합니다. 목표는 $goal${widget.options.mode == RunningMode.distanceGoal ? '예요' : '이에요'}.',
    );
    _liveActivity.start(_liveActivityState());
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) =>
          _session.diagnostics.event('app', {'state': state.name}),
    );
  }

  @override
  void dispose() {
    // 끝났거나 화면을 닫으면 친구들에게 보이던 내 위치·지나간 길을 지웁니다.
    _live?.dispose();
    WakelockPlus.disable();
    _lifecycle.dispose();
    _liveActivity.end();
    _session.dispose();
    _map.dispose();
    super.dispose();
  }

  void _followCamera() {
    // 화면이 안 보일 때는 지도를 움직이지 않아 배터리를 아낍니다. 돌아오면 다음 위치에서 따라갑니다.
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    final p = _session.lastPosition;
    if (p == null || identical(p, _followedPosition)) return;
    _followedPosition = p;
    if (_followUser) _map.follow(LatLng(p.latitude, p.longitude));
  }

  void _shareLive() {
    final p = _session.lastPosition;
    final routePoint = _session.segments.lastOrNull?.lastOrNull?.latLng;
    _live?.update(
      meters: _session.distanceMeters,
      moving: _session.elapsed,
      paused: _session.status != RunningStatus.running || _session.autoPaused,
      position: p == null ? null : (p.latitude, p.longitude),
      routePoint: routePoint == null
          ? null
          : (routePoint.latitude, routePoint.longitude),
    );
  }

  /// 내 위치에서 친구까지 거리(m). 둘 중 하나라도 위치를 모르면 null.
  double? _awayMeters(LiveFriend f) {
    final me = _session.lastPosition;
    final friend = f.run?.position;
    if (me == null || friend == null) return null;
    return Geolocator.distanceBetween(
      me.latitude,
      me.longitude,
      friend.$1,
      friend.$2,
    );
  }

  /// 다이내믹 아일랜드에 보낼 값. 거리는 화면처럼 0.01 km 단위로 맞춥니다.
  Map<String, Object?> _liveActivityState() => {
    'distanceKm': double.parse(RunningFormat.km(_session.distanceMeters)),
    'pace': RunningFormat.livePace(_session.paceSecondsPerKm),
    'paused': _session.status == RunningStatus.paused || _session.autoPaused,
    'goal': widget.options.goalStatus(
      _session.distanceMeters,
      _session.elapsed,
    ),
    'elapsedSeconds': _session.elapsed.inSeconds,
    // 다이내믹 아일랜드 작은 칸: 거리 목표만 km, 자유·시간 목표는 달리는 시간을 보여 줍니다.
    'showTime': widget.options.mode != RunningMode.distanceGoal,
  };

  void _updateLiveActivity() => _liveActivity.update(_liveActivityState());

  /// 음성 안내가 켜져 있을 때만 읽습니다.
  void _say(String text) {
    if (widget.options.voiceGuide) _voice.speak(text);
  }

  /// 읽기용 목표. 예: 5킬로미터, 30분. 자유 러닝이면 null.
  String? get _goalText => switch (widget.options.mode) {
    RunningMode.free => null,
    RunningMode.distanceGoal => RunningVoice.km(widget.options.goalKm),
    RunningMode.timeGoal => RunningGoal.minutes(widget.options.goalMinutes),
  };

  bool _wasAutoPaused = false;

  /// 자동 일시정지가 걸리고 풀릴 때 알려 줍니다.
  void _announceAutoPause() {
    final autoPaused = _session.autoPaused;
    if (autoPaused == _wasAutoPaused) return;
    _wasAutoPaused = autoPaused;
    _say(autoPaused ? '자동 일시정지.' : '다시 측정합니다.');
  }

  /// 1km마다 거리·시간·평균 페이스를 읽어 줍니다. 거리 목표면 남은 거리도 알려 줍니다.
  void _announceKm() {
    final km = (_session.distanceMeters / 1000).floor();
    if (km <= _spokenKm) return;
    _spokenKm = km;
    final pace = _session.paceSecondsPerKm;
    final options = widget.options;
    final left = options.mode == RunningMode.distanceGoal
        ? options.goalKm - _session.distanceMeters / 1000
        : null;
    _say(
      [
        '$km킬로미터.',
        '시간 ${RunningVoice.duration(_session.elapsed)}.',
        if (pace != null)
          '평균 페이스 ${RunningVoice.duration(Duration(seconds: pace.round()))}.',
        if (left != null && left > 0.05)
          '목표까지 ${left.toStringAsFixed(1)}킬로미터 남았어요.',
      ].join(' '),
    );
  }

  /// 목표를 처음 채운 순간 한 번만 진동과 안내를 띄웁니다. 러닝은 계속 이어집니다.
  void _checkGoal() {
    if (_goalReached) return;
    final progress = widget.options.goalProgress(
      _session.distanceMeters,
      _session.elapsed,
    );
    if (progress == null || progress < 1) return;
    _goalReached = true;
    HapticFeedback.heavyImpact();
    _say(
      widget.options.mode == RunningMode.distanceGoal
          ? '목표 거리 $_goalText를 달성했어요. 계속 달려도 돼요.'
          : '목표 시간 $_goalText을 채웠어요. 계속 달려도 돼요.',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('목표 달성! 계속 달려도 돼요.'),
      ),
    );
  }

  /// 칼로리 퀘스트 단계를 새로 넘으면 진동·음성으로 알리고 달성 창을 띄웁니다. 기록은 계속됩니다.
  void _checkQuest() {
    if (!widget.options.calorieQuest) return;
    final done = CalorieQuest.completed(_session.calories);
    if (done <= _questShown) return;
    _questShown = done;
    final stage = CalorieQuest.stages[done - 1];
    HapticFeedback.heavyImpact();
    _say('칼로리 퀘스트 $done단계 달성. ${stage.fullName}만큼 태웠어요.');
    // 이미 창이 떠 있거나 종료 확인 중이면 창은 띄우지 않습니다(카드의 퀘스트 줄은 바뀝니다).
    if (_ending || _questSheetOpen) return;
    _questSheetOpen = true;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      isScrollControlled: true,
      builder: (_) => CalorieQuestAchievedSheet(
        stageIndex: done - 1,
        listenable: _session,
        calories: () => _session.calories,
        elapsed: () => _session.elapsed,
      ),
    ).whenComplete(() => _questSheetOpen = false);
  }

  void _openQuestPage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CalorieQuestPage(
          listenable: _session,
          calories: () => _session.calories,
        ),
      ),
    );
  }

  void _recenter() {
    setState(() => _followUser = true);
    final p = _session.lastPosition;
    if (p != null) _map.moveTo(LatLng(p.latitude, p.longitude), zoom: _zoom);
  }

  void _pause() {
    HapticFeedback.mediumImpact();
    _say('일시정지했어요.');
    setState(() => _collapsed = false);
    _session.pause();
  }

  void _resume() {
    HapticFeedback.mediumImpact();
    _say('다시 시작합니다.');
    _session.resume();
  }

  Future<void> _openEndSheet() async {
    if (_ending) return;
    _ending = true;
    final wasRunning = _session.status == RunningStatus.running;
    _session.pause();
    final action = await showModalBottomSheet<_EndAction>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      isScrollControlled: true,
      sheetAnimationStyle: const AnimationStyle(
        duration: AppMotion.endConfirmation,
      ),
      builder: (_) => _EndConfirmSheet(session: _session),
    );
    if (!mounted) return;

    switch (action) {
      case _EndAction.save:
        final record = _session.finish();
        final saved = recordFromSession(record);
        while (mounted) {
          try {
            await RunningRecordStore.instance.save(saved);
            RecordPlaces.instance.fill(RunningRecordStore.instance, [saved]);
            // 결과 화면을 보는 동안 목록용 지도 사진을 미리 만들어, 목록에 들어가면 바로 보이게 합니다.
            RouteThumbnails.instance.get(saved);
            if (widget.togetherId case final id?) {
              unawaited(TogetherStore.instance.runFinished(id, saved));
            }
            // 자동 공유를 켜 두었으면 장소 이름을 찾은 뒤 친구 피드에 올립니다.
            unawaited(
              record.places.then(
                (p) => RecordShare.instance.shareIfAuto(
                  saved.withPlaces(area: p.area, start: p.start, end: p.end),
                ),
              ),
            );
            break;
          } catch (_) {
            if (!mounted) return;
            final retry = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (context) => PopScope(
                canPop: false,
                child: AlertDialog(
                  title: const Text('기록 저장 실패'),
                  content: const Text(
                    '러닝 기록을 저장하지 못했습니다. 저장 공간을 확인한 후 다시 시도해 주세요.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('저장하지 않고 종료'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('다시 저장'),
                    ),
                  ],
                ),
              ),
            );
            if (retry != true) {
              if (mounted) Navigator.of(context).pop();
              return;
            }
          }
        }
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          runningPushRoute(
            RunningResultPage(record: record),
            AppMotion.resultPush,
          ),
        );
      case _EndAction.discard:
        _session.finish();
        Navigator.of(context).pop();
      case _EndAction.keepRunning || null:
        _ending = false;
        if (wasRunning) _session.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _openEndSheet();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppColors.mapLand,
          body: ListenableBuilder(
            listenable: Listenable.merge([_session, ?_live]),
            builder: (context, _) => _buildMap(context),
          ),
        ),
      ),
    );
  }

  Widget _buildMap(BuildContext context) {
    final position = _session.lastPosition;
    final point = position == null
        ? null
        : LatLng(position.latitude, position.longitude);
    final firstPoint = _session.segments.firstOrNull?.firstOrNull;
    final pausePoint = _session.currentPausePoint;
    // 달리는 중이거나 잠깐 멈춘, 1km 안의 친구만 지도에 그립니다.
    final friends = [
      for (final f in _live?.friends ?? const <LiveFriend>[])
        if (f.run?.position case (final lat, final lng)?)
          if ((f.state == LiveFriendState.running ||
                  f.state == LiveFriendState.paused) &&
              (_awayMeters(f) ?? double.infinity) <=
                  RunningConfig.friendMapRadiusMeters)
            MapFriend(
              LatLng(lat, lng),
              f.name,
              route: [for (final (a, b) in f.run!.route) LatLng(a, b)],
            ),
    ];

    // 카드·버튼은 지도 children 밖에 겹쳐야 그 위의 드래그가 지도를 움직이지 않습니다.
    return Stack(
      children: [
        RunneryMap(
          controller: _map,
          initialCenter:
              point ?? widget.initialCenter ?? const LatLng(37.5665, 126.9780),
          initialZoom: _zoom,
          showLabels: _showMapLabels,
          routeWidth: RouteWidth.running,
          // 경로가 1초마다 늘어날 때마다 다시 그리면 지명·도로명이 깜빡여 5초마다 그립니다(기록은 그대로 1초마다).
          routeUpdateInterval: const Duration(seconds: 5),
          route: [
            for (final segment in _session.segments)
              [for (final p in segment) p.latLng],
          ],
          markers: [
            if (firstPoint != null)
              MapMarker(firstPoint.latLng, MapMarkerKind.start),
            if (pausePoint != null)
              MapMarker(pausePoint.latLng, MapMarkerKind.pause),
          ],
          // 일시정지 중에는 현재 위치 대신 일시정지 마커를 보여줍니다.
          userLocation: point == null || pausePoint != null
              ? null
              : MapUserLocation(point, position!.accuracy.clamp(5, 60)),
          friends: friends,
          onUserGesture: () {
            if (_followUser) setState(() => _followUser = false);
          },
        ),
        _buildControls(context),
      ],
    );
  }

  Widget _buildControls(BuildContext context) {
    final paused = _session.status == RunningStatus.paused;
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space4,
                AppSpacing.topControlSafeAreaGapMax,
                AppSpacing.space4,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: paused
                        ? [
                            const StatusChip(label: '일시정지됨', icon: Icons.pause),
                            const Spacer(),
                            StatusChip(
                              label: '쉬는 시간',
                              trailing: Text(
                                RunningFormat.timer(_session.pauseElapsed),
                                style: runningNumberStyle(
                                  13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ]
                        : [
                            StatusChip(
                              label: '기록 중',
                              leading: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            const Spacer(),
                            GpsStatusChip(
                              locationState: switch (_session.gpsError) {
                                LocationServiceDisabledException() =>
                                  RunningLocationState.serviceDisabled,
                                PermissionDeniedException() =>
                                  RunningLocationState.denied,
                                _ => RunningLocationState.ready,
                              },
                              position: _session.lastPosition,
                            ),
                          ],
                  ),
                  // 함께 달리는 친구: 이름, 거리·페이스(또는 상태), 멀리 있으면 떨어진 거리.
                  for (final f in _live?.friends ?? const <LiveFriend>[]) ...[
                    const SizedBox(height: AppSpacing.space2),
                    // 이름이 길어 화면 폭을 넘으면 칩을 통째로 줄입니다.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: _FriendLiveChip(
                        friend: f,
                        awayMeters: _awayMeters(f),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: AppSpacing.mapCardHorizontal,
          right: AppSpacing.mapCardHorizontal,
          bottom: AppSpacing.mapCardBottom,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                      left:
                          AppSpacing.mapScaleLeft -
                          AppSpacing.mapCardHorizontal,
                    ),
                    child: MapScaleBar(camera: _map),
                  ),
                  const Spacer(),
                  Column(
                    children: [
                      MapCircleButton(
                        icon: Icons.layers_outlined,
                        tooltip: _showMapLabels ? '지명 숨기기' : '지명 보기',
                        onPressed: () =>
                            setState(() => _showMapLabels = !_showMapLabels),
                      ),
                      const SizedBox(height: AppSpacing.mapControlGap),
                      MapCircleButton(
                        icon: _followUser
                            ? Icons.my_location
                            : Icons.location_searching,
                        tooltip: '현재 위치',
                        onPressed: _recenter,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.mapControlAboveCard),
              _buildCard(context, paused),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard(BuildContext context, bool paused) {
    final Widget content;
    if (_collapsed) {
      content = _CollapsedCard(
        key: const ValueKey('collapsed'),
        session: _session,
        onPause: _pause,
        onResume: _resume,
      );
    } else if (paused) {
      content = _PausedCard(
        key: const ValueKey('paused'),
        session: _session,
        onResume: _resume,
        onEnd: _openEndSheet,
      );
    } else {
      content = _RunningCard(
        key: const ValueKey('running'),
        session: _session,
        options: widget.options,
        onPause: _pause,
        onEnd: _openEndSheet,
        onOpenQuest: _openQuestPage,
      );
    }

    // 카드를 아래로 밀면 한 줄 요약으로 접고, 위로 밀면 펼칩니다.
    return GestureDetector(
      onVerticalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v.abs() < 100) return;
        setState(() => _collapsed = v > 0);
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.96),
          borderRadius: AppRadius.sheetBorder,
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _collapsed = !_collapsed),
              child: const SizedBox(
                width: double.infinity,
                height: 20,
                child: Center(child: SheetHandle()),
              ),
            ),
            AnimatedSize(
              duration: AppMotion.pauseTransition,
              curve: AppMotion.pushSlideCurve,
              alignment: Alignment.bottomCenter,
              child: AnimatedSwitcher(
                duration: AppMotion.pauseTransition,
                child: content,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 함께 달리는 친구 한 명: 흰 점(지도와 같은 표시), 이름, 거리·페이스 또는 상태.
class _FriendLiveChip extends StatelessWidget {
  const _FriendLiveChip({required this.friend, required this.awayMeters});

  final LiveFriend friend;

  /// 내 위치에서 친구까지 거리(m). 모르면 null.
  final double? awayMeters;

  @override
  Widget build(BuildContext context) {
    final f = friend;
    final run = f.run;
    final number = runningNumberStyle(13, color: AppColors.textPrimary);
    const word = TextStyle(fontSize: 12, color: AppColors.textSecondary);
    final away = awayMeters;
    return StatusChip(
      label: f.name,
      leading: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color:
              f.state == LiveFriendState.running ||
                  f.state == LiveFriendState.paused
              ? AppColors.textPrimary
              : AppColors.textTertiary,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.background, width: 1.5),
        ),
      ),
      trailing: Text.rich(
        TextSpan(
          children: [
            ...switch (f.state) {
              LiveFriendState.waiting => [
                const TextSpan(text: '출발 전이에요', style: word),
              ],
              LiveFriendState.lost => [
                const TextSpan(text: '신호 없음', style: word),
              ],
              LiveFriendState.finished => [
                const TextSpan(text: '끝났어요  ', style: word),
                TextSpan(
                  text: '${f.result!.distanceKm.toStringAsFixed(2)} km',
                  style: number,
                ),
              ],
              LiveFriendState.running || LiveFriendState.paused => [
                TextSpan(
                  text: '${run!.distanceKm.toStringAsFixed(2)} km',
                  style: number,
                ),
                f.state == LiveFriendState.paused
                    ? const TextSpan(text: '  멈춤', style: word)
                    : TextSpan(
                        text:
                            '  ${RunningFormat.livePace(run.paceSeconds?.toDouble())}',
                        style: number,
                      ),
              ],
            },
            if (away != null &&
                away > RunningConfig.friendMapRadiusMeters &&
                (f.state == LiveFriendState.running ||
                    f.state == LiveFriendState.paused))
              TextSpan(
                text: '  ${(away / 1000).toStringAsFixed(1)} km 떨어져 있어요',
                style: word,
              ),
          ],
        ),
      ),
    );
  }
}

/// 06 실시간 러닝 카드.
class _RunningCard extends StatelessWidget {
  const _RunningCard({
    super.key,
    required this.session,
    required this.options,
    required this.onPause,
    required this.onEnd,
    required this.onOpenQuest,
  });

  final RunningSession session;
  final RunningStartOptions options;
  final VoidCallback onPause;
  final VoidCallback onEnd;
  final VoidCallback onOpenQuest;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('거리', style: _labelStyle),
              if (session.autoPaused) ...[
                const SizedBox(width: AppSpacing.space2),
                const Text(
                  '자동 일시정지',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
              const Spacer(),
              if (options.voiceGuide && options.mode == RunningMode.free)
                const Text(
                  '1 km마다 음성 안내',
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
            ],
          ),
          const SizedBox(height: 4),
          UnitValue(
            value: RunningFormat.km(session.distanceMeters),
            unit: 'km',
            size: runningHeroSize(context),
          ),
          if (options.goalProgress(session.distanceMeters, session.elapsed)
              case final progress?) ...[
            const SizedBox(height: AppSpacing.space3),
            ClipRRect(
              borderRadius: AppRadius.pillBorder,
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 6,
                color: AppColors.textPrimary,
                backgroundColor: AppColors.divider,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              options.goalStatus(session.distanceMeters, session.elapsed)!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.space4),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.space3),
          StatRow(
            cells: [
              StatCell(
                label: '시간',
                value: RunningFormat.clock(session.elapsed),
              ),
              StatCell(
                label: '페이스',
                value: RunningFormat.livePace(session.paceSecondsPerKm),
                unit: '/km',
              ),
              StatCell(
                label: '칼로리',
                value: RunningFormat.kcal(session.calories),
                unit: 'kcal',
              ),
            ],
          ),
          if (options.calorieQuest) ...[
            const SizedBox(height: AppSpacing.space3),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.space3),
            CalorieQuestRow(kcal: session.calories, onTap: onOpenQuest),
          ],
          const SizedBox(height: AppSpacing.space4),
          Row(
            children: [
              EndRunButton(onPressed: onEnd),
              const SizedBox(width: AppSpacing.space3),
              Expanded(
                child: WhiteButton(
                  label: '일시정지',
                  icon: Icons.pause,
                  height: AppComponentMetrics.runningCardButtonHeight,
                  onPressed: onPause,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 07 일시정지 카드.
class _PausedCard extends StatelessWidget {
  const _PausedCard({
    super.key,
    required this.session,
    required this.onResume,
    required this.onEnd,
  });

  final RunningSession session;
  final VoidCallback onResume;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                '일시정지',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Spacer(),
              Icon(Icons.pause, color: AppColors.textPrimary, size: 26),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '숨을 고르고 준비되면 다시 시작하세요',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.space4),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.space3),
          StatRow(
            cells: [
              StatCell(
                label: '거리',
                value: RunningFormat.km(session.distanceMeters),
                unit: 'km',
              ),
              StatCell(
                label: '시간',
                value: RunningFormat.clock(session.elapsed),
              ),
              StatCell(
                label: '칼로리',
                value: RunningFormat.kcal(session.calories),
                unit: 'kcal',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space4),
          Row(
            children: [
              EndRunButton(onPressed: onEnd),
              const SizedBox(width: AppSpacing.space3),
              Expanded(
                child: _OrangeButton(label: '다시 시작', onPressed: onResume),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 06-3 한 줄 요약 카드.
class _CollapsedCard extends StatelessWidget {
  const _CollapsedCard({
    super.key,
    required this.session,
    required this.onPause,
    required this.onResume,
  });

  final RunningSession session;
  final VoidCallback onPause;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final paused = session.status == RunningStatus.paused;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: StatRow(
              dividers: false,
              cells: [
                StatCell(
                  label: '거리',
                  value: RunningFormat.km(session.distanceMeters),
                  unit: 'km',
                ),
                StatCell(
                  label: '시간',
                  value: RunningFormat.clock(session.elapsed),
                ),
                StatCell(
                  label: '페이스',
                  value: RunningFormat.livePace(session.paceSecondsPerKm),
                  unit: '/km',
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.space2),
          Material(
            color: paused ? AppColors.primary : AppColors.textPrimary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: paused ? onResume : onPause,
              child: SizedBox.square(
                dimension: 52,
                child: Icon(
                  paused ? Icons.play_arrow_rounded : Icons.pause,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 08 종료 확인 바텀 시트.
class _EndConfirmSheet extends StatelessWidget {
  const _EndConfirmSheet({required this.session});

  final RunningSession session;

  @override
  Widget build(BuildContext context) {
    final startedAt = session.startedAt ?? DateTime.now();
    final today = DateUtils.isSameDay(startedAt, DateTime.now());
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.space3,
        AppSpacing.screenHorizontal,
        AppSpacing.space3 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: SheetHandle()),
          const SizedBox(height: AppSpacing.space5),
          const Text(
            '러닝을 종료할까요?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '지금까지 달린 경로와 기록이 저장돼요.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.space5),
          Container(
            padding: const EdgeInsets.all(AppSpacing.space3),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: AppRadius.thumbnailBorder,
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox.square(
                    dimension: 64,
                    child: CustomPaint(
                      painter: RouteThumbnailPainter(session.segments),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.space4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UnitValue(
                        value: RunningFormat.km(session.distanceMeters),
                        unit: 'km',
                        size: 28,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${RunningFormat.koreanDuration(session.elapsed)} · '
                        '${RunningFormat.kcal(session.calories)} kcal · '
                        '${today ? '오늘 ' : ''}${RunningFormat.time(startedAt)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.space5),
          WhiteButton(
            label: '종료하고 저장',
            onPressed: () => Navigator.pop(context, _EndAction.save),
          ),
          const SizedBox(height: AppSpacing.space3),
          OutlineButton(
            label: '계속 달리기',
            onPressed: () => Navigator.pop(context, _EndAction.keepRunning),
          ),
          const SizedBox(height: AppSpacing.space2),
          TextButton(
            onPressed: () => Navigator.pop(context, _EndAction.discard),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textTertiary,
              minimumSize: const Size.fromHeight(
                AppComponentMetrics.minimumTouchTarget,
              ),
            ),
            child: const Text(
              '저장하지 않고 종료',
              style: TextStyle(
                fontSize: 13,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════
// 러닝·결과 화면 공통 조각
// ═════════════════════════════════════════════════════

const _labelStyle = TextStyle(fontSize: 12, color: AppColors.textSecondary);

/// 러닝 숫자: Archivo 폭 75, 자릿수 고정.
TextStyle runningNumberStyle(
  double size, {
  FontWeight weight = FontWeight.w700,
  Color color = AppColors.textPrimary,
}) => TextStyle(
  fontFamily: AppTextStyles.numberFontFamily,
  fontVariations: const [AppTextStyles.numberWidth],
  fontFeatures: const [FontFeature.tabularFigures()],
  fontSize: size,
  fontWeight: weight,
  height: 1,
  color: color,
);

/// 실시간 큰 숫자: 작은 화면 56, 기준 64, Pro Max 72, Android 60.
double runningHeroSize(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  if (size.height < AppComponentMetrics.compactHeightThreshold) {
    return AppTextStyles.compactRunningNumberSize;
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    return AppTextStyles.androidRunningNumberSize;
  }
  if (size.width >= AppComponentMetrics.largeFrame.width) {
    return AppTextStyles.largeRunningNumberSize;
  }
  return AppTextStyles.baseRunningNumberSize;
}

/// 애니메이션 없이 바로 전환하는 푸시. duration은 받지만 사용하지 않습니다.
Route<T> runningPushRoute<T>(Widget page, Duration duration) =>
    PageRouteBuilder<T>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, animation, _, child) => SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: AppMotion.pushSlideCurve),
        ),
        child: child,
      ),
    );

/// 숫자 + 작은 단위. 예: 5.24 km
class UnitValue extends StatelessWidget {
  const UnitValue({
    super.key,
    required this.value,
    required this.unit,
    required this.size,
  });

  final String value;
  final String unit;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: value,
            style: runningNumberStyle(size, weight: FontWeight.w800),
          ),
          TextSpan(
            text: ' $unit',
            style: TextStyle(
              fontSize: math.max(11, size * 0.22),
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 여러 숫자·단위 조합. 예: 32분 15초
class PartsValue extends StatelessWidget {
  const PartsValue({
    super.key,
    required this.parts,
    this.size = 24,
    this.suffix,
  });

  final List<(String, String)> parts;
  final double size;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final unitStyle = TextStyle(
      fontSize: math.max(11, size * 0.45),
      color: AppColors.textSecondary,
    );
    return Text.rich(
      TextSpan(
        children: [
          for (final (i, (number, unit)) in parts.indexed) ...[
            TextSpan(text: number, style: runningNumberStyle(size)),
            TextSpan(
              text: unit.isEmpty
                  ? ''
                  : ' $unit${i < parts.length - 1 ? ' ' : ''}',
              style: unitStyle,
            ),
          ],
          if (suffix != null) TextSpan(text: ' $suffix', style: unitStyle),
        ],
      ),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.fade,
    );
  }
}

class StatCell {
  const StatCell({required this.label, required this.value, this.unit});
  final String label;
  final String value;
  final String? unit;
}

/// 3열 스탯. 구분선 1.
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.cells, this.dividers = true});

  final List<StatCell> cells;
  final bool dividers;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        children: [
          for (final (i, cell) in cells.indexed) ...[
            if (i > 0)
              dividers
                  ? const VerticalDivider(width: 25, thickness: 1)
                  : const SizedBox(width: AppSpacing.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cell.label, style: _labelStyle),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: cell.value,
                            style: runningNumberStyle(22),
                          ),
                          if (cell.unit != null)
                            TextSpan(
                              text: ' ${cell.unit}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      decoration: const BoxDecoration(
        color: AppColors.borderDefault,
        borderRadius: AppRadius.pillBorder,
      ),
    );
  }
}

/// 흰색 버튼: 한 화면에 하나. 글자 검정.
class WhiteButton extends StatelessWidget {
  const WhiteButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = AppComponentMetrics.whiteButtonMediumHeight,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.textPrimary,
          foregroundColor: Colors.black,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: AppComponentMetrics.buttonIconSize),
              const SizedBox(width: AppSpacing.buttonIconGap),
            ],
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// 테두리 버튼: 계속 달리기·자세히 보기.
class OutlineButton extends StatelessWidget {
  const OutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.height = AppComponentMetrics.whiteButtonMediumHeight,
    this.borderColor = AppColors.borderDefault,
    this.horizontalPadding = AppSpacing.space4,
  });

  final String label;
  final Widget? leading;
  final VoidCallback? onPressed;
  final double height;
  final Color borderColor;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: borderColor),
          shape: const StadiumBorder(),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppSpacing.buttonIconGap),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 러닝 종료: 흰 테두리 + 정지 사각형, 폭 120.
class EndRunButton extends StatelessWidget {
  const EndRunButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppComponentMetrics.runningEndButtonWidth,
      child: OutlineButton(
        label: '러닝 종료',
        height: AppComponentMetrics.runningCardButtonHeight,
        borderColor: AppColors.textPrimary,
        horizontalPadding: AppSpacing.space3,
        leading: Container(width: 10, height: 10, color: AppColors.textPrimary),
        onPressed: onPressed,
      ),
    );
  }
}

class _OrangeButton extends StatelessWidget {
  const _OrangeButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppComponentMetrics.runningCardButtonHeight,
      child: FilledButton(
        onPressed: onPressed,
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed)
                ? AppColors.primaryPressed
                : AppColors.primary,
          ),
          foregroundColor: const WidgetStatePropertyAll(Colors.black),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.play_arrow_rounded,
              size: AppComponentMetrics.buttonIconSize,
            ),
            const SizedBox(width: AppSpacing.buttonIconGap),
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

enum _RouteMarkerKind { start, finish, pause }

/// 출발(재생)·도착(정지)·일시정지 마커: 흰 원 + 검정 기호.
class RouteMarker extends StatelessWidget {
  const RouteMarker.start({super.key}) : _kind = _RouteMarkerKind.start;
  const RouteMarker.finish({super.key}) : _kind = _RouteMarkerKind.finish;
  const RouteMarker.pause({super.key}) : _kind = _RouteMarkerKind.pause;

  final _RouteMarkerKind _kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppComponentMetrics.startMarkerLarge,
      height: AppComponentMetrics.startMarkerLarge,
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 1.5),
      ),
      alignment: Alignment.center,
      child: switch (_kind) {
        _RouteMarkerKind.start => const Icon(
          Icons.play_arrow_rounded,
          size: 15,
          color: Colors.black,
        ),
        _RouteMarkerKind.finish => Container(
          width: 8,
          height: 8,
          color: Colors.black,
        ),
        _RouteMarkerKind.pause => const Icon(
          Icons.pause,
          size: 13,
          color: Colors.black,
        ),
      },
    );
  }
}

/// 지도 없이 경로 모양만 그린 썸네일.
class RouteThumbnailPainter extends CustomPainter {
  RouteThumbnailPainter(this.segments);

  final List<List<TrackPoint>> segments;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.mapLand);
    final points = [for (final s in segments) ...s];
    if (points.length < 2) return;

    final lats = points.map((p) => p.latLng.latitude);
    final lngs = points.map((p) => p.latLng.longitude);
    final minLat = lats.reduce(math.min), maxLat = lats.reduce(math.max);
    final minLng = lngs.reduce(math.min), maxLng = lngs.reduce(math.max);
    final lngScale = math.cos(((minLat + maxLat) / 2) * math.pi / 180);
    final spanX = math.max((maxLng - minLng) * lngScale, 1e-6);
    final spanY = math.max(maxLat - minLat, 1e-6);
    const pad = 10.0;
    final scale = math.min(
      (size.width - pad * 2) / spanX,
      (size.height - pad * 2) / spanY,
    );
    final offsetX = (size.width - spanX * scale) / 2;
    final offsetY = (size.height - spanY * scale) / 2;
    Offset project(LatLng p) => Offset(
      offsetX + (p.longitude - minLng) * lngScale * scale,
      offsetY + (maxLat - p.latitude) * scale,
    );

    for (final segment in segments) {
      if (segment.length < 2) continue;
      final path = Path()
        ..addPolygon([for (final p in segment) project(p.latLng)], false);
      canvas
        ..drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = Colors.black,
        )
        ..drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = AppColors.primary,
        );
    }
    canvas.drawCircle(
      project(points.first.latLng),
      3.5,
      Paint()..color = AppColors.textPrimary,
    );
  }

  @override
  bool shouldRepaint(RouteThumbnailPainter old) => true;
}
