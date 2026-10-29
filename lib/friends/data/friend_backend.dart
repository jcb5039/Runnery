import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'friend_models.dart';

/// 친구 작업이 서버에서 실패했을 때. [message]는 화면에 그대로 보여 줍니다.
class FriendException implements Exception {
  const FriendException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 친구 서버와 주고받는 부분. 앱은 Firestore 구현을 쓰고, 테스트는 가짜로 바꿔 씁니다.
///
/// 서버 구조:
/// - `profiles/{uid}`: 친구 찾기용 공개 정보(이름·아이디·검색어). 인증을 마친 사람은 누구나 읽습니다.
/// - `friendRequests/{보낸 uid}_{받는 uid}`: 친구 요청. 보낸 사람과 받는 사람만 봅니다.
/// - `users/{uid}/friends/{친구 uid}`: 친구 목록. 수락할 때 양쪽에 함께 적고, 삭제할 때 함께 지웁니다.
abstract class FriendBackend {
  /// 내 공개 정보를 올립니다(이름·아이디가 바뀌면 덮어씁니다).
  Future<void> publishProfile(PublicProfile me);

  /// 이름 일부나 아이디 앞부분으로 찾습니다. [query]는 소문자로 바꾼 검색어입니다.
  Future<List<PublicProfile>> search(String query);

  /// 여러 사람의 공개 정보. 서버에 없는 사람은 빠집니다.
  Future<Map<String, PublicProfile>> profiles(List<String> uids);

  /// 내 친구들의 uid.
  Future<List<String>> friendIds(String uid);

  /// 나에게 친구 요청을 보낸 사람들의 uid.
  Future<List<String>> incoming(String uid);

  /// 내가 친구 요청을 보낸 사람들의 uid.
  Future<List<String>> outgoing(String uid);

  Future<void> sendRequest(String from, String to);
  Future<void> cancelRequest(String from, String to);

  /// [from]이 보낸 요청을 받아 친구가 됩니다. [alsoMine]이면 내가 [from]에게 보낸 요청도 지웁니다.
  Future<void> accept(String me, String from, {bool alsoMine = false});
  Future<void> decline(String me, String from);

  /// 양쪽 친구 목록에서 서로를 지웁니다. 상대에게 알림은 가지 않습니다.
  Future<void> removeFriend(String me, String friend);

  /// 내 기록 공유 설정. 저장한 적이 없으면 기본값(자동 공유 꺼짐, 모든 항목 보임).
  Future<ShareSettings> readShareSettings(String uid);
  Future<void> writeShareSettings(String uid, ShareSettings settings);

  /// 친구 피드에 기록을 올립니다. 같은 기록을 다시 올리면 덮어씁니다.
  Future<void> publishPost(FeedPost post);

  /// 공유를 취소합니다. 그 기록에 받은 응원도 함께 지웁니다.
  Future<void> deletePost(String uid, String recordId);

  /// [since] 이후에 시작한 기록 중 내가 공유한 기록 번호.
  Future<Set<String>> sharedIds(String uid, DateTime since);

  /// 한 사람이 공유한 기록. 최근에 달린 순서입니다.
  Future<List<FeedPost>> posts(String ownerUid, {int limit = 10});

  /// 기록 하나에 받은 응원. 응원한 사람의 uid → 보낸 응원.
  Future<Map<String, Set<CheerType>>> cheers(String ownerUid, String recordId);

  /// 내 응원을 바꿉니다. [types]가 비어 있으면 내 응원을 지웁니다.
  Future<void> setCheer(
    String ownerUid,
    String recordId,
    String me,
    Set<CheerType> types,
  );

  /// 내 주간 목표. 정한 적이 없으면 null. 나만 봅니다.
  Future<WeeklyGoal?> readGoal(String uid);
  Future<void> writeGoal(String uid, WeeklyGoal goal);

  /// 랭킹·목표 비교용 합계를 올립니다. 친구만 읽습니다.
  Future<void> publishStats(String uid, RunStats stats);

  /// 여러 사람의 합계. 올린 적이 없는 사람은 빠집니다.
  Future<Map<String, RunStats>> stats(List<String> uids);

  /// 내가 참여한 함께 달리기 약속들.
  Future<List<Together>> togethers(String uid);

