import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../friends/data/friend_store.dart';
import '../../friends/data/record_share.dart';
import '../models/running_record.dart';
import 'record_sync.dart';

/// Flush a temporary file before publishing each run as an independent JSON file.
///
/// 기록은 항상 폰에 먼저 저장합니다. 로그인한 계정의 기록은 [RecordSync]가 서버와 맞춥니다
/// ([startSync] 이후). 동기화를 주지 않으면(테스트 등) 폰 안에서만 동작합니다.
class RunningRecordStore extends ChangeNotifier implements LocalRecords {
  RunningRecordStore({
    Future<Directory> Function()? directory,
    RecordSync? sync,
  }) : _directory = directory ?? getApplicationDocumentsDirectory,
       _sync = sync;
  static final instance = RunningRecordStore(sync: RecordSync());
  final Future<Directory> Function() _directory;
  final RecordSync? _sync;
  Future<void> _pending = Future.value();

  /// 서버와 맞추는 중인지(로그인한 계정이 있는지).
  bool get syncActive => _sync?.active ?? false;

  /// [uid] 계정의 기록 동기화를 시작하고 한 번 맞춥니다. 서버에 닿지 못해도 오류를 던지지 않습니다.
  Future<void> startSync(String uid) async {
    final sync = _sync;
    if (sync == null) return;
    await sync.start(uid);
    await sync.syncNow(this);
  }

  /// 동기화를 멈춥니다(로그아웃).
  Future<void> stopSync() async => _sync?.stop();

  /// 서버와 한 번 맞춥니다. [minAge] 안에 이미 맞췄다면 건너뜁니다.
  Future<void> syncNow({Duration? minAge}) async =>
      _sync?.syncNow(this, minAge: minAge);

  /// 서버에 못 올린 기록을 올려 보고, 그래도 못 올린 기록 수를 돌려줍니다.
  Future<int> flushSync() async => await _sync?.flush(this) ?? 0;

  @override
  Future<RunningRecord?> find(String id) async {
    await _pending;
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) return null;
    final file = File('${(await _folder()).path}/$id.json');
    if (!await file.exists()) return null;
    return RunningRecord.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
  }

  /// 앞선 저장·삭제가 끝난 뒤에 [body]를 하나씩 실행합니다.
  Future<void> _serial(Future<void> Function() body) {
    final operation = _pending.then((_) => body());
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  @override
  Future<void> applyRemote(RunningRecord record) => _serial(() async {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(record.id)) return;
    final folder = await _folder();
    final target = File('${folder.path}/${record.id}.json');
    final content = jsonEncode(record.toJson());
    // 이미 같은 내용이면 다시 쓰지 않아 화면이 불필요하게 새로 그려지지 않게 합니다.
    if (await target.exists() && await target.readAsString() == content) {
      return;
    }
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsString(content, flush: true);
    await temporary.rename(target.path);
    notifyListeners();
  });

  @override
  Future<void> applyRemoteDelete(String id) => _serial(() async {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) return;
    final folder = (await _folder()).path;
    var removed = false;
    for (final file in [
      File('$folder/$id.json'),
      File('$folder/$id.map.png'),
      File('$folder/$id.png'),
    ]) {
      if (await file.exists()) {
        await file.delete();
        removed = true;
      }
    }
    if (removed) notifyListeners();
  });

  Future<Directory> _folder() async {
    final base = await _directory();
    return Directory('${base.path}/running_records').create(recursive: true);
  }

  @override
  Future<List<RunningRecord>> load() async {
    await _pending;
    final folder = await _folder();
    final records = <RunningRecord>[];
    await for (final file in folder.list()) {
      if (file is! File || !file.path.endsWith('.json')) continue;
      records.add(
        RunningRecord.fromJson(
          jsonDecode(await file.readAsString()) as Map<String, dynamic>,
        ),
      );
    }
    records.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return List.unmodifiable(records);
  }

  /// 기록 목록 썸네일 지도 사진 파일. 기록과 같은 폴더에 두어 삭제·초기화 때 함께 지워집니다.
  Future<File> thumbnailFile(String id) async =>
      File('${(await _folder()).path}/$id.map.png');

  /// 저장된 러닝 기록을 모두 지웁니다. 새 계정을 만들 때 씁니다.
  Future<void> clear() {
    final operation = _pending.then((_) async {
      final folder = await _folder();
      await for (final file in folder.list()) {
        if (file is File) await file.delete();
      }
      notifyListeners();
    });
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  /// 저장된 최신 기록을 읽어 [change]를 적용해 다시 저장합니다. 메모와 장소 이름처럼
  /// 서로 다른 때 바뀌는 값이 덮어써지지 않게 합니다. 없는 기록이면 아무 일도 하지 않습니다.
  Future<void> update(
    String id,
    RunningRecord Function(RunningRecord) change,
  ) async {
    final current = (await load()).where((r) => r.id == id).firstOrNull;
    if (current != null) await save(change(current));
  }

  /// 기록 하나를 지웁니다. 없는 기록이면 아무 일도 하지 않습니다.
  /// 동기화 중이면 서버에도 지운 표시를 남겨 다른 폰에서도 지워지게 합니다.
  /// 친구에게 공유한 기록이면 친구 피드에서도 내리고, 친구 랭킹 합계도 다시 올립니다
  /// (기다리지 않고 뒤에서 합니다).
  Future<void> delete(String id) async {
    await _deleteLocal(id);
    _sync?.recordDeleted(this, id);
    if (_sync != null) {
      unawaited(RecordShare.instance.recordDeleted(id));
      unawaited(FriendStore.instance.recordsChanged());
    }
  }

  Future<void> _deleteLocal(String id) {
    final operation = _pending.then((_) async {
      if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) {
        throw const FormatException('Invalid record id');
      }
      final folder = (await _folder()).path;
      for (final file in [
        File('$folder/$id.json'),
        File('$folder/$id.map.png'),
        // 출처 띠가 찍혀 있던 첫 버전의 썸네일.
        File('$folder/$id.png'),
      ]) {
        if (await file.exists()) await file.delete();
      }
      notifyListeners();
    });
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  /// 기록을 폰에 저장합니다. 동기화 중이면 서버에도 올립니다(인터넷이 없으면 나중에).
  /// 친구 랭킹 합계도 다시 올립니다(기다리지 않고 뒤에서 합니다).
  Future<void> save(RunningRecord record) async {
    await _saveLocal(record);
    _sync?.recordSaved(this, record);
    if (_sync != null) unawaited(FriendStore.instance.recordsChanged());
  }

  Future<void> _saveLocal(RunningRecord record) {
    final operation = _pending.then((_) async {
      if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(record.id)) {
        throw const FormatException('Invalid record id');
      }
      final folder = await _folder();
      final target = '${folder.path}/${record.id}.json';
      final temporary = File('$target.tmp');
      await temporary.writeAsString(jsonEncode(record.toJson()), flush: true);
      await temporary.rename(target);
      notifyListeners();
    });
    // Failed writes must not block a retry or reading existing records.
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }
}
