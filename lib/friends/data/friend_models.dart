import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// 친구 찾기·목록에 보이는 다른 사람의 정보. 이름과 아이디만 담고, 이메일·나이·체중은 담지 않습니다.
@immutable
class PublicProfile {
  const PublicProfile({
    required this.uid,
    required this.name,
    required this.id,
  });
  final String uid, name, id;

  /// 아바타에 쓰는 이름 첫 글자.
  String get initial =>
      name.isEmpty ? '러' : String.fromCharCode(name.runes.first);

  @override
  bool operator ==(Object other) =>
      other is PublicProfile &&
      other.uid == uid &&
      other.name == name &&
      other.id == id;

  @override
  int get hashCode => Object.hash(uid, name, id);
}

/// 나와 다른 사람의 관계. 친구 찾기 결과의 버튼 모양을 정합니다.
enum FriendRelation { me, friend, requested, incoming, none }

/// 이름 일부나 아이디 앞부분으로 찾을 수 있게 미리 만들어 두는 검색어 목록.
/// 서버는 글자 일부 검색을 못 하므로, 이름은 띄어쓰기를 뺀 모든 부분 글자(10자까지),
/// 아이디는 모든 앞부분을 넣어 둡니다. 예: '박하은' → 박, 하, 은, 박하, 하은, 박하은.
List<String> searchKeywords(String name, String id) {
  final words = <String>{};
  final plain = name.toLowerCase().replaceAll(RegExp(r'\s'), '');
  final letters = plain.runes.map(String.fromCharCode).toList();
  for (var start = 0; start < letters.length; start++) {
    for (
      var end = start + 1;
      end <= letters.length && end - start <= 10;
      end++
    ) {
      words.add(letters.sublist(start, end).join());
    }
  }
  final lowerId = id.toLowerCase();
  for (var end = 1; end <= lowerId.length; end++) {
    words.add(lowerId.substring(0, end));
  }
  return words.toList();
}

/// 친구 피드에 보여 줄 항목. 거리는 항상 보이고 나머지는 고를 수 있습니다.
@immutable
class ShareFields {
  const ShareFields({
    this.time = true,
    this.pace = true,
    this.kcal = true,
    this.food = true,
  });
  final bool time, pace, kcal, food;

  ShareFields copyWith({bool? time, bool? pace, bool? kcal, bool? food}) =>
      ShareFields(
        time: time ?? this.time,
        pace: pace ?? this.pace,
        kcal: kcal ?? this.kcal,
        food: food ?? this.food,
      );

  @override
  bool operator ==(Object other) =>
      other is ShareFields &&
      other.time == time &&
      other.pace == pace &&
      other.kcal == kcal &&
      other.food == food;

  @override
  int get hashCode => Object.hash(time, pace, kcal, food);
}

/// 기록 공유 설정. 자동 공유는 처음에 꺼져 있습니다.
@immutable
class ShareSettings {
  const ShareSettings({
    this.autoShare = false,
    this.fields = const ShareFields(),
  });
  final bool autoShare;
  final ShareFields fields;

  ShareSettings copyWith({bool? autoShare, ShareFields? fields}) =>
      ShareSettings(
        autoShare: autoShare ?? this.autoShare,
        fields: fields ?? this.fields,
      );

  @override
  bool operator ==(Object other) =>
      other is ShareSettings &&
      other.autoShare == autoShare &&
      other.fields == fields;

  @override
  int get hashCode => Object.hash(autoShare, fields);
}

/// 친구에게 공유한 러닝 한 번. 고르지 않은 항목은 null이라 서버에도 올라가지 않습니다.
/// 경로는 지도 좌표가 아닌 0~1 사이로 줄인 모양만 담아, 어디서 달렸는지 좌표로는 알 수 없습니다.
@immutable
class FeedPost {
  const FeedPost({
    required this.ownerUid,
    required this.recordId,
    required this.startedAt,
    required this.distanceKm,
    this.movingSeconds,
    this.paceSeconds,
    this.kcal,
    this.hetbahn,
    this.area,
    this.startPlace,
    this.endPlace,
    this.shape = const [],
  });
  final String ownerUid, recordId;
  final DateTime startedAt;
  final double distanceKm;
  final int? movingSeconds, paceSeconds, kcal;
  final double? hetbahn;
  final String? area, startPlace, endPlace;
  final List<(double, double)> shape;

