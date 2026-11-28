import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'crew_models.dart';
import 'friend_backend.dart' show FirebaseFriendBackend, FriendException;
import 'friend_models.dart' show LiveRun, PublicProfile, TogetherResult;

/// 크루 서버와 주고받는 부분. 앱은 Firestore 구현을 쓰고, 테스트는 가짜로 바꿔 씁니다.
///
/// 서버 구조:
/// - `crews/{번호}`: 이름, 방장, 멤버 uid 목록, 공지, 마지막 메시지 요약. 멤버만 읽습니다.
/// - `crews/{번호}/members/{uid}`: 들어온 시각, 마지막으로 읽은 시각, 알림 끄기. 멤버만 읽고 본인만 바꿉니다.
/// - `crews/{번호}/messages/{번호}`: 채팅 메시지(글자, 들어옴·나감·내보냄 안내). 멤버만 읽고 씁니다.
/// - `crews/{번호}/runs/{번호}`: 함께 달리기 모집(대기실). 멤버만 읽고, 바꾸는 건 서버 함수 `crewRun`만 합니다.
/// - `crewInvites/{크루 번호}_{받는 uid}`: 크루 초대. 보낸 사람과 받는 사람만 봅니다.
/// - `crews/{번호}.code`, `crewCodes/{코드}`: 초대 코드. 만들기·바꾸기·코드로 들어가기는 서버 함수 `crewCode`만 합니다.
/// - `crews/{번호}/runs/{모집}/routes/{uid}`: 팀 기록에 남긴 각자의 지나간 길(서버 함수만 씀, 멤버만 읽음).
/// - `crews/{번호}/banned/{uid}`: 크루장이 내보낸 사람(코드로 못 들어옴). 다시 초대받아 수락하면 지웁니다.
abstract class CrewBackend {
  /// 여러 사람의 공개 정보. 서버에 없는 사람은 빠집니다.
  Future<Map<String, PublicProfile>> profiles(List<String> uids);

  /// 내가 멤버인 크루들을 계속 지켜봅니다.
  Stream<List<Crew>> watchMyCrews(String uid);

  /// 크루 하나를 계속 지켜봅니다. 지워졌거나 내가 멤버가 아니게 되면 null이 옵니다.
  Stream<Crew?> watchCrew(String id);

  /// 크루를 만들고 번호를 돌려줍니다. 만든 사람이 방장이자 첫 멤버입니다.
  Future<String> createCrew(String owner, String name);

  /// 최근 메시지 [limit]개를 계속 지켜봅니다. 오래된 것부터입니다.
  /// [since]가 있으면 그 시각(내가 들어온 시각) 뒤의 메시지만 옵니다.
  Stream<List<CrewMessage>> watchMessages(
    String id, {
    int limit = 50,
    DateTime? since,
  });

  /// 글자 메시지를 보내고, 목록에 보일 마지막 메시지도 바꿉니다.
  Future<void> sendMessage(String id, String uid, String text);

  /// [since] 뒤에 온 메시지 수(안 읽은 메시지).
  Future<int> countSince(String id, DateTime since);

  Future<List<CrewMember>> members(String id);
  Future<CrewMember?> member(String id, String uid);

  /// 마지막으로 읽은 시각을 지금으로 바꿉니다.
  Future<void> markRead(String id, String uid);
  Future<void> setMuted(String id, String uid, {required bool muted});

  /// 방장이 공지를 씁니다. [text]가 비어 있으면 공지를 지웁니다.
  Future<void> setNotice(String id, String by, String text);

  /// 방장이 멤버를 내보냅니다.
  Future<void> kick(String id, String owner, String target);

  /// 크루를 나갑니다. 방장이면 [newOwner]에게 방장을 넘기고, 혼자였으면([newOwner]가 null) 크루를 지웁니다.
  Future<void> leave(String id, String me, {String? newOwner});

  /// 친구를 크루에 초대합니다.
  Future<void> invite(Crew crew, String from, String to);

  /// 내가 이 크루에 초대한 사람들의 uid(아직 답하지 않은 초대).
  Future<List<String>> invitedBy(String crewId, String from);

