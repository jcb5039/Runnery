import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/design_system/app_theme.dart';
import 'package:runnery_new/home/running/running_start_page.dart';

void main() {
  testWidgets('러닝 카드 숫자 줄: 페이스가 길어져도 높이가 그대로예요', (tester) async {
    Future<double> heightFor(String pace) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 600,
                child: StatRow(
                  cells: [
                    const StatCell(label: '시간', value: '0:08'),
                    StatCell(label: '페이스', value: pace, unit: '/km'),
                    const StatCell(label: '칼로리', value: '5', unit: 'kcal'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      return tester.getSize(find.byType(StatRow)).height;
    }

    // 멈춰 서면 페이스가 길어집니다. 글자는 줄여 한 줄로 보이는데 높이는 두 줄로 잡히면 카드가 출렁입니다.
    final normal = await heightFor('6′12″');
    final slow = await heightFor('123′45″');
    expect(slow, normal);
  });
}
