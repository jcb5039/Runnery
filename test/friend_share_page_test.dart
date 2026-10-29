import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/friends/data/friend_store.dart';
import 'package:runnery_new/friends/data/record_share.dart';
import 'package:runnery_new/friends/friends_page.dart';
import 'package:runnery_new/friends/share/record_visibility_page.dart';
import 'package:runnery_new/friends/share/share_record_sheet.dart';
import 'package:runnery_new/record/models/running_record.dart';

import 'support/fake_friend_backend.dart';

void main() {
  const minji = PublicProfile(uid: 'u1', name: '김민지', id: 'minji_run');
  const haeun = PublicProfile(uid: 'u2', name: '박하은', id: 'haeun_run');

  RunningRecord run(String id, DateTime startedAt) => RunningRecord(
    id: id,
    startedAt: startedAt,
    distanceKm: 5.24,
    movingSeconds: 1935,
    calories: 315,
    caloriesKcal: 315,
    startPlace: '여의나루역',
    endPlace: '여의도공원',
    route: const [
      RecordCoordinate(37.527, 126.932),
      RecordCoordinate(37.529, 126.936),
    ],
  );

  late FakeFriendBackend server;
  setUp(() {
    server = FakeFriendBackend()
      ..friends[minji.uid] = {haeun.uid}
      ..friends[haeun.uid] = {minji.uid}
      ..profilesByUid[minji.uid] = minji
      ..profilesByUid[haeun.uid] = haeun;
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('friend feed shows shared runs and toggles a cheer', (
    tester,
  ) async {
    phone(tester);
    await RecordShare(
      backend: server,
      me: () => haeun,
    ).share(run('r1', DateTime.now()), fields: const ShareFields(kcal: false));
    final store = FriendStore(
      backend: server,
      me: () => minji,
      records: () async => const [],
    );
    await tester.pumpWidget(MaterialApp(home: FriendsPage(store: store)));
    await tester.pumpAndSettle();

    expect(find.text('친구들의 최근 러닝'), findsOneWidget);
    expect(find.text('박하은'), findsOneWidget);
    expect(find.textContaining('여의나루역'), findsOneWidget);
    expect(find.text('5.24'), findsOneWidget);
    expect(find.textContaining('kcal'), findsNothing);

    await tester.tap(find.text('👏'));
    await tester.pumpAndSettle();
    expect(server.cheersByPost['u2/r1'], {
      'u1': {CheerType.clap},
    });
    expect(find.bySemanticsLabel(RegExp('박수 응원 1개 · 내가 보냄')), findsOneWidget);
  });

  testWidgets('share sheet hides unchecked items and posts the run', (
    tester,
  ) async {
    phone(tester);
    final share = RecordShare(backend: server, me: () => minji);
    final record = run('r1', DateTime.now());
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showShareRecordSheet(context, record, share: share),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.text('친구에게 기록 공유'), findsOneWidget);
    expect(find.textContaining('여의나루역 → 여의도공원'), findsOneWidget);
    expect(find.textContaining('315 kcal'), findsOneWidget);
    await tester.tap(find.text('소모 칼로리'));
    await tester.pumpAndSettle();
    expect(find.textContaining('315 kcal'), findsNothing);

    await tester.tap(find.text('친구에게 공유'));
    await tester.pumpAndSettle();
    expect(find.text('친구 피드에 올렸어요'), findsOneWidget);
    final post = server.postsByOwner[minji.uid]!['r1']!;
    expect(post.kcal, isNull);
    expect(post.movingSeconds, 1935);
  });

  testWidgets('visibility page turns auto share on and hides a record', (
    tester,
  ) async {
    phone(tester);
    final share = RecordShare(backend: server, me: () => minji);
    final now = DateTime(2026, 10, 29, 12); // 목요일
    final records = [
      run('thu', DateTime(2026, 10, 29, 7)),
      run('mon', DateTime(2026, 10, 26, 7)),
      run('lastweek', DateTime(2026, 10, 25, 7)),
    ];
    await share.share(records[0]);
    await tester.pumpWidget(
      MaterialApp(
        home: RecordVisibilityPage(
          share: share,
          records: () async => records,
          now: now,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('10월 29일 목요일'), findsOneWidget);
    expect(find.text('10월 26일 월요일'), findsOneWidget);
    expect(find.text('10월 25일 일요일'), findsNothing);
    expect(find.text('공개 1개 · 비공개 1개'), findsOneWidget);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(server.shareSettings[minji.uid]!.autoShare, isTrue);

    await tester.tap(find.byType(Switch).at(1));
    await tester.pumpAndSettle();
    expect(server.postsByOwner[minji.uid], isEmpty);
    expect(find.text('공개 0개 · 비공개 2개'), findsOneWidget);
  });
}