  /// 피드 카드에 보이는 장소: 동네 이름, 없으면 출발지.
  String? get placeLabel => area ?? startPlace;
}

/// 피드 카드의 응원 세 가지.
enum CheerType {
  clap('👏', '박수'),
  fire('🔥', '불꽃'),
  muscle('💪', '근육');

  const CheerType(this.emoji, this.word);
  final String emoji, word;
}

/// 피드 카드 하나: 친구, 공유한 기록, 응원 수와 내가 보낸 응원.
@immutable
class FeedItem {
  const FeedItem({
    required this.friend,
    required this.post,
    this.counts = const {},
    this.mine = const {},
    this.cheeredBy = const [],
  });
  final PublicProfile friend;
  final FeedPost post;
  final Map<CheerType, int> counts;
  final Set<CheerType> mine;

  /// 응원을 보낸 사람 이름. 내가 공유한 기록(내 피드)에서 누가 응원했는지 보여 줍니다.
  final List<String> cheeredBy;

  String get key => '${post.ownerUid}/${post.recordId}';

  int count(CheerType type) => counts[type] ?? 0;

  /// 내 응원 하나를 켜거나 끈 결과.
  FeedItem toggled(CheerType type) {
    final on = !mine.contains(type);
    return FeedItem(
      friend: friend,
      post: post,
      counts: {...counts, type: count(type) + (on ? 1 : -1)},
      mine: on ? {...mine, type} : ({...mine}..remove(type)),
      cheeredBy: cheeredBy,
    );
  }
}

/// GPS 경로를 0~1 상자 안의 모양으로 줄입니다. 가로세로 비율은 지키고 가운데에 놓으며,
/// 점은 [maxPoints]개까지만 고르게 남깁니다. 실제 위치는 남지 않습니다.
List<(double, double)> routeShape(
  List<(double, double)> latLng, {
  int maxPoints = 100,
}) {
  if (latLng.length < 2) return const [];
  final lat0 = latLng.first.$1 * math.pi / 180;
  final points = [
    for (final (lat, lng) in latLng) (lng * math.cos(lat0), -lat),
  ];
  var minX = points.first.$1, maxX = minX;
  var minY = points.first.$2, maxY = minY;
  for (final (x, y) in points) {
    minX = math.min(minX, x);
    maxX = math.max(maxX, x);
    minY = math.min(minY, y);
    maxY = math.max(maxY, y);
  }
  final width = maxX - minX, height = maxY - minY;
  final size = math.max(width, height);
  if (size <= 0) return const [];
  final step = points.length <= maxPoints
      ? 1.0
      : (points.length - 1) / (maxPoints - 1);
  double round(double v) => (v * 1000).roundToDouble() / 1000;
  return [
    for (var i = 0.0; i.round() < points.length; i += step)
      (
        round((points[i.round()].$1 - minX + (size - width) / 2) / size),
        round((points[i.round()].$2 - minY + (size - height) / 2) / size),
      ),
  ];
}

/// 피드 카드의 시각: 오늘 오전 7:12 / 어제 오후 9:03 / 10월 22일 오후 6:40.
String feedTimeLabel(DateTime time, DateTime now) {
  final day = DateTime(time.year, time.month, time.day);
  final today = DateTime(now.year, now.month, now.day);
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final clock =
      '${time.hour < 12 ? '오전' : '오후'} $hour:${time.minute.toString().padLeft(2, '0')}';
  return switch (today.difference(day).inDays) {
    0 => '오늘 $clock',
    1 => '어제 $clock',
    _ => '${time.month}월 ${time.day}일 $clock',
  };
}

/// 이번 주 목표 거리. [public]이면 친구 목표 비교에 내 달성률이 보입니다.
@immutable
class WeeklyGoal {
  const WeeklyGoal({required this.km, this.public = true});
  final int km;
  final bool public;

  static const minKm = 1, maxKm = 100;

  @override
  bool operator ==(Object other) =>
      other is WeeklyGoal && other.km == km && other.public == public;

  @override
  int get hashCode => Object.hash(km, public);
}

/// 친구 랭킹·목표 비교에 쓰는 합계. 기록 하나하나가 아닌 이번 주·이번 달 합계만 담습니다.
/// 주는 월요일부터, 기간은 그 사람 폰의 날짜 기준입니다.
@immutable
class RunStats {
  const RunStats({
    required this.weekStart,
    required this.monthKey,
    this.weekKm = 0,
    this.weekRuns = 0,
    this.monthKm = 0,
    this.goalKm,
  });

