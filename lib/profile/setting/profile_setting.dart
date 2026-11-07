import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../design_system/app_colors.dart';
import '../../friends/share/record_visibility_page.dart';
import '../../home/running/calorie_quest.dart';

/// 러닝 설정. 기기에 저장되어 앱을 다시 켜도 유지되고, 러닝 시작 화면의 기본값으로 쓰입니다.
class ProfileSettings extends ChangeNotifier {
  ProfileSettings({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;

  /// 앱 전체가 쓰는 설정. 테스트에서는 새로 만들어 씁니다.
  static final instance = ProfileSettings();
  static const countdownOptions = ['없음', '3초', '5초', '10초'];
  static const themeModeOptions = ['라이트', '다크', '시스템 설정'];

  final Future<Directory> Function() _directory;
  Future<void>? _loading;

  bool voice = true;
  bool autoPause = true;
  bool calorieQuest = true;

  /// 칼로리 퀘스트를 다시 시작하는 주기. 처음에는 일간입니다.
  CalorieQuestPeriod calorieQuestPeriod = CalorieQuestPeriod.daily;
  String countdown = '3초';

  /// 화면 모드. 처음에는 라이트이고, '시스템 설정'이면 아이폰 설정을 따릅니다.
  String themeMode = '라이트';

  /// 지금 써야 할 색. [platform]은 아이폰의 다크 모드 여부입니다.
  AppPalette paletteFor(Brightness platform) => switch (themeMode) {
    '다크' => AppColors.dark,
    '시스템 설정' => platform == Brightness.dark ? AppColors.dark : AppColors.light,
    _ => AppColors.light,
  };

  /// 카운트다운 초. '없음'이면 0.
  int get countdownSeconds => switch (countdown) {
    '없음' => 0,
    '5초' => 5,
    '10초' => 10,
    _ => 3,
  };

  Future<File> _file() async =>
      File('${(await _directory()).path}/settings.json');

  /// 저장된 설정을 한 번만 읽습니다. 파일이 없거나 깨졌으면 기본값을 씁니다.
  Future<void> load() => _loading ??= () async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      voice = json['voice'] as bool? ?? voice;
      autoPause = json['autoPause'] as bool? ?? autoPause;
      calorieQuest = json['calorieQuest'] as bool? ?? calorieQuest;
      calorieQuestPeriod = CalorieQuestPeriod.fromLabel(
        json['calorieQuestPeriod'] as String?,
      );
      final saved = json['countdown'] as String?;
      if (countdownOptions.contains(saved)) countdown = saved!;
      final mode = json['themeMode'] as String?;
      if (themeModeOptions.contains(mode)) themeMode = mode!;
      notifyListeners();
    } catch (_) {
      // 읽지 못하면 기본값으로 둡니다.
    }
  }();

  void update(VoidCallback change) {
    change();
    notifyListeners();
    _save();
  }

  Future<void> _save() async {
    try {
      final file = await _file();
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(
        jsonEncode({
          'voice': voice,
          'autoPause': autoPause,
          'calorieQuest': calorieQuest,
          'calorieQuestPeriod': calorieQuestPeriod.label,
          'countdown': countdown,
          'themeMode': themeMode,
        }),
        flush: true,
      );
      await temporary.rename(file.path);
    } catch (_) {
      // 저장에 실패해도 이번 실행 동안은 바뀐 값을 씁니다.
    }
  }
}

class ProfileSettingPage extends StatelessWidget {
  const ProfileSettingPage({
    super.key,
    required this.settings,
    this.onLogout,
    this.onEditProfile,
    this.onChangePassword,
  });
  final ProfileSettings settings;
  final VoidCallback? onLogout;

  /// '개인 정보 수정'. 없으면 준비 중 안내를 띄웁니다.
  final VoidCallback? onEditProfile;

  /// '비밀번호 변경'. 없으면 준비 중 안내를 띄웁니다.
  final VoidCallback? onChangePassword;

