import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/running_record.dart';
import 'record_backend.dart';

/// 동기화가 폰에 저장된 기록을 읽고 쓸 때 쓰는 통로(RunningRecordStore가 구현합니다).
abstract class LocalRecords {
  Future<List<RunningRecord>> load();

  /// 기록 하나. 폰에 없으면 null.
  Future<RunningRecord?> find(String id);

  /// 서버에서 받은 기록을 폰에 저장합니다. 이 저장은 다시 서버로 올리지 않습니다.
  Future<void> applyRemote(RunningRecord record);

  /// 다른 폰에서 지운 기록을 폰에서도 지웁니다.
  Future<void> applyRemoteDelete(String id);
}

class _Op {
  const _Op(this.kind, this.seq);

  /// 'upsert'(올리기) 또는 'delete'(지우기).
  final String kind;

  /// 같은 기록이 올라가는 사이에 또 바뀌었는지 알아보는 번호.
  final int seq;
}

/// 러닝 기록의 폰 ↔ 서버 동기화. 폰이 기준이고, 서버는 같은 계정의 다른 폰과 나누는 창고입니다.
///
/// - 기록을 저장·수정·삭제하면 '올릴 일'로 적어 두고(앱을 꺼도 남음) 서버에 올립니다.
/// - 서버의 새 변경(다른 폰이 올린 기록, 지운 표시)은 마지막으로 가져온 시각 이후만 가져옵니다.
/// - 인터넷이 없으면 올릴 일을 그대로 두고 다음에 다시 합니다.
class RecordSync {
  RecordSync({RecordBackend? backend, Future<Directory> Function()? directory})
    : _backend = backend,
      _directory = directory ?? getApplicationDocumentsDirectory;

  /// 서버 시각이 조금 어긋나도 변경을 놓치지 않게, 마지막 시각보다 조금 앞에서부터 가져옵니다.
  static const _overlap = Duration(minutes: 2);

  RecordBackend? _backend;

  /// 처음 쓸 때 실제 서버 연결을 만듭니다(테스트는 가짜를 넣어 두므로 만들지 않습니다).
  RecordBackend get backend => _backend ??= FirebaseRecordBackend();
  final Future<Directory> Function() _directory;

  String? _uid;
  DateTime? _lastPull;
  DateTime? _lastSyncAt;
  int _seq = 0;
  final Map<String, _Op> _pending = {};
  Future<void> _chain = Future.value();
  Future<void> _stateChain = Future.value();

  /// 로그인한 계정의 기록을 동기화하는 중인지.
  bool get active => _uid != null;

  Future<File> _stateFile() async =>
      File('${(await _directory()).path}/record_sync.json');

  /// [uid] 계정의 동기화를 시작합니다. 다른 계정이 쓰던 상태는 버립니다.
  Future<void> start(String uid) async {
    if (_uid == uid) return;
    // 저장해 둔 상태를 다 읽은 뒤에 한 번에 켭니다(읽는 도중에 켜져 상태가 덮이지 않게).
    final state = await _readState(uid);
    _pending
      ..clear()
      ..addAll(state.pending);
    _lastPull = state.lastPull;
    _uid = uid;
  }

  /// 동기화를 멈추고 저장해 둔 상태를 지웁니다(로그아웃).
  Future<void> stop() async {
    _uid = null;
    _pending.clear();
    _lastPull = null;
    _lastSyncAt = null;
    await _saveState();
  }

