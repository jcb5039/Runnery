import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../login/auth_ui/auth_ui.dart' show RegistrationData;
import '../record/data/running_record_store.dart';
import 'account_backend.dart';

export 'account_backend.dart' show AccountBackend, AuthException, BackendUser;

/// 가입할 때 입력한 정보. 비밀번호는 담지 않습니다.
@immutable
class Account {
  const Account({
    required this.name,
    required this.email,
    required this.id,
    required this.age,
    required this.gender,
    required this.weightKg,
    this.photo,
  });
  final String name, email, id, gender;
  final int age;
  final double weightKg;

  /// 프로필 사진 파일 이름(앱 Documents 폴더 안). 없으면 이름 첫 글자를 보여 줍니다.
  /// 앱을 다시 설치하면 폴더 경로가 바뀌므로 전체 경로가 아닌 파일 이름만 저장합니다.
  final String? photo;

  /// 아바타에 쓰는 이름 첫 글자.
  String get initial =>
      name.isEmpty ? '러' : String.fromCharCode(name.runes.first);
}

/// 서버(Firebase)에 있는 계정과 로그인 상태.
/// 비밀번호는 서버만 알고 이 기기에는 저장하지 않습니다. 프로필 사진만 이 기기에 둡니다.
class AccountStore extends ChangeNotifier {
  AccountStore({
    Future<Directory> Function()? directory,
    RunningRecordStore? records,
    AccountBackend? backend,
  }) : _directory = directory ?? getApplicationDocumentsDirectory,
       _records = records,
       _backend = backend;

  /// 앱 전체가 쓰는 저장소. 테스트에서만 교체합니다.
  static AccountStore instance = AccountStore();

  final Future<Directory> Function() _directory;
  final RunningRecordStore? _records;
  AccountBackend? _backend;

  /// 처음 쓸 때 실제 서버 연결을 만듭니다(테스트는 가짜를 넣어 두므로 만들지 않습니다).
  AccountBackend get backend => _backend ??= FirebaseAccountBackend();
  RunningRecordStore get records => _records ?? RunningRecordStore.instance;

  BackendUser? _user;
  Account? _account;
  String? _folderPath;

  /// 이 기기에 저장해 두는 정보. 계정(uid)별로 프로필 복사본과 사진 파일 이름을 둡니다.
  /// 복사본은 러닝 중처럼 인터넷이 없을 때도 앱을 열 수 있게 하려는 것입니다.
  final Map<String, Map<String, Object?>> _profiles = {};
  final Map<String, String> _photos = {};
  bool _loaded = false;
  Future<void> _pending = Future.value();
  DateTime? _verificationSentAt;
  String? _verificationError;

  /// 인증 메일을 마지막으로 보낸 시각. 한 번도 못 보냈으면 null.
  /// 인증 화면이 '다시 보내기' 대기 시간을 계산하는 데 씁니다.
  DateTime? get verificationSentAt => _verificationSentAt;

  /// 마지막 인증 메일 발송이 실패했다면 그 이유. 성공했으면 null.
  String? get verificationError => _verificationError;

  /// 로그인했고 이메일 인증도 끝난 상태.
  bool get isLoggedIn =>
      _user != null && _user!.emailVerified && _account != null;

  /// 로그인은 됐지만 이메일 인증을 아직 안 한 상태.
  bool get needsVerification => _user != null && !_user!.emailVerified;

  /// 인증 메일을 받는 이메일.
  String? get pendingEmail => _user?.email;

  /// 로그인한 사용자. 로그아웃 상태면 null.
  Account? get current => isLoggedIn ? _account : null;

  /// 로그인한 사용자의 서버 계정 번호. 친구 기능이 서버에서 나를 가리킬 때 씁니다.
  String? get uid => isLoggedIn ? _user!.uid : null;

  /// 로그인한 사용자의 프로필 사진 파일. 없으면 null.
  File? get photoFile {
    final photo = current?.photo, folder = _folderPath;
    return photo == null || folder == null ? null : File('$folder/$photo');
  }

  Future<File> _file() async {
    _folderPath = (await _directory()).path;
    return File('$_folderPath/account_local.json');
  }

  /// 앱을 켤 때: 이전 로그인이 남아 있으면 이어서 씁니다. 읽지 못하면 로그아웃 상태로 봅니다.
  Future<void> load() async {
    await _pending;
    if (_loaded) return;
    try {
      final file = await _file();
      await _deleteLegacyAccount(file.parent);
      await _readLocal(file);
      final user = await backend.restore();
      _user = user;
      if (user != null && user.emailVerified) {
        await _loadProfile(user);
        _startRecordSync(user);
      }
    } catch (_) {
      _user = null;
      _account = null;
    }
    _loaded = true;
    notifyListeners();
  }

  /// 서버가 없던 시절 이 기기에만 저장하던 계정 파일. 더 쓰지 않으므로 지웁니다.
  Future<void> _deleteLegacyAccount(Directory folder) async {
    final legacy = File('${folder.path}/account.json');
    try {
      if (await legacy.exists()) await legacy.delete();
    } on FileSystemException {
      // 지우지 못해도 앱 동작에는 영향이 없습니다.
    }
  }

