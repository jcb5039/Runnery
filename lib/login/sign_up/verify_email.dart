import 'dart:async';

import 'package:flutter/material.dart';

import '../../account/account_store.dart';
import '../../design_system/app_colors.dart';
import '../../home/main_tabs.dart';
import '../auth_ui/auth_ui.dart';
import '../login.dart';

/// 가입 직후나 인증 전 로그인 때 보여 주는 이메일 인증 안내. 인증이 끝나면 홈으로 이동합니다.
class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key, this.store});

  /// 기본값은 AccountStore.instance.
  final AccountStore? store;
  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  /// 메일을 연달아 보내면 서버가 막으므로, 다시 보내기 사이에 둘 간격(초).
  static const _resendSeconds = 60;

  late final AccountStore _store = widget.store ?? AccountStore.instance;
  Timer? _timer;
  int _cooldown = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // 방금(가입·로그인 때) 메일을 보냈다면 남은 대기 시간만큼 '다시 보내기'를 잠급니다.
    final sentAt = _store.verificationSentAt;
    if (sentAt != null) {
      final left = _resendSeconds - DateTime.now().difference(sentAt).inSeconds;
      if (left > 0) {
        _cooldown = left;
        _startTimer();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _check() async {
    setState(() => _busy = true);
    try {
      final verified = await _store.refreshVerification();
      if (!mounted) return;
      if (verified) {
        Navigator.of(context).pushReplacement<void, void>(
          MaterialPageRoute(builder: (_) => const MainTabs()),
        );
      } else {
        _message('아직 인증되지 않았어요. 메일의 링크를 눌러주세요');
      }
    } on AuthException catch (e) {
      if (mounted) _message(e.message);
    } catch (_) {
      if (mounted) _message('확인하지 못했어요. 다시 시도해주세요');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _busy = true);
    try {
      await _store.resendVerification();
      if (!mounted) return;
      _message('인증 메일을 다시 보냈어요');
      _startCooldown(_resendSeconds);
    } on AuthException catch (e) {
      if (mounted) _message(e.message);
    } catch (_) {
      if (mounted) _message('메일을 보내지 못했어요. 다시 시도해주세요');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startCooldown(int seconds) {
    setState(() => _cooldown = seconds);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _cooldown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _cooldown = 0);
        return;
      }
      setState(() => _cooldown--);
    });
  }

  Future<void> _useOtherAccount() async {
    await _store.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute(builder: (_) => LoginPageV2(store: _store)),
    );
  }

  @override
  Widget build(BuildContext context) => AuthFrame(
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 44),
        Text('EMAIL VERIFICATION', style: authLabelStyle),
        const SizedBox(height: 12),
        Text(
          'VERIFY\nEMAIL',
          style: TextStyle(
            fontFamily: 'Archivo',
            fontVariations: [FontVariation('wdth', 125)],
            fontSize: 28,
            height: 1.04,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '이메일 인증을 마치면 러너리를 쓸 수 있어요',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '인증 메일을 보낸 곳',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
              const SizedBox(height: 6),
              Text(
                _store.pendingEmail ?? '',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (_store.verificationError != null) ...[
                Text(
                  '인증 메일을 보내지 못했어요: ${_store.verificationError}\n아래 \'메일 다시 보내기\'를 눌러주세요.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                '메일의 링크를 누른 뒤, 돌아와서 아래 \'인증했어요\' 버튼을 눌러주세요. 메일이 도착하기까지 몇 분 걸릴 수 있어요. 스팸 메일함과 프로모션 탭도 확인해주세요.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    actions: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthButton(
          label: _busy ? '확인 중…' : '인증했어요',
          onPressed: _busy ? null : _check,
        ),
        const SizedBox(height: 12),
        AuthButton(
          label: _cooldown > 0 ? '메일 다시 보내기 ($_cooldown초)' : '메일 다시 보내기',
          outlined: true,
          onPressed: _busy || _cooldown > 0 ? null : _resend,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy ? null : _useOtherAccount,
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          child: const Text(
            '다른 계정으로 로그인',
            style: TextStyle(
              fontSize: 12,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    ),
  );
}
