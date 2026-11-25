import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart'
    show OAuthToken, UserApi, isKakaoTalkInstalled;

import '../friends/data/friend_backend.dart';
import '../friends/data/friend_models.dart';

/// 로그인·가입 같은 계정 작업이 맞지 않을 때. [message]는 화면에 그대로 보여 줍니다.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 서버에 있는 로그인 계정.
@immutable
class BackendUser {
  const BackendUser({
    required this.uid,
    required this.email,
    required this.emailVerified,
    this.social = false,
  });
  final String uid, email;
  final bool emailVerified;

  /// 카카오·구글처럼 다른 회사 계정으로 가입한 계정. 비밀번호가 없고 이메일 인증도 하지 않습니다.
  final bool social;

  /// 앱에 들어올 수 있는 계정인지: 이메일 인증을 마쳤거나 소셜 로그인 계정.
  bool get verified => emailVerified || social;
}

/// 계정에 로그인하는 방법. 회원 탈퇴 때 본인 확인 방법이 달라집니다.
enum LoginMethod { email, google, kakao, naver }

/// 계정 서버와 주고받는 부분. 앱은 Firebase 구현을 쓰고, 테스트는 가짜로 바꿔 씁니다.
abstract class AccountBackend {
  /// 앱을 켰을 때 이전 로그인이 남아 있으면 그 계정. 없으면 null.
  Future<BackendUser?> restore();
  Future<BackendUser> signUp(String email, String password);
  Future<BackendUser> signIn(String email, String password);
  Future<void> signOut();

  /// 카카오 로그인 창을 띄우고, 서버 함수가 확인한 뒤 Firebase 계정으로 로그인합니다.
  /// 사용자가 로그인 창을 닫으면 null.
  Future<BackendUser?> signInWithKakao();

  /// 구글 로그인 창을 띄우고 그 계정으로 Firebase에 로그인합니다. 사용자가 창을 닫으면 null.
  Future<BackendUser?> signInWithGoogle();

  /// 네이버 로그인 웹 화면을 띄우고, 서버 함수가 확인한 뒤 Firebase 계정으로 로그인합니다.
  /// 사용자가 화면을 닫거나 동의하지 않으면 null.
  Future<BackendUser?> signInWithNaver();

  /// 이메일 인증을 했는지 서버에서 다시 읽어 옵니다.
  Future<BackendUser?> reload();
  Future<void> sendVerification();
  Future<void> sendPasswordReset(String email);
  Future<void> changePassword(String current, String next);

  /// 아이디가 비어 있는지. 인터넷이 없으면 [AuthException]을 던집니다.
  Future<bool> isIdAvailable(String id);

  /// 아이디를 차지하고 프로필을 만듭니다. 이미 쓰는 아이디면 [AuthException].
  Future<void> createProfile(
    String uid,
    String id,
    Map<String, Object?> profile,
  );

  /// 프로필이 서버에 없으면 null. 서버에 닿지 못하면 [AuthException].
  Future<Map<String, Object?>?> readProfile(String uid);

  /// 프로필을 고칩니다. 아이디가 바뀌면 새 아이디를 차지하고 옛 아이디를 놓습니다.
  Future<void> updateProfile(
    String uid,
    Map<String, Object?> profile, {
    String? oldId,
    String? newId,
  });

  /// 방금 만든 계정을 지우고 로그아웃합니다(가입 도중 실패했을 때 뒷정리).
  Future<void> deleteUser();

  /// 룸메이트(캐릭터) 이름을 프로필에 저장합니다.
  Future<void> updateMateName(String uid, String name);

  /// 지금 로그인한 계정의 로그인 방법. 로그아웃 상태면 null.
  LoginMethod? get loginMethod;

  /// 회원 탈퇴. 본인 확인(이메일 계정은 [password], 카카오·네이버·구글 계정은 그 로그인을 한 번 더)을 한 뒤
  /// 서버 함수가 서버 데이터와 로그인 계정을 지우고, 이 기기는 로그아웃합니다.
  /// 사용자가 로그인 화면을 닫으면 아무것도 지우지 않고 false를 돌려줍니다.
  Future<bool> deleteAccount({String? password});
}

