import 'package:flutter/material.dart';

import '../account/account_store.dart';
import '../design_system/app_colors.dart';
import '../home/main_tabs.dart';
import 'auth_ui/auth_ui.dart';
import 'sign_up/sign_up_choice.dart';
import 'sign_up/verify_email.dart';

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// 로그인 첫 화면: 소셜 계정(Apple·카카오·네이버·Google)으로 로그인하고, 이메일 로그인과 회원가입으로 갑니다.
/// 성공하면 홈(이메일 인증 전이면 인증 안내)으로 이동합니다.
class LoginPageV2 extends StatefulWidget {
  const LoginPageV2({super.key, this.store, this.onForgotPassword});

  /// 기본값은 AccountStore.instance.
  final AccountStore? store;

  /// 이메일 로그인 화면의 '비밀번호 찾기'를 바꿀 때(테스트용). 기본은 재설정 메일 보내기.
  final VoidCallback? onForgotPassword;

  @override
  State<LoginPageV2> createState() => _LoginPageV2State();
}

/// 로그인·가입이 끝난 뒤: 이메일 인증 전이면 인증 안내, 아니면 홈. 앞의 로그인 화면은 모두 닫습니다.
void _openAfterLogin(BuildContext context, AccountStore store) =>
    Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute(
        builder: (_) => store.needsVerification
            ? VerifyEmailPage(store: store)
            : const MainTabs(),
      ),
      (_) => false,
    );

class _LoginPageV2State extends State<LoginPageV2> {
  late final AccountStore _store = widget.store ?? AccountStore.instance;
  bool busy = false;

  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void _next() => _openAfterLogin(context, _store);

