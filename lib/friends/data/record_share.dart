import 'package:flutter/foundation.dart';

import '../../record/models/running_record.dart';
import 'friend_store.dart';
import 'friend_models.dart';

export 'friend_models.dart' show ShareFields, ShareSettings;

/// 내 러닝 기록을 친구 피드에 올리고 내리는 일. 공유한 기록과 설정은 서버에만 둡니다.
class RecordShare extends ChangeNotifier {
  RecordShare({FriendBackend? backend, PublicProfile? Function()? me})
    : _backend = backend,
      _me = me ?? FriendStore.loggedIn;

  /// 앱 전체가 쓰는 공유 담당. 테스트에서만 교체합니다.
  static RecordShare instance = RecordShare();

  final FriendBackend? _backend;
  final PublicProfile? Function() _me;

  FriendBackend get backend => _backend ?? FriendStore.instance.backend;

  String? _owner;
  ShareSettings? _settings;
  Set<String> _shared = {};

  /// 로그인한 계정의 공개 정보. 로그아웃 상태면 null.
  PublicProfile? get me => _me();

  /// 이번 실행에서 공유한 것으로 알고 있는 기록인지.
  bool isShared(String recordId) => _shared.contains(recordId);

  PublicProfile _require() {
    final me = _me();
    if (me == null) throw const FriendException('로그인이 필요해요');
    if (me.uid != _owner) {
      _owner = me.uid;
      _settings = null;
      _shared = {};
    }
    return me;
  }

  /// 공유 설정. 한 번 읽으면 이번 실행 동안 기억합니다.
  Future<ShareSettings> settings() async {
    final me = _require();
    return _settings ??= await backend.readShareSettings(me.uid);
  }

  Future<void> saveSettings(ShareSettings value) async {
    final me = _require();
    await backend.writeShareSettings(me.uid, value);
    _settings = value;
    notifyListeners();
  }

  /// [since] 이후 기록 중 공유한 것을 서버에서 다시 읽습니다.
  Future<Set<String>> loadShared(DateTime since) async {
    final me = _require();
    final ids = await backend.sharedIds(me.uid, since);
    _shared = {..._shared.where((id) => !ids.contains(id)), ...ids};
    notifyListeners();
    return ids;
  }

  /// 기록을 친구 피드에 올립니다. [fields]를 주면 다음 공유에도 그 항목을 쓰도록 설정에 남깁니다.
  Future<void> share(RunningRecord record, {ShareFields? fields}) async {
    final me = _require();
    final current = await settings();
    final chosen = fields ?? current.fields;
    await backend.publishPost(postFor(me.uid, record, chosen));
    _shared = {..._shared, record.id};
    notifyListeners();
    if (chosen != current.fields) {
      try {
        await saveSettings(current.copyWith(fields: chosen));
      } on FriendException {
        // 공유는 끝났습니다. 고른 항목은 다음에 다시 고르면 됩니다.
      }
    }
  }

  Future<void> unshare(String recordId) async {
    final me = _require();
    await backend.deletePost(me.uid, recordId);
    _shared = {..._shared}..remove(recordId);
    notifyListeners();
  }

  /// 러닝을 저장한 뒤 부릅니다. 자동 공유가 켜져 있을 때만 올리고, 실패해도 조용히 넘어갑니다
  /// (기록 공개 설정에서 다시 올릴 수 있습니다).
  Future<void> shareIfAuto(RunningRecord record) async {
    if (_me() == null) return;
    try {
      if ((await settings()).autoShare) await share(record);
    } on FriendException {
      // 러닝 저장은 이미 끝났습니다.
    }
  }

  /// 기록을 지울 때 부릅니다. 공유한 적이 없거나 로그아웃 상태면 아무 일도 하지 않습니다.
  Future<void> recordDeleted(String recordId) async {
    if (_me() == null) return;
    try {
      await unshare(recordId);
    } on FriendException {
      // 기록 삭제는 이미 끝났습니다.
    }
  }
}

/// 친구에게 보낼 기록 요약. 고르지 않은 항목과 정확한 좌표는 담지 않습니다.
FeedPost postFor(String uid, RunningRecord record, ShareFields fields) {
  String? known(String place) => place == unknownPlace ? null : place;
  return FeedPost(
    ownerUid: uid,
    recordId: record.id,
    startedAt: record.startedAt,
    distanceKm: (record.distanceKm * 100).round() / 100,
    movingSeconds: fields.time ? record.movingSeconds : null,
    paceSeconds: fields.pace && record.distanceKm >= .01
        ? record.paceSeconds
        : null,
    kcal: fields.kcal ? record.energyKcal.round() : null,
    hetbahn: fields.food ? (record.hetbahnCount * 10).round() / 10 : null,
    area: known(record.place),
    startPlace: known(record.startPlace),
    endPlace: known(record.endPlace),
    shape: routeShape([
      for (final p in record.route) (p.latitude, p.longitude),
    ]),
  );
}
