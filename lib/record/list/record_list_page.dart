import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../home/home_page.dart';
import '../../profile/profile_main_page.dart';
import '../record_calendar_page.dart';
import '../record_stats_page.dart';
import 'detail/record_detail_page.dart';
import '../data/record_places.dart';
import '../data/running_record_store.dart';

/// 로컬 러닝 기록을 표시하는 테스트용 Record 탭.
class RecordListPageV2 extends StatefulWidget {
  const RecordListPageV2({
    super.key,
    this.records,
    this.store,
    this.initialMonth,
    this.initialCalendar = false,
    this.onHome,
    this.onProfile,
    this.showNavigation = true,
  });
  final List<RunningRecord>? records;
  final RunningRecordStore? store;
  final DateTime? initialMonth;
  final bool initialCalendar;
  final VoidCallback? onHome, onProfile;

  /// 하단 탭을 이 화면이 직접 그릴지. 탭 묶음(MainTabs) 안에서는 false.
  final bool showNavigation;
  @override
  State<RecordListPageV2> createState() => _RecordListPageV2State();
}

/// 기록 탭 맨 위에서 고르는 화면.
enum _RecordView { list, calendar, stats }

class _RecordListPageV2State extends State<RecordListPageV2> {
  late var _view = widget.initialCalendar
      ? _RecordView.calendar
      : _RecordView.list;
  late DateTime month = widget.initialMonth ?? DateTime.now();
  DateTime? selectedDay;
  late final _store = widget.store ?? RunningRecordStore.instance;
  List<RunningRecord> _saved = const [];
  bool _loading = true;
  Object? _error;
  // 스와이프로 지운 기록은 저장소를 다시 읽기 전에도 바로 목록에서 뺍니다.
  final _deleted = <String>{};

  /// 선택 삭제 모드와 고른 기록.
  bool _selecting = false;
  final _selected = <String>{};

  void _setSelecting(bool value) => setState(() {
    _selecting = value;
    _selected.clear();
  });

  void _toggleSelected(RunningRecord r) => setState(() {
    if (!_selected.remove(r.id)) _selected.add(r.id);
  });

  /// 고른 기록을 한 번에 지웁니다. 일부가 실패하면 지운 것만 목록에서 빼고 알려 줍니다.
  Future<void> _deleteSelected() async {
    final ids = _selected.toList();
    if (ids.isEmpty || !await confirmRecordDelete(context, count: ids.length)) {
      return;
    }
    var failed = 0;
    for (final id in ids) {
      try {
        await _store.delete(id);
        _deleted.add(id);
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    _setSelecting(false);
    if (failed > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('기록 $failed개를 삭제하지 못했어요. 다시 시도해 주세요.')),
      );
    }
  }

  List<RunningRecord> get records => (widget.records ?? _saved)
      .where((r) => !_deleted.contains(r.id))
      .toList();

  @override
  void initState() {
    super.initState();
    _store.addListener(_reload);
    _reload();
    // 다른 폰에서 올린 새 기록이 있는지 서버를 확인합니다(30초 안에 한 번 했으면 건너뜁니다).
    if (widget.records == null) {
      unawaited(
        _store.syncNow(minAge: const Duration(seconds: 30)).catchError((Object _) {}),
      );
    }
  }

  Future<void> _reload() async {
    try {
      final saved = widget.records ?? await _store.load();
      // 장소 이름 없이 저장된 기록은 뒤에서 이름을 찾아 채웁니다(채우면 목록이 다시 읽힙니다).
      if (widget.records == null) RecordPlaces.instance.fill(_store, saved);
      if (mounted) {
        setState(() {
          _saved = saved;
          _loading = false;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _store.removeListener(_reload);
    super.dispose();
  }

  List<RunningRecord> get monthly =>
      records
          .where(
            (r) =>
                r.startedAt.year == month.year &&
                r.startedAt.month == month.month,
          )
          .toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  void _changeMonth(int delta) => setState(() {
    month = DateTime(month.year, month.month + delta);
    selectedDay = null;
  });
  void _openRecord(RunningRecord r) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RecordDetailPage(
          record: r,
          // 열어 둔 사이 장소 이름이 채워졌을 수 있어 저장된 최신 기록에 메모만 바꿉니다.
          onSaveMemo: (value) =>
              _store.update(r.id, (current) => current.withMemo(value)),
          onDelete: () => _store.delete(r.id),
        ),
      ),
    );
  }

  void _home() {
    if (widget.onHome != null) {
      widget.onHome!();
      return;
    }
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute(builder: (_) => const HomePageV2()),
    );
  }

