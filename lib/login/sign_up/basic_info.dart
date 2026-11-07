import 'package:flutter/material.dart';

import '../../account/account_store.dart';
import '../auth_ui/auth_ui.dart';
import 'account.dart';

class BasicInfoPage extends StatefulWidget {
  const BasicInfoPage({super.key, this.store});

  /// 기본값은 AccountStore.instance. 다음 화면(아이디 확인)에 그대로 넘깁니다.
  final AccountStore? store;
  @override
  State<BasicInfoPage> createState() => _BasicInfoPageState();
}

class _BasicInfoPageState extends State<BasicInfoPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    super.dispose();
  }

  Future<void> next() async {
    if (!form.currentState!.validate()) return;
    final result = await Navigator.push<RegistrationData>(
      context,
      MaterialPageRoute(
        builder: (_) => AccountPage(
          name: name.text.trim(),
          email: email.text.trim(),
          store: widget.store,
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
            step: 1,
            title: 'BASIC\nINFORMATION',
            description: '러너리에서 사용할 이름과 이메일을 알려주세요',
          ),
          const SizedBox(height: 40),
          AuthField(
            label: 'NAME',
            controller: name,
            hint: '이름을 입력해주세요',
            validator: (v) =>
                v == null || v.trim().isEmpty ? '이름을 입력해주세요' : null,
          ),
          const SizedBox(height: 24),
          AuthField(
            label: 'EMAIL',
            controller: email,
            hint: '이메일을 입력해주세요',
            keyboard: TextInputType.emailAddress,
            action: TextInputAction.done,
            validator: (v) =>
                RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v?.trim() ?? '')
                ? null
                : '올바른 이메일을 입력해주세요',
            success: '올바른 이메일 형식이에요',
          ),
        ],
      ),
    ),
    actions: AuthButton(label: '다음', arrow: true, onPressed: next),
  );
}