/// Firebase(로그인) + Firestore(프로필·아이디)를 쓰는 실제 구현.
class FirebaseAccountBackend implements AccountBackend {
  static const _timeout = Duration(seconds: 15);

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  /// 아이디 하나당 문서 하나. 같은 아이디를 둘이 쓰지 못하게 막는 데 씁니다.
  DocumentReference<Map<String, dynamic>> _idDoc(String id) =>
      _db.collection('usernames').doc(id);

  /// 소셜 계정의 uid는 서버 함수가 `kakao:회원번호`처럼 만듭니다.
  static bool _isSocialUid(String uid) =>
      uid.startsWith('kakao:') || uid.startsWith('naver:');

  BackendUser _user(User u) => BackendUser(
    uid: u.uid,
    email: u.email ?? '',
    emailVerified: u.emailVerified,
    social:
        _isSocialUid(u.uid) ||
        (u.providerData.any((p) => p.providerId == 'google.com') &&
            !u.providerData.any((p) => p.providerId == 'password')),
  );

  /// 구글 로그인 설정. 안드로이드가 Firebase용 확인 표를 받으려면 웹 클라이언트 ID가 필요합니다.
  /// 아이폰 클라이언트 ID는 Info.plist(GIDClientID)에서 읽습니다. 둘 다 공개 값입니다.
  static const _googleServerClientId =
      '1007882678480-kdrt37uup07fh5mkqjs2rhs9q01pq10t.apps.googleusercontent.com';
  static Future<void>? _googleReady;

  /// 서버 오류를 화면에 보여 줄 한국어 안내로 바꿉니다.
  static AuthException _error(
    Object e, {
    String fallback = '처리하지 못했어요. 다시 시도해주세요',
  }) {
    if (e is AuthException) return e;
    if (e is TimeoutException) {
      return const AuthException('인터넷 연결을 확인해주세요');
    }
    final code = e is FirebaseException ? e.code : '';
    return AuthException(switch (code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' ||
      'invalid-login-credentials' => '이메일 또는 비밀번호가 맞지 않아요',
      'invalid-email' => '올바른 이메일을 입력해주세요',
      'email-already-in-use' => '이미 가입된 이메일이에요',
      'weak-password' => '비밀번호가 너무 쉬워요. 더 복잡하게 만들어주세요',
      'user-disabled' => '사용할 수 없는 계정이에요',
      'too-many-requests' => '요청이 너무 많아요. 잠시 후 다시 시도해주세요',
      'network-request-failed' ||
      'unavailable' ||
      'deadline-exceeded' => '인터넷 연결을 확인해주세요',
      'permission-denied' => '권한이 없어요. 잠시 후 다시 시도해주세요',
      'requires-recent-login' => '다시 로그인한 뒤 시도해주세요',
      // 처음 보는 오류는 원인을 찾을 수 있게 오류 이름을 붙여요.
      _ => '$fallback (${code.isNotEmpty ? code : e.runtimeType})',
    });
  }

  @override
  Future<BackendUser?> restore() async {
    final user = await _auth.authStateChanges().first.timeout(
      const Duration(seconds: 5),
    );
    if (user == null) return null;
    try {
      await user.reload().timeout(const Duration(seconds: 5));
    } on FirebaseAuthException catch (e) {
      // 계정이 지워졌거나 막힌 경우에만 로그아웃합니다. 인터넷이 없으면 저장된 상태를 씁니다.
      if (e.code == 'user-not-found' ||
          e.code == 'user-disabled' ||
          e.code == 'user-token-expired') {
        await _auth.signOut();
        return null;
      }
    } on TimeoutException {
      // 느린 네트워크에서는 저장된 상태를 그대로 씁니다.
    }
    final fresh = _auth.currentUser;
    return fresh == null ? null : _user(fresh);
  }