  void _profile() {
    if (widget.onProfile != null) {
      widget.onProfile!();
      return;
    }
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute(builder: (_) => const ProfileMainPage()),
    );
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: recordBackground,
    ),
    child: Scaffold(
      backgroundColor: recordBackground,
      bottomNavigationBar: _selecting
          ? _selectionBar()
          : widget.showNavigation
          ? _navigation()
          : null,
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              key: PageStorageKey('record-${_view.name}'),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selecting ? '${_selected.length}개 선택됨' : '러닝 기록',
                          style: recordText(26, weight: FontWeight.w800),
                        ),
                      ),
                      if (_view == _RecordView.list && records.isNotEmpty)
                        TextButton(
                          onPressed: () => _setSelecting(!_selecting),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                          ),
                          child: Text(_selecting ? '취소' : '선택'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    height: 40,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF343D43)),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        _toggle('목록', _RecordView.list),
                        _toggle('달력', _RecordView.calendar),
                        _toggle('통계', _RecordView.stats),
                      ],
                    ),
                  ),
                  // 통계는 주간·월간을 따로 넘기므로 달 이동 줄을 숨깁니다.
                  if (_view != _RecordView.stats) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: '이전 달',
                            onPressed: () => _changeMonth(-1),
                            icon: const Icon(Icons.chevron_left, size: 20),
                          ),
                          Expanded(
                            child: Text(
                              '${month.year}년 ${month.month}월',
                              textAlign: TextAlign.center,
                              style: recordText(18, weight: FontWeight.w800),
                            ),
                          ),
                          IconButton(
                            tooltip: '다음 달',
                            onPressed: () => _changeMonth(1),
                            icon: const Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: recordMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFF343D43)),
                  ],
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Text('러닝 기록을 불러오지 못했습니다.'),
                          TextButton(
                            onPressed: _reload,
                            child: const Text('다시 시도'),
                          ),
                        ],
                      ),
                    )
                  else if (_view == _RecordView.stats)
                    RecordStatsView(records: records)
                  else if (_view == _RecordView.calendar)
                    RecordCalendarPage(
                      embedded: true,
                      records: records,
                      month: month,
                      selectedDay: selectedDay,
                      onDaySelected: (day) => setState(() => selectedDay = day),
                      onRecordTap: _openRecord,
                    )
                  else
                    ..._list(),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _toggle(String label, _RecordView value) => Expanded(
    child: Semantics(
      selected: _view == value,
      button: true,
      child: Material(
        color: _view == value ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => setState(() {
            _view = value;
            _selecting = false;
            _selected.clear();
          }),
          child: Center(
            child: Text(
              label,
              style: recordText(
                14,
                color: _view == value ? recordBackground : recordSecondary,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  List<Widget> _list() {
    final runs = monthly;
    final total = runs.fold(0.0, (sum, r) => sum + r.distanceKm);
    final seconds = runs.fold(0, (sum, r) => sum + r.movingSeconds);
    final kcal = runs.fold(0.0, (sum, r) => sum + r.energyKcal);
    final groups = <DateTime, List<RunningRecord>>{};
    for (final r in runs) {
      final d = DateTime(r.startedAt.year, r.startedAt.month, r.startedAt.day);
      final monday = d.subtract(Duration(days: d.weekday - 1));
      groups.putIfAbsent(monday, () => []).add(r);
    }
    final reference = DateTime.now();
    final currentMonday = DateTime(
      reference.year,
      reference.month,
      reference.day,
    ).subtract(Duration(days: reference.weekday - 1));
    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateUtils.isSameMonth(month, DateTime.now())
                        ? '이번 달 달린 거리'
                        : '${month.month}월 달린 거리',
                    style: recordText(
                      12,
                      color: recordSecondary,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: total.toStringAsFixed(2),
                            style: recordNumber(52),
                          ),
                          TextSpan(
                            text: ' km',
                            style: recordText(16, color: recordSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${runs.length}회 러닝',
                  style: recordText(13, weight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  seconds < 3600
                      ? '${seconds ~/ 60}분'
                      : '${seconds ~/ 3600}시간 ${seconds ~/ 60 % 60}분',
                  style: recordText(12, color: recordSecondary),
                ),
                const SizedBox(height: 5),
                Text(
                  '햇반 ${kcal == 0 ? '0' : (kcal / 315).toStringAsFixed(1)}개',
                  style: recordText(12, color: recordSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
      const Divider(height: 1, color: recordLine),
      if (runs.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 64),
          child: Text(
            records.isEmpty ? '아직 저장된 러닝 기록이 없습니다.' : '이번 달에는 러닝 기록이 없습니다.',
            textAlign: TextAlign.center,
            style: recordText(14, color: recordMuted),
          ),
        ),
      for (final group in groups.entries) ...[
        Padding(
          padding: const EdgeInsets.only(top: 26, bottom: 10),
          child: Row(
            children: [
              Text(
                _weekLabel(group.key, currentMonday),
                style: recordText(15, weight: FontWeight.w800),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _range(group.key),
                  style: recordText(11, color: recordMuted),
                ),
              ),
              Text(
                records
                    .where(
                      (r) =>
                          !r.startedAt.isBefore(group.key) &&
                          r.startedAt.isBefore(
                            DateTime(
                              group.key.year,
                              group.key.month,
                              group.key.day + 7,
                            ),
                          ),
                    )
                    .fold(0.0, (s, r) => s + r.distanceKm)
                    .toStringAsFixed(2),
                style: recordNumber(16, color: recordSecondary),
              ),
              Text(' km', style: recordText(10, color: recordMuted)),
            ],
          ),
        ),
        const Divider(height: 1, color: recordLine),
        for (final r in group.value) _recordTile(r),
      ],
    ];
  }

  String _weekLabel(DateTime day, DateTime monday) {
    final weeks = monday.difference(day).inDays ~/ 7;
    return weeks == 0
        ? '이번 주'
        : weeks == 1
        ? '지난주'
        : weeks > 1 && weeks < 5
        ? '$weeks주 전'
        : '${day.month}월 ${day.day}일 주';
  }

  String _range(DateTime first) {
    final last = first.add(const Duration(days: 6));
    return '${first.month}월 ${first.day}일 – ${last.month != first.month ? '${last.month}월 ' : ''}${last.day}일';
  }

  /// 왼쪽으로 밀면 삭제 확인 창을 띄웁니다. 선택 모드에서는 밀어서 지우기를 쓰지 않습니다.
  Widget _recordTile(RunningRecord r) => _selecting
      ? _recordContent(r)
      : Dismissible(
          key: ValueKey('record-${r.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: recordDelete,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete_outline, color: Colors.white),
                SizedBox(height: 4),
                Text(
                  '삭제',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          confirmDismiss: (_) async {
            if (!await confirmRecordDelete(context)) return false;
            try {
              await _store.delete(r.id);
              return true;
            } catch (_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('기록 삭제에 실패했습니다. 다시 시도해 주세요.')),
                );
              }
              return false;
            }
          },
          onDismissed: (_) => setState(() => _deleted.add(r.id)),
          child: _recordContent(r),
        );

  Widget _recordContent(RunningRecord r) => InkWell(
    onTap: () => _selecting ? _toggleSelected(r) : _openRecord(r),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: recordLine)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            height: 88,
            // 기록마다 실제 지도를 띄우면 지도가 여러 개 겹쳐 화면을 넘길 때 잔상이 남습니다.
            // 그래서 지도는 한 번 사진으로 만들어 두고 그 사진을 보여 줍니다.
            child: Stack(
              children: [
                Positioned.fill(child: RecordRouteThumbnail(record: r)),
                if (_selecting)
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Icon(
                      _selected.contains(r.id)
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: Colors.white,
                      size: 24,
                      semanticLabel: _selected.contains(r.id)
                          ? '선택됨'
                          : '선택 안 됨',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.dateLabel,
                        style: recordText(14, weight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      clockText(r.startedAt),
                      style: recordText(11, color: recordMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: r.distanceKm.toStringAsFixed(2),
                        style: recordNumber(30),
                      ),
                      TextSpan(
                        text: ' km',
                        style: recordText(12, color: recordSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${r.durationLabel} · ${r.paceLabel}/km · ${r.calories} kcal',
                  style: recordText(11, color: recordSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!_selecting)
            const Icon(Icons.chevron_right, size: 17, color: recordMuted),
        ],
      ),
    ),
  );

  /// 선택 모드 하단: 이번 달 전체 선택과 삭제 버튼.
  Widget _selectionBar() {
    final ids = monthly.map((r) => r.id).toSet();
    final all = ids.isNotEmpty && _selected.containsAll(ids);
    return Container(
      decoration: const BoxDecoration(
        color: recordBackground,
        border: Border(top: BorderSide(color: recordLine)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        child: Row(
          children: [
            TextButton(
              onPressed: () => setState(() {
                if (all) {
                  _selected.removeAll(ids);
                } else {
                  _selected.addAll(ids);
                }
              }),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: Text(all ? '전체 해제' : '이번 달 전체 선택'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: _selected.isEmpty ? null : _deleteSelected,
                  style: FilledButton.styleFrom(
                    backgroundColor: recordDelete,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF2A2C2E),
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(
                    _selected.isEmpty ? '삭제' : '${_selected.length}개 삭제',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navigation() => Container(
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: recordLine)),
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            _nav('홈', Icons.home_outlined, false, _home),
            _nav('기록', Icons.format_align_left, true, () {}),
            _nav('내 정보', Icons.person_outline, false, _profile),
          ],
        ),
      ),
    ),
  );
  Widget _nav(String label, IconData icon, bool selected, VoidCallback onTap) =>
      Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          child: InkWell(
            onTap: onTap,
            child: Column(
              children: [
                Container(
                  height: 3,
                  width: 28,
                  color: selected ? Colors.white : Colors.transparent,
                ),
                const SizedBox(height: 8),
                Icon(
                  icon,
                  size: 22,
                  color: selected ? Colors.white : recordMuted,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: recordText(
                    11,
                    color: selected ? Colors.white : recordMuted,
                    weight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
