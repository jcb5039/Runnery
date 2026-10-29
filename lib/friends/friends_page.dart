import 'dart:async';

import 'package:flutter/material.dart';

import '../design_system/app_colors.dart';
import '../design_system/app_radius.dart';
import '../design_system/app_spacing.dart';
import 'add/friend_add_page.dart';
import 'data/friend_store.dart';
import 'feed/feed_card.dart';
import 'goal/friend_goal_tab.dart';
import 'list/friend_list_page.dart';
import 'data/together_store.dart';
import 'ranking/friend_ranking_tab.dart';
import 'together/together_tab.dart';
import 'widgets/friend_widgets.dart';

/// 17 친구 탭. 위쪽에서 내 친구·친구 추가로 가고, 피드·랭킹·목표를 위쪽 메뉴로 바꿔 봅니다.
/// 피드에서는 받은 친구 요청을 알려 주고, 친구들이 공유한 러닝과 응원 버튼을 보여 줍니다.
/// 함께 달리기에서는 약속을 잡고, 대기실에서 친구와 함께 시작합니다.
class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key, this.store, this.together});

  /// 테스트에서만 넣습니다. 없으면 앱 전체 저장소를 씁니다.
  final FriendStore? store;
  final TogetherStore? together;

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

enum _Tab {
  feed('피드'),
  ranking('랭킹'),
  goal('목표'),
  together('함께 달리기', flex: 145);

  const _Tab(this.label, {this.flex = 100});
  final String label;

  /// 메뉴에서 차지하는 너비 비율. '함께 달리기'는 글자가 길어 넓게 둡니다.
  final int flex;
}

class _FriendsPageState extends State<FriendsPage> {
  FriendStore get _store => widget.store ?? FriendStore.instance;

  _Tab _tab = _Tab.feed;

  @override
  void initState() {
    super.initState();
    unawaited(_store.refresh());
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    // 다른 화면에서 수락·삭제한 결과를 다시 맞춥니다.
    unawaited(_store.refresh());
  }

  Future<void> _cheer(FeedItem item, CheerType type) async {
    try {
      await _store.toggleCheer(item, type);
    } on FriendException catch (e) {
      if (mounted) showFriendMessage(context, e.message);
    }
  }

  void _openAdd() => _open(FriendAddPage(store: widget.store));
  void _openList() => _open(FriendListPage(store: widget.store));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: _store,
        builder: (context, _) => RefreshIndicator(
          onRefresh: _store.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: AppSpacing.space6),
            children: [
              _header(),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  10,
                  AppSpacing.screenHorizontal,
                  0,
                ),
                child: _menu(),
              ),
              Padding(
                // 랭킹 줄은 바탕색이 화면 여백 안쪽까지 넓게 칠해지도록 여백을 줄입니다.
                padding: EdgeInsets.symmetric(
                  horizontal: _tab == _Tab.ranking
                      ? AppSpacing.screenHorizontal - 12
                      : AppSpacing.screenHorizontal,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_tab == _Tab.feed && _store.incoming.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _requestBanner(_store.incoming.length),
                    ],
                    SizedBox(height: _tab == _Tab.feed ? 28 : 18),
                    switch (_tab) {
                      _Tab.feed => _body(),
                      _Tab.ranking => FriendRankingTab(store: _store),
                      _Tab.goal => FriendGoalTab(store: _store),
                      _Tab.together => TogetherTab(
                        friends: _store,
                        store: widget.together,
                      ),
                    },
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(AppSpacing.screenHorizontal, 4, 12, 0),
    child: SizedBox(
      height: 52,
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '친구',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: '내 친구 목록',
            icon: const Icon(Icons.people_outline),
            onPressed: _openList,
          ),
          IconButton(
            tooltip: '친구 추가',
            icon: const Icon(Icons.person_add_alt_outlined),
            onPressed: _openAdd,
          ),
        ],
      ),
    ),
  );

  /// 피드·랭킹·목표·함께 달리기 메뉴.
  Widget _menu() => Container(
    height: 44,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      borderRadius: AppRadius.pillBorder,
      border: Border.all(color: AppColors.borderDefault),
    ),
    child: Row(
      children: [
        for (final tab in _Tab.values)
          Expanded(
            flex: tab.flex,
            child: Semantics(
              selected: tab == _tab,
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _tab = tab),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tab == _tab
                        ? AppColors.textPrimary
                        : Colors.transparent,
                    borderRadius: AppRadius.pillBorder,
                  ),
                  child: Text(
                    tab.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: tab == _tab
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: tab == _tab
                          ? AppColors.background
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _requestBanner(int count) => Material(
    color: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: AppRadius.thumbnailBorder,
      side: BorderSide(color: AppColors.divider),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: _openAdd,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
        child: Row(
          children: [
            const Icon(Icons.person_add_alt_outlined, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: '새 친구 요청 ',
                  children: [
                    TextSpan(
                      text: '$count개',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Text(
              '확인하기',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _body() {
    final friends = _store.friends;
    if (friends.isEmpty && _store.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (friends.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Text(
              _store.error ?? '친구를 추가하고 함께 달려요',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FriendPillButton(label: '친구 추가', onPressed: _openAdd),
          ],
        ),
      );
    }
    return FeedSection(
      items: _store.feed,
      error: _store.feedError,
      onCheer: _cheer,
    );
  }
}