  Future<void> _readLocal(File file) async {
    _profiles.clear();
    _photos.clear();
    try {
      if (!await file.exists()) return;
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      for (final e in (json['profiles'] as Map<String, dynamic>).entries) {
        _profiles[e.key] = Map<String, Object?>.from(e.value as Map);
      }
      for (final e in (json['photos'] as Map<String, dynamic>).entries) {
        _photos[e.key] = e.value as String;
      }
    } catch (_) {
      // 파일이 깨졌으면 비어 있는 것으로 봅니다.
      _profiles.clear();
      _photos.clear();
    }
  }

  Future<void> _writeLocal() {
    final snapshot = jsonEncode({
      'version': 2,
      'profiles': _profiles,
      'photos': _photos,
    });
    final operation = _pending.then((_) async {
      final target = await _file();
      final temporary = File('${target.path}.tmp');
      await temporary.writeAsString(snapshot, flush: true);
      await temporary.rename(target.path);
    });
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Account _toAccount(Map<String, Object?> data, BackendUser user) => Account(
    name: data['name'] as String? ?? '',
    email: user.email,
    id: data['id'] as String? ?? '',
    age: (data['age'] as num?)?.toInt() ?? 0,
    gender: data['gender'] as String? ?? '선택 안 함',
    weightKg: (data['weightKg'] as num?)?.toDouble() ?? 60,
    photo: _photos[user.uid],
  );

  /// 서버에서 프로필을 읽어 옵니다. 서버에 닿지 못하면 이 기기에 저장해 둔 복사본을 씁니다.
  Future<void> _loadProfile(BackendUser user) async {
    Map<String, Object?>? data;
    var fromServer = true;
    try {
      data = await backend.readProfile(user.uid);
    } catch (_) {
      data = _profiles[user.uid];
      fromServer = false;
      if (data == null) rethrow;
    }
    if (data == null) throw const AuthException('계정 정보를 찾지 못했어요');
    _account = _toAccount(data, user);
    if (fromServer) {
      _profiles[user.uid] = _plain(data);
      await _writeLocal();
    }
  }

  /// 파일에 저장할 수 있는 값만 남깁니다(서버 시각 같은 값은 뺍니다).
  Map<String, Object?> _plain(Map<String, Object?> data) => {
    for (final key in const ['name', 'id', 'age', 'gender', 'weightKg'])
      if (data[key] != null) key: data[key],
  };

  /// 로그인이 끝난 계정의 러닝 기록을 서버와 맞추기 시작합니다. 기다리지 않고 뒤에서 합니다.
  void _startRecordSync(BackendUser user) {
    unawaited(records.startSync(user.uid).catchError((Object _) {}));
  }

  /// 로그아웃하기 전에 쓰는 확인: 서버에 못 올린 러닝 기록을 올려 보고, 그래도 못 올린 기록 수를
  /// 돌려줍니다. 0이 아니면 지금 로그아웃할 때 그 기록이 사라집니다.
  Future<int> unsyncedRecordCount() => records.flushSync();

  /// 서버 계정을 만들고, 아이디를 차지하고, 프로필을 저장한 뒤 인증 메일을 보냅니다.
  /// 이 기기에 있던 예전 러닝 기록은 지웁니다. 이메일 인증을 마쳐야 로그인 상태가 됩니다.
  Future<void> register(RegistrationData data) async {
    final email = data.email.trim(), id = data.id.trim();
    final user = await backend.signUp(email, data.password);
    final profile = <String, Object?>{
      'name': data.name.trim(),
      'email': email,
      'id': id,
      'age': data.age,
      'gender': data.gender,
      'weightKg': data.weight,
    };
    try {
      await backend.createProfile(user.uid, id, profile);
    } catch (_) {
      await backend.deleteUser();
      rethrow;
    }
    await _sendVerification();
    try {
      await records.clear();
    } catch (_) {
      // 예전 기록을 지우지 못해도 가입은 마칩니다.
    }
    _user = user;
    _account = _toAccount(profile, user);
    _profiles[user.uid] = _plain(profile);
    await _writeLocal();
    if (user.emailVerified) _startRecordSync(user);
    notifyListeners();
  }

  /// 인증 메일을 보냅니다. 실패해도 가입·로그인은 이어 가고, 실패 이유는 [verificationError]에
  /// 남겨 인증 화면이 알려 줍니다(실패를 숨기지 않습니다).
  Future<void> _sendVerification() async {
    try {
      await backend.sendVerification();
      _verificationSentAt = DateTime.now();
      _verificationError = null;
    } on AuthException catch (e) {
      _verificationError = e.message;
    } catch (_) {
      _verificationError = '인증 메일을 보내지 못했어요';
    }
  }

  /// 이메일과 비밀번호로 로그인합니다. 인증을 안 한 계정은 [needsVerification]이 true가 되고,
  /// 이때 인증 메일을 새로 한 번 보냅니다.
  Future<void> login(String email, String password) async {
    final user = await backend.signIn(email.trim(), password);
    _user = user;
    _account = null;
    if (!user.emailVerified) {
      await _sendVerification();
    } else {
      try {
        await _loadProfile(user);
      } catch (_) {
        await _dropSession();
        rethrow;
      }
      _startRecordSync(user);
    }
    notifyListeners();
  }

  Future<void> _dropSession() async {
    try {
      await backend.signOut();
    } catch (_) {
      // 로그아웃하지 못해도 이 앱 안에서는 로그아웃 상태로 둡니다.
    }
    _user = null;
    _account = null;
  }

  /// 인증 메일의 링크를 눌렀는지 서버에서 다시 확인합니다. 인증됐으면 true.
  Future<bool> refreshVerification() async {
    final fresh = await backend.reload();
    if (fresh == null) {
      _user = null;
      _account = null;
      notifyListeners();
      return false;
    }
    _user = fresh;
    if (fresh.emailVerified) {
      if (_account == null) await _loadProfile(fresh);
      _startRecordSync(fresh);
    }
    notifyListeners();
    return fresh.emailVerified;
  }

  /// 인증 메일을 다시 보냅니다. 실패하면 이유를 담은 [AuthException]을 던집니다.
  Future<void> resendVerification() async {
    await backend.sendVerification();
    _verificationSentAt = DateTime.now();
    _verificationError = null;
    notifyListeners();
  }

  Future<void> sendPasswordReset(String email) =>
      backend.sendPasswordReset(email.trim());

  Future<void> changePassword(String current, String next) =>
      backend.changePassword(current, next);

  Future<bool> isIdAvailable(String id) => backend.isIdAvailable(id.trim());

  /// 프로필 수정 화면에서 바꾼 정보를 저장합니다. 이메일과 러닝 기록은 그대로입니다.
  /// [newPhoto]가 있으면 앱 폴더로 복사해 프로필 사진으로 쓰고, [removePhoto]면 사진을 지웁니다.
  /// 사진은 이 기기에만 저장하고 서버에는 올리지 않습니다.
  Future<void> updateProfile({
    required String name,
    required String id,
    required int age,
    required String gender,
    required double weightKg,
    File? newPhoto,
    bool removePhoto = false,
  }) async {
    final old = _account, user = _user;
    if (old == null || user == null) {
      throw const AuthException('로그인이 필요해요');
    }
    final newId = id.trim();
    final profile = <String, Object?>{
      'name': name.trim(),
      'id': newId,
      'age': age,
      'gender': gender,
      'weightKg': weightKg,
    };
    final folder = (await _file()).parent.path;
    var photo = removePhoto ? null : old.photo;
    String? copied;
    if (newPhoto != null) {
      photo = copied = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await newPhoto.copy('$folder/$photo');
    }
    try {
      await backend.updateProfile(
        user.uid,
        profile,
        oldId: old.id,
        newId: newId,
      );
    } catch (_) {
      // 서버에 저장하지 못했으면 새로 복사한 사진도 되돌립니다.
      if (copied != null) {
        try {
          await File('$folder/$copied').delete();
        } on FileSystemException {
          // 이미 없으면 그대로 둡니다.
        }
      }
      rethrow;
    }
    _account = Account(
      name: profile['name']! as String,
      email: old.email,
      id: newId,
      age: age,
      gender: gender,
      weightKg: weightKg,
      photo: photo,
    );
    _profiles[user.uid] = _plain(profile);
    if (photo == null) {
      _photos.remove(user.uid);
    } else {
      _photos[user.uid] = photo;
    }
    await _writeLocal();
    // 새 정보를 저장한 뒤에 이전 사진을 지워, 저장이 실패해도 사진이 사라지지 않게 합니다.
    if (old.photo != null && old.photo != photo) {
      try {
        await File('$folder/${old.photo}').delete();
      } on FileSystemException {
        // 이미 없으면 그대로 둡니다.
      }
    }
    notifyListeners();
  }

  /// 로그아웃합니다. 서버와 맞추던 러닝 기록은 서버에 있으므로 이 폰에서는 지워 다른 계정의 기록과
  /// 섞이지 않게 하고(다시 로그인하면 서버에서 돌아옵니다), 프로필 복사본도 지웁니다.
  /// 서버에 못 올린 기록이 있는지는 부르기 전에 [unsyncedRecordCount]로 확인합니다.
  Future<void> logout() async {
    final uid = _user?.uid;
    final hadRecordSync = records.syncActive;
    if (hadRecordSync) await records.stopSync();
    await backend.signOut();
    _user = null;
    _account = null;
    if (hadRecordSync) {
      try {
        await records.clear();
      } catch (_) {
        // 지우지 못해도 로그아웃은 끝났습니다.
      }
    }
    if (uid != null && _profiles.remove(uid) != null) {
      try {
        await _writeLocal();
      } catch (_) {
        // 복사본을 지우지 못해도 로그아웃은 끝났습니다.
      }
    }
    notifyListeners();
  }
}