  /// 이번 주 월요일(예: 2026-10-26)과 이번 달(예: 2026-10).
  final String weekStart, monthKey;
  final double weekKm, monthKm;
  final int weekRuns;

  /// 친구에게 공개한 이번 주 목표. 공개하지 않았으면 null.
  final int? goalKm;

  /// 폰에 있는 기록으로 [now]가 속한 주·달의 합계를 냅니다.
  factory RunStats.from(
    Iterable<(DateTime, double)> runs,
    DateTime now, {
    int? goalKm,
  }) {
    final week = weekOf(now), month = DateTime(now.year, now.month);
    var weekKm = 0.0, monthKm = 0.0, weekRuns = 0;
    for (final (startedAt, km) in runs) {
      if (!startedAt.isBefore(week) &&
          startedAt.isBefore(week.add(const Duration(days: 7)))) {
        weekKm += km;
        weekRuns++;
      }
      if (startedAt.year == month.year && startedAt.month == month.month) {
        monthKm += km;
      }
    }
    double round(double v) => (v * 100).round() / 100;
    return RunStats(
      weekStart: dayKey(week),
      monthKey: monthKeyOf(now),
      weekKm: round(weekKm),
      weekRuns: weekRuns,
      monthKm: round(monthKm),
      goalKm: goalKm,
    );
  }

  /// [now]가 속한 주의 값. 지난주에 올린 합계면 0으로 봅니다.
  double weekKmAt(DateTime now) =>
      weekStart == dayKey(weekOf(now)) ? weekKm : 0;
  int weekRunsAt(DateTime now) =>
      weekStart == dayKey(weekOf(now)) ? weekRuns : 0;
  double monthKmAt(DateTime now) => monthKey == monthKeyOf(now) ? monthKm : 0;

  @override
  bool operator ==(Object other) =>
      other is RunStats &&
      other.weekStart == weekStart &&
      other.monthKey == monthKey &&
      other.weekKm == weekKm &&
      other.weekRuns == weekRuns &&
      other.monthKm == monthKm &&
      other.goalKm == goalKm;

  @override
  int get hashCode =>
      Object.hash(weekStart, monthKey, weekKm, weekRuns, monthKm, goalKm);
}

/// [time]이 속한 주의 월요일 0시.
DateTime weekOf(DateTime time) {
  final day = DateTime(time.year, time.month, time.day);
  return day.subtract(Duration(days: day.weekday - 1));
}

