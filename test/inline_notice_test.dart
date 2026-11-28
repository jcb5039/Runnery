import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnery_new/design_system/inline_notice.dart';

/// 화면 아래에서 올라오는 알림(SnackBar)은 하단 탭·버튼을 가려서 쓰지 않고,
/// 방금 누른 곳 바로 아래(맨 아래 버튼이면 바로 위)에 글씨로 알려요.
void main() {
  test('앱 코드에 하단 알림(SnackBar)을 띄우는 곳이 없어요', () {
    final found = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final lines = file.readAsLinesSync();
      for (final (i, line) in lines.indexed) {
        final code = line.trimLeft();
        if (code.startsWith('//')) continue;
        if (code.contains('showSnackBar') || code.contains('SnackBar(')) {
          found.add('${file.path}:${i + 1}');
        }
      }
    }
    expect(found, isEmpty, reason: '하단 알림 대신 InlineNotice·NoticeSlot을 써 주세요');
  });

  testWidgets('그 자리에 빨간 글씨가 보였다가 5초 뒤 사라지고, 다시 보이면 바뀌어요', (tester) async {
    final notices = Notices();
    addTearDown(notices.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const Text('버튼'),
              NoticeSlot(notices: notices, id: 'a'),
              NoticeSlot(notices: notices, id: 'b'),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(InlineNotice), findsNothing);

    notices.show('a', '인터넷 연결을 확인해주세요');
    await tester.pump();
    expect(find.text('인터넷 연결을 확인해주세요'), findsOneWidget);
    // 다른 자리에는 나오지 않아요.
    expect(find.byType(InlineNotice), findsOneWidget);

    notices.show('a', '다시 시도해주세요');
    await tester.pump();
    expect(find.text('인터넷 연결을 확인해주세요'), findsNothing);
    expect(find.text('다시 시도해주세요'), findsOneWidget);

    await tester.pump(Notices.showFor);
    expect(find.text('다시 시도해주세요'), findsNothing);
  });

  testWidgets('잘 된 일은 회색, 실패는 빨간 글씨예요', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            InlineNotice('메일을 보냈어요', success: true),
            InlineNotice('보내지 못했어요'),
            InlineNotice(null),
          ],
        ),
      ),
    );
    final ok = tester.widget<Text>(find.text('메일을 보냈어요'));
    final fail = tester.widget<Text>(find.text('보내지 못했어요'));
    expect(ok.style!.color, isNot(fail.style!.color));
    expect(find.byType(Text), findsNWidgets(2));
  });
}
