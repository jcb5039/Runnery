import 'package:runnery_new/account/account_store.dart';

class _FakeUser {
  _FakeUser(this.uid, this.email, this.password, this.verified);
  final String uid, email;
  String password;
  bool verified;
}

/// 테스트용 가짜 계정 서버. 메모리에만 있고, 같은 인스턴스를 여러 AccountStore가 나눠 쓰면
/// 앱을 껐다 켠 것처럼(로그인 유지) 동작합니다.
class FakeAccountBackend implements AccountBackend {
  /// 가입하면 곧바로 이메일 인증이 끝난 것으로 봅니다. false면 [verify]로 인증시킵니다.
  FakeAccountBackend({this.autoVerify = true});

  final bool autoVerify;

  /// true면 프로필 읽기가 인터넷이 없는 것처럼 실패합니다.
  bool offline = false;

  /// true면 인증 메일 발송이 서버에서 거절당한 것처럼 실패합니다.
  bool failSendVerification = false;
  int verificationsSent = 0;
  final List<String> resetsSent = [];

  final Map<String, _FakeUser> _users = {};
  final Map<String, String> _ids = {};
  final Map<String, Map<String, Object?>> _profiles = {};
  _FakeUser? _current;
  int _seq = 0;

  BackendUser _view(_FakeUser u) => BackendUser(
    uid: u.uid,
    email: u.email,
    emailVerified: u.verified,
    social:
        u.uid.startsWith('kakao:') ||
        u.uid.startsWith('naver:') ||
        _google.contains(u.uid),
  );

  /// 인증 메일의 링크를 누른 것처럼 처리합니다.
  void verify(String email) => _users[email]!.verified = true;

  @override
  Future<BackendUser?> restore() async =>
      _current == null ? null : _view(_current!);

  @override
  Future<BackendUser> signUp(String email, String password) async {
    if (_users.containsKey(email)) {
      throw const AuthException('이미 가입된 이메일이에요');
    }
    final user = _FakeUser('uid-${++_seq}', email, password, autoVerify);
    _users[email] = user;
    _current = user;
    return _view(user);
  }

  @override
  Future<BackendUser> signIn(String email, String password) async {
    final user = _users[email];
    if (user == null || user.password != password) {
      throw const AuthException('이메일 또는 비밀번호가 맞지 않아요');
    }
    _current = user;
    return _view(user);
  }

  @override
  Future<void> signOut() async => _current = null;

  /// 구글 로그인 결과로 쓸 구글 이메일. null이면 사용자가 로그인 창을 닫은 것으로 봅니다.
  String? googleEmail = 'minji@gmail.com';

  @override
  Future<BackendUser?> signInWithGoogle() async {
    final email = googleEmail;
    if (email == null) return null;
    final key = 'google:$email';
    final user = _users[key] ??= _FakeUser('uid-${++_seq}', email, '', true);
    _google.add(user.uid);
    _current = user;
    return _view(user);
  }

  /// 구글로 가입한 계정(uid). 비밀번호가 없는 소셜 계정으로 봅니다.
  final Set<String> _google = {};

  /// 네이버 로그인 결과로 쓸 네이버 회원번호. null이면 사용자가 로그인 화면을 닫은 것으로 봅니다.
  String? naverId = 'n-3003';

  @override
  Future<BackendUser?> signInWithNaver() async {
    final id = naverId;
    if (id == null) return null;
    final key = 'naver:$id';
    final user = _users[key] ??= _FakeUser(key, '', '', false);
    _current = user;
    return _view(user);
  }

  /// 카카오 로그인 결과로 쓸 카카오 회원번호. null이면 사용자가 로그인 창을 닫은 것으로 봅니다.
  String? kakaoId = '1001';

  @override
  Future<BackendUser?> signInWithKakao() async {
    final id = kakaoId;
    if (id == null) return null;
    final key = 'kakao:$id';
    final user = _users[key] ??= _FakeUser(key, '', '', false);
    _current = user;
    return BackendUser(
      uid: user.uid,
      email: '',
      emailVerified: false,
      social: true,
    );
  }

  @override
  Future<BackendUser?> reload() async =>
      _current == null ? null : _view(_current!);

