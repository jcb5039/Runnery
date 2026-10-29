import 'dart:async';

import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/app_radius.dart';
import '../../design_system/app_spacing.dart';
import '../data/friend_store.dart';
import '../widgets/friend_widgets.dart';

/// 18 친구 추가: 이름이나 아이디로 찾아 친구 요청을 보내고, 받은 요청을 수락·거절합니다.
class FriendAddPage extends StatefulWidget {
  const FriendAddPage({super.key, this.store});

  /// 테스트에서만 넣습니다. 없으면 앱 전체 저장소를 씁니다.
  final FriendStore? store;

  @override
  State<FriendAddPage> createState() => _FriendAddPageState();
}

class _FriendAddPageState extends State<FriendAddPage> {
  FriendStore get _store => widget.store ?? FriendStore.instance;

  final _query = TextEditingController();
  Timer? _debounce;
  String _searched = '';
  List<PublicProfile>? _results;
  bool _searching = false;
  String? _searchError;

  /// 받은 요청은 수락·거절해도 이 화면을 나갈 때까지 줄을 남겨 결과를 보여 줍니다.
  final List<PublicProfile> _requests = [];
  final Map<String, bool> _answered = {};

  /// 서버에 보내는 중인 사람. 그동안 버튼을 막습니다.
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _store.addListener(_syncRequests);
    _syncRequests();
    unawaited(_store.refresh());
  }

  @override
  void dispose() {
    _store.removeListener(_syncRequests);
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _syncRequests() {
    final fresh = _store.incoming.where(
      (p) => !_requests.any((r) => r.uid == p.uid),
    );
    if (fresh.isEmpty) return;
    setState(() => _requests.addAll(fresh));
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    setState(() {});
    if (text.trim().isEmpty) {
      setState(() {
        _searched = '';
        _results = null;
        _searchError = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(text));
  }

  Future<void> _search(String text) async {
    setState(() => _searching = true);
    try {
      final found = await _store.search(text);
      if (!mounted || _query.text != text) return;
      setState(() {
        _searched = text;
        _results = found;
        _searchError = null;
      });
    } on FriendException catch (e) {
      if (!mounted || _query.text != text) return;
      setState(() {
        _searched = text;
        _results = null;
        _searchError = e.message;
      });
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _clear() {
    _query.clear();
    _onChanged('');
  }

  /// 서버 작업을 하는 동안 그 사람의 버튼을 막고, 실패하면 이유를 알려 줍니다.
  Future<void> _act(String uid, Future<void> Function() task) async {
    if (_busy.contains(uid)) return;
    setState(() => _busy.add(uid));
    try {
      await task();
    } on FriendException catch (e) {
      if (mounted) showFriendMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(uid));
    }
  }

  Future<void> _accept(PublicProfile person) => _act(person.uid, () async {
    await _store.accept(person);
    _answered[person.uid] = true;
  });

  Future<void> _decline(PublicProfile person) => _act(person.uid, () async {
    await _store.decline(person);
    _answered[person.uid] = false;
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: friendAppBar(context, '친구 추가'),
    body: SafeArea(
      top: false,
      child: ListenableBuilder(
        listenable: _store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.space4,
            AppSpacing.screenHorizontal,
            AppSpacing.space6,
          ),
          children: [
            const Text(
              '이름이나 아이디로 찾기',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            _searchField(),
            if (_query.text.trim().isNotEmpty) ..._searchSection(),
            const SizedBox(height: 32),
            ..._requestSection(),
            const SizedBox(height: 32),
            const Text(
              '친구가 되면 서로의 러닝 기록과 응원을 볼 수 있어요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _searchField() => TextField(
    controller: _query,
    onChanged: _onChanged,
    textInputAction: TextInputAction.search,
    onSubmitted: (text) {
      _debounce?.cancel();
      if (text.trim().isNotEmpty) _search(text);
    },
    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
    cursorColor: AppColors.textPrimary,
    decoration: InputDecoration(
      hintText: '이름 또는 아이디',
      hintStyle: const TextStyle(color: AppColors.textTertiary),
      prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
      prefixIconConstraints: const BoxConstraints(minWidth: 34),
      suffixIcon: _query.text.isEmpty
          ? null
          : IconButton(
              tooltip: '검색어 지우기',
              icon: const Icon(
                Icons.cancel,
                size: 18,
                color: AppColors.textTertiary,
              ),
              onPressed: _clear,
            ),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.borderControl),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.textPrimary),
      ),
    ),
  );

  List<Widget> _searchSection() {
    final results = _results;
    return [
      const SizedBox(height: 28),
      FriendSectionHeader(
        title: '검색 결과',
        meta: results == null ? null : '${results.length}명',
      ),
      const SizedBox(height: 6),
      if (_searchError case final error?)
        _note(error)
      else if (results == null || (_searching && _searched != _query.text))
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        )
      else if (results.isEmpty)
        _note('찾는 친구가 없어요. 이름이나 아이디를 다시 확인해 주세요')
      else
        for (final (i, person) in results.indexed)
          FriendRow(
            person: person,
            divider: i > 0,
            trailing: _searchAction(person),
          ),
    ];
  }

  Widget _searchAction(PublicProfile person) {
    final busy = _busy.contains(person.uid);
    return switch (_store.relation(person.uid)) {
      FriendRelation.me => const Text(
        '나',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textTertiary,
        ),
      ),
      FriendRelation.friend => const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 16, color: AppColors.textTertiary),
          SizedBox(width: 4),
          Text(
            '친구예요',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
      FriendRelation.requested => FriendPillButton(
        label: '요청됨',
        filled: false,
        semanticLabel: '${person.name} 님에게 보낸 요청 취소',
        onPressed: busy
            ? null
            : () => _act(person.uid, () => _store.cancelRequest(person.uid)),
      ),
      FriendRelation.incoming => FriendPillButton(
        label: '수락',
        semanticLabel: '${person.name} 님 요청 수락',
        onPressed: busy ? null : () => _accept(person),
      ),
      FriendRelation.none => FriendPillButton(
        label: '친구 요청',
        semanticLabel: '${person.name} 님에게 친구 요청',
        onPressed: busy
            ? null
            : () => _act(person.uid, () => _store.sendRequest(person)),
      ),
    };
  }

  List<Widget> _requestSection() {
    final waiting = _requests
        .where((p) => !_answered.containsKey(p.uid))
        .length;
    return [
      FriendSectionHeader(
        title: '받은 친구 요청',
        meta: _requests.isEmpty
            ? null
            : waiting > 0
            ? '$waiting개'
            : '모두 확인했어요',
      ),
      const SizedBox(height: 6),
      if (_requests.isEmpty)
        _note(_store.loading ? '불러오는 중이에요' : _store.error ?? '받은 친구 요청이 없어요')
      else
        for (final (i, person) in _requests.indexed)
          FriendRow(
            person: person,
            divider: i > 0,
            trailing: _requestAction(person),
          ),
    ];
  }

  Widget _requestAction(PublicProfile person) {
    if (_answered[person.uid] case final accepted?) {
      return accepted
          ? Container(
              height: 22,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: const BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: AppRadius.pillBorder,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, size: 12, color: AppColors.background),
                  SizedBox(width: 4),
                  Text(
                    '친구가 됐어요',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.background,
                    ),
                  ),
                ],
              ),
            )
          : const Text(
              '거절했어요',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
              ),
            );
    }
    final busy = _busy.contains(person.uid);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FriendPillButton(
          label: '거절',
          filled: false,
          semanticLabel: '${person.name} 님 요청 거절',
          onPressed: busy ? null : () => _decline(person),
        ),
        const SizedBox(width: 6),
        FriendPillButton(
          label: '수락',
          semanticLabel: '${person.name} 님 요청 수락',
          onPressed: busy ? null : () => _accept(person),
        ),
      ],
    );
  }

  Widget _note(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
    ),
  );
}
