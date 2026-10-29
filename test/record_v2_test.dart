import 'package:runnery_new/record/data/running_record_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/record/list/record_list_page.dart';
import 'package:runnery_new/record/list/detail/record_detail_page.dart';
import 'package:runnery_new/record/record_calendar_page.dart';

void main() {
  testWidgets('select mode deletes several records at once', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = _MemoryStore();
    final now = DateTime.now();
    for (var i = 0; i < 3; i++) {
      await store.save(
        RunningRecord(
          id: 'run$i',
          startedAt: DateTime(now.year, now.month, 1, 8 + i),
          distanceKm: i + 1.0,
          movingSeconds: 600,
          calories: 50,
          route: const [],
        ),
      );
    }
    await tester.pumpWidget(MaterialApp(home: RecordListPageV2(store: store)));
    await tester.pumpAndSettle();
    expect(find.text('3회 러닝'), findsOneWidget);

    await tester.tap(find.text('선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.00 km', findRichText: true));
    await tester.tap(find.text('2.00 km', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.text('2개 선택됨'), findsOneWidget);
    await tester.tap(find.text('2개 삭제'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2개를 삭제할까요?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '삭제'));
    await tester.pumpAndSettle();

    expect((await store.load()).map((r) => r.id), ['run2']);
    expect(find.text('1회 러닝'), findsOneWidget);
    expect(find.text('러닝 기록'), findsOneWidget);
  });

  testWidgets('store records load on entry and refresh after saving', (
    tester,
  ) async {
    final store = _MemoryStore();
    final run = RunningRecord(
      id: 'live',
      startedAt: DateTime.now(),
      distanceKm: 1,
      movingSeconds: 300,
      calories: 50,
      route: const [],
    );
    await tester.pumpWidget(MaterialApp(home: RecordListPageV2(store: store)));
    await tester.pumpAndSettle();
    expect(find.text('아직 저장된 러닝 기록이 없습니다.'), findsOneWidget);
    await store.save(run);
    await tester.pumpAndSettle();
    expect(find.text('1회 러닝'), findsOneWidget);
    expect(find.text(run.dateLabel), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets(
    'empty history shows zero stats without fabricated rows or calendar routes',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RecordListPageV2(
            records: const [],
            initialMonth: DateTime.now(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('아직 저장된 러닝 기록이 없습니다.'), findsOneWidget);
      expect(find.text('0회 러닝'), findsOneWidget);
      expect(find.text('0분'), findsOneWidget);
      expect(find.text('햇반 0개'), findsOneWidget);
      expect(find.byType(RecordRouteMap), findsNothing);
      await tester.tap(find.text('달력'));
      await tester.pumpAndSettle();
      expect(find.byType(MiniRunningRoute), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'month changes update totals and a selected row opens the same record',
    (tester) async {
      final september = RunningRecord(
        id: 'sep',
        startedAt: DateTime(2026, 9, 30, 8),
        distanceKm: 2,
        movingSeconds: 600,
        calories: 50,
        route: const [],
      );
      final october = RunningRecord(
        id: 'oct',
        startedAt: DateTime(2026, 10, 1, 9),
        distanceKm: 3,
        movingSeconds: 1200,
        calories: 75,
        route: const [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: RecordListPageV2(
            records: [september, october],
            initialMonth: DateTime(2026, 10),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1회 러닝'), findsOneWidget);
      expect(find.text('20분'), findsOneWidget);
      expect(
        find.text('5.00'),
        findsOneWidget,
      ); // Full week across the month boundary.
      await tester.tap(find.byTooltip('이전 달'));
      await tester.pumpAndSettle();
      expect(find.text('10분'), findsOneWidget);
      expect(find.text(september.dateLabel), findsOneWidget);
      expect(find.text(october.dateLabel), findsNothing);
      await tester.tap(find.text(september.dateLabel));
      await tester.pumpAndSettle();
      expect(
        tester.widget<RecordDetailPage>(find.byType(RecordDetailPage)).record,
        same(september),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('calendar mini routes use only actual saved coordinates', (
    tester,
  ) async {
    final points = [
      RecordCoordinate(37.5, 127, timestamp: DateTime(2026, 10, 1)),
      const RecordCoordinate(37.501, 127.002),
    ];
    final run = RunningRecord(
      id: 'gps',
      startedAt: DateTime(2026, 10, 1),
      distanceKm: .2,
      movingSeconds: 60,
      calories: 10,
      route: points,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecordCalendarPage(
              embedded: true,
              records: [run],
              month: DateTime(2026, 10),
              selectedDay: DateTime(2026, 10, 2),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MiniRunningRoute), findsOneWidget);
    expect(
      tester
          .widget<MiniRunningRoute>(find.byType(MiniRunningRoute))
          .coordinates,
      same(points),
    );
    expect(find.byType(RecordRouteMap), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stats tab compares this week and switches to month', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        home: RecordListPageV2(
          records: [
            RunningRecord(
              id: 'today',
              startedAt: DateTime(now.year, now.month, now.day, 0, 1),
              distanceKm: 3,
              movingSeconds: 1200,
              calories: 200,
              route: const [],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('통계'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('이전 달'), findsNothing);
    expect(find.text('성장 중'), findsOneWidget);
    expect(find.text('지난주엔 달리지 않았어요'), findsOneWidget);
    expect(find.text('3.00'), findsOneWidget);
    expect(find.text('▲ 3.00 km'), findsOneWidget);

    await tester.tap(find.byTooltip('이전 주'));
    await tester.pumpAndSettle();
    expect(find.text('정체 중'), findsOneWidget);
    expect(find.text('이 주엔 달리지 않았어요'), findsOneWidget);

    await tester.tap(find.text('월간'));
    await tester.pumpAndSettle();
    expect(find.text('${now.year}년 ${now.month}월'), findsOneWidget);
    expect(find.byTooltip('이전 달'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _MemoryStore extends RunningRecordStore {
  final _records = <RunningRecord>[];
  @override
  Future<List<RunningRecord>> load() async => List.unmodifiable(_records);
  @override
  Future<void> save(RunningRecord record) async {
    _records.add(record);
    notifyListeners();
  }

  @override
  Future<void> delete(String id) async {
    _records.removeWhere((r) => r.id == id);
    notifyListeners();
  }
}
