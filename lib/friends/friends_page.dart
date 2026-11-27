import 'dart:async';

import 'package:flutter/material.dart';

import '../design_system/app_colors.dart';
import '../design_system/app_radius.dart';
import '../design_system/app_spacing.dart';
import 'add/friend_add_page.dart';
import 'calendar/friend_calendar_page.dart';
import 'data/friend_store.dart';
import 'feed/feed_card.dart';
import 'feed/feed_menu.dart';
import 'list/friend_list_page.dart';
import '../record/record_stats_page.dart' show PillTabs;
import 'data/together_store.dart';
import 'together/together_tab.dart';
import 'widgets/friend_widgets.dart';

/// 17 친구 탭(추가 수정). 위쪽에서 내 친구·친구 추가로 가고, 친구 · 함께 달리기 · 크루를 위쪽 메뉴로 바꿔 봅니다.
/// 친구에서는 받은 친구 요청을 알려 주고, '친구' 탭에 친구들이 공유한 러닝과 응원 버튼을,
/// '내 피드' 탭에 내가 공유한 러닝과 받은 응원(누가 응원했는지)을 보여 줍니다.
/// 친구 카드의 이름을 누르면 친구 달력이, '더보기'를 누르면 신고·차단이 열립니다.
/// 함께 달리기에서는 약속을 잡고, 대기실에서 친구와 함께 시작합니다. 크루는 아직 준비 중입니다.
class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key, this.store, this.together});

  /// 테스트에서만 넣습니다. 없으면 앱 전체 저장소를 씁니다.
  final FriendStore? store;
  final TogetherStore? together;

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

enum _Tab {
  feed('친구'),
  together('함께 달리기', flex: 145),
  crew('크루');

  const _Tab(this.label, {this.flex = 100});
  final String label;

  /// 메뉴에서 차지하는 너비 비율. '함께 달리기'는 글자가 길어 넓게 둡니다.
  final int flex;
}

class _FriendsPageState extends State<FriendsPage> {
  FriendStore get _store => widget.store ?? FriendStore.instance;

  _Tab _tab = _Tab.feed;

  /// 피드 안에서 내가 공유한 기록(내 피드)을 볼지, 친구들의 기록을 볼지.
  bool _myFeed = false;

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

  void _openCalendar(FeedItem item) =>
      _open(FriendCalendarPage(friend: item.friend, store: widget.store));

  /// 17-16 더보기 → 신고하기(17-17) 또는 차단하기(17-18).
  Future<void> _more(FeedItem item) async {
    final person = item.friend;
    final action = await showModalBottomSheet<FeedMenuAction>(
      context: context,
      backgroundColor: AppColors.sheet,
      showDragHandle: true,
      builder: (context) => FeedMenuSheet(person: person),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case FeedMenuAction.report:
        await Navigator.of(context).push(
          MaterialPageRoute<bool>(
            builder: (_) => ReportPage(
              person: person,
              onSubmit: (reason, detail) => _store.report(
                person,
                reason,
                detail: detail,
                recordId: item.post.recordId,
              ),
            ),
          ),
        );
      case FeedMenuAction.block:
        final confirmed = await showModalBottomSheet<bool>(
          context: context,
          backgroundColor: AppColors.sheet,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (context) => BlockConfirmSheet(person: person),
        );
        if (confirmed == true && mounted) _block(person);
    }
  }

  /// 17-18-1 차단 후: 카드를 바로 감추고 '되돌리기'를 잠깐 보여 준 뒤, 누르지 않으면 차단합니다.
  void _block(PublicProfile person) {
    _store.hideFromFeed(person.uid, hide: true);
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    final bar = messenger.showSnackBar(
      SnackBar(
        content: Text('${person.name} 님을 차단했어요'),
        duration: const Duration(seconds: 4),
        // '되돌리기'가 있어도 4초 뒤 저절로 닫혀야 차단이 확정됩니다.
        persist: false,
        action: SnackBarAction(label: '되돌리기', onPressed: () {}),
      ),
    );
    unawaited(
      bar.closed.then((reason) async {
        if (reason == SnackBarClosedReason.action) {
          _store.hideFromFeed(person.uid, hide: false);
          return;
        }
        try {
          await _store.block(person);
        } on FriendException catch (e) {
          _store.hideFromFeed(person.uid, hide: false);
          messenger.showSnackBar(SnackBar(content: Text(e.message)));
        }
      }),
    );
  }

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
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
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
                      _Tab.together => TogetherTab(
                        friends: _store,
                        store: widget.together,
                      ),
                      _Tab.crew => const _CrewSoon(),
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

  /// 친구·함께 달리기·크루 메뉴.
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
    shape: RoundedRectangleBorder(
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
            Text(
              '확인하기',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    ),
  );

  /// 피드: '내 피드'(내가 공유한 기록과 받은 응원)와 '친구'(친구들이 공유한 기록) 탭.
  Widget _body() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 160,
          child: PillTabs(
            labels: const ['내 피드', '친구'],
            selected: _myFeed ? 0 : 1,
            onTap: (i) => setState(() => _myFeed = i == 0),
          ),
        ),
      ),
      const SizedBox(height: 4),
      if (_myFeed)
        FeedSection(
          items: _store.myFeed,
          error: _store.feedError,
          onCheer: null,
        )
      else
        _friendFeed(),
    ],
  );

  Widget _friendFeed() {
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
              style: TextStyle(color: AppColors.textSecondary),
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
      onOpenFriend: _openCalendar,
      onMore: _more,
    );
  }
}

/// 크루 탭 자리. 크루(채팅방·함께 모집)는 다음 단계에서 만듭니다.
class _CrewSoon extends StatelessWidget {
  const _CrewSoon();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(
      children: [
        Icon(Icons.groups_outlined, size: 40, color: AppColors.textTertiary),
        const SizedBox(height: 14),
        const Text(
          '크루는 준비 중이에요',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          '크루원들과 채팅하고 함께 달릴 수 있게 만들고 있어요',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}
