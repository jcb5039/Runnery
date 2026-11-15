import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/home/running/running_watch_link.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('runnery/watch_test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<Map<Object?, Object?>> sent;
  late int? reply;
  late DateTime now;

  setUp(() {
    sent = [];
    reply = 0;
    now = DateTime(2026, 11, 14, 7);
    messenger.setMockMethodCallHandler(channel, (call) async {
      sent.add(call.arguments as Map<Object?, Object?>);
      return reply;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  RunningWatchLink link() =>
      RunningWatchLink(channel: channel, now: () => now, supported: true);

  final route = [for (var i = 0; i < 1000; i++) (37.5 + i * 1e-5, 127.0)];
  List<(double, double)> slice(int from, int count) =>
      route.sublist(from, from + count);

  void update(
    RunningWatchLink l, {
    required int seconds,
    required double meters,
    int routeCount = 0,
    bool force = false,
  }) => l.update(
    paused: false,
    autoPaused: false,
    ending: false,
    elapsed: Duration(seconds: seconds),
    meters: meters,
    averagePace: 360,
    voice: true,
    routeCount: routeCount,
    routeSlice: slice,
    force: force,
  );

  test('1km를 넘을 때마다 구간 시간을 쌓아요', () {
    final l = link();
    update(l, seconds: 0, meters: 0);
    update(l, seconds: 370, meters: 1001);
    update(l, seconds: 720, meters: 2003);
    expect(l.splits, [370, 350]);
  });

  test('지금 페이스는 최근 30초 동안 움직인 거리로 내요', () {
    final l = link();
    // 처음 60초는 느리게(7분/km), 그다음 30초는 빠르게(5분/km).
    for (var s = 0; s <= 60; s++) {
      update(l, seconds: s, meters: s * 1000 / 420);
    }
    final base = 60 * 1000 / 420;
    for (var s = 61; s <= 90; s++) {
      update(l, seconds: s, meters: base + (s - 60) * 1000 / 300);
    }
    expect(l.currentPace, closeTo(300, 1));
  });

  test('거의 움직이지 않으면 지금 페이스를 비워요', () {
    final l = link();
    update(l, seconds: 0, meters: 0);
    update(l, seconds: 10, meters: 5);
    expect(l.currentPace, isNull);
  });

  test('1초에 한 번만 보내고, 경로는 워치가 받은 다음 점부터 나눠 보내요', () async {
    final l = link();
    update(l, seconds: 0, meters: 0, routeCount: 1000, force: true);
    await pumpEventQueue();
    expect(sent, hasLength(1));
    expect(sent.single['routeFrom'], 0);
    expect(
      (sent.single['route'] as List).length,
      RunningWatchLink.maxRoutePerMessage * 2,
    );

    // 1초가 안 지났으면 보내지 않아요.
    reply = 400;
    update(l, seconds: 0, meters: 0, routeCount: 1000);
    await pumpEventQueue();
    expect(sent, hasLength(1));

    // 워치가 0개라고 답했으니 다음에도 처음부터 보내요. 이번엔 400개 받았다고 답해요.
    now = now.add(const Duration(seconds: 1));
    update(l, seconds: 1, meters: 3, routeCount: 1000);
    await pumpEventQueue();
    expect(sent.last['routeFrom'], 0);

    now = now.add(const Duration(seconds: 1));
    update(l, seconds: 2, meters: 6, routeCount: 1000);
    await pumpEventQueue();
    expect(sent.last['routeFrom'], 400);
    expect(sent.last['state'], 'running');
    expect(sent.last['avgPace'], 360);
  });

  test('워치 앱이 닫혀 있으면(답이 없으면) 다음에 경로를 처음부터 보내요', () async {
    final l = link();
    reply = 300;
    update(l, seconds: 0, meters: 0, routeCount: 300, force: true);
    await pumpEventQueue();
    reply = null;
    update(l, seconds: 1, meters: 3, routeCount: 310, force: true);
    await pumpEventQueue();
    expect(sent.last['routeFrom'], 300);
    update(l, seconds: 2, meters: 6, routeCount: 320, force: true);
    await pumpEventQueue();
    expect(sent.last['routeFrom'], 0);
  });

  test('워치 버튼을 러닝 화면에 전하고, 끝나면 기본 화면으로 돌려요', () async {
    final actions = <String>[];
    final l = RunningWatchLink(
      channel: channel,
      supported: true,
      onControl: actions.add,
    )..start();
    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(const MethodCall('control', 'pause')),
      (_) {},
    );
    expect(actions, ['pause']);
    await l.end();
    expect(sent.last, {'state': 'ended'});
  });
}