  /// 약속을 만들고 번호를 돌려줍니다. 보낸 사람은 수락, 나머지는 대기 상태로 만듭니다.
  Future<String> createTogether({
    required String host,
    required List<String> members,
    required DateTime startsAt,
    required int goalKm,
  });

  /// 약속 하나를 계속 지켜봅니다(대기실). 약속이 지워지면 null이 옵니다.
  Stream<Together?> watchTogether(String id);

  Future<void> setTogetherStatus(String id, String uid, TogetherStatus status);

  /// 대기실에 들어와 있다고 알리거나([ready]가 true), 나갔다고 알립니다.
  Future<void> setTogetherReady(String id, String uid, {required bool ready});

  /// 함께 시작합니다. 이미 누가 시작했으면 그대로 둡니다.
  Future<void> startTogether(String id);

  Future<void> submitTogetherResult(String id, String uid, TogetherResult r);

  /// 보낸 사람이 약속을 취소합니다.
  Future<void> deleteTogether(String id);
}

/// Firestore를 쓰는 실제 구현.
class FirebaseFriendBackend implements FriendBackend {
  static const _timeout = Duration(seconds: 15);

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _profile(String uid) =>
      _db.collection('profiles').doc(uid);

  DocumentReference<Map<String, dynamic>> _request(String from, String to) =>
      _db.collection('friendRequests').doc('${from}_$to');

  CollectionReference<Map<String, dynamic>> _friends(String uid) =>
      _db.collection('users').doc(uid).collection('friends');

  CollectionReference<Map<String, dynamic>> _posts(String uid) =>
      _db.collection('users').doc(uid).collection('posts');

  DocumentReference<Map<String, dynamic>> _shareSettings(String uid) =>
      _db.collection('users').doc(uid).collection('settings').doc('share');

  DocumentReference<Map<String, dynamic>> _goal(String uid) =>
      _db.collection('users').doc(uid).collection('settings').doc('goal');

  CollectionReference<Map<String, dynamic>> get _togethers =>
      _db.collection('together');

  DocumentReference<Map<String, dynamic>> _stats(String uid) =>
      _db.collection('users').doc(uid).collection('stats').doc('summary');

  /// 서버 오류를 화면에 보여 줄 한국어 안내로 바꿉니다.
  static FriendException _error(Object e, String fallback) {
    if (e is FriendException) return e;
    if (e is TimeoutException) {
      return const FriendException('인터넷 연결을 확인해주세요');
    }
    final code = e is FirebaseException ? e.code : '';
    return FriendException(switch (code) {
      'unavailable' || 'deadline-exceeded' => '인터넷 연결을 확인해주세요',
      'permission-denied' => '권한이 없어요. 잠시 후 다시 시도해주세요',
      _ => fallback,
    });
  }

  Future<T> _run<T>(Future<T> Function() task, String fallback) async {
    try {
      return await task().timeout(_timeout);
    } catch (e) {
      throw _error(e, fallback);
    }
  }

  static PublicProfile? _toProfile(String uid, Map<String, dynamic>? data) {
    final name = data?['name'], id = data?['id'];
    if (name is! String || id is! String) return null;
    return PublicProfile(uid: uid, name: name, id: id);
  }

  @override
  Future<void> publishProfile(PublicProfile me) => _run(
    () => _profile(me.uid).set({
      'name': me.name,
      'id': me.id,
      'keywords': searchKeywords(me.name, me.id),
    }),
    '친구 정보를 올리지 못했어요',
  );

  @override
  Future<List<PublicProfile>> search(String query) => _run(() async {
    final snapshot = await _db
        .collection('profiles')
        .where('keywords', arrayContains: query)
        .limit(20)
        .get();
    return [for (final doc in snapshot.docs) ?_toProfile(doc.id, doc.data())];
  }, '찾지 못했어요. 다시 시도해주세요');

  @override
  Future<Map<String, PublicProfile>> profiles(List<String> uids) => _run(
    () async {
      final docs = await Future.wait(uids.map((uid) => _profile(uid).get()));
      return {for (final doc in docs) doc.id: ?_toProfile(doc.id, doc.data())};
    },
    '친구 정보를 불러오지 못했어요',
  );

  @override
  Future<List<String>> friendIds(String uid) => _run(() async {
    final snapshot = await _friends(uid).get();
    return [for (final doc in snapshot.docs) doc.id];
  }, '친구 목록을 불러오지 못했어요');

