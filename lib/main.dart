import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app_start.dart';
import 'design_system/app_colors.dart';
import 'design_system/app_theme.dart';
import 'firebase_options.dart';
import 'profile/setting/profile_setting.dart';
import 'record/list/detail/record_detail_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 서버에 연결하지 못해도 앱은 켜지도록, 실패는 로그만 남깁니다.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase 초기화 실패: $e');
  }
  RecordRouteMap.basemapEnabled = true;
  // 첫 화면부터 저장된 화면 모드로 그리도록 설정을 먼저 읽습니다.
  await ProfileSettings.instance.load();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

/// 화면 모드(라이트·다크·시스템 설정)를 앱 전체에 적용합니다.
class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final _settings = ProfileSettings.instance;

  @override
  void initState() {
    super.initState();
    AppColors.current = _palette;
    WidgetsBinding.instance.addObserver(this);
    _settings.addListener(_apply);
  }

  @override
  void dispose() {
    _settings.removeListener(_apply);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  AppPalette get _palette => _settings.paletteFor(
    WidgetsBinding.instance.platformDispatcher.platformBrightness,
  );

  /// 아이폰의 다크 모드가 바뀌면('시스템 설정'일 때) 따라갑니다.
  @override
  void didChangePlatformBrightness() => _apply();

  void _apply() {
    final palette = _palette;
    if (identical(palette, AppColors.current) || !mounted) return;
    AppColors.current = palette;
    setState(() {});
    // 색은 각 화면이 그릴 때 읽으므로, 열려 있는 모든 화면을 새 색으로 다시 그립니다.
    void refresh(Element element) {
      element.markNeedsBuild();
      if (element is RenderObjectElement) element.renderObject.markNeedsPaint();
      element.visitChildren(refresh);
    }

    (context as Element).visitChildren(refresh);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '러너리',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.current,
    home: const AppStartPage(),
  );
}
