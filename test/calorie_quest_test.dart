import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/design_system/app_theme.dart';
import 'package:runnery_new/home/running/calorie_quest.dart';

void main() {
  group('단계 계산', () {
    test('10단계이고 칼로리가 점점 커져요', () {
      expect(CalorieQuest.stages, hasLength(10));
      for (var i = 1; i < CalorieQuest.stages.length; i++) {
        expect(
          CalorieQuest.stages[i].kcal,
          greaterThan(CalorieQuest.stages[i - 1].kcal),
        );
      }
    });

    test('186 kcal이면 3단계 달성, 4단계 바나나맛우유까지 22 kcal 남아요', () {
      expect(CalorieQuest.completed(186), 3);
      expect(CalorieQuest.current(186)!.name, '바나나맛우유');
      expect(CalorieQuest.remaining(186), 22);
      // 160 → 208 구간에서 26/48만큼 진행.
      expect(CalorieQuest.stageProgress(186), closeTo(26 / 48, 1e-9));
    });

    test('화면에 보이는 반올림 값으로 달성을 판단해요', () {
      expect(CalorieQuest.completed(49.4), 0);
      expect(CalorieQuest.completed(49.6), 1);
      expect(CalorieQuest.completed(0), 0);
      expect(CalorieQuest.stageProgress(0), 0);
    });

    test('마지막 단계를 넘기면 모두 달성이에요', () {
      expect(CalorieQuest.completed(1208), 10);
      expect(CalorieQuest.current(1300), isNull);
      expect(CalorieQuest.remaining(1300), 0);
      expect(CalorieQuest.stageProgress(1300), 1);
    });
  });

  Widget app(Widget child) => MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(body: child),
  );

  testWidgets('러닝 카드의 퀘스트 줄: 진행 단계·남은 칼로리·다음 단계', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      app(CalorieQuestRow(kcal: 186, onTap: () => tapped = true)),
    );
    expect(find.text('칼로리 퀘스트 · 4단계'), findsOneWidget);
    expect(find.text('바나나맛우유 1개'), findsOneWidget);
    expect(find.text('다음 빼빼로'), findsOneWidget);
    expect(find.textContaining('22 kcal'), findsOneWidget);
    await tester.tap(find.text('바나나맛우유 1개'));
    expect(tapped, isTrue);
  });

  testWidgets('모두 달성하면 퀘스트 줄이 완료로 바뀌어요', (tester) async {
    await tester.pumpWidget(app(CalorieQuestRow(kcal: 1250, onTap: () {})));
    expect(find.text('칼로리 퀘스트 · 완료'), findsOneWidget);
    expect(find.text('10단계 모두 달성'), findsOneWidget);
  });

  testWidgets('퀘스트 목록: 달성 3개, 진행 중 단계, 칼로리가 오르면 바로 바뀌어요', (
    tester,
  ) async {
    final kcal = ValueNotifier<double>(186);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: CalorieQuestPage(listenable: kcal, calories: () => kcal.value),
      ),
    );
    expect(find.text('4단계 진행 중'), findsOneWidget);
    expect(find.text('10단계 중 3단계 달성'), findsOneWidget);
    expect(find.text('달성'), findsNWidgets(3));
    expect(find.text('22 kcal 남음'), findsOneWidget);
    expect(find.text('186 / 208 kcal'), findsOneWidget);

    kcal.value = 210;
    await tester.pump();
    expect(find.text('5단계 진행 중'), findsOneWidget);
    expect(find.text('달성'), findsNWidgets(4));
  });

  testWidgets('달성 창: 단계 이름과 다음 단계, 계속 달리기로 닫혀요', (tester) async {
    final kcal = ValueNotifier<double>(315);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => CalorieQuestAchievedSheet(
                  stageIndex: 5,
                  listenable: kcal,
                  calories: () => kcal.value,
                  elapsed: () => const Duration(minutes: 32, seconds: 15),
                ),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('6단계 달성'), findsOneWidget);
    expect(find.text('CJ 햇반 백미밥 1개만큼\n태웠어요'), findsOneWidget);
    expect(find.text('지금까지 315 kcal · 32분 15초'), findsOneWidget);
    expect(find.text('다음 7단계'), findsOneWidget);
    expect(find.text('롯데리아 불고기버거 1개 · 476 kcal'), findsOneWidget);

    await tester.tap(find.text('계속 달리기'));
    await tester.pumpAndSettle();
    expect(find.text('6단계 달성'), findsNothing);
  });

  testWidgets('달성 창은 잠시 뒤 저절로 닫혀요', (tester) async {
    final kcal = ValueNotifier<double>(50);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => CalorieQuestAchievedSheet(
                  stageIndex: 0,
                  listenable: kcal,
                  calories: () => kcal.value,
                  elapsed: () => const Duration(minutes: 5),
                ),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('1단계 달성'), findsOneWidget);
    await tester.pump(CalorieQuestAchievedSheet.autoClose);
    await tester.pumpAndSettle();
    expect(find.text('1단계 달성'), findsNothing);
  });
}