  /// 나에게 온 크루 초대를 계속 지켜봅니다.
  Stream<List<CrewInvite>> watchInvites(String uid);

  /// 초대를 받아 크루에 들어갑니다.
  Future<void> acceptInvite(CrewInvite invite);

  /// 초대를 거절합니다(초대를 지웁니다).
  Future<void> declineInvite(CrewInvite invite);

  /// 크루장이 초대 코드를 새로 만듭니다(예전 코드는 막힙니다). 새 코드를 돌려줍니다.
  Future<String> issueCode(String crewId);

  /// 초대 코드로 크루에 들어갑니다. 들어간(이미 멤버였던) 크루 번호를 돌려줍니다.
  /// 규칙에 맞지 않으면 그 이유를 담은 [FriendException]을 던집니다.
  Future<String> joinByCode(String code);

  /// 모집 하나를 계속 지켜봅니다. 없으면 null.
  Stream<CrewRun?> watchRun(String crewId, String runId);

  /// 모집 일을 서버 함수에 맡깁니다: create(title) · join · color(color) · ready(ready) · leave · start ·
  /// finish(result: 내 기록) · end(팀장의 팀 끝내기) · vote(voteEnd: 종료 투표에 종료/끝내지 않기).
  /// 모집 번호를 돌려줍니다. 규칙에 맞지 않으면 그 이유를 담은 [FriendException]을 던집니다.
  Future<String> runAction(
    String crewId,
    String action, {
    String? runId,
    String? title,
    int? color,
    bool? ready,
    TogetherResult? result,
    bool? voteEnd,
  });

  /// 같은 모집 사람들의 실시간 상태를 계속 지켜봅니다.
  Stream<List<LiveRun>> watchRunLive(String crewId, String runId);

  /// 내 실시간 상태를 올립니다(앞의 [sentPoints]개 점은 이미 올림).
  Future<void> setRunLive(
    String crewId,
    String runId,
    LiveRun run, {
    int sentPoints = 0,
  });

  /// 달리기를 끝내면 내 실시간 상태를 지웁니다.
  Future<void> deleteRunLive(String crewId, String runId, String uid);

  /// 팀 기록이 끝난 모집들(최근 것부터). 서랍의 '함께 달린 기록'.
  Future<List<CrewRun>> endedRuns(String crewId, {int limit = 30});

  /// 팀 기록에 남은 각자의 지나간 길(uid → 길). 팀이 끝나기 전이면 비어 있습니다.
  Future<Map<String, CrewRunRoute>> runRoutes(String crewId, String runId);
}

/// Firestore를 쓰는 실제 구현.
class FirebaseCrewBackend implements CrewBackend {
  static const _timeout = Duration(seconds: 15);

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _crews =>
      _db.collection('crews');

  CollectionReference<Map<String, dynamic>> _members(String id) =>
      _crews.doc(id).collection('members');

  CollectionReference<Map<String, dynamic>> _messages(String id) =>
      _crews.doc(id).collection('messages');

  DocumentReference<Map<String, dynamic>> _invite(String crewId, String to) =>
      _db.collection('crewInvites').doc('${crewId}_$to');

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

  static DateTime? _time(Object? v) => v is Timestamp ? v.toDate() : null;

  static Crew? _toCrew(String id, Map<String, dynamic>? d) {
    final name = d?['name'], owner = d?['owner'];
    if (d == null || name is! String || owner is! String) return null;
    final notice = d['notice'], last = d['lastMessage'];
    return Crew(
      id: id,
      name: name,
      owner: owner,
      members: [for (final m in d['members'] as List? ?? const []) '$m'],
      createdAt: _time(d['createdAt']),
      notice: notice is Map && notice['text'] is String
          ? CrewNotice(
              text: notice['text'] as String,
              by: '${notice['by']}',
              at: _time(notice['at']) ?? DateTime.now(),
            )
          : null,
      code: d['code'] is String ? d['code'] as String : null,
      lastMessage: last is Map && last['text'] is String
          ? CrewLastMessage(
              uid: '${last['uid']}',
              text: last['text'] as String,
              at: _time(last['at']) ?? DateTime.now(),
            )
          : null,
    );
  }