  Future<List<String>> _requests(String field, String uid, String other) =>
      _run(() async {
        final snapshot = await _db
            .collection('friendRequests')
            .where(field, isEqualTo: uid)
            .get();
        return [
          for (final doc in snapshot.docs)
            if (doc.data()[other] case final String id) id,
        ];
      }, '친구 요청을 불러오지 못했어요');

  @override
  Future<List<String>> incoming(String uid) => _requests('to', uid, 'from');

  @override
  Future<List<String>> outgoing(String uid) => _requests('from', uid, 'to');

  @override
  Future<void> sendRequest(String from, String to) => _run(
    () => _request(
      from,
      to,
    ).set({'from': from, 'to': to, 'createdAt': FieldValue.serverTimestamp()}),
    '친구 요청을 보내지 못했어요',
  );

  @override
  Future<void> cancelRequest(String from, String to) =>
      _run(() => _request(from, to).delete(), '요청을 취소하지 못했어요');

  @override
  Future<void> accept(String me, String from, {bool alsoMine = false}) =>
      _run(() {
        final batch = _db.batch()
          ..set(_friends(me).doc(from), {'since': FieldValue.serverTimestamp()})
          ..set(_friends(from).doc(me), {'since': FieldValue.serverTimestamp()})
          ..delete(_request(from, me));
        if (alsoMine) batch.delete(_request(me, from));
        return batch.commit();
      }, '수락하지 못했어요. 다시 시도해주세요');

  @override
  Future<void> decline(String me, String from) =>
      _run(() => _request(from, me).delete(), '거절하지 못했어요. 다시 시도해주세요');

  @override
  Future<void> removeFriend(String me, String friend) => _run(
    () =>
        (_db.batch()
              ..delete(_friends(me).doc(friend))
              ..delete(_friends(friend).doc(me)))
            .commit(),
    '삭제하지 못했어요. 다시 시도해주세요',
  );

  @override
  Future<ShareSettings> readShareSettings(String uid) => _run(() async {
    final data = (await _shareSettings(uid).get()).data();
    if (data == null) return const ShareSettings();
    bool flag(String key, bool fallback) =>
        data[key] is bool ? data[key] as bool : fallback;
    return ShareSettings(
      autoShare: flag('autoShare', false),
      fields: ShareFields(
        time: flag('showTime', true),
        pace: flag('showPace', true),
        kcal: flag('showKcal', true),
        food: flag('showFood', true),
      ),
    );
  }, '공유 설정을 불러오지 못했어요');

  @override
  Future<void> writeShareSettings(String uid, ShareSettings settings) => _run(
    () => _shareSettings(uid).set({
      'autoShare': settings.autoShare,
      'showTime': settings.fields.time,
      'showPace': settings.fields.pace,
      'showKcal': settings.fields.kcal,
      'showFood': settings.fields.food,
    }),
    '공유 설정을 저장하지 못했어요',
  );

  @override
  Future<void> publishPost(FeedPost post) => _run(
    () => _posts(post.ownerUid).doc(post.recordId).set({
      'startedAt': Timestamp.fromDate(post.startedAt),
      'distanceKm': post.distanceKm,
      'movingSeconds': ?post.movingSeconds,
      'paceSeconds': ?post.paceSeconds,
      'kcal': ?post.kcal,
      'hetbahn': ?post.hetbahn,
      'area': ?post.area,
      'startPlace': ?post.startPlace,
      'endPlace': ?post.endPlace,
      // 0~1 사이 모양을 0~1000 정수로 펼쳐 담습니다(x, y, x, y, …).
      'shape': [
        for (final (x, y) in post.shape) ...[
          (x * 1000).round(),
          (y * 1000).round(),
        ],
      ],
      'sharedAt': FieldValue.serverTimestamp(),
    }),
    '친구에게 공유하지 못했어요',
  );

