import 'package:flutter/material.dart';

import '../../account/account_store.dart';
import '../../design_system/app_colors.dart';
import '../../login/auth_ui/auth_ui.dart';
import '../../login/login.dart';

/// 설정 > 회원 탈퇴. 지워지는 것을 알려 주고, 본인 확인(이메일 계정은 비밀번호, 소셜 계정은 그 로그인을
/// 한 번 더) 뒤 계정과 데이터를 지우고 로그인 화면으로 갑니다.
class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key, this.store});

  /// 기본값은 AccountStore.instance.
  final AccountStore? store;

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  late final AccountStore _store = widget.store ?? AccountStore.instance;
  late final LoginMethod _method = _store.loginMethod ?? LoginMethod.email;
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _deleting = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  String get _socialName => switch (_method) {
    LoginMethod.kakao => '카카오',
    LoginMethod.naver => '네이버',
    LoginMethod.google => '구글',
    LoginMethod.email => '',
  };

  Future<void> _delete() async {
    if (_deleting) return;
    if (_method == LoginMethod.email && !_form.currentState!.validate()) return;
    setState(() => _deleting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final deleted = await _store.deleteAccount(
        password: _method == LoginMethod.email ? _password.text : null,
      );
      if (!mounted || !deleted) return;
      Navigator.of(context).pushAndRemoveUntil<void>(
        MaterialPageRoute(builder: (_) => LoginPageV2(store: _store)),
        (_) => false,
      );
      messenger.showSnackBar(const SnackBar(content: Text('탈퇴했어요. 그동안 고마웠어요')));
    } on AuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('탈퇴하지 못했어요. 다시 시도해주세요')),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    // 지우는 도중에는 뒤로 가지 않게 합니다.
    canPop: !_deleting,
    child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          tooltip: '뒤로',
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: _deleting ? null : () => Navigator.pop(context),
        ),
        title: const Text(
          '회원 탈퇴',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: _deleting ? null : _delete,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
              foregroundColor: AppColors.onInverse,
              disabledBackgroundColor: AppColors.surfacePressed,
              disabledForegroundColor: AppColors.textTertiary,
              shape: const StadiumBorder(),
            ),
            child: Text(
              _deleting ? '탈퇴하는 중…' : '탈퇴하기',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                Text(
                  '정말 탈퇴할까요?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '탈퇴하면 아래 정보가 모두 지워지고 되돌릴 수 없어요.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                for (final item in const [
                  '러닝 기록 전부 (이 폰과 서버 모두)',
                  '프로필(이름·아이디·나이·성별·체중)과 프로필 사진',
                  '로그인 계정',
                ])
                  _Bullet(item),
                const SizedBox(height: 16),
                Text(
                  '같은 계정으로 다시 가입해도 기록은 돌아오지 않아요.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                if (_method == LoginMethod.email)
                  AuthField(
                    label: 'PASSWORD',
                    controller: _password,
                    password: true,
                    hint: '본인 확인을 위해 비밀번호를 입력해주세요',
                    action: TextInputAction.done,
                    validator: (v) =>
                        v == null || v.isEmpty ? '비밀번호를 입력해주세요' : null,
                  )
                else
                  Text(
                    '본인 확인을 위해 탈퇴하기를 누르면 $_socialName 로그인 화면이 한 번 더 열려요. '
                    '가입한 $_socialName 계정으로 로그인해주세요.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// 지워지는 것 한 줄.
class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '·  ',
          style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );
}