  void _pending(BuildContext context, String label) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$label 기능은 준비 중이에요')));
  }

  Future<void> _choose(
    BuildContext context,
    String title,
    String current,
    List<String> options,
    ValueChanged<String> onSelected,
  ) async {
    final value = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.sheet,
      showDragHandle: true,
      builder: (context) => SafeArea(
        // 화면이 낮아도 선택지가 잘리지 않도록 스크롤을 허용합니다.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              for (final option in options)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(option),
                  trailing: option == current
                      ? Icon(Icons.check, color: AppColors.textPrimary)
                      : null,
                  onTap: () => Navigator.pop(context, option),
                ),
            ],
          ),
        ),
      ),
    );
    if (value != null) settings.update(() => onSelected(value));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        tooltip: '뒤로',
        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        '설정',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      centerTitle: true,
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListenableBuilder(
            listenable: settings,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              children: [
                _section('러닝'),
                _toggle(
                  '음성 안내',
                  '1 km마다 거리와 페이스를 알려줘요',
                  settings.voice,
                  (v) => settings.update(() => settings.voice = v),
                ),
                _toggle(
                  '자동 일시정지',
                  '멈춰 서면 기록을 잠시 멈춰요',
                  settings.autoPause,
                  (v) => settings.update(() => settings.autoPause = v),
                ),
                _toggle(
                  '칼로리 퀘스트',
                  '태운 칼로리를 간식 단계로 보여줘요',
                  settings.calorieQuest,
                  (v) => settings.update(() => settings.calorieQuest = v),
                ),
                if (settings.calorieQuest)
                  _row(
                    '칼로리 퀘스트 주기',
                    subtitle: '고른 기간마다 1단계부터 다시 시작해요',
                    value: settings.calorieQuestPeriod.label,
                    onTap: () => _choose(
                      context,
                      '칼로리 퀘스트 주기',
                      settings.calorieQuestPeriod.label,
                      [for (final p in CalorieQuestPeriod.values) p.label],
                      (v) => settings.calorieQuestPeriod =
                          CalorieQuestPeriod.fromLabel(v),
                    ),
                  ),
                _row(
                  '카운트다운',
                  value: settings.countdown,
                  onTap: () => _choose(
                    context,
                    '카운트다운',
                    settings.countdown,
                    ProfileSettings.countdownOptions,
                    (v) => settings.countdown = v,
                  ),
                ),
                // 마일 단위는 아직 없어 km만 보여 줍니다.
                _row('거리 단위', value: 'km', divider: false),
                // 시안의 '지도'(1 km 구간 표시·GPS 정확도)는 기능을 만들 때 넣습니다.
                const SizedBox(height: 26),
                _section('화면'),
                _row(
                  '화면 모드',
                  subtitle: '처음 설치하면 라이트 모드로 시작해요',
                  value: settings.themeMode,
                  divider: false,
                  onTap: () => _choose(
                    context,
                    '화면 모드',
                    settings.themeMode,
                    ProfileSettings.themeModeOptions,
                    (v) => settings.themeMode = v,
                  ),
                ),
                const SizedBox(height: 26),
                _section('계정'),
                _row(
                  '개인 정보 수정',
                  onTap: onEditProfile ?? () => _pending(context, '개인 정보 수정'),
                ),
                _row(
                  '기록 공개 설정',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RecordVisibilityPage(),
                    ),
                  ),
                ),
                // 시안의 '알림'은 켜고 끌 알림 설정이 생기면 넣습니다.
                _row(
                  '비밀번호 변경',
                  divider: false,
                  onTap: onChangePassword ?? () => _pending(context, '비밀번호 변경'),
                ),
                const SizedBox(height: 26),
                _section('앱 정보'),
                // 이용약관·개인정보 처리방침은 문서가 준비되면 넣습니다.
                _row('버전', value: '2.0.0', divider: false),
                const SizedBox(height: 28),
                Divider(color: AppColors.borderDefault, height: 1),
                Row(
                  children: [
                    TextButton(
                      onPressed: onLogout ?? () => _pending(context, '로그아웃'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        foregroundColor: AppColors.textPrimary,
                      ),
                      child: const Text('로그아웃'),
                    ),
                    // '회원 탈퇴'는 기능을 만들 때 '로그아웃 | 회원 탈퇴'로 넣습니다.
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 12,
        color: AppColors.textTertiary,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _toggle(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) => _row(
    title,
    subtitle: subtitle,
    trailing: Switch(
      value: value,
      onChanged: onChanged,
      activeTrackColor: AppColors.textPrimary,
      activeThumbColor: AppColors.background,
      inactiveTrackColor: AppColors.divider,
      inactiveThumbColor: AppColors.textSecondary,
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    onTap: () => onChanged(!value),
  );

  Widget _row(
    String title, {
    String? subtitle,
    String? value,
    Widget? trailing,
    VoidCallback? onTap,
    bool divider = true,
  }) => Container(
    decoration: BoxDecoration(
      border: divider
          ? Border(bottom: BorderSide(color: AppColors.divider))
          : null,
    ),
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (trailing != null)
                trailing
              else ...[
                if (value != null)
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (onTap != null)
                  Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
