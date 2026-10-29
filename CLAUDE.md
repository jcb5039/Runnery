# CLAUDE.md

이 파일은 이 저장소에서 작업하는 Claude Code를 위한 안내서입니다.

## 대화 방식

- 모든 대답과 설명은 한국어로 합니다.
- 불필요한 인사말 없이 바로 답합니다.
- 불필요한 수식어를 사용하지 않습니다.
- 간단한 질문은 짧게, 복잡한 작업은 충분히 자세히 답합니다.
- 확실하지 않은 사실, 날짜, 수치, 출처는 먼저 불확실하다고 말합니다.
- 사용자는 코드를 직접 읽지 못합니다. 설명은 코드 대신 "어떤 화면에서 무엇이 바뀌는지" 기준으로, 전문용어 없이 쉬운 한국어로 합니다.


## 변경 통제

- 현재 요청을 처리하는 데 꼭 필요한 파일과 코드만 수정합니다.
- 요청과 직접 관련 없는 수정(정리, 리팩터링, 다른 버그 수정)은 하지 말고, 필요해 보이면 먼저 물어봅니다.
- 큰 변경, 파일 삭제, 덮어쓰기는 먼저 무엇을 바꿀지 설명하고 확인을 받습니다.
- 수정 후 `flutter analyze`로 오류가 없는지 확인합니다.
- 작업이 끝나면 수정한 파일 목록, 각 파일을 고친 이유, 사용자가 직접 확인해야 할 점을 짧게 정리합니다.

## 고위험 행동 차단

- 패키지 추가·삭제, 로컬 저장 데이터 구조 변경, 외부 전송, 삭제처럼 되돌리기 어려운 행동은 먼저 확인을 받습니다.

## 보안 및 개인정보 보호

- API 키, 비밀번호, 인증 토큰 등의 민감한 정보를 코드에 직접 작성하지 않는다.
- 민감한 인증 정보를 GitHub에 업로드하지 않는다.
- Firebase 설정 파일(`firebase_options.dart`, `google-services.json`)은 공개용 키이므로 예외로 둔다. 관리자 키, 서명 키, 비밀번호, 토큰은 절대 올리지 않는다.
- 아이폰 서명 설정(`ios/Runner.xcodeproj/project.pbxproj`의 `DEVELOPMENT_TEAM`, 개인 계정용으로 바꾼 `PRODUCT_BUNDLE_IDENTIFIER`)은 각자 맥에만 두고 GitHub에 올리지 않는다. 사람마다 Apple 계정이 달라 올리면 서로 설치가 꼬인다. 커밋할 때 이 변경이 섞이지 않았는지 확인한다.
- Firebase 보안 규칙을 임의로 완화하지 않는다.
- 개인정보와 인증 서류는 권한이 없는 사용자가 접근하지 못하도록 설계한다.
- 개인정보가 포함된 실제 데이터를 테스트에 사용하지 않는다.
- 보안 문제가 발견되면 임의로 우회하지 않고 먼저 보고한다.

## 기억과 연속성

- 중요한 결정은 저장소 맨 위의 [MEMORY.md](MEMORY.md)에 날짜와 함께 남깁니다.
- 세션을 끝낼 때 완료한 일, 진행 중인 일, 다음 할 일을 요약합니다.

## 명령어

Flutter 앱(Dart SDK ^3.13.3)이며 UI는 한국어("러너리 / RUNNERY")입니다. `analysis_options.yaml`에서 플랫폼 폴더를 제외하므로 `lib/`와 `test/`만 분석합니다.

```
flutter pub get
flutter run
flutter analyze
flutter test                                # 전체 테스트
flutter test test/record_storage_test.dart  # 파일 하나
flutter test --plain-name "some test name"  # 테스트 하나
```

## 아키텍처

- **상태 관리 패키지와 라우터가 없습니다.** 화면 이동은 일반 `Navigator` push를 쓰고, 상태는 `ChangeNotifier` 싱글턴이 들고 있습니다. 계정과 기록은 **Firebase(로그인·Firestore)와 기기 파일을 함께** 씁니다. 서버 연결은 `AccountBackend`·`RecordBackend`로 분리돼 있어, 생성자에 디렉터리(`Future<Directory> Function()`)와 서버 연결을 주입할 수 있습니다. 테스트에서는 임시 디렉터리와 가짜 서버(`test/support/fake_account_backend.dart`, `fake_record_backend.dart`)를 씁니다. 서버 연결 Dart 코드는 안드로이드·아이폰이 함께 쓰고, 플랫폼별로 다른 것은 설정 파일(`android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`)뿐입니다.
  - `AccountStore` ([lib/account/account_store.dart](lib/account/account_store.dart)): 서버(Firebase Auth)의 계정과 로그인 상태를 관리합니다. 이메일+비밀번호로 가입·로그인하고 **이메일 인증을 마쳐야** 앱에 들어갑니다(`isLoggedIn`, 인증 전은 `needsVerification`). 아이디는 로그인용이 아니라 앱 안에서 보이는 이름이며 Firestore `usernames/{아이디}` 문서로 중복을 막습니다. 프로필(이름·아이디·나이·성별·체중)은 Firestore `users/{uid}`에 저장하고, 인터넷이 없어도 앱을 열 수 있게 기기 `account_local.json`에 복사본을 둡니다. 프로필 사진은 기기에만 저장하고 서버에 올리지 않습니다. 비밀번호는 기기에 저장하지 않습니다. 서버와 주고받는 부분은 `AccountBackend`([lib/account/account_backend.dart](lib/account/account_backend.dart))에 있습니다.
  - `RunningRecordStore` ([lib/record/data/running_record_store.dart](lib/record/data/running_record_store.dart)): 러닝 한 번당 JSON 파일 하나를 `<documents>/running_records/`에 **항상 기기에 먼저** 저장합니다. 임시 파일에 먼저 쓴 뒤 게시하며, 작업은 `_pending` future 체인으로 직렬화됩니다. 로그인한 계정의 기록은 `RecordSync`([lib/record/data/record_sync.dart](lib/record/data/record_sync.dart))가 서버 `users/{uid}/records/{기록 번호}`와 맞춥니다(본문은 gzip으로 압축한 한 덩어리, [lib/record/data/record_backend.dart](lib/record/data/record_backend.dart)). 저장·수정·삭제는 '올릴 일'로 적어 두고(`record_sync.json`) 올리며, 인터넷이 없으면 나중에 올립니다. 지운 기록은 서버에서 문서를 지우지 않고 지운 표시만 남겨 다른 폰이 알게 합니다. 로그인·앱 시작·기록 탭을 열 때 서버의 새 변경을 가져옵니다. 로그아웃하면 서버와 맞추던 폰 기록을 지우고(못 올린 기록이 있으면 먼저 경고), 다시 로그인하면 서버에서 돌아옵니다. 목록 썸네일 지도 사진은 서버에 올리지 않고 폰에서 새로 만듭니다.
  - 서버 보안 규칙은 [firestore.rules](firestore.rules)에 있고 `firebase deploy --only firestore:rules --project runnery-f0faf`로 올립니다. 규칙을 바꾸거나 올릴 때는 사용자에게 먼저 확인받습니다.
