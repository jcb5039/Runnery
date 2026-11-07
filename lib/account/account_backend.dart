import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

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
  });
  final String uid, email;
  final bool emailVerified;
}

/// 계정 서버와 주고받는 부분. 앱은 Firebase 구현을 쓰고, 테스트는 가짜로 바꿔 씁니다.
abstract class AccountBackend {
  /// 앱을 켰을 때 이전 로그인이 남아 있으면 그 계정. 없으면 null.
  Future<BackendUser?> restore();
  Future<BackendUser> signUp(String email, String password);
  Future<BackendUser> signIn(String email, String password);
  Future<void> signOut();

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

  BackendUser _user(User u) => BackendUser(
    uid: u.uid,
    email: u.email ?? '',
    emailVerified: u.emailVerified,
  );

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
      _ => fallback,
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
  Future<void> signOut() => _auth.signOut();

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
}
