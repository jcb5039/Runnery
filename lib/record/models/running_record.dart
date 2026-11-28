import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// 저장된 GPS 위도/경도를 그대로 전달할 수 있는 경로 모델.
@immutable
class RecordCoordinate {
  const RecordCoordinate(
    this.latitude,
    this.longitude, {
    this.timestamp,
    this.startsSegment = false,
  });
  final DateTime? timestamp;
  final bool startsSegment;
  final double latitude;
  final double longitude;
}

/// 장소 이름을 아직 찾지 못했을 때 보여 주는 문구.
const unknownPlace = '위치 정보 없음';

@immutable
class RunningRecord {
  const RunningRecord({
    required this.id,
    required this.startedAt,
    required this.distanceKm,
    required this.movingSeconds,
    required this.calories,
    required this.route,
    this.pauseSeconds = 0,
    this.finishedAt,
    this.movingMilliseconds,
    this.caloriesKcal,
    this.weightKg,
    this.speedDistancesKm = const [],
    this.place = unknownPlace,
    this.startPlace = unknownPlace,
    this.endPlace = unknownPlace,
    this.memo = '',
    this.speeds = const [],
    this.splitSeconds = const [],
    this.pauseFractions = const [],
    this.diagnostics,
    this.crewName,
  });

  /// 크루 모집으로 함께 달렸으면 그 크루 이름('○○ 크루와 함께'). 혼자 달렸으면 null.
  /// 예전 기록에는 이 값이 없습니다.
  final String? crewName;

  /// 러닝 중 GPS 진단 기록(받은·버린 위치 수, 백그라운드 전환, 위치 공백 등). 화면에는 쓰지 않습니다.
  final Map<String, dynamic>? diagnostics;
  final DateTime? finishedAt;
  final int? movingMilliseconds;
  double get _movingSeconds =>
      (movingMilliseconds ?? movingSeconds * 1000) / 1000;
  final double? caloriesKcal, weightKg;
  final List<double> speedDistancesKm;
  double get energyKcal => caloriesKcal ?? calories.toDouble();
  double get hetbahnCount => energyKcal / 315;
  final String id;
  final DateTime startedAt;
  final double distanceKm;
  final int movingSeconds, pauseSeconds, calories;
  final String place, startPlace, endPlace, memo;
  final List<RecordCoordinate> route;

  /// 시간 순서의 km/h 샘플과 1km별 초 단위 페이스. 데이터 소스 연결 지점.
  final List<double> speeds;
  final List<int> splitSeconds;

  /// 전체 경로에서 일시정지한 위치(0~1).
  final List<double> pauseFractions;
  DateTime get endedAt =>
      finishedAt ??
      startedAt.add(Duration(seconds: movingSeconds + pauseSeconds));
  int get paceSeconds =>
      distanceKm > 0 ? (_movingSeconds / distanceKm).round() : 0;
  double get averageSpeed =>
      _movingSeconds > 0 ? distanceKm / _movingSeconds * 3600 : 0;
  double get maxSpeed => speeds.isEmpty ? 0 : speeds.reduce(math.max);
  String get dateLabel =>
      '${startedAt.month}월 ${startedAt.day}일 ${const ['월', '화', '수', '목', '금', '토', '일'][startedAt.weekday - 1]}요일';
  String get durationLabel => durationWords(movingSeconds);
  String get paceLabel =>
      distanceKm < .01 || movingSeconds == 0 ? '—' : paceText(paceSeconds);

  Map<String, dynamic> toJson() => {
    'version': 1,
    'id': id,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'distanceKm': distanceKm,
    'movingSeconds': movingSeconds,
    'movingMilliseconds': movingMilliseconds,
    'pauseSeconds': pauseSeconds,
    'calories': calories,
    'caloriesKcal': energyKcal,
    'hetbahnCount': hetbahnCount,
    'weightKg': weightKg,
    'averageSpeedKmh': averageSpeed,
    'averagePaceSeconds': distanceKm < .01 ? null : paceSeconds,
    'maxSpeedKmh': speeds.isEmpty ? null : maxSpeed,
    'bestPaceSeconds': maxSpeed > 0 ? 3600 / maxSpeed : null,
    'place': place,
    'startPlace': startPlace,
    'endPlace': endPlace,
    'memo': memo,
    'speeds': speeds,
    'speedDistancesKm': speedDistancesKm,
    'splitSeconds': splitSeconds,
    'pauseFractions': pauseFractions,
    'diagnostics': ?diagnostics,
    'crewName': ?crewName,
    'route': [
      for (final p in route)
        {
          'latitude': p.latitude,
          'longitude': p.longitude,
          'timestamp': p.timestamp?.toIso8601String(),
          'startsSegment': p.startsSegment,
        },
    ],
  };

