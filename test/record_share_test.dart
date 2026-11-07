import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/friends/data/friend_models.dart';
import 'package:runnery_new/friends/data/friend_store.dart';
import 'package:runnery_new/friends/data/record_share.dart';
import 'package:runnery_new/record/models/running_record.dart';

import 'support/fake_friend_backend.dart';

void main() {
  const minji = PublicProfile(uid: 'u1', name: '김민지', id: 'minji_run');
  const haeun = PublicProfile(uid: 'u2', name: '박하은', id: 'haeun_run');

  RunningRecord run(String id, DateTime startedAt) => RunningRecord(
    id: id,
    startedAt: startedAt,
    distanceKm: 5.237,
    movingSeconds: 1935,
    calories: 315,
    caloriesKcal: 315,
    startPlace: '여의나루역',
    endPlace: '여의도공원',
    route: const [
      RecordCoordinate(37.527, 126.932),
      RecordCoordinate(37.529, 126.936),
      RecordCoordinate(37.526, 126.940),
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

  test('route shape fits in a unit box without real coordinates', () {
    final shape = routeShape([
      for (var i = 0; i < 500; i++) (37.5 + i * 0.0001, 127.0 + i * 0.00005),
    ]);
    expect(shape.length, lessThanOrEqualTo(100));
    for (final (x, y) in shape) {
      expect(x, inInclusiveRange(0, 1));
      expect(y, inInclusiveRange(0, 1));
    }
    expect(routeShape([(37.5, 127.0)]), isEmpty);
  });

  test('post leaves out unchosen fields and unknown places', () {
    final post = postFor(
      minji.uid,
      run('r1', DateTime(2026, 10, 29, 7)).withPlaces(area: unknownPlace),
      const ShareFields(time: false, food: false),
    );
    expect(post.distanceKm, 5.24);
    expect(post.movingSeconds, isNull);
    expect(post.hetbahn, isNull);
    expect(post.paceSeconds, isNotNull);
    expect(post.kcal, 315);
    expect(post.area, isNull);
    expect(post.startPlace, '여의나루역');
    expect(post.shape, hasLength(3));
  });

  test('shared record shows in friend feed and takes cheers', () async {
    final share = RecordShare(backend: server, me: () => minji);
    await share.share(run('r1', DateTime(2026, 10, 29, 7)));
    expect(share.isShared('r1'), isTrue);

    final friend = FriendStore(
      backend: server,
      me: () => haeun,
      records: () async => const [],
    );
    await friend.refresh();
    expect(friend.feed, hasLength(1));
    final item = friend.feed.single;
    expect(item.friend, minji);
    expect(item.count(CheerType.clap), 0);

    await friend.toggleCheer(item, CheerType.clap);
    expect(friend.feed.single.count(CheerType.clap), 1);
    expect(friend.feed.single.mine, {CheerType.clap});
    expect(server.cheersByPost['u1/r1'], {
      'u2': {CheerType.clap},
    });

    await friend.toggleCheer(friend.feed.single, CheerType.clap);
    expect(friend.feed.single.count(CheerType.clap), 0);
    expect(server.cheersByPost['u1/r1'], isEmpty);

    await share.unshare('r1');
    await friend.refresh();
    expect(friend.feed, isEmpty);
  });

  test('failed cheer is rolled back', () async {
    await RecordShare(
      backend: server,
      me: () => minji,
    ).share(run('r1', DateTime(2026, 10, 29, 7)));
    final friend = FriendStore(
      backend: server,
      me: () => haeun,
      records: () async => const [],
    );
    await friend.refresh();
    server.offline = true;
    await expectLater(
      friend.toggleCheer(friend.feed.single, CheerType.fire),
      throwsA(isA<FriendException>()),
    );
    expect(friend.feed.single.count(CheerType.fire), 0);
    expect(friend.feed.single.mine, isEmpty);
  });

  test('auto share is off at first and follows the setting', () async {
    final share = RecordShare(backend: server, me: () => minji);
    await share.shareIfAuto(run('r1', DateTime(2026, 10, 29, 7)));
    expect(server.postsByOwner[minji.uid], isNull);

    await share.saveSettings(const ShareSettings(autoShare: true));
    await share.shareIfAuto(run('r2', DateTime(2026, 10, 29, 8)));
    expect(server.postsByOwner[minji.uid]!.keys, ['r2']);
  });

  test('chosen fields are remembered for the next share', () async {
    final share = RecordShare(backend: server, me: () => minji);
    await share.share(
      run('r1', DateTime(2026, 10, 29, 7)),
      fields: const ShareFields(kcal: false),
    );
    expect(server.shareSettings[minji.uid]!.fields.kcal, isFalse);
    await share.share(run('r2', DateTime(2026, 10, 29, 8)));
    expect(server.postsByOwner[minji.uid]!['r2']!.kcal, isNull);
  });

  test('deleting a record while logged out does nothing', () async {
    final share = RecordShare(backend: server, me: () => null);
    await share.recordDeleted('r1');
    await share.shareIfAuto(run('r1', DateTime(2026, 10, 29, 7)));
    expect(server.postsByOwner, isEmpty);
  });

  test('feed time label says today, yesterday or the date', () {
    final now = DateTime(2026, 10, 29, 12);
    expect(feedTimeLabel(DateTime(2026, 10, 29, 7, 12), now), '오늘 오전 7:12');
    expect(feedTimeLabel(DateTime(2026, 10, 28, 21, 3), now), '어제 오후 9:03');
    expect(
      feedTimeLabel(DateTime(2026, 10, 22, 18, 40), now),
      '10월 22일 오후 6:40',
    );
  });
}