  @override
  Future<BackendUser> signUp(String email, String password) async {
    try {
      final credential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password)
          .timeout(_timeout);
      return _user(credential.user!);
    } catch (e) {
      throw _error(e, fallback: '가입하지 못했어요. 다시 시도해주세요');
    }
  }

  @override
  Future<BackendUser> signIn(String email, String password) async {
    try {
      final credential = await _auth
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(_timeout);
      return _user(credential.user!);
    } catch (e) {
      throw _error(e, fallback: '로그인하지 못했어요. 다시 시도해주세요');
    }
  }

  @override
  Future<void> signOut() async {
    // 카카오·구글 쪽 로그인도 끊어, 다음에 다른 계정을 고를 수 있게 합니다.
    try {
      await UserApi.instance.logout();
    } catch (_) {
      // 카카오로 로그인하지 않았거나 이미 끊겼으면 그대로 둡니다.
    }
    try {
      if (_googleReady != null) await GoogleSignIn.instance.signOut();
    } catch (_) {
      // 구글로 로그인하지 않았으면 그대로 둡니다.
    }
    await _auth.signOut();
  }

  @override
  Future<BackendUser?> signInWithKakao() async {
    final String accessToken;
    try {
      final token = await _kakaoToken();
      if (token == null) return null;
      accessToken = token.accessToken;
    } catch (_) {
      throw const AuthException('카카오 로그인을 하지 못했어요. 다시 시도해주세요');
    }
    try {
      final result =
          await FirebaseFunctions.instanceFor(region: 'asia-northeast3')
              .httpsCallable('kakaoLogin')
              .call<Map<String, dynamic>>({'accessToken': accessToken})
              .timeout(_timeout);
      final customToken = result.data['customToken'] as String;
      final credential = await _auth
          .signInWithCustomToken(customToken)
          .timeout(_timeout);
      return _user(credential.user!);
    } on FirebaseFunctionsException catch (e) {
      throw AuthException(e.message ?? '카카오 로그인을 확인하지 못했어요');
    } catch (e) {
      throw _error(e, fallback: '카카오 로그인을 하지 못했어요. 다시 시도해주세요');
    }
  }

  /// 구글 로그인 창을 띄워 구글 확인 표(idToken)를 받습니다. 창을 닫으면 null.
  static Future<String?> _googleIdToken() async {
    try {
      await (_googleReady ??= GoogleSignIn.instance.initialize(
        serverClientId: _googleServerClientId,
      ));
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null) throw const AuthException('구글 로그인을 하지 못했어요');
      return token;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw const AuthException('구글 로그인을 하지 못했어요. 다시 시도해주세요');
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException('구글 로그인을 하지 못했어요. 다시 시도해주세요');
    }
  }

  @override
  Future<BackendUser?> signInWithGoogle() async {
    final idToken = await _googleIdToken();
    if (idToken == null) return null;
    try {
      final credential = await _auth
          .signInWithCredential(GoogleAuthProvider.credential(idToken: idToken))
          .timeout(_timeout);
      return _user(credential.user!);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        throw const AuthException('이미 이메일로 가입한 주소예요. 이메일로 로그인해주세요');
      }
      throw _error(e, fallback: '구글 로그인을 하지 못했어요. 다시 시도해주세요');
    } catch (e) {
      throw _error(e, fallback: '구글 로그인을 하지 못했어요. 다시 시도해주세요');
    }
  }

  /// 네이버 로그인: Client ID는 공개 값이고, 비밀 키는 서버 함수에만 있습니다.
  static const _naverClientId = '16Yu9d6lDo16Rl8g1rlM';
  static const _naverCallback =
      'https://asia-northeast3-runnery-f0faf.cloudfunctions.net/naverCallback';
  static const _naverAppScheme = 'runnerynaverlogin';

  @override
  Future<BackendUser?> signInWithNaver() async {
    final verifier = await _naverVerifier();
    if (verifier == null) return null;
    try {
      final result =
          await FirebaseFunctions.instanceFor(region: 'asia-northeast3')
              .httpsCallable('naverFinish')
              .call<Map<String, dynamic>>({'verifier': verifier})
              .timeout(_timeout);
      final credential = await _auth
          .signInWithCustomToken(result.data['customToken'] as String)
          .timeout(_timeout);
      return _user(credential.user!);
    } on FirebaseFunctionsException catch (e) {
      throw AuthException(e.message ?? '네이버 로그인을 확인하지 못했어요');
    } catch (e) {
      throw _error(e, fallback: '네이버 로그인을 하지 못했어요. 다시 시도해주세요');
    }
  }

  /// 네이버 로그인 웹 화면을 띄우고, 끝나면 서버에 결과를 받으러 갈 확인 값(verifier)을 돌려줍니다.
  /// 화면을 닫거나 동의하지 않으면 null.
  static Future<String?> _naverVerifier() async {
    // 앱만 아는 확인 값. 서버에는 이 값의 SHA-256(state)만 먼저 보내고, 로그인 표는 확인 값을 보내야 받습니다.
    final random = Random.secure();
    final verifier = base64UrlEncode([
      for (var i = 0; i < 32; i++) random.nextInt(256),
    ]).replaceAll('=', '');
    final state = sha256.convert(utf8.encode(verifier)).toString();
    final url = Uri.https('nid.naver.com', '/oauth2.0/authorize', {
      'response_type': 'code',
      'client_id': _naverClientId,
      'redirect_uri': _naverCallback,
      'state': state,
    }).toString();
    final Uri back;
    try {
      back = Uri.parse(
        await FlutterWebAuth2.authenticate(
          url: url,
          callbackUrlScheme: _naverAppScheme,
        ),
      );
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') return null;
      throw const AuthException('네이버 로그인을 하지 못했어요. 다시 시도해주세요');
    } catch (_) {
      throw const AuthException('네이버 로그인을 하지 못했어요. 다시 시도해주세요');
    }
    final error = back.queryParameters['error'];
    if (error == 'cancel') return null;
    if (error != null || back.queryParameters['state'] != state) {
      throw const AuthException('네이버 로그인을 하지 못했어요. 다시 시도해주세요');
    }
    return verifier;
  }

  /// 카카오톡이 깔려 있으면 카카오톡으로, 아니면 카카오 계정 화면으로 로그인합니다. 닫으면 null.
  static Future<OAuthToken?> _kakaoToken() async {
    bool cancelled(Object e) => e is PlatformException && e.code == 'CANCELED';
    if (await isKakaoTalkInstalled()) {
      try {
        return await UserApi.instance.loginWithKakaoTalk();
      } catch (e) {
        if (cancelled(e)) return null;
        // 카카오톡에 연결된 계정이 없으면 카카오 계정 화면으로 이어 갑니다.
      }
    }
    try {
      return await UserApi.instance.loginWithKakaoAccount();
    } catch (e) {
      if (cancelled(e)) return null;
      rethrow;
    }
  }

  @override
  Future<BackendUser?> reload() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      await user.reload().timeout(_timeout);
      // 서버 규칙이 인증 여부를 보도록 로그인 증표도 새로 받습니다.
      await _auth.currentUser?.getIdToken(true);
    } catch (e) {
      throw _error(e, fallback: '인증 여부를 확인하지 못했어요');
    }
    final fresh = _auth.currentUser;
    return fresh == null ? null : _user(fresh);
  }

  @override
  Future<void> sendVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException('로그인이 필요해요');
    try {
      await user.sendEmailVerification().timeout(_timeout);
    } on FirebaseAuthException catch (e) {
      // 같은 주소로 짧은 시간에 여러 번 보내면 서버가 막습니다(가입자 수와 상관없습니다).
      if (e.code == 'too-many-requests') {
        throw const AuthException('인증 메일을 너무 자주 보냈어요. 몇 분 뒤에 다시 눌러주세요');
      }
      throw _error(e, fallback: '인증 메일을 보내지 못했어요');
    } catch (e) {
      throw _error(e, fallback: '인증 메일을 보내지 못했어요');
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email).timeout(_timeout);
    } on FirebaseAuthException catch (e) {
      // 가입 여부를 알려 주지 않으려고, 없는 이메일도 보낸 것처럼 처리합니다.
      if (e.code == 'user-not-found') return;
      throw _error(e, fallback: '메일을 보내지 못했어요');
    } catch (e) {
      throw _error(e, fallback: '메일을 보내지 못했어요');
    }
  }

  @override
  Future<void> changePassword(String current, String next) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AuthException('로그인이 필요해요');
    }
    try {
      await user
          .reauthenticateWithCredential(
            EmailAuthProvider.credential(email: email, password: current),
          )
          .timeout(_timeout);
      await user.updatePassword(next).timeout(_timeout);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw const AuthException('현재 비밀번호가 맞지 않아요');
      }
      throw _error(e, fallback: '비밀번호를 바꾸지 못했어요');
    } catch (e) {
      throw _error(e, fallback: '비밀번호를 바꾸지 못했어요');
    }
  }

  @override
  Future<bool> isIdAvailable(String id) async {
    try {
      // 인터넷이 없을 때 옛 정보로 '비어 있다'고 잘못 답하지 않도록 서버에서만 읽습니다.
      final snapshot = await _idDoc(id)
          .get(const GetOptions(source: Source.server))
          .timeout(_timeout);
      return !snapshot.exists;
    } catch (e) {
      throw _error(e, fallback: '아이디를 확인하지 못했어요. 다시 시도해주세요');
    }
  }

  @override
  Future<void> createProfile(
    String uid,
    String id,
    Map<String, Object?> profile,
  ) async {
    try {
      await _db
          .runTransaction((transaction) async {
            if ((await transaction.get(_idDoc(id))).exists) {
              throw const AuthException('이미 사용 중인 아이디예요');
            }
            transaction.set(_idDoc(id), {'uid': uid});
            transaction.set(_userDoc(uid), {
              ...profile,
              'id': id,
              'createdAt': FieldValue.serverTimestamp(),
            });
          })
          .timeout(_timeout);
    } catch (e) {
      throw _error(e, fallback: '계정 정보를 저장하지 못했어요. 다시 시도해주세요');
    }
  }

  @override
  Future<Map<String, Object?>?> readProfile(String uid) async {
    try {
      final snapshot = await _userDoc(uid)
          .get()
          .timeout(const Duration(seconds: 8));
      return snapshot.data();
    } catch (e) {
      throw _error(e, fallback: '계정 정보를 불러오지 못했어요');
    }
  }

  @override
  Future<void> updateProfile(
    String uid,
    Map<String, Object?> profile, {
    String? oldId,
    String? newId,
  }) async {
    try {
      await _db
          .runTransaction((transaction) async {
            if (newId != null && newId != oldId) {
              if ((await transaction.get(_idDoc(newId))).exists) {
                throw const AuthException('이미 사용 중인 아이디예요');
              }
              transaction.set(_idDoc(newId), {'uid': uid});
              if (oldId != null) transaction.delete(_idDoc(oldId));
            }
            transaction.update(_userDoc(uid), profile);
          })
          .timeout(_timeout);
    } catch (e) {
      throw _error(e, fallback: '저장하지 못했어요. 다시 시도해주세요');
    }
    // 친구 찾기에 바뀐 이름·아이디가 보이게 합니다. 실패해도 친구 탭을 열 때 다시 올립니다.
    final name = profile['name'], id = profile['id'];
    if (name is String && id is String) {
      try {
        await FirebaseFriendBackend().publishProfile(
          PublicProfile(uid: uid, name: name, id: id),
        );
      } catch (_) {
        // 프로필 저장은 이미 끝났습니다.
      }
    }
  }

  @override
  Future<void> deleteUser() async {
    try {
      await _auth.currentUser?.delete();
    } catch (_) {
      // 지우지 못해도 로그아웃은 합니다.
    } finally {
      await _auth.signOut();
    }
  }

  @override
  Future<void> updateMateName(String uid, String name) async {
    try {
      await _userDoc(uid).update({'mateName': name}).timeout(_timeout);
    } catch (e) {
      throw _error(e, fallback: '이름을 저장하지 못했어요. 다시 시도해주세요');
    }
  }

  @override
  LoginMethod? get loginMethod {
    final u = _auth.currentUser;
    if (u == null) return null;
    if (u.uid.startsWith('kakao:')) return LoginMethod.kakao;
    if (u.uid.startsWith('naver:')) return LoginMethod.naver;
    final google = u.providerData.any((p) => p.providerId == 'google.com');
    final password = u.providerData.any((p) => p.providerId == 'password');
    return google && !password ? LoginMethod.google : LoginMethod.email;
  }

  @override
  Future<bool> deleteAccount({String? password}) async {
    final user = _auth.currentUser;
    final method = loginMethod;
    if (user == null || method == null) {
      throw const AuthException('로그인이 필요해요');
    }
    // 본인 확인. 이메일·구글은 Firebase에서 다시 로그인해 로그인 시각을 새로 만들고(서버가 5분 안인지 봅니다),
    // 카카오·네이버는 방금 받은 로그인 결과를 서버 함수에 보내 서버가 같은 계정인지 직접 확인합니다.
    final data = <String, Object?>{};
    switch (method) {
      case LoginMethod.email:
        final email = user.email;
        if (email == null || password == null || password.isEmpty) {
          throw const AuthException('비밀번호를 입력해주세요');
        }
        try {
          await user
              .reauthenticateWithCredential(
                EmailAuthProvider.credential(email: email, password: password),
              )
              .timeout(_timeout);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
            throw const AuthException('비밀번호가 맞지 않아요');
          }
          throw _error(e, fallback: '본인 확인을 하지 못했어요. 다시 시도해주세요');
        } catch (e) {
          throw _error(e, fallback: '본인 확인을 하지 못했어요. 다시 시도해주세요');
        }
      case LoginMethod.google:
        final idToken = await _googleIdToken();
        if (idToken == null) return false;
        try {
          await user
              .reauthenticateWithCredential(
                GoogleAuthProvider.credential(idToken: idToken),
              )
              .timeout(_timeout);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'user-mismatch') {
            throw const AuthException('가입한 구글 계정으로 로그인해주세요');
          }
          throw _error(e, fallback: '본인 확인을 하지 못했어요. 다시 시도해주세요');
        } catch (e) {
          throw _error(e, fallback: '본인 확인을 하지 못했어요. 다시 시도해주세요');
        }
      case LoginMethod.kakao:
        final OAuthToken? token;
        try {
          token = await _kakaoToken();
        } catch (_) {
          throw const AuthException('카카오 로그인을 하지 못했어요. 다시 시도해주세요');
        }
        if (token == null) return false;
        data['kakaoAccessToken'] = token.accessToken;
      case LoginMethod.naver:
        final verifier = await _naverVerifier();
        if (verifier == null) return false;
        data['naverVerifier'] = verifier;
    }
    try {
      await FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable(
            'deleteAccount',
            options: HttpsCallableOptions(timeout: const Duration(minutes: 5)),
          )
          .call<Map<String, dynamic>>(data);
    } on FirebaseFunctionsException catch (e) {
      // 다른 카카오 계정으로 로그인했다면 그 카카오 로그인은 끊어 둡니다(러너리 로그인은 그대로).
      if (method == LoginMethod.kakao) await _kakaoLogout();
      throw AuthException(e.message ?? '탈퇴하지 못했어요. 다시 시도해주세요');
    } catch (e) {
      if (method == LoginMethod.kakao) await _kakaoLogout();
      throw _error(e, fallback: '탈퇴하지 못했어요. 다시 시도해주세요');
    }
    // 서버에서 계정을 지웠습니다. 카카오는 우리 앱과의 연결도 끊습니다(실패해도 탈퇴는 끝났습니다).
    if (method == LoginMethod.kakao) {
      try {
        await UserApi.instance.unlink();
      } catch (_) {
        // 이미 끊겼거나 카카오에 닿지 못했으면 그대로 둡니다.
      }
    }
    try {
      await signOut();
    } catch (_) {
      // 계정이 이미 지워져 로그아웃이 실패해도 이 기기는 로그아웃 상태로 봅니다.
    }
    return true;
  }

  static Future<void> _kakaoLogout() async {
    try {
      await UserApi.instance.logout();
    } catch (_) {
      // 카카오 로그인이 없으면 그대로 둡니다.
    }
  }
}