  factory RunningRecord.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported record version');
    }
    double number(dynamic value) {
      if (value is! num || !value.isFinite || value < 0) {
        throw const FormatException('Invalid record metric');
      }
      return value.toDouble();
    }

    final route = (json['route'] as List).map((value) {
      final p = value as Map<String, dynamic>;
      final lat = (p['latitude'] as num).toDouble();
      final lng = (p['longitude'] as num).toDouble();
      if (!lat.isFinite || !lng.isFinite || lat.abs() > 90 || lng.abs() > 180) {
        throw const FormatException('Invalid GPS coordinate');
      }
      return RecordCoordinate(
        lat,
        lng,
        timestamp: p['timestamp'] == null
            ? null
            : DateTime.parse(p['timestamp'] as String),
        startsSegment: p['startsSegment'] as bool? ?? false,
      );
    }).toList();
    return RunningRecord(
      id: json['id'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      finishedAt: DateTime.parse(json['endedAt'] as String),
      distanceKm: number(json['distanceKm']),
      movingSeconds: number(json['movingSeconds']).toInt(),
      movingMilliseconds: json['movingMilliseconds'] == null
          ? null
          : number(json['movingMilliseconds']).toInt(),
      pauseSeconds: number(json['pauseSeconds']).toInt(),
      calories: number(json['calories']).toInt(),
      caloriesKcal: number(json['caloriesKcal']),
      weightKg: json['weightKg'] == null ? null : number(json['weightKg']),
      route: List.unmodifiable(route),
      place: json['place'] as String,
      startPlace: json['startPlace'] as String,
      endPlace: json['endPlace'] as String,
      memo: json['memo'] as String,
      speeds: List.unmodifiable((json['speeds'] as List).map(number)),
      speedDistancesKm: List.unmodifiable(
        (json['speedDistancesKm'] as List).map(number),
      ),
      splitSeconds: List.unmodifiable(
        (json['splitSeconds'] as List).map((v) => number(v).toInt()),
      ),
      pauseFractions: List.unmodifiable(
        (json['pauseFractions'] as List).map(number),
      ),
      diagnostics: json['diagnostics'] as Map<String, dynamic>?,
      crewName: json['crewName'] is String ? json['crewName'] as String : null,
    );
  }

  /// 크루와 함께 달린 기록으로 표시합니다.
  RunningRecord withCrew(String name) =>
      RunningRecord.fromJson({...toJson(), 'crewName': name});

  RunningRecord withMemo(String value) =>
      RunningRecord.fromJson({...toJson(), 'memo': value});

  /// 찾은 장소 이름만 바꿉니다. null인 값은 그대로 둡니다.
  RunningRecord withPlaces({String? area, String? start, String? end}) =>
      RunningRecord.fromJson({
        ...toJson(),
        'place': ?area,
        'startPlace': ?start,
        'endPlace': ?end,
      });

  /// 출발·도착·동네 이름 중 아직 찾지 못한 것이 있는지.
  bool get missingPlaces =>
      place == unknownPlace ||
      startPlace == unknownPlace ||
      endPlace == unknownPlace;
}

String clockText(DateTime time) =>
    '${time.hour < 12 ? '오전' : '오후'} ${time.hour % 12 == 0 ? 12 : time.hour % 12}:${time.minute.toString().padLeft(2, '0')}';
String paceText(int seconds) =>
    "${seconds ~/ 60}'${(seconds % 60).toString().padLeft(2, '0')}\"";
String durationWords(int seconds) =>
    '${seconds >= 3600 ? '${seconds ~/ 3600}시간 ' : ''}${seconds ~/ 60 % 60}분 ${(seconds % 60).toString().padLeft(2, '0')}초';