- **시작 흐름:** `main.dart`(Firebase 초기화, 실패해도 앱은 켜짐) → `AppStartPage`(스플래시, [lib/app_start.dart](lib/app_start.dart)) → `AuthGate`(`lib/login/login.dart`) → 로그인 / 이메일 인증 안내(`lib/login/sign_up/verify_email.dart`) / `HomePage`. `main()`은 `RecordRouteMap.basemapEnabled = true`를 설정합니다(기록 상세의 MapLibre 베이스맵). 기본값은 `false`라서 위젯 테스트에서 네이티브 지도가 생성되지 않습니다.
- **러닝 파이프라인:** `home/running/running_start_page.dart`(`geolocator`로 GPS 수집, wakelock, 정확도·흔들림 필터링과 햇반 칼로리 단위를 담은 `RunningConfig`) → `running_result_page.dart` → `record/data/record_from_session.dart`가 세션 결과를 저장용 `RunningRecord` 모델(`record/models/`)로 변환합니다. 지도 렌더링은 `maplibre_gl`을 씁니다.
- **기록 UI:** 기록 탭은 [lib/record/list/record_list_page.dart](lib/record/list/record_list_page.dart)의 `RecordListPageV2`를 사용합니다(스와이프 삭제 포함). 상세 화면은 `record/list/detail/record_detail_page.dart`이며 우측 상단 메뉴에서 메모 수정·기록 삭제를 합니다. [docs/record-v2.md](docs/record-v2.md)는 병합 전 작업 보고라 `record_list_page_1.dart` 등 지금과 다른 파일 이름이 나옵니다.
- **친구 탭:** `lib/friends/`. 상태는 `FriendStore`([lib/friends/data/friend_store.dart](lib/friends/data/friend_store.dart)) 싱글턴이 들고, 서버 연결은 `FriendBackend`([lib/friends/data/friend_backend.dart](lib/friends/data/friend_backend.dart))입니다(테스트는 `test/support/fake_friend_backend.dart`). 서버에는 공개 정보 `profiles/{uid}`, 친구 요청 `friendRequests/{보낸_받는}`, 친구 목록 `users/{uid}/friends/{친구 uid}`, 공유한 기록 `users/{uid}/posts/{기록 번호}`(응원은 그 아래 `cheers/{uid}`), 공유 설정 `users/{uid}/settings/share`, 주간 목표 `users/{uid}/settings/goal`, 랭킹용 합계 `users/{uid}/stats/summary`, 함께 달리기 약속 `together/{번호}`가 있고 폰에는 저장하지 않습니다. 기록 공유는 `RecordShare`([lib/friends/data/record_share.dart](lib/friends/data/record_share.dart))가 맡습니다. 랭킹·목표 계산은 [lib/friends/data/ranking.dart](lib/friends/data/ranking.dart)에 있습니다. 함께 달리기는 `TogetherStore`([lib/friends/data/together_store.dart](lib/friends/data/together_store.dart))와 대기실([lib/friends/together/together_lobby_page.dart](lib/friends/together/together_lobby_page.dart))이 맡고, 대기실에서 시작한 러닝은 `RunningStartPage(togetherId:)`로 약속과 이어집니다. 동작 방식과 결정은 [MEMORY.md](MEMORY.md)에 있습니다.
- **디자인 시스템:** `lib/design_system/`에는 브랜드 가이드([lib/design_system/design_guide.md](lib/design_system/design_guide.md))에서 추출한 토큰(색, 텍스트 스타일, 간격, 모서리, 그림자, 모션, 컴포넌트 치수)이 있습니다(다크/블랙 테마, 기준 프레임 390×844, 주황은 경로·현재 위치·시작에만 사용). 값을 직접 쓰지 말고 이 토큰을 쓰세요. 앱 테마는 `AppTheme.dark`입니다.

## 코드 규칙

- 코드 주석과 UI 문자열은 한국어로 씁니다. UI 문구는 짧은 해요체를 씁니다.
- 테스트는 `test/`에 있습니다(페이지 위젯 테스트와, 임시 디렉터리와 가짜 서버를 주입하는 스토어 테스트). 테스트에서 진짜 Firebase를 부르지 않습니다.
