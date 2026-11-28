import 'package:flutter/foundation.dart';

import 'friend_models.dart' show TogetherResult;

/// 크루 하나. 멤버만 읽을 수 있고, 들어오는 방법은 멤버가 보낸 초대뿐입니다.
@immutable
class Crew {
  const Crew({
    required this.id,
    required this.name,
    required this.owner,
    required this.members,
    this.createdAt,
    this.notice,
    this.lastMessage,
    this.code,
  });
  final String id, name;

  /// 방장(크루장) uid. 멤버 내보내기·공지 쓰기를 할 수 있습니다.
  final String owner;

  /// 멤버 uid(방장 포함).
  final List<String> members;
  final DateTime? createdAt;
  final CrewNotice? notice;

  /// 목록에 보여 줄 마지막 메시지. 아직 없으면 null.
  final CrewLastMessage? lastMessage;

  /// 초대 코드(영어 대문자·숫자 6자리). 친구가 아니어도 이 코드로 들어올 수 있습니다. 예전 크루는 없을 수 있습니다.
  final String? code;

  /// 코드에 쓰는 글자(헷갈리는 0·O·1·I·L은 뺌). 서버 함수(functions/crew_code.js)와 같습니다.
  static const codeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const codeLength = 6;

  /// 입력한 코드를 대문자로 바꾸고 띄어쓰기를 지웁니다. 코드 모양이 아니면 null.
  static String? normalizeCode(String text) {
    final code = text.replaceAll(RegExp(r'\s'), '').toUpperCase();
    if (code.length != codeLength) return null;
    for (final c in code.split('')) {
      if (!codeAlphabet.contains(c)) return null;
    }
    return code;
  }

  /// 크루 최대 인원.
  static const maxMembers = 200;

  /// 크루 이름 최대 글자 수.
  static const maxName = 20;

  bool isOwner(String uid) => owner == uid;

  /// 목록 정렬 기준: 마지막 메시지 시각, 없으면 만든 시각.
  DateTime get activeAt =>
      lastMessage?.at ?? createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
}

/// 크루 공지(방장만 씁니다).
@immutable
class CrewNotice {
  const CrewNotice({required this.text, required this.by, required this.at});
  final String text, by;
  final DateTime at;

  static const maxText = 200;
}

/// 크루 목록에 보이는 마지막 메시지 요약.
@immutable
class CrewLastMessage {
  const CrewLastMessage({
    required this.uid,
    required this.text,
    required this.at,
  });
  final String uid, text;
  final DateTime at;

  /// 목록에 담는 글자 수.
  static const maxText = 100;
}

/// 채팅방 메시지 종류. 글자 말고는 들어옴·나감·내보냄 안내와 함께 달리기 모집 카드(run)입니다.
enum CrewMessageKind { text, join, leave, kick, run }

/// 채팅방 메시지 하나.
@immutable
class CrewMessage {
  const CrewMessage({
    required this.id,
    required this.uid,
    required this.kind,
    required this.createdAt,
    this.text = '',
    this.target,
    this.runId,
  });
  final String id;

  /// 쓴 사람. 내보냄(kick)이면 내보낸 방장입니다.
  final String uid;
  final CrewMessageKind kind;
  final String text;

  /// 내보냄(kick)이면 내보낸 사람.
  final String? target;

  /// 모집 카드(run)면 그 모집 번호. 제목은 [text]에 있습니다.
  final String? runId;

  /// 서버 시각. 막 보낸 메시지는 서버가 시각을 정하기 전이라 null일 수 있습니다.
  final DateTime? createdAt;

  static const maxText = 1000;
}

/// 크루에서 나에 대한 정보: 들어온 시각, 마지막으로 읽은 시각, 알림 끄기.
@immutable
class CrewMember {
  const CrewMember({
    required this.uid,
    required this.joinedAt,
    this.lastReadAt,
    this.muted = false,
  });
  final String uid;
  final DateTime joinedAt;
  final DateTime? lastReadAt;
  final bool muted;
}

/// 크루 초대. 받은 사람은 아직 멤버가 아니라 크루를 읽지 못해서, 초대에 크루 이름을 함께 담습니다.
@immutable
class CrewInvite {
  const CrewInvite({
    required this.crewId,
    required this.crewName,
    required this.from,
    required this.to,
    this.createdAt,
  });
  final String crewId, crewName, from, to;
  final DateTime? createdAt;

  String get id => '${crewId}_$to';
}

/// 함께 달리기 모집의 상태: 모으는 중 · 출발함 · 팀 기록 끝 · 닫힘(팀장이 나감).
enum CrewRunStatus { open, started, ended, closed }