  /// 저장해 둔 상태를 읽습니다. 없거나 다른 계정의 것이거나 깨졌으면 빈 상태를 돌려줍니다
  /// (그러면 처음부터 다시 맞추고, 폰에만 있는 기록은 다시 올라갑니다).
  Future<({DateTime? lastPull, Map<String, _Op> pending})> _readState(
    String uid,
  ) async {
    try {
      final file = await _stateFile();
      if (!await file.exists()) return (lastPull: null, pending: _none());
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      if (json['uid'] != uid) return (lastPull: null, pending: _none());
      final ms = json['lastPullMs'] as int?;
      return (
        lastPull: ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms),
        pending: {
          for (final e in (json['pending'] as Map<String, dynamic>).entries)
            e.key: _Op(e.value as String, 0),
        },
      );
    } catch (_) {
      return (lastPull: null, pending: _none());
    }
  }

  static Map<String, _Op> _none() => <String, _Op>{};

  Future<void> _saveState() {
    final uid = _uid;
    final snapshot = uid == null
        ? null
        : jsonEncode({
            'uid': uid,
            'lastPullMs': _lastPull?.millisecondsSinceEpoch,
            'pending': {for (final e in _pending.entries) e.key: e.value.kind},
          });
    final operation = _stateChain.then((_) async {
      final file = await _stateFile();
      if (snapshot == null) {
        if (await file.exists()) await file.delete();
        return;
      }
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(snapshot, flush: true);
      await temporary.rename(file.path);
    });
    _stateChain = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  /// 기록을 저장했으니 서버에 올릴 일로 적어 두고 바로 올려 봅니다.
  void recordSaved(LocalRecords local, RunningRecord record) =>
      _mark(local, record.id, 'upsert');

  /// 기록을 지웠으니 서버에도 지운 표시를 남길 일로 적어 둡니다.
  void recordDeleted(LocalRecords local, String id) =>
      _mark(local, id, 'delete');

  void _mark(LocalRecords local, String id, String kind) {
    if (_uid == null) return;
    _pending[id] = _Op(kind, ++_seq);
    unawaited(
      _saveState()
          .catchError((Object _) {})
          .then((_) => syncNow(local))
          .catchError((Object _) {}),
    );
  }

  /// 서버의 새 변경을 가져오고, 올릴 일을 올립니다. 인터넷이 없으면 조용히 끝나고 다음에 다시 합니다.
  /// [minAge]를 주면 그 시간 안에 이미 했을 때는 건너뜁니다.
  Future<void> syncNow(
    LocalRecords local, {
    Duration? minAge,
    Duration? ackTimeout,
  }) {
    if (_uid == null) return Future.value();
    final last = _lastSyncAt;
    if (minAge != null &&
        last != null &&
        DateTime.now().difference(last) < minAge) {
      return Future.value();
    }
    final run = _chain.then((_) => _sync(local, ackTimeout));
    _chain = run.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return run;
  }

  Future<void> _sync(LocalRecords local, Duration? ackTimeout) async {
    final uid = _uid;
    if (uid == null) return;
    _lastSyncAt = DateTime.now();
    try {
      await _pull(uid, local);
    } catch (_) {
      // 인터넷이 없거나 서버가 막으면 이번에는 가져오기를 건너뜁니다.
    }
    if (_uid != uid) return;
    await _push(uid, local, ackTimeout);
  }

  Future<void> _pull(String uid, LocalRecords local) async {
    final first = _lastPull == null;
    final changes = await backend.fetchChanges(
      uid,
      since: _lastPull?.subtract(_overlap),
    );
    if (_uid != uid) return;
    final seen = <String>{};
    for (final item in changes.items) {
      seen.add(item.id);
      // 폰에서 바꾼 것이 아직 서버에 안 올라갔으면 폰의 것이 우선입니다.
      if (_pending.containsKey(item.id)) continue;
      if (item.deleted) {
        await local.applyRemoteDelete(item.id);
      } else {
        await local.applyRemote(item.record!);
      }
    }
    if (first) {
      // 처음 맞출 때: 서버에 없는 폰의 기록(동기화 기능이 생기기 전 기록 등)은 올릴 일로 적습니다.
      for (final record in await local.load()) {
        if (!seen.contains(record.id)) {
          _pending[record.id] = _Op('upsert', ++_seq);
        }
      }
    }
    final latest = changes.latest;
    if (latest != null && (_lastPull == null || latest.isAfter(_lastPull!))) {
      _lastPull = latest;
    } else if (first) {
      // 서버에 기록이 하나도 없어도 '처음 맞추기'는 끝난 것으로 표시합니다.
      _lastPull = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    await _saveState();
  }

  Future<void> _push(
    String uid,
    LocalRecords local,
    Duration? ackTimeout,
  ) async {
    for (final id in _pending.keys.toList()) {
      if (_uid != uid) return;
      final op = _pending[id];
      if (op == null) continue;
      try {
        if (op.kind == 'delete') {
          await backend.markDeleted(uid, id, timeout: ackTimeout);
        } else {
          final record = await local.find(id);
          // 기록을 읽는 사이에 로그아웃했다면 더 올리지 않습니다.
          if (_uid != uid) return;
          if (record != null) {
            await backend.upsert(uid, record, timeout: ackTimeout);
          }
        }
        // 올리는 사이에 같은 기록이 또 바뀌었다면 올릴 일을 남겨 둡니다.
        if (_pending[id]?.seq == op.seq) _pending.remove(id);
        await _saveState();
      } catch (_) {
        // 인터넷이 없는 것으로 보고 이번에는 여기서 멈춥니다. 남은 일은 다음에 다시 합니다.
        return;
      }
    }
  }

  /// 서버에 아직 올리지 못한 기록 수. 처음 맞추기 전에는 폰의 기록 전부를 못 올린 것으로 봅니다.
  Future<int> unsyncedCount(LocalRecords local) async {
    if (_uid == null) return 0;
    final ids = {
      for (final e in _pending.entries)
        if (e.value.kind == 'upsert') e.key,
    };
    if (_lastPull == null) {
      try {
        ids.addAll((await local.load()).map((r) => r.id));
      } catch (_) {
        // 읽지 못하면 올릴 일로 적힌 것만 셉니다.
      }
    }
    return ids.length;
  }

  /// 올리지 못한 기록을 올려 보고, 그래도 못 올린 기록 수를 돌려줍니다(로그아웃 전에 확인).
  Future<int> flush(
    LocalRecords local, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_uid == null) return 0;
    await syncNow(
      local,
      ackTimeout: timeout,
    ).timeout(timeout + const Duration(seconds: 15), onTimeout: () {});
    return unsyncedCount(local);
  }
}
