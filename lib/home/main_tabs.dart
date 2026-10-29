import 'package:flutter/material.dart';

import '../design_system/app_colors.dart';
import '../friends/friends_page.dart';
import '../profile/profile_main_page.dart';
import '../record/list/record_list_page.dart';
import 'home_page.dart';

/// 홈·기록·친구·내 정보 네 탭을 한 번만 만들어 두고 효과 없이 바로 바꿉니다.
/// 탭을 누를 때마다 화면(기록 읽기·지도)을 새로 만들지 않아 끊기지 않고,
/// 안 보이는 탭은 그리지 않아 이전 탭의 지도가 남아 보이지 않습니다.
class MainTabs extends StatefulWidget {
  const MainTabs({super.key, this.initialIndex = 0});

  /// 0 홈, 1 기록, 2 친구, 3 내 정보.
  final int initialIndex;

  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  static const _tabs = [
    ('홈', Icons.home_outlined),
    ('기록', Icons.format_align_left),
    ('친구', Icons.people_outline),
    ('내 정보', Icons.person_outline),
  ];

  late int _index = widget.initialIndex;

  /// 처음 연 탭만 만듭니다. 한 번 만든 탭은 다른 탭으로 가도 그대로 둡니다.
  late final Set<int> _opened = {_index};

  late final List<Widget> _pages = [
    HomePageV2(
      showNavigation: false,
      onRecords: () => _go(1),
      onProfile: () => _go(3),
    ),
    RecordListPageV2(
      showNavigation: false,
      onHome: () => _go(0),
      onProfile: () => _go(3),
    ),
    const FriendsPage(),
    ProfileMainPage(
      showNavigation: false,
      onHome: () => _go(0),
      onRecords: () => _go(1),
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    bottomNavigationBar: _TabBar(index: _index, onTap: _go),
    body: Stack(
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
    ),
  );
}

/// 탭 묶음의 하단 탭. 각 화면이 그리던 탭과 같은 모양입니다.
class _TabBar extends StatelessWidget {
  const _TabBar({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.divider)),
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            for (final (i, (label, icon)) in _MainTabsState._tabs.indexed)
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
                          color: i == index ? Colors.white : Colors.transparent,
                        ),
                        const SizedBox(height: 8),
                        Icon(
                          icon,
                          size: 22,
                          color: i == index
                              ? Colors.white
                              : AppColors.textTertiary,
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
                                ? Colors.white
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
