import 'package:flutter/material.dart';

import '../../account/account_store.dart';
import '../auth_ui/auth_ui.dart';
import 'running_info.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key, this.name = '', this.email = '', this.store});
  final String name, email;

  /// 기본값은 AccountStore.instance. 아이디가 비어 있는지 서버에 물어볼 때 씁니다.
  final AccountStore? store;
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  /// 프로필 수정 화면과 같은 규칙입니다. 서버 문서 이름으로도 쓰므로 소문자만 받습니다.
  static final _idPattern = RegExp(r'^[a-z0-9_]{4,16}$');

  late final AccountStore _store = widget.store ?? AccountStore.instance;
  final form = GlobalKey<FormState>();
  final id = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();

  /// 서버에 물어봤더니 이미 쓰고 있다고 한 아이디.
  String? _takenId;
  bool _checking = false;
  @override
  void dispose() {
    id.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> next() async {
    if (_checking || !form.currentState!.validate()) return;
    final value = id.text.trim();
    setState(() => _checking = true);
    try {
      if (!await _store.isIdAvailable(value)) {
        _takenId = value;
        form.currentState!.validate();
        return;
      }
    } on AuthException catch (e) {
      if (mounted) _message(e.message);
      return;
    } catch (_) {
      if (mounted) _message('아이디를 확인하지 못했어요. 다시 시도해주세요');
      return;
    } finally {
      if (mounted) setState(() => _checking = false);
    }
    if (!mounted) return;
    final result = await Navigator.push<RegistrationData>(
      context,
      MaterialPageRoute(
        builder: (_) => RunningInfoPage(
          name: widget.name,
          email: widget.email,
          id: id.text.trim(),
          password: password.text,
        ),
      ),
    );
    if (mounted && result != null) Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) => AuthFrame(
    content: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SignupHeading(
            step: 2,
            title: 'ACCOUNT',
            description: '앱에서 쓸 아이디와 로그인할 비밀번호를 만들어주세요',
          ),
          const SizedBox(height: 40),
          AuthField(
            label: 'ID',
            controller: id,
            hint: '아이디를 입력해주세요',
            success: '사용할 수 있는 형식이에요',
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return '아이디를 입력해주세요';
              if (!_idPattern.hasMatch(value)) {
                return '영문 소문자, 숫자, _ 로 4~16자를 입력해주세요';
              }
              if (value == _takenId) return '이미 사용 중인 아이디예요';
              return null;
            },
          ),
          const SizedBox(height: 24),
          AuthField(
            label: 'PASSWORD',
            controller: password,
            password: true,
            hint: '비밀번호를 입력해주세요',
            success: '영문·숫자 포함 8자 이상',
            validator: (v) =>
                v != null &&
                    v.length >= 8 &&
                    RegExp('[a-zA-Z]').hasMatch(v) &&
                    RegExp('[0-9]').hasMatch(v)
                ? null
                : '영문·숫자 포함 8자 이상 입력해주세요',
          ),
          const SizedBox(height: 24),
          AuthField(
            label: 'CONFIRM PASSWORD',
            controller: confirm,
            password: true,
            hint: '비밀번호를 다시 입력해주세요',
            action: TextInputAction.done,
            validator: (v) => v != null && v.isNotEmpty && v == password.text
                ? null
                : '비밀번호가 일치하지 않아요',
            success: '비밀번호가 일치해요',
          ),
        ],
      ),
    ),
    actions: AuthButton(
      label: _checking ? '확인 중…' : '다음',
      arrow: !_checking,
      onPressed: _checking ? null : next,
    ),
  );
}
