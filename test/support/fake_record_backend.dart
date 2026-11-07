import 'dart:async';

import 'package:runnery_new/record/data/record_backend.dart';
import 'package:runnery_new/record/models/running_record.dart';

class _Doc {
  _Doc(this.updatedAt, this.record);
  final DateTime updatedAt;

  /// 지운 기록이면 null.
  final RunningRecord? record;
}

/// 테스트용 가짜 기록 서버. 같은 인스턴스를 여러 '폰'이 나눠 쓰면 서로의 기록이 오갑니다.
class FakeRecordBackend implements RecordBackend {
  /// true면 인터넷이 없는 것처럼 모든 요청이 실패합니다.
  bool offline = false;
  int upserts = 0;

  final Map<String, Map<String, _Doc>> _docs = {};
  int _clock = 0;

  /// 서버 시각. 동기화가 변경을 겹쳐 가져오는 시간(2분)보다 넉넉히 벌려 둡니다.
  DateTime _tick() =>
      DateTime.fromMillisecondsSinceEpoch(1700000000000 + (_clock += 600000));

  Map<String, _Doc> _of(String uid) => _docs.putIfAbsent(uid, () => {});

  /// 서버에 있는(지워지지 않은) 기록.
  Map<String, RunningRecord> recordsOf(String uid) => {
    for (final e in _of(uid).entries)
      if (e.value.record != null) e.key: e.value.record!,
  };

  /// 서버에 지운 표시가 남은 기록 번호.
  Set<String> deletedOf(String uid) => {
    for (final e in _of(uid).entries)
      if (e.value.record == null) e.key,
  };

  void _check() {
    if (offline) throw TimeoutException('offline');
  }

  @override
  Future<RecordChanges> fetchChanges(String uid, {DateTime? since}) async {
    _check();
    final items = <RemoteRecord>[];
    DateTime? latest;
    final docs = _of(uid).entries.toList()
      ..sort((a, b) => a.value.updatedAt.compareTo(b.value.updatedAt));
    for (final e in docs) {
      if (since != null && !e.value.updatedAt.isAfter(since)) continue;
      latest = e.value.updatedAt;
      items.add(
        e.value.record == null
            ? RemoteRecord.deleted(e.key)
            : RemoteRecord(e.key, e.value.record),
      );
    }
    return RecordChanges(items, latest);
  }

  @override
  Future<void> upsert(
    String uid,
    RunningRecord record, {
    Duration? timeout,
  }) async {
    _check();
    upserts++;
    // 실제처럼 압축해서 보내고 풀어서 읽습니다(저장 형식이 깨지지 않는지 함께 확인).
    _of(uid)[record.id] = _Doc(
      _tick(),
      decodeRecordPayload(encodeRecordPayload(record)),
    );
  }

  @override
  Future<void> markDeleted(String uid, String id, {Duration? timeout}) async {
    _check();
    _of(uid)[id] = _Doc(_tick(), null);
  }
}
