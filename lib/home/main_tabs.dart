import 'package:flutter/material.dart';

import '../design_system/app_colors.dart';
import '../friends/data/crew_store.dart';
import '../friends/data/friend_store.dart';
import '../friends/data/together_store.dart';
import '../friends/friends_feature.dart';
import '../friends/friends_page.dart';
import '../friends/notifications/friend_request_banner.dart';
import '../friends/together/together_invite.dart';
import '../hamster/hamster_room_page.dart';
import '../hamster/roommate_feature.dart';
import '../profile/profile_main_page.dart';
import '../record/list/record_list_page.dart';
import 'home_page.dart';

/// 홈·기록·(친구)·룸메이트·내 정보 탭을 한 번만 만들어 두고 효과 없이 바로 바꿉니다.
/// 룸메이트(캐릭터 탭)는 시안 미리보기이고, [RoommateFeature.available]이 켜져 있을 때만 있습니다(지금은 숨김).
/// 친구 탭은 [FriendsFeature.available]이 켜져 있을 때만 있습니다(지금은 켜짐, 탭 5개).
/// 탭을 누를 때마다 화면(기록 읽기·지도)을 새로 만들지 않아 끊기지 않고,
/// 안 보이는 탭은 그리지 않아 이전 탭의 지도가 남아 보이지 않습니다.
/// 친구 기능이 켜져 있으면, 앱을 켜 둔 동안 친구가 함께 달리기 약속을 보낼 때 어느 탭에서든 창을 띄우고,
/// 친구 탭 아이콘에 아직 답하지 않은 약속 수를 표시합니다.
class MainTabs extends StatefulWidget {
  const MainTabs({super.key, this.initialIndex = 0});

  /// 0 홈, 1 기록, 2 친구, 3 룸메이트, 4 내 정보 순서이고, 꺼진 탭(친구·룸메이트)은 빠지며 뒤 번호가 당겨집니다.
  final int initialIndex;

  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  /// (이름, 아이콘, 그림 아이콘). 그림 아이콘이 있으면 아이콘 대신 그 그림을 씁니다.
  /// 그림 아이콘은 흰색 모양만 있는 그림이고, 다른 탭 아이콘과 같은 색을 칠합니다.
  static const _tabs = <(String, IconData, String?)>[
    ('홈', Icons.home_outlined, null),
    ('기록', Icons.format_align_left, null),
    if (FriendsFeature.available) ('친구', Icons.people_outline, null),
    if (RoommateFeature.available)
      ('룸메이트', Icons.meeting_room_outlined, 'assets/hamster/tab_room.png'),
    ('내 정보', Icons.person_outline, null),
  ];
  static const _home = 0;
  static const _records = 1;

  /// 친구 탭 번호. 친구 기능이 꺼져 있으면 없는 번호(-1)입니다.
  static const _friends = FriendsFeature.available ? 2 : -1;
  static const _profile =
      2 +
      (FriendsFeature.available ? 1 : 0) +
      (RoommateFeature.available ? 1 : 0);

  late int _index = widget.initialIndex;

  /// 처음 연 탭만 만듭니다. 한 번 만든 탭은 다른 탭으로 가도 그대로 둡니다.
  late final Set<int> _opened = {_index};

  late final List<Widget> _pages = [
    HomePageV2(
      showNavigation: false,
      onRecords: () => _go(_records),
      onProfile: () => _go(_profile),
    ),
    RecordListPageV2(
      showNavigation: false,
      onHome: () => _go(_home),
      onProfile: () => _go(_profile),
    ),
    if (FriendsFeature.available) const FriendsPage(),
    if (RoommateFeature.available) const HamsterRoomPage(),
    ProfileMainPage(
      showNavigation: false,
      onHome: () => _go(_home),
      onRecords: () => _go(_records),
    ),
  ];

  void _go(int index) {
    if (index == _index) return;
    setState(() {
      _index = index;
      _opened.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = Stack(
      children: [
        for (final i in _opened.toList()..sort())
          KeyedSubtree(
            key: ValueKey(i),
            child: Offstage(
              offstage: i != _index,
              child: TickerMode(enabled: i == _index, child: _pages[i]),
            ),
          ),
      ],
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: FriendsFeature.available
          ? ListenableBuilder(
              listenable: Listenable.merge([
                TogetherStore.instance,
                FriendStore.instance,
                CrewStore.instance,
              ]),
              builder: (context, _) => _TabBar(
                index: _index,
                onTap: _go,
                // 크루 알림을 꺼 둔 크루의 안 읽은 채팅도 점으로 알립니다.
                friendDot:
                    TogetherStore.instance.requests.isNotEmpty ||
                    FriendStore.instance.incoming.isNotEmpty ||
                    CrewStore.instance.invites.isNotEmpty ||
                    CrewStore.instance.hasUnread,
              ),
            )
          : _TabBar(index: _index, onTap: _go),
      body: FriendsFeature.available
          ? TogetherInviteListener(child: FriendRequestListener(child: pages))
          : pages,
    );
  }
}

/// 탭 묶음의 하단 탭. 각 화면이 그리던 탭과 같은 모양입니다.
class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.index,
    required this.onTap,
    this.friendDot = false,
  });

  final int index;
  final ValueChanged<int> onTap;

  /// 친구 탭 아이콘 오른쪽 위 빨간 점: 안 읽은 크루 채팅, 받은 함께 달리기 제안·친구 요청·크루 초대가 있으면 true.
  final bool friendDot;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.divider)),
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            for (final (i, (label, icon, image))
                in _MainTabsState._tabs.indexed)
              Expanded(
                child: Semantics(
                  selected: i == index,
                  button: true,
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: Column(
                      children: [
                        Container(
                          height: 2,
                          width: 28,
                          color: i == index
                              ? AppColors.textPrimary
                              : Colors.transparent,
                        ),
                        const SizedBox(height: 8),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            if (image != null)
                              // 그림 모양에 다른 탭 아이콘과 같은 색을 칠합니다.
                              Image.asset(
                                image,
                                width: 22,
                                height: 22,
                                color: i == index
                                    ? AppColors.textPrimary
                                    : AppColors.textTertiary,
                                colorBlendMode: BlendMode.srcIn,
                                filterQuality: FilterQuality.medium,
                              )
                            else
                              Icon(
                                icon,
                                size: 22,
                                color: i == index
                                    ? AppColors.textPrimary
                                    : AppColors.textTertiary,
                              ),
                            // 새 소식이 있으면 숫자 없이 빨간 점만 붙입니다.
                            if (i == _MainTabsState._friends && friendDot)
                              Positioned(
                                top: -2,
                                right: -4,
                                child: Semantics(
                                  label: '새 소식 있음',
                                  child: Container(
                                    width: 9,
                                    height: 9,
                                    decoration: BoxDecoration(
                                      color: AppColors.error,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.background,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: i == index
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: i == index
                                ? AppColors.textPrimary
                                : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
