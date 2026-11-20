import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/home/running/stretch/stretch_figure.dart';
import 'package:runnery_new/home/running/stretch/stretch_pages.dart';

void main() {
  test('스트레칭 그림: 디자인에서 옮긴 경로와 움직임을 모두 읽을 수 있어요', () {
    var shapes = 0;
    void walk(FigNode node) {
      switch (node) {
        case FigGroup():
          if (node.motion != null) {
            expect(stretchMotions[node.motion], isNotNull, reason: node.motion);
          }
          node.children.forEach(walk);
        case FigShape():
          shapes++;
          final d = node.d;
          if (d != null) {
            final bounds = parseSvgPath(d).getBounds();
            expect(bounds.width + bounds.height, greaterThan(0), reason: d);
          }
      }
    }

    expect(stretchFigures, hasLength(stretchMoves.length));
    stretchFigures.forEach(walk);
    expect(shapes, greaterThan(50));
  });

  test('스트레칭 움직임: 한 바퀴가 지나면 처음 자세로 돌아와요', () {
    final motion = stretchMotions['st1-nlT']!;
    final start = motion.poseAt(0);
    final again = motion.poseAt(motion.seconds);
    expect(again.angle, closeTo(start.angle!, 0.001));
    // 4분의 1 지점은 다른 자세예요(디자인 -40.1도).
    expect(motion.poseAt(motion.seconds / 4).angle, closeTo(-40.1, 0.001));
  });

  Future<void> openIntro(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(stretchIntroRoute()),
              child: const Text('홈 러닝'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('홈 러닝'));
    await tester.pump();
  }

  testWidgets('스트레칭 안내: 동작 5개와 시작·건너뛰기 버튼을 보여 줘요', (tester) async {
    await openIntro(tester);
    expect(find.text('달리기 전에\n몸을 풀어요'), findsOneWidget);
    expect(find.text('약 3분'), findsOneWidget);
    expect(find.text('5개 동작'), findsOneWidget);
    for (final m in stretchMoves) {
      expect(find.text(m.name), findsOneWidget);
    }
    expect(find.text('스트레칭 시작'), findsOneWidget);
    expect(find.text('건너뛰고 바로 달리기'), findsOneWidget);

    // X를 누르면 홈으로 돌아가요.
    await tester.tap(find.byTooltip('닫기'));
    await tester.pump();
    expect(find.text('홈 러닝'), findsOneWidget);
  });

  testWidgets('따라 하기: 시간이 다 되면 다음 동작으로 넘어가고, 멈추면 시간이 그대로예요', (tester) async {
    await openIntro(tester);
    await tester.tap(find.text('스트레칭 시작'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('발목 돌리기'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('왼쪽 발목'), findsOneWidget);
    expect(find.text('15초 뒤 오른쪽으로 바꿔요'), findsOneWidget);
    expect(find.text('레그 스윙'), findsOneWidget); // 다음 동작 카드

    // 절반이 지나면 오른쪽 차례예요.
    await tester.pump(const Duration(seconds: 16));
    expect(find.text('오른쪽 발목 · 마지막 14초'), findsOneWidget);

    // 멈추면 시간이 줄지 않아요.
    await tester.tap(find.byTooltip('일시정지'));
    await tester.pump();
    expect(find.text('초 · 일시정지됨'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('14'), findsOneWidget);

    // 다시 움직여 시간이 다 되면 다음 동작이에요.
    await tester.tap(find.byTooltip('계속하기'));
    await tester.pump(const Duration(seconds: 15));
    expect(find.text('양쪽 20초씩 앞뒤로'), findsNothing);
    expect(find.text('벽을 짚고 한쪽 다리를 앞뒤로 크게 흔들어요'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);

    // X는 안내 화면으로 돌아가요.
    await tester.tap(find.byTooltip('스트레칭 그만하기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('스트레칭 시작'), findsOneWidget);
  });

  testWidgets('따라 하기: 마지막 동작이 끝나면 출발 화면이 나오고, 닫으면 홈으로 가요', (tester) async {
    await openIntro(tester);
    await tester.tap(find.text('스트레칭 시작'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 다음 버튼으로 마지막 동작까지 넘깁니다.
    for (var i = 0; i < stretchMoves.length - 1; i++) {
      await tester.tap(find.byTooltip('다음 동작'));
      await tester.pump();
    }
    expect(find.text('버트 킥'), findsOneWidget);
    expect(find.text('끝나면 바로 달릴 수 있어요'), findsOneWidget);
    expect(find.byTooltip('스트레칭 마치기'), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('몸이 다 풀렸어요\n이제 달려볼까요?'), findsOneWidget);
    // 시간을 끝까지 채운 건 마지막 동작 하나예요.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('러닝 시작'), findsOneWidget);
    expect(find.text('스트레칭 다시 하기'), findsOneWidget);

    await tester.tap(find.byTooltip('닫기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('홈 러닝'), findsOneWidget);
  });

  testWidgets('작은 화면(375×667)에서도 세 화면이 넘치지 않아요', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final page in <Widget>[
      const StretchIntroPage(),
      const StretchDoingPage(),
      StretchDonePage(
        done: 5,
        elapsed: const Duration(seconds: 170),
        checkLocation: () async => 'GPS 신호 양호 · 바로 시작할 수 있어요',
      ),
    ]) {
      await tester.pumpWidget(MaterialApp(home: page));
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull);
    }
    expect(find.text('2:50'), findsOneWidget);
    expect(find.text('GPS 신호 양호 · 바로 시작할 수 있어요'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