  void _emailLogin() => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => EmailLoginPage(
        store: widget.store,
        onForgotPassword: widget.onForgotPassword,
      ),
    ),
  );

  Future<void> register() async {
    final result = await Navigator.push<Object>(
      context,
      MaterialPageRoute(builder: (_) => SignUpChoicePage(store: _store)),
    );
    if (!mounted) return;
    // 소셜 계정으로 가입·로그인을 마쳤으면 바로 홈으로 갑니다.
    if (result is SocialSignedIn) return _next();
    if (result is! RegistrationData) return;
    final data = result;
    setState(() => busy = true);
    try {
      await _store.register(data);
      if (!mounted) return;
      _next();
    } on AuthException catch (e) {
      if (mounted) message(e.message);
    } catch (_) {
      if (mounted) message('가입하지 못했어요. 다시 시도해주세요');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthFrame(
    content: const _Brand(),
    actions: Builder(
      // 안내 메시지를 띄울 때 이 화면의 Scaffold를 찾도록 안쪽 context를 씁니다.
      builder: (inner) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SocialLoginButtons(
            verb: '로그인',
            store: widget.store,
            onSignedIn: () => _openAfterLogin(inner, _store),
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: busy ? null : _emailLogin,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
              child: const Text(
                '이메일로 로그인하기',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '아직 계정이 없나요?',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              TextButton(
                onPressed: busy ? null : register,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 36),
                ),
                child: Text(
                  busy ? '처리 중…' : '회원가입',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// 로그인 첫 화면 위쪽: 줄무늬, RUNNERY, '러 너 리 — KM BY KM'.
class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 56),
      Transform.translate(
        offset: const Offset(-24, 0),
        child: const CustomPaint(size: Size(285, 74), painter: _BrandLinesV2()),
      ),
      const SizedBox(height: 36),
      const FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          'RUNNERY',
          style: TextStyle(
            fontFamily: 'Archivo',
            fontVariations: [FontVariation('wdth', 125)],
            fontSize: 40,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.4,
          ),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Text(
            '러 너 리',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          Container(
            width: 24,
            height: 1,
            color: AppColors.borderControl,
            margin: const EdgeInsets.symmetric(horizontal: 14),
          ),
          Text(
            'KM BY KM',
            style: authLabelStyle.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    ],
  );
}

/// 이메일과 비밀번호로 로그인하는 화면. 로그인 첫 화면의 '이메일로 로그인하기'로 엽니다.
class EmailLoginPage extends StatefulWidget {
  const EmailLoginPage({super.key, this.store, this.onForgotPassword});
  final AccountStore? store;
  final VoidCallback? onForgotPassword;

  @override
  State<EmailLoginPage> createState() => _EmailLoginPageState();
}

class _EmailLoginPageState extends State<EmailLoginPage> {
  late final AccountStore _store = widget.store ?? AccountStore.instance;
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> login() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await _store.login(email.text.trim(), password.text);
      if (!mounted) return;
      _openAfterLogin(context, _store);
    } on AuthException catch (e) {
      if (mounted) message(e.message);
    } catch (_) {
      if (mounted) message('로그인하지 못했어요. 다시 시도해주세요');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// 가입한 이메일을 받아 비밀번호 재설정 메일을 보냅니다.
  Future<void> _forgotPassword() async {
    final input = await showDialog<String>(
      context: context,
      builder: (_) => _ForgotPasswordDialog(initial: email.text.trim()),
    );
    if (input == null || !mounted) return;
    if (!_emailPattern.hasMatch(input)) {
      return message('올바른 이메일을 입력해주세요');
    }
    setState(() => busy = true);
    try {
      await _store.sendPasswordReset(input);
      if (mounted) message('가입된 이메일이라면 재설정 메일을 보냈어요. 메일함을 확인해주세요');
    } on AuthException catch (e) {
      if (mounted) message(e.message);
    } catch (_) {
      if (mounted) message('메일을 보내지 못했어요. 다시 시도해주세요');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthFrame(
    content: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.zero,
              tooltip: '뒤로',
              icon: Icon(
                Icons.arrow_back_ios_new,
                size: 18,
                color: AppColors.textPrimary,
              ),
              onPressed: () => Navigator.maybePop(context),
            ),
          ),
          const SizedBox(height: 40),
          Text('LOGIN', style: authLabelStyle),
          const SizedBox(height: 12),
          Text(
            'EMAIL\nLOGIN',
            style: TextStyle(
              fontFamily: 'Archivo',
              fontVariations: [FontVariation('wdth', 125)],
              fontSize: 28,
              height: 1.04,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 40),
          AuthField(
            label: 'EMAIL',
            controller: email,
            hint: '이메일을 입력하세요',
            keyboard: TextInputType.emailAddress,
            validator: (v) => v == null || v.trim().isEmpty
                ? '이메일을 입력해주세요'
                : _emailPattern.hasMatch(v.trim())
                ? null
                : '올바른 이메일을 입력해주세요',
          ),
          const SizedBox(height: 24),
          AuthField(
            label: 'PASSWORD',
            controller: password,
            hint: '비밀번호를 입력하세요',
            password: true,
            action: TextInputAction.done,
            validator: (v) => v == null || v.isEmpty ? '비밀번호를 입력해주세요' : null,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: busy
                  ? null
                  : widget.onForgotPassword ?? _forgotPassword,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: EdgeInsets.zero,
              ),
              child: const Text(
                '비밀번호 찾기',
                style: TextStyle(
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    actions: AuthButton(
      label: busy ? '처리 중…' : '로그인',
      onPressed: busy ? null : login,
    ),
  );
}

class _BrandLinesV2 extends CustomPainter {
  const _BrandLinesV2();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textPrimary
      ..strokeWidth = 2;
    const widths = [200.0, 230.0, 245.0, 220.0, 285.0];
    for (int i = 0; i < widths.length; i++) {
      canvas.drawLine(Offset(0, i * 18.0), Offset(widths[i], i * 18.0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BrandLinesV2 oldDelegate) => false;
}

/// 비밀번호 재설정 메일을 받을 이메일을 입력받는 창. 닫을 때 입력한 이메일을 돌려줍니다.
class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({required this.initial});
  final String initial;
  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('비밀번호 찾기'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(hintText: '가입한 이메일을 입력해주세요'),
      onSubmitted: (v) => Navigator.pop(context, v.trim()),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('메일 보내기'),
      ),
    ],
  );
}

/// 앱을 켤 때 이전 로그인을 이어서 확인해 홈, 이메일 인증, 로그인 화면 중 하나를 엽니다.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.store});
  final AccountStore? store;
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AccountStore _store = widget.store ?? AccountStore.instance;
  late final Future<void> _loaded = _store.load().catchError((Object _) {});

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _loaded,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return Scaffold(backgroundColor: AppColors.background);
      }
      if (_store.isLoggedIn) return const MainTabs();
      if (_store.needsVerification) return VerifyEmailPage(store: _store);
      return LoginPageV2(store: _store);
    },
  );
}