  @override
  Future<void> sendVerification() async {
    if (failSendVerification) {
      throw const AuthException('인증 메일을 너무 자주 보냈어요. 몇 분 뒤에 다시 눌러주세요');
    }
    verificationsSent++;
  }

  @override
  Future<void> sendPasswordReset(String email) async => resetsSent.add(email);

  @override
  Future<void> changePassword(String current, String next) async {
    final user = _current!;
    if (user.password != current) {
      throw const AuthException('현재 비밀번호가 맞지 않아요');
    }
    user.password = next;
  }

  @override
  Future<bool> isIdAvailable(String id) async => !_ids.containsKey(id);

  @override
  Future<void> createProfile(
    String uid,
    String id,
    Map<String, Object?> profile,
  ) async {
    if (_ids.containsKey(id)) throw const AuthException('이미 사용 중인 아이디예요');
    _ids[id] = uid;
    _profiles[uid] = {...profile, 'id': id};
  }

  @override
  Future<Map<String, Object?>?> readProfile(String uid) async {
    if (offline) throw const AuthException('인터넷 연결을 확인해주세요');
    final profile = _profiles[uid];
    return profile == null ? null : {...profile};
  }

  @override
  Future<void> updateProfile(
    String uid,
    Map<String, Object?> profile, {
    String? oldId,
    String? newId,
  }) async {
    if (newId != null && newId != oldId) {
      if (_ids.containsKey(newId)) {
        throw const AuthException('이미 사용 중인 아이디예요');
      }
      _ids[newId] = uid;
      if (oldId != null) _ids.remove(oldId);
    }
    _profiles[uid] = {...?_profiles[uid], ...profile};
  }

  @override
  Future<void> deleteUser() async {
    final user = _current;
    if (user != null) {
      _users.removeWhere((_, u) => u == user);
      _profiles.remove(user.uid);
      _ids.removeWhere((_, uid) => uid == user.uid);
    }
    _current = null;
  }

  /// true면 룸메이트 이름 저장이 인터넷이 없는 것처럼 실패합니다.
  bool failMateName = false;

  @override
  Future<void> updateMateName(String uid, String name) async {
    if (failMateName) throw const AuthException('인터넷 연결을 확인해주세요');
    _profiles[uid] = {...?_profiles[uid], 'mateName': name};
  }

  /// 서버에 저장된 룸메이트 이름(확인용).
  String? mateNameOf(String uid) => _profiles[uid]?['mateName'] as String?;

  @override
  LoginMethod? get loginMethod {
    final user = _current;
    if (user == null) return null;
    if (user.uid.startsWith('kakao:')) return LoginMethod.kakao;
    if (user.uid.startsWith('naver:')) return LoginMethod.naver;
    if (_google.contains(user.uid)) return LoginMethod.google;
    return LoginMethod.email;
  }

  /// true면 탈퇴 때 소셜 로그인 화면을 닫은 것으로 봅니다.
  bool cancelReauth = false;

  /// 탈퇴 때 다시 로그인한 계정이 다른 계정인 것으로 봅니다.
  bool reauthOtherAccount = false;

  /// true면 서버가 탈퇴 처리에 실패한 것으로 봅니다(인터넷 끊김 등).
  bool failDeleteAccount = false;

  /// 탈퇴한 계정(uid).
  final List<String> deletedAccounts = [];

  @override
  Future<bool> deleteAccount({String? password}) async {
    final user = _current;
    final method = loginMethod;
    if (user == null || method == null) {
      throw const AuthException('로그인이 필요해요');
    }
    if (method == LoginMethod.email) {
      if (password == null || password.isEmpty) {
        throw const AuthException('비밀번호를 입력해주세요');
      }
      if (password != user.password) {
        throw const AuthException('비밀번호가 맞지 않아요');
      }
    } else {
      if (cancelReauth) return false;
      if (reauthOtherAccount) {
        throw const AuthException('가입한 계정으로 로그인해주세요');
      }
    }
    if (failDeleteAccount) {
      throw const AuthException('탈퇴하지 못했어요. 다시 시도해주세요');
    }
    deletedAccounts.add(user.uid);
    _google.remove(user.uid);
    await deleteUser();
    return true;
  }

  /// 서버에 이 계정의 프로필이 남아 있는지(탈퇴 확인용).
  bool hasProfile(String uid) => _profiles.containsKey(uid);
}
