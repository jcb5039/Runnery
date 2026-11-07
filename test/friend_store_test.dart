import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/friends/data/friend_models.dart';
import 'package:runnery_new/friends/data/friend_store.dart';

import 'support/fake_friend_backend.dart';

void main() {
  const minji = PublicProfile(uid: 'u1', name: '김민지', id: 'minji_run');
  const haeun = PublicProfile(uid: 'u2', name: '박하은', id: 'haeun_run');
  const kim = PublicProfile(uid: 'u3', name: '김하은', id: 'kim_haeun');

  late FakeFriendBackend server;
  FriendStore storeFor(PublicProfile me) =>
      FriendStore(backend: server, me: () => me, records: () async => const []);

  setUp(() => server = FakeFriendBackend());

  test('keywords find names by any part and ids by prefix', () {
    final words = searchKeywords('박 하은', 'Haeun_Run');
    expect(words, containsAll(['박', '하은', '박하은', 'h', 'haeun_run']));
    expect(words, isNot(contains('run')));
  });

  test('refresh publishes my profile so others can find me', () async {
    await storeFor(haeun).refresh();
    await storeFor(kim).refresh();
    final found = await storeFor(minji).search('하은');
    expect(found.map((p) => p.name), ['김하은', '박하은']);
    expect(await storeFor(minji).search('@kim'), [kim]);
    expect(await storeFor(minji).search('  '), isEmpty);
  });

  test('request, accept and remove keep both sides in sync', () async {
    final a = storeFor(minji), b = storeFor(haeun);
    await a.refresh();
    await b.refresh();

    await a.sendRequest(haeun);
    expect(a.relation(haeun.uid), FriendRelation.requested);

    await b.refresh();
    expect(b.incoming, [minji]);
    expect(b.relation(minji.uid), FriendRelation.incoming);

    await b.accept(minji);
    expect(b.friends, [minji]);
    expect(b.incoming, isEmpty);

    await a.refresh();
    expect(a.friends, [haeun]);
    expect(a.relation(haeun.uid), FriendRelation.friend);
    expect(a.relation(minji.uid), FriendRelation.me);

    await b.remove(minji.uid);
    await a.refresh();
    expect(a.friends, isEmpty);
    expect(b.friends, isEmpty);
  });

  test('requesting someone who already asked me accepts at once', () async {
    final a = storeFor(minji), b = storeFor(haeun);
    await a.refresh();
    await b.refresh();
    await a.sendRequest(haeun);
    await b.refresh();
    await b.sendRequest(minji);
    expect(b.friends, [minji]);
    expect(server.requests, isEmpty);
  });

  test('decline and cancel remove the request', () async {
    final a = storeFor(minji), b = storeFor(haeun);
    await a.refresh();
    await b.refresh();
    await a.sendRequest(haeun);
    await a.cancelRequest(haeun.uid);
    expect(a.relation(haeun.uid), FriendRelation.none);
    await b.refresh();
    expect(b.incoming, isEmpty);

    await a.sendRequest(haeun);
    await b.refresh();
    await b.decline(minji);
    expect(b.incoming, isEmpty);
    expect(server.requests, isEmpty);
  });

  test('offline refresh keeps an error message instead of crashing', () async {
    final a = storeFor(minji);
    server.offline = true;
    await a.refresh();
    expect(a.error, '인터넷 연결을 확인해주세요');
    expect(a.loading, isFalse);
    expect(() => a.sendRequest(haeun), throwsA(isA<FriendException>()));
  });

  test('logged out store does nothing', () async {
    final store = FriendStore(
      backend: server,
      me: () => null,
      records: () async => const [],
    );
    await store.refresh();
    expect(store.friends, isEmpty);
    expect(server.profilesByUid, isEmpty);
  });
}