/// 종료 투표: 출발하고 2시간이 지나도 팀이 끝나지 않으면 서버가 엽니다.
/// 참가자의 20%(최소 1명)가 '종료'를 누르면 끝나고, 30분 동안 '끝내지 않기'가 없어도 끝납니다.
@immutable
class CrewRunVote {
  const CrewRunVote({
    required this.askedAt,
    this.end = const {},
    this.keep = const {},
  });
  final DateTime askedAt;
  final Set<String> end, keep;

  bool answered(String uid) => end.contains(uid) || keep.contains(uid);
}

/// 팀 기록의 한 사람: 팀장이 팀을 끝낸 때(또는 모두 끝낸 때)의 거리·시간.
@immutable
class CrewTeamEntry {
  const CrewTeamEntry({
    required this.distanceKm,
    required this.movingSeconds,
    this.finished = false,
  });
  final double distanceKm;
  final int movingSeconds;

  /// 팀이 끝나기 전에 스스로 끝냈는지.
  final bool finished;
}

/// 팀 기록에 남은 한 사람의 지나간 길. 팀 달리기가 끝나면 서버가 실시간 상태에서 옮겨 저장합니다
/// (출발·도착 200m는 잘라 냄). 크루 멤버 누구나 '기록 보기'에서 봅니다.
@immutable
class CrewRunRoute {
  const CrewRunRoute({
    required this.uid,
    required this.color,
    this.points = const [],
  });
  final String uid;

  /// 대기실에서 고른 이름표 색 번호.
  final int color;

  /// 지나간 길(위도, 경도).
  final List<(double, double)> points;
}

/// 크루 함께 달리기 모집(대기실). 바꾸는 건 모두 서버 함수가 하고, 앱은 읽기만 합니다.
@immutable
class CrewRun {
  const CrewRun({
    required this.id,
    required this.crewId,
    required this.host,
    required this.title,
    required this.members,
    this.colors = const {},
    this.ready = const {},
    this.status = CrewRunStatus.open,
    this.createdAt,
    this.startedAt,
    this.endedAt,
    this.results = const {},
    this.team = const {},
    this.vote,
  });
  final String id, crewId;

  /// 모집을 연 사람(팀장). 이 모집에서만 팀장입니다.
  final String host;
  final String title;

  /// 참여한 사람(팀장 포함, 들어온 순서).
  final List<String> members;

  /// 이름표 색 번호(0~15).
  final Map<String, int> colors;

  /// 준비 완료한 사람(팀장은 늘 준비된 것으로 봅니다).
  final Set<String> ready;
  final CrewRunStatus status;
  final DateTime? createdAt, startedAt, endedAt;

  /// 각자 끝낸 기록.
  final Map<String, TogetherResult> results;

  /// 팀 기록(팀이 끝났을 때만). 크루방 안에서만 보여 줍니다.
  final Map<String, CrewTeamEntry> team;

  /// 열려 있는 종료 투표. 없으면 null.
  final CrewRunVote? vote;

  /// 모집 하나의 최대 인원(고정).
  static const maxRunners = 10;

  /// 제목 최대 글자 수.
  static const maxTitle = 20;

  /// 고를 수 있는 이름표 색 수.
  static const colorCount = 16;

  bool get isOpen => status == CrewRunStatus.open;
  bool get isFull => members.length >= maxRunners;

  bool isReady(String uid) => uid == host || ready.contains(uid);

  /// 준비한 사람 수(팀장 포함).
  int get readyCount => members.where(isReady).length;

  /// 모두 준비했고 함께 달릴 사람이 있으면 팀장이 시작할 수 있습니다.
  bool get canStart =>
      isOpen && members.length >= 2 && readyCount == members.length;

  int colorOf(String uid) => colors[uid] ?? 0;

  bool get isStarted => status == CrewRunStatus.started;
  bool get isEnded => status == CrewRunStatus.ended;

  /// 아직 끝내지 않고 달리는 사람.
  List<String> get stillRunning => [
    for (final m in members)
      if (!results.containsKey(m)) m,
  ];

  /// 팀 기록의 합친 거리.
  double get teamKm => team.values.fold(0, (s, e) => s + e.distanceKm);
}

/// 러닝 화면·결과 화면이 이어진 크루 모집.
@immutable
class CrewRunLink {
  const CrewRunLink({
    required this.crewId,
    required this.runId,
    required this.crewName,
  });
  final String crewId, runId, crewName;
}
