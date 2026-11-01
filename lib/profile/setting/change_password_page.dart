import 'package:flutter/material.dart';

import '../../account/account_store.dart';
import '../../design_system/app_colors.dart';
import '../../login/auth_ui/auth_ui.dart';

/// 설정 > 비밀번호 변경. 현재 비밀번호를 한 번 더 확인한 뒤 새 비밀번호로 바꿉니다.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key, this.store});

  /// 기본값은 AccountStore.instance.
  final AccountStore? store;
  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  late final AccountStore _store = widget.store ?? AccountStore.instance;
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _store.changePassword(_current.text, _next.text);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(content: Text('비밀번호를 바꿨어요')));
    } on AuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('비밀번호를 바꾸지 못했어요. 다시 시도해주세요')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      leading: IconButton(
        tooltip: '뒤로',
        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        '비밀번호 변경',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: SizedBox(
        height: 52,
        child: FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.textPrimary,
            foregroundColor: AppColors.onInverse,
            disabledBackgroundColor: AppColors.surfacePressed,
            disabledForegroundColor: AppColors.textTertiary,
            shape: const StadiumBorder(),
          ),
          child: Text(
            _saving ? '변경 중…' : '변경하기',
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
              AuthField(
                label: 'CURRENT PASSWORD',
                controller: _current,
                password: true,
                hint: '현재 비밀번호를 입력해주세요',
                validator: (v) =>
                    v == null || v.isEmpty ? '현재 비밀번호를 입력해주세요' : null,
              ),
              const SizedBox(height: 24),
              AuthField(
                label: 'NEW PASSWORD',
                controller: _next,
                password: true,
                hint: '새 비밀번호를 입력해주세요',
                success: '영문·숫자 포함 8자 이상',
                validator: (v) {
                  final ok =
                      v != null &&
                      v.length >= 8 &&
                      RegExp('[a-zA-Z]').hasMatch(v) &&
                      RegExp('[0-9]').hasMatch(v);
                  if (!ok) return '영문·숫자 포함 8자 이상 입력해주세요';
                  if (v == _current.text) return '현재 비밀번호와 다르게 입력해주세요';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              AuthField(
                label: 'CONFIRM NEW PASSWORD',
                controller: _confirm,
                password: true,
                hint: '새 비밀번호를 다시 입력해주세요',
                action: TextInputAction.done,
                success: '비밀번호가 일치해요',
                validator: (v) => v != null && v.isNotEmpty && v == _next.text
                    ? null
                    : '비밀번호가 일치하지 않아요',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