  static CrewMessage _toMessage(String id, Map<String, dynamic> d) =>
      CrewMessage(
        id: id,
        uid: '${d['uid']}',
        kind: CrewMessageKind.values.firstWhere(
          (k) => k.name == d['kind'],
          orElse: () => CrewMessageKind.text,
        ),
        // 모집 카드(run)는 제목을 글자 자리에 둡니다.
        text: d['text'] is String
            ? d['text'] as String
            : d['title'] is String
            ? d['title'] as String
            : '',
        target: d['target'] is String ? d['target'] as String : null,
        runId: d['runId'] is String ? d['runId'] as String : null,
        // 막 보낸 메시지는 서버 시각이 정해지기 전이라 비어 있습니다.
        createdAt: _time(d['createdAt']),
      );

  static CrewMember _toMember(String uid, Map<String, dynamic>? d) =>
      CrewMember(
        uid: uid,
        joinedAt:
            _time(d?['joinedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        lastReadAt: _time(d?['lastReadAt']),
        muted: d?['muted'] == true,
      );

  static CrewInvite? _toInvite(Map<String, dynamic> d) {
    final crewId = d['crewId'], name = d['crewName'];
    final from = d['from'], to = d['to'];
    if (crewId is! String || name is! String || from is! String) return null;
    if (to is! String) return null;
    return CrewInvite(
      crewId: crewId,
      crewName: name,
      from: from,
      to: to,
      createdAt: _time(d['createdAt']),
    );
  }

  @override
  Future<Map<String, PublicProfile>> profiles(List<String> uids) =>
      _run(() async {
        final docs = await Future.wait(
          uids.map((uid) => _db.collection('profiles').doc(uid).get()),
        );
        return {
          for (final doc in docs)
            if (doc.data() case {
              'name': final String name,
              'id': final String id,
            })
              doc.id: PublicProfile(uid: doc.id, name: name, id: id),
        };
      }, '멤버 정보를 불러오지 못했어요');

  @override
  Stream<List<Crew>> watchMyCrews(String uid) => _crews
      .where('members', arrayContains: uid)
      .snapshots()
      .map((s) => [for (final doc in s.docs) ?_toCrew(doc.id, doc.data())]);

  @override
  Stream<Crew?> watchCrew(String id) => _crews
      .doc(id)
      .snapshots()
      .map((doc) => _toCrew(doc.id, doc.data()))
      // 내보내져 읽을 권한이 없어지면 크루가 없는 것으로 봅니다(채팅방이 알 수 있게 null을 보냅니다).
      .transform(
        StreamTransformer<Crew?, Crew?>.fromHandlers(
          handleError: (e, stack, sink) =>
              e is FirebaseException ? sink.add(null) : sink.addError(e, stack),
        ),
      );

  @override
  Future<String> createCrew(String owner, String name) => _run(() async {
    final crew = _crews.doc();
    final batch = _db.batch()
      ..set(crew, {
        'name': name,
        'owner': owner,
        'members': [owner],
        'createdAt': FieldValue.serverTimestamp(),
      })
      ..set(_members(crew.id).doc(owner), {
        'joinedAt': FieldValue.serverTimestamp(),
        'lastReadAt': FieldValue.serverTimestamp(),
        'muted': false,
      });
    await batch.commit();
    return crew.id;
  }, '크루를 만들지 못했어요');

  @override
  Stream<List<CrewMessage>> watchMessages(
    String id, {
    int limit = 50,
    DateTime? since,
  }) =>
      (since == null
              ? _messages(id)
              : _messages(id).where(
                  'createdAt',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(since),
                ))
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots(includeMetadataChanges: false)
          .map(
            (s) => [
              for (final doc in s.docs.reversed) _toMessage(doc.id, doc.data()),
            ],
          );

  @override
  Future<void> sendMessage(String id, String uid, String text) => _run(() {
    final preview = text.length > CrewLastMessage.maxText
        ? text.substring(0, CrewLastMessage.maxText)
        : text;
    return (_db.batch()
          ..set(_messages(id).doc(), {
            'uid': uid,
            'kind': CrewMessageKind.text.name,
            'text': text,
            'createdAt': FieldValue.serverTimestamp(),
          })
          ..update(_crews.doc(id), {
            'lastMessage': {
              'uid': uid,
              'text': preview,
              'at': FieldValue.serverTimestamp(),
            },
          }))
        .commit();
  }, '메시지를 보내지 못했어요');

  @override
  Future<int> countSince(String id, DateTime since) => _run(() async {
    final result = await _messages(id)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(since))
        .count()
        .get();
    return result.count ?? 0;
  }, '메시지 수를 불러오지 못했어요');

  @override
  Future<List<CrewMember>> members(String id) => _run(() async {
    final s = await _members(id).orderBy('joinedAt').get();
    return [for (final doc in s.docs) _toMember(doc.id, doc.data())];
  }, '멤버를 불러오지 못했어요');

  @override
  Future<CrewMember?> member(String id, String uid) => _run(() async {
    final doc = await _members(id).doc(uid).get();
    return doc.exists ? _toMember(uid, doc.data()) : null;
  }, '크루 정보를 불러오지 못했어요');

  @override
  Future<void> markRead(String id, String uid) => _run(
    () =>
        _members(id)
            .doc(uid)
            .update({'lastReadAt': FieldValue.serverTimestamp()}),
    '읽음 표시를 하지 못했어요',
  );

  @override
  Future<void> setMuted(String id, String uid, {required bool muted}) => _run(
    () => _members(id).doc(uid).update({'muted': muted}),
    '알림 설정을 바꾸지 못했어요',
  );

  @override
  Future<void> setNotice(String id, String by, String text) => _run(
    () => _crews.doc(id).update({
      'notice': text.isEmpty
          ? FieldValue.delete()
          : {'text': text, 'by': by, 'at': FieldValue.serverTimestamp()},
    }),
    '공지를 저장하지 못했어요',
  );

  @override
  Future<void> kick(String id, String owner, String target) => _run(
    () =>
        (_db.batch()
              ..update(_crews.doc(id), {
                'members': FieldValue.arrayRemove([target]),
              })
              ..delete(_members(id).doc(target))
              // 코드로 다시 들어오지 못하게 적어 둡니다.
              ..set(_crews.doc(id).collection('banned').doc(target), {
                'by': owner,
                'at': FieldValue.serverTimestamp(),
              })
              ..set(_messages(id).doc(), {
                'uid': owner,
                'kind': CrewMessageKind.kick.name,
                'target': target,
                'createdAt': FieldValue.serverTimestamp(),
              }))
            .commit(),
    '내보내지 못했어요. 다시 시도해주세요',
  );

  @override
  Future<void> leave(String id, String me, {String? newOwner}) => _run(() {
    final crew = _crews.doc(id);
    final batch = _db.batch()..delete(_members(id).doc(me));
    if (newOwner == null) {
      // 혼자 남은 방장이면 크루를 지웁니다.
      batch.delete(crew);
    } else {
      batch
        ..update(crew, {
          'members': FieldValue.arrayRemove([me]),
          if (newOwner.isNotEmpty) 'owner': newOwner,
        })
        ..set(_messages(id).doc(), {
          'uid': me,
          'kind': CrewMessageKind.leave.name,
          'createdAt': FieldValue.serverTimestamp(),
        });
    }
    return batch.commit();
  }, '크루를 나가지 못했어요. 다시 시도해주세요');

  @override
  Future<void> invite(Crew crew, String from, String to) => _run(
    () => _invite(crew.id, to).set({
      'crewId': crew.id,
      'crewName': crew.name,
      'from': from,
      'to': to,
      'createdAt': FieldValue.serverTimestamp(),
    }),
    '초대하지 못했어요',
  );

  @override
  Future<List<String>> invitedBy(String crewId, String from) => _run(() async {
    final s = await _db
        .collection('crewInvites')
        .where('crewId', isEqualTo: crewId)
        .where('from', isEqualTo: from)
        .get();
    return [
      for (final doc in s.docs)
        if (doc.data()['to'] case final String to) to,
    ];
  }, '초대 목록을 불러오지 못했어요');

  @override
  Stream<List<CrewInvite>> watchInvites(String uid) => _db
      .collection('crewInvites')
      .where('to', isEqualTo: uid)
      .snapshots()
      .map((s) => [for (final doc in s.docs) ?_toInvite(doc.data())]);

  @override
  Future<void> acceptInvite(CrewInvite invite) => _run(
    () =>
        (_db.batch()
              ..update(_crews.doc(invite.crewId), {
                'members': FieldValue.arrayUnion([invite.to]),
              })
              ..set(_members(invite.crewId).doc(invite.to), {
                'joinedAt': FieldValue.serverTimestamp(),
                'lastReadAt': FieldValue.serverTimestamp(),
                'muted': false,
              })
              ..set(_messages(invite.crewId).doc(), {
                'uid': invite.to,
                'kind': CrewMessageKind.join.name,
                'createdAt': FieldValue.serverTimestamp(),
              })
              // 예전에 내보내졌어도 다시 초대받아 들어오면 코드 막힘을 풉니다.
              ..delete(
                _crews.doc(invite.crewId).collection('banned').doc(invite.to),
              )
              ..delete(_invite(invite.crewId, invite.to)))
            .commit(),
    '크루에 들어가지 못했어요. 다시 시도해주세요',
  );

  @override
  Future<void> declineInvite(CrewInvite invite) => _run(
    () => _invite(invite.crewId, invite.to).delete(),
    '거절하지 못했어요. 다시 시도해주세요',
  );

  @override
  Future<String> issueCode(String crewId) async =>
      '${(await _code({'action': 'issue', 'crewId': crewId}))['code'] ?? ''}';

  @override
  Future<String> joinByCode(String code) async =>
      '${(await _code({'action': 'join', 'code': code}))['crewId'] ?? ''}';

  Future<Map<String, dynamic>> _code(Map<String, Object> data) async {
    try {
      final response =
          await FirebaseFunctions.instanceFor(region: 'asia-northeast3')
              .httpsCallable('crewCode')
              .call<Map<String, dynamic>>(data)
              .timeout(_timeout);
      return response.data;
    } on FirebaseFunctionsException catch (e) {
      throw FriendException(e.message ?? '잠시 후 다시 시도해주세요');
    } catch (e) {
      throw _error(e, '잠시 후 다시 시도해주세요');
    }
  }

  static CrewRun? _toRun(String crewId, String id, Map<String, dynamic>? d) {
    final host = d?['host'], title = d?['title'];
    if (d == null || host is! String || title is! String) return null;
    final colors = d['colors'], ready = d['ready'];
    final results = d['results'], team = d['team'], vote = d['vote'];
    return CrewRun(
      id: id,
      crewId: crewId,
      host: host,
      title: title,
      members: [for (final m in d['members'] as List? ?? const []) '$m'],
      colors: {
        if (colors is Map)
          for (final MapEntry(:key, :value) in colors.entries)
            if (value is num) '$key': value.toInt(),
      },
      ready: {
        if (ready is Map)
          for (final MapEntry(:key, :value) in ready.entries)
            if (value == true) '$key',
      },
      status: CrewRunStatus.values.firstWhere(
        (s) => s.name == d['status'],
        orElse: () => CrewRunStatus.closed,
      ),
      createdAt: _time(d['createdAt']),
      startedAt: _time(d['startedAt']),
      endedAt: _time(d['endedAt']),
      results: {
        if (results is Map)
          for (final MapEntry(:key, :value) in results.entries)
            if (value is Map)
              '$key': TogetherResult(
                recordId: '${value['recordId'] ?? ''}',
                distanceKm: (value['distanceKm'] as num?)?.toDouble() ?? 0,
                movingSeconds: (value['movingSeconds'] as num?)?.toInt() ?? 0,
                kcal: (value['kcal'] as num?)?.toInt() ?? 0,
                finishedAt: _time(value['finishedAt']) ?? DateTime.now(),
              ),
      },
      vote: vote is Map && _time(vote['askedAt']) != null
          ? CrewRunVote(
              askedAt: _time(vote['askedAt'])!,
              end: {for (final u in vote['end'] as List? ?? const []) '$u'},
              keep: {for (final u in vote['keep'] as List? ?? const []) '$u'},
            )
          : null,
      team: {
        if (team is Map)
          for (final MapEntry(:key, :value) in team.entries)
            if (value is Map)
              '$key': CrewTeamEntry(
                distanceKm: (value['distanceKm'] as num?)?.toDouble() ?? 0,
                movingSeconds: (value['movingSeconds'] as num?)?.toInt() ?? 0,
                finished: value['finished'] == true,
              ),
      },
    );
  }

  CollectionReference<Map<String, dynamic>> _runLive(
    String crewId,
    String runId,
  ) => _crews.doc(crewId).collection('runs').doc(runId).collection('live');

  @override
  Stream<List<LiveRun>> watchRunLive(String crewId, String runId) =>
      _runLive(crewId, runId).snapshots().map(
        (s) => [
          for (final doc in s.docs)
            FirebaseFriendBackend.liveFrom(doc.id, doc.data()),
        ],
      );

  @override
  Future<void> setRunLive(
    String crewId,
    String runId,
    LiveRun run, {
    int sentPoints = 0,
  }) => _run(
    () => _runLive(crewId, runId)
        .doc(run.uid)
        .set(
          FirebaseFriendBackend.liveData(run, sentPoints),
          SetOptions(merge: true),
        ),
    '함께 달리는 정보를 올리지 못했어요',
  );

  @override
  Future<void> deleteRunLive(String crewId, String runId, String uid) => _run(
    () => _runLive(crewId, runId).doc(uid).delete(),
    '함께 달린 위치 정보를 지우지 못했어요',
  );

  @override
  Future<Map<String, CrewRunRoute>> runRoutes(String crewId, String runId) =>
      _run(() async {
        final s = await _crews
            .doc(crewId)
            .collection('runs')
            .doc(runId)
            .collection('routes')
            .get();
        return {
          for (final doc in s.docs)
            doc.id: () {
              final flat = [
                for (final v in doc.data()['points'] as List? ?? const [])
                  if (v is num) v.toDouble(),
              ];
              return CrewRunRoute(
                uid: doc.id,
                color: (doc.data()['color'] as num?)?.toInt() ?? 0,
                points: [
                  for (var i = 0; i + 1 < flat.length; i += 2)
                    (flat[i], flat[i + 1]),
                ],
              );
            }(),
        };
      }, '함께 달린 길을 불러오지 못했어요');

  @override
  Future<List<CrewRun>> endedRuns(String crewId, {int limit = 30}) =>
      _run(() async {
        // 팀이 끝난 모집에만 endedAt이 있어, 그 순서로 가져오면 끝난 모집만 옵니다.
        final s = await _crews
            .doc(crewId)
            .collection('runs')
            .orderBy('endedAt', descending: true)
            .limit(limit)
            .get();
        return [
          for (final doc in s.docs)
            if (_toRun(crewId, doc.id, doc.data()) case final run?
                when run.isEnded)
              run,
        ];
      }, '함께 달린 기록을 불러오지 못했어요');

  @override
  Stream<CrewRun?> watchRun(String crewId, String runId) => _crews
      .doc(crewId)
      .collection('runs')
      .doc(runId)
      .snapshots()
      .map((doc) => _toRun(crewId, doc.id, doc.data()));

  @override
  Future<String> runAction(
    String crewId,
    String action, {
    String? runId,
    String? title,
    int? color,
    bool? ready,
    TogetherResult? result,
    bool? voteEnd,
  }) async {
    try {
      final response =
          await FirebaseFunctions.instanceFor(region: 'asia-northeast3')
              .httpsCallable('crewRun')
              .call<Map<String, dynamic>>({
                'crewId': crewId,
                'action': action,
                'runId': ?runId,
                'title': ?title,
                'color': ?color,
                'ready': ?ready,
                'end': ?voteEnd,
                if (result != null)
                  'result': {
                    'recordId': result.recordId,
                    'distanceKm': result.distanceKm,
                    'movingSeconds': result.movingSeconds,
                    'kcal': result.kcal,
                  },
              })
              .timeout(_timeout);
      return '${response.data['runId'] ?? runId ?? ''}';
    } on FirebaseFunctionsException catch (e) {
      throw FriendException(e.message ?? '잠시 후 다시 시도해주세요');
    } catch (e) {
      throw _error(e, '잠시 후 다시 시도해주세요');
    }
  }
}
