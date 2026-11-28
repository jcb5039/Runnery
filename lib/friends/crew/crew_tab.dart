import 'dart:async';

import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../record/models/running_record.dart' show clockText;
import '../data/crew_store.dart';
import '../data/friend_store.dart';
import '../widgets/friend_widgets.dart';
import 'crew_new_page.dart';
import 'crew_room_page.dart';

/// 17-7 크루 목록: 내 크루(최근에 이야기한 순), 크루 만들기. 크루를 누르면 채팅방이 열립니다.
class CrewTab extends StatefulWidget {
  const CrewTab({super.key, required this.friends, this.store});

  final FriendStore friends;

  /// 테스트에서만 넣습니다. 없으면 앱 전체 저장소를 씁니다.
  final CrewStore? store;

  @override
  State<CrewTab> createState() => _CrewTabState();
}

class _CrewTabState extends State<CrewTab> {
  CrewStore get _store => widget.store ?? CrewStore.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_store.refresh());
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    unawaited(_store.refresh());
  }

  void _openNew() =>
      _open(CrewNewPage(friends: widget.friends, store: widget.store));

  void _openRoom(Crew crew) => _open(
    CrewRoomPage(id: crew.id, friends: widget.friends, store: widget.store),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _store,
    builder: (context, _) {
      final crews = _store.crews;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: FriendSectionHeader(
                  title: '내 크루',
                  meta: crews.isEmpty ? null : '${crews.length}개',
                ),
              ),
              const SizedBox(width: 12),
              FriendPillButton(label: '크루 만들기', onPressed: _openNew),
            ],
          ),
          const SizedBox(height: 4),
          if (!_store.loaded)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (crews.isEmpty)
            _empty()
          else
            for (final (i, crew) in crews.indexed)
              _CrewRow(
                crew: crew,
                store: _store,
                divider: i > 0,
                onTap: () => _openRoom(crew),
              ),
        ],
      );
    },
  );

  Widget _empty() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(
      children: [
        Icon(Icons.groups_outlined, size: 40, color: AppColors.textTertiary),
        const SizedBox(height: 14),
        Text(
          _store.error ?? '아직 크루가 없어요',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          '크루를 만들고 친구를 초대해 함께 달려요',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}

/// 크루 한 줄: 멤버 얼굴, 이름·인원, 마지막 메시지, 시각, 안 읽은 수.
class _CrewRow extends StatelessWidget {
  const _CrewRow({
    required this.crew,
    required this.store,
    required this.onTap,
    this.divider = true,
  });

  final Crew crew;
  final CrewStore store;
  final VoidCallback onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final last = crew.lastMessage;
    final unread = store.unread(crew.id), muted = store.muted(crew.id);
    final preview = last == null
        ? '아직 메시지가 없어요'
        : '${last.uid == store.me?.uid ? '나' : store.nameOf(last.uid)}: ${last.text}';
    return Semantics(
      button: true,
      label:
          '${crew.name} 크루 채팅방, ${crew.members.length}명, $preview'
          '${unread > 0 ? ', 안 읽은 메시지 $unread개' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: divider ? AppColors.divider : Colors.transparent,
              ),
            ),
          ),
          child: Row(
            children: [
              CrewFaces(crew: crew, store: store),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            crew.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${crew.members.length}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        if (muted) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.notifications_off_outlined,
                            size: 14,
                            color: AppColors.textTertiary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    crewTimeLabel(crew.activeAt, store.now),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (unread > 0)
                    Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      height: 20,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: muted
                            ? AppColors.borderDefault
                            : AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 크루 멤버 얼굴 최대 4개를 2×2로 겹쳐 그립니다.
class CrewFaces extends StatelessWidget {
  const CrewFaces({
    super.key,
    required this.crew,
    required this.store,
    this.size = 48,
  });

  final Crew crew;
  final CrewStore store;
  final double size;

  @override
  Widget build(BuildContext context) {
    final faces = crew.members.take(4).toList();
    final small = size * 0.54;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          for (final (i, uid) in faces.indexed)
            Positioned(
              left: faces.length == 1
                  ? (size - small) / 2
                  : (i % 2) * (size - small),
              top: faces.length <= 2
                  ? (size - small) / 2
                  : (i ~/ 2) * (size - small),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.background,
                ),
                child: FriendAvatar(
                  initial: store.person(uid)?.initial ?? '·',
                  size: small,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 목록의 시각: 오늘은 '오후 6:12', 어제는 '어제', 그 전은 '10월 22일'.
String crewTimeLabel(DateTime time, DateTime now) {
  final day = DateTime(time.year, time.month, time.day);
  final today = DateTime(now.year, now.month, now.day);
  return switch (today.difference(day).inDays) {
    0 => clockText(time),
    1 => '어제',
    _ => '${time.month}월 ${time.day}일',
  };
}