  @override
  Future<void> deletePost(String uid, String recordId) => _run(() async {
    final post = _posts(uid).doc(recordId);
    final cheers = await post.collection('cheers').get();
    final batch = _db.batch();
    for (final doc in cheers.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(post);
    await batch.commit();
  }, '공유를 취소하지 못했어요');

  @override
  Future<Set<String>> sharedIds(String uid, DateTime since) => _run(() async {
    final snapshot = await _posts(uid)
        .where('startedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .get();
    return {for (final doc in snapshot.docs) doc.id};
  }, '공유한 기록을 불러오지 못했어요');

  static FeedPost? _toPost(String owner, String id, Map<String, dynamic> d) {
    final startedAt = d['startedAt'], distance = d['distanceKm'];
    if (startedAt is! Timestamp || distance is! num) return null;
    int? whole(String key) => (d[key] as num?)?.toInt();
    String? text(String key) => d[key] is String ? d[key] as String : null;
    final flat = [
      for (final v in d['shape'] as List? ?? const []) (v as num) / 1000,
    ];
    return FeedPost(
      ownerUid: owner,
      recordId: id,
      startedAt: startedAt.toDate(),
      distanceKm: distance.toDouble(),
      movingSeconds: whole('movingSeconds'),
      paceSeconds: whole('paceSeconds'),
      kcal: whole('kcal'),
      hetbahn: (d['hetbahn'] as num?)?.toDouble(),
      area: text('area'),
      startPlace: text('startPlace'),
      endPlace: text('endPlace'),
      shape: [
        for (var i = 0; i + 1 < flat.length; i += 2) (flat[i], flat[i + 1]),
      ],
    );
  }

  @override
  Future<List<FeedPost>> posts(String ownerUid, {int limit = 10}) => _run(
    () async {
      final snapshot = await _posts(ownerUid)
          .orderBy('startedAt', descending: true)
          .limit(limit)
          .get();
      return [
        for (final doc in snapshot.docs) ?_toPost(ownerUid, doc.id, doc.data()),
      ];
    },
    '친구 기록을 불러오지 못했어요',
  );

  @override
  Future<Map<String, Set<CheerType>>> cheers(
    String ownerUid,
    String recordId,
  ) => _run(() async {
    final snapshot = await _posts(ownerUid)
        .doc(recordId)
        .collection('cheers')
        .get();
    return {
      for (final doc in snapshot.docs)
        doc.id: {
          for (final type in CheerType.values)
            if (doc.data()[type.name] == true) type,
        },
    };
  }, '응원을 불러오지 못했어요');

  @override
  Future<void> setCheer(
    String ownerUid,
    String recordId,
    String me,
    Set<CheerType> types,
  ) => _run(() {
    final doc = _posts(ownerUid).doc(recordId).collection('cheers').doc(me);
    if (types.isEmpty) return doc.delete();
    return doc.set({
      for (final type in CheerType.values) type.name: types.contains(type),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }, '응원을 보내지 못했어요');

  @override
  Future<WeeklyGoal?> readGoal(String uid) => _run(() async {
    final data = (await _goal(uid).get()).data();
    final km = data?['km'];
    if (km is! num) return null;
    return WeeklyGoal(km: km.toInt(), public: data?['public'] != false);
  }, '목표를 불러오지 못했어요');

  @override
  Future<void> writeGoal(String uid, WeeklyGoal goal) => _run(
    () => _goal(uid).set({'km': goal.km, 'public': goal.public}),
    '목표를 저장하지 못했어요',
  );

  @override
  Future<void> publishStats(String uid, RunStats stats) => _run(
    () => _stats(uid).set({
      'weekStart': stats.weekStart,
      'weekKm': stats.weekKm,
      'weekRuns': stats.weekRuns,
      'monthKey': stats.monthKey,
      'monthKm': stats.monthKm,
      'goalKm': ?stats.goalKm,
      'updatedAt': FieldValue.serverTimestamp(),
    }),
    '랭킹 정보를 올리지 못했어요',
  );

  static RunStats? _toStats(Map<String, dynamic>? d) {
    final week = d?['weekStart'], month = d?['monthKey'];
    if (week is! String || month is! String) return null;
    return RunStats(
      weekStart: week,
      monthKey: month,
      weekKm: (d?['weekKm'] as num?)?.toDouble() ?? 0,
      weekRuns: (d?['weekRuns'] as num?)?.toInt() ?? 0,
      monthKm: (d?['monthKm'] as num?)?.toDouble() ?? 0,
      goalKm: (d?['goalKm'] as num?)?.toInt(),
    );
  }

  @override
  Future<Map<String, RunStats>> stats(List<String> uids) => _run(() async {
    final docs = await Future.wait(uids.map((uid) => _stats(uid).get()));
    return {
      for (final (i, doc) in docs.indexed) uids[i]: ?_toStats(doc.data()),
    };
  }, '랭킹 정보를 불러오지 못했어요');

  static Together? _toTogether(String id, Map<String, dynamic>? d) {
    final host = d?['host'], startsAt = d?['startsAt'];
    if (d == null || host is! String || startsAt is! Timestamp) return null;
    DateTime? time(Object? v) => v is Timestamp ? v.toDate() : null;
    Map<String, dynamic> map(String key) =>
        d[key] is Map ? Map<String, dynamic>.from(d[key] as Map) : const {};
    return Together(
      id: id,
      host: host,
      members: [for (final m in d['members'] as List? ?? const []) '$m'],
      statuses: {
        for (final MapEntry(:key, :value) in map('statuses').entries)
          key: TogetherStatus.values.firstWhere(
            (s) => s.name == value,
            orElse: () => TogetherStatus.pending,
          ),
      },
      startsAt: startsAt.toDate(),
      goalKm: (d['goalKm'] as num?)?.toInt() ?? 5,
      createdAt: time(d['createdAt']),
      ready: {
        for (final MapEntry(:key, :value) in map('ready').entries)
          key: ?time(value),
      },
      startedAt: time(d['startedAt']),
      results: {
        for (final MapEntry(:key, :value) in map('results').entries)
          if (value is Map)
            key: TogetherResult(
              recordId: '${value['recordId']}',
              distanceKm: (value['distanceKm'] as num?)?.toDouble() ?? 0,
              movingSeconds: (value['movingSeconds'] as num?)?.toInt() ?? 0,
              kcal: (value['kcal'] as num?)?.toInt() ?? 0,
              finishedAt: time(value['finishedAt']) ?? startsAt.toDate(),
            ),
      },
    );
  }

  @override
  Future<List<Together>> togethers(String uid) => _run(() async {
    final snapshot = await _togethers
        .where('members', arrayContains: uid)
        .get();
    return [for (final doc in snapshot.docs) ?_toTogether(doc.id, doc.data())];
  }, '함께 달리기 약속을 불러오지 못했어요');

  @override
  Future<String> createTogether({
    required String host,
    required List<String> members,
    required DateTime startsAt,
    required int goalKm,
  }) => _run(() async {
    final doc = _togethers.doc();
    await doc.set({
      'host': host,
      'members': members,
      'statuses': {
        for (final m in members)
          m: m == host
              ? TogetherStatus.accepted.name
              : TogetherStatus.pending.name,
      },
      'startsAt': Timestamp.fromDate(startsAt),
      'goalKm': goalKm,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }, '약속을 보내지 못했어요');

  @override
  Stream<Together?> watchTogether(String id) => _togethers
      .doc(id)
      .snapshots()
      .map((doc) => _toTogether(doc.id, doc.data()));

  @override
  Future<void> setTogetherStatus(
    String id,
    String uid,
    TogetherStatus status,
  ) => _run(
    () => _togethers.doc(id).update({'statuses.$uid': status.name}),
    '답하지 못했어요. 다시 시도해주세요',
  );

  @override
  Future<void> setTogetherReady(String id, String uid, {required bool ready}) =>
      _run(
        () => _togethers.doc(id).update({
          'ready.$uid': ready
              ? FieldValue.serverTimestamp()
              : FieldValue.delete(),
        }),
        '대기실에 들어가지 못했어요',
      );

  @override
  Future<void> startTogether(String id) => _run(
    () => _db.runTransaction((transaction) async {
      final doc = _togethers.doc(id);
      final current = await transaction.get(doc);
      if (current.data()?['startedAt'] != null) return;
      transaction.update(doc, {'startedAt': FieldValue.serverTimestamp()});
    }),
    '시작하지 못했어요. 다시 시도해주세요',
  );

  @override
  Future<void> submitTogetherResult(String id, String uid, TogetherResult r) =>
      _run(
        () => _togethers.doc(id).update({
          'results.$uid': {
            'recordId': r.recordId,
            'distanceKm': r.distanceKm,
            'movingSeconds': r.movingSeconds,
            'kcal': r.kcal,
            'finishedAt': Timestamp.fromDate(r.finishedAt),
          },
        }),
        '함께 달린 기록을 올리지 못했어요',
      );

  @override
  Future<void> deleteTogether(String id) =>
      _run(() => _togethers.doc(id).delete(), '약속을 취소하지 못했어요');
}