String dayKey(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

String monthKeyOf(DateTime time) =>
    '${time.year}-${time.month.toString().padLeft(2, '0')}';

/// 함께 달리기 약속에서 한 사람의 답.
enum TogetherStatus { pending, accepted, declined }

/// 함께 달리기에서 한 사람이 달린 결과. 각자 끝낸 뒤 자기 것만 올립니다.
@immutable
class TogetherResult {
  const TogetherResult({
    required this.recordId,
    required this.distanceKm,
    required this.movingSeconds,
    required this.kcal,
    required this.finishedAt,
  });
  final String recordId;
  final double distanceKm;
  final int movingSeconds, kcal;
  final DateTime finishedAt;

  /// 1 km 페이스(초). 거리가 너무 짧으면 null.
  int? get paceSeconds =>
      distanceKm < .01 ? null : (movingSeconds / distanceKm).round();
}

/// 함께 달리기 약속. 날짜·시간은 안내용이고, 대기실에서 누군가 시작을 누르면
/// 대기실에 있던 사람들이 함께 시작합니다([startedAt]).
@immutable
class Together {
  const Together({
    required this.id,
    required this.host,
    required this.members,
    required this.statuses,
    required this.startsAt,
    required this.goalKm,
    this.createdAt,
    this.ready = const {},
    this.startedAt,
    this.results = const {},
  });
  final String id, host;

  /// 보낸 사람을 포함한 참여자 uid.
  final List<String> members;
  final Map<String, TogetherStatus> statuses;

  /// 약속한 날짜·시간. '지금 바로 같이 뛰기'는 만든 시각입니다.
  final DateTime startsAt;

  /// 목표 거리(km). 0이면 '지금 바로 같이 뛰기'로 만든, 목표 없이 자유롭게 달리는 약속입니다.
  final int goalKm;
  final DateTime? createdAt;

  /// 대기실에 들어와 있는 사람 → 마지막으로 알린 시각.
  final Map<String, DateTime> ready;

  /// 함께 시작한 시각. 아직 시작 전이면 null.
  final DateTime? startedAt;
  final Map<String, TogetherResult> results;

  /// 약속 시간이 이만큼 지나면 지난 약속으로 봅니다.
  static const expireAfter = Duration(hours: 3);

  /// 대기실 표시가 이보다 오래되면 나간 것으로 봅니다.
  static const readyFor = Duration(seconds: 60);

  static const kmOptions = [3, 5, 7, 10];
  static const maxMembers = 6;

  /// '지금 바로 같이 뛰기'로 만든 약속인지(목표 없음).
  bool get isQuick => goalKm == 0;

  /// 목표 5 km / 목표 없이 자유롭게
  String get goalLabel => isQuick ? '목표 없이 자유롭게' : '목표 $goalKm km';

  TogetherStatus statusOf(String uid) =>
      statuses[uid] ?? TogetherStatus.declined;

  List<String> others(String me) => [
    for (final m in members)
      if (m != me) m,
  ];

  bool isReady(String uid, DateTime now) {
    final at = ready[uid];
    return at != null && now.difference(at) < readyFor;
  }

  /// 내가 결과를 올렸거나 약속 시간이 한참 지났으면 지난 약속입니다.
  bool isPast(String me, DateTime now) =>
      results.containsKey(me) || now.isAfter(startsAt.add(expireAfter));

  /// 나 말고 수락한 사람들이 모두 수락했는지(거절한 사람은 빼고 봅니다).
  bool allAccepted(String me) =>
      others(me)
          .where((m) => statusOf(m) != TogetherStatus.declined)
          .every((m) => statusOf(m) == TogetherStatus.accepted);

  /// 함께 달린 거리와 칼로리 합계.
  double get totalKm => results.values.fold(0, (a, r) => a + r.distanceKm);
  int get totalKcal => results.values.fold(0, (a, r) => a + r.kcal);
}

/// 함께 달리는 동안 한 사람의 실시간 상태. 그 약속의 참여자만 보고, 달리기가 끝나면 지웁니다.
@immutable
class LiveRun {
  const LiveRun({
    required this.uid,
    this.distanceKm = 0,
    this.movingSeconds = 0,
    this.paused = false,
    this.position,
    this.route = const [],
    this.updatedAt,
  });
  final String uid;
  final double distanceKm;
  final int movingSeconds;

  /// 서버에 마지막으로 올린 시각. 올릴 때마다 바뀌므로 새 소식인지 알 수 있습니다.
  final DateTime? updatedAt;

  /// 직접 멈췄거나 자동 일시정지 중인지.
  final bool paused;

  /// 마지막 위치(위도, 경도). GPS를 아직 못 잡았으면 null.
  final (double, double)? position;

  /// 지나간 길(위도, 경도). 15m쯤 움직일 때마다 점이 하나씩 늘어납니다.
  final List<(double, double)> route;

  /// 1 km 페이스(초). 거리가 너무 짧으면 null.
  int? get paceSeconds =>
      distanceKm < .01 ? null : (movingSeconds / distanceKm).round();
}

/// 약속 시각: 오늘 오전 7:00 / 내일 오후 8:00 / 10월 28일 오후 9:00.
String togetherTimeLabel(DateTime time, DateTime now) {
  final day = DateTime(time.year, time.month, time.day);
  final today = DateTime(now.year, now.month, now.day);
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final clock =
      '${time.hour < 12 ? '오전' : '오후'} $hour:${time.minute.toString().padLeft(2, '0')}';
  return switch (day.difference(today).inDays) {
    0 => '오늘 $clock',
    1 => '내일 $clock',
    _ => '${time.month}월 ${time.day}일 $clock',
  };
}

/// 요일 한 글자.
String weekdayLetter(DateTime day) =>
    const ['월', '화', '수', '목', '금', '토', '일'][day.weekday - 1];

/// 받은 시각: 방금 전 / 12분 전 / 2시간 전 / 3일 전.
String agoLabel(DateTime time, DateTime now) {
  final d = now.difference(time);
  if (d.inMinutes < 1) return '방금 전';
  if (d.inHours < 1) return '${d.inMinutes}분 전';
  if (d.inDays < 1) return '${d.inHours}시간 전';
  return '${d.inDays}일 전';
}
