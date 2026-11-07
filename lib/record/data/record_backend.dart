import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/running_record.dart';

/// 기록 하나를 서버에 올릴 덩어리로 바꿉니다. 경로 점이 많은 기록도 서버 문서 한도(약 1MB)를
/// 넘지 않도록 압축합니다(약 1시간 러닝이 40KB 안팎).
Uint8List encodeRecordPayload(RunningRecord record) =>
    Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(record.toJson()))));

/// [encodeRecordPayload]로 만든 덩어리를 기록으로 되돌립니다. 읽을 수 없으면 예외를 던집니다.
RunningRecord decodeRecordPayload(List<int> bytes) => RunningRecord.fromJson(
  jsonDecode(utf8.decode(gzip.decode(bytes))) as Map<String, dynamic>,
);

/// 서버에 있는 기록 한 건. 지워진 기록이면 [record]가 null입니다.
class RemoteRecord {
  const RemoteRecord(this.id, this.record);
  const RemoteRecord.deleted(this.id) : record = null;
  final String id;
  final RunningRecord? record;
  bool get deleted => record == null;
}

/// 서버에서 가져온 변경 목록.
class RecordChanges {
  const RecordChanges(this.items, this.latest);

  /// 새로 생기거나 고쳐지거나 지워진 기록.
  final List<RemoteRecord> items;

  /// 가져온 변경 중 가장 최근 서버 시각. 변경이 없으면 null.
  final DateTime? latest;
}

/// 러닝 기록을 서버와 주고받는 부분. 앱은 Firebase 구현을 쓰고, 테스트는 가짜로 바꿔 씁니다.
abstract class RecordBackend {
  /// [since] 이후에 바뀐 기록을 가져옵니다. null이면 전부. 인터넷이 없으면 예외를 던집니다.
  Future<RecordChanges> fetchChanges(String uid, {DateTime? since});

  /// 기록을 서버에 올립니다(이미 있으면 덮어씁니다). 서버가 받을 때까지 기다립니다.
  Future<void> upsert(String uid, RunningRecord record, {Duration? timeout});

  /// 기록을 지웁니다. 다른 폰이 알 수 있도록 지운 표시를 남깁니다.
  Future<void> markDeleted(String uid, String id, {Duration? timeout});
}

/// Firestore(`users/{uid}/records/{id}`)를 쓰는 실제 구현.
class FirebaseRecordBackend implements RecordBackend {
  static const _timeout = Duration(seconds: 20);

  CollectionReference<Map<String, dynamic>> _records(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('records');

  @override
  Future<RecordChanges> fetchChanges(String uid, {DateTime? since}) async {
    var query = _records(uid).orderBy('updatedAt');
    if (since != null) {
      query = query.where(
        'updatedAt',
        isGreaterThan: Timestamp.fromDate(since),
      );
    }
    // 인터넷이 없을 때 옛 정보를 새 정보로 착각하지 않도록 서버에서만 읽습니다.
    final snapshot = await query
        .get(const GetOptions(source: Source.server))
        .timeout(_timeout);
    final items = <RemoteRecord>[];
    DateTime? latest;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final updated = (data['updatedAt'] as Timestamp?)?.toDate();
      if (updated != null && (latest == null || updated.isAfter(latest))) {
        latest = updated;
      }
      if (data['deleted'] == true) {
        items.add(RemoteRecord.deleted(doc.id));
        continue;
      }
      final payload = data['payload'];
      if (payload is! Blob) continue;
      try {
        items.add(RemoteRecord(doc.id, decodeRecordPayload(payload.bytes)));
      } catch (_) {
        // 읽을 수 없는 기록 하나 때문에 나머지 동기화가 멈추지 않게 건너뜁니다.
      }
    }
    return RecordChanges(items, latest);
  }

  @override
  Future<void> upsert(
    String uid,
    RunningRecord record, {
    Duration? timeout,
  }) => _records(uid)
      .doc(record.id)
      .set({
        'version': 1,
        'deleted': false,
        'updatedAt': FieldValue.serverTimestamp(),
        'startedAt': Timestamp.fromDate(record.startedAt),
        'distanceKm': record.distanceKm,
        'payload': Blob(encodeRecordPayload(record)),
      })
      .timeout(timeout ?? _timeout);

  @override
  Future<void> markDeleted(String uid, String id, {Duration? timeout}) =>
      _records(uid)
          .doc(id)
          .set({
            'version': 1,
            'deleted': true,
            'updatedAt': FieldValue.serverTimestamp(),
          })
          .timeout(timeout ?? _timeout);
}
