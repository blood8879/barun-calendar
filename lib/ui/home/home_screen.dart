import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../data/event/event_photo_store.dart';
import '../../data/event/event_repository.dart';
import '../../data/notification/notification_service.dart';
import '../../data/settings/settings_repository.dart';
import '../../domain/calendar/day_info.dart';
import '../../domain/calendar/jdn.dart';
import '../../domain/event/event.dart';
import '../ads/ad_banner.dart';
import '../anniversary/anniversary_screen.dart';
import '../basis/basis_screen.dart';
import '../converter/converter_screen.dart';
import '../date_detail/date_detail_sheet.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';

const _weekdayLabels = ['일', '월', '화', '수', '목', '금', '토'];

class HomeScreen extends StatefulWidget {
  final EventRepository repository;
  final SettingsRepository settingsRepository;
  final ValueChanged<AppSettings> onSettingsChanged;
  final DayInfoProvider dayInfoProvider;
  final LunarCalendarDataSource lunarSource;
  final AppSettings settings;
  final ValueChanged<List<CalendarEvent>>? onEventsChanged;

  const HomeScreen({
    super.key,
    required this.repository,
    required this.settingsRepository,
    required this.onSettingsChanged,
    required this.dayInfoProvider,
    required this.lunarSource,
    this.settings = const AppSettings(),
    this.onEventsChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DayInfoProvider get _dayInfoProvider => widget.dayInfoProvider;
  final _uuid = const Uuid();

  late DateTime _visibleMonth;
  List<CalendarEvent> _events = [];
  int? _indexedYear;
  Map<String, List<CalendarEvent>> _eventIndex = const {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month, 1);
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final events = await widget.repository.loadAll();
    if (!mounted) return;
    setState(() {
      _events = events;
      _indexedYear = null; // 재계산 유도
    });
    widget.onEventsChanged?.call(events);
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta, 1);
    });
  }

  Future<void> _pickMonth(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _visibleMonth,
      firstDate: DateTime(1899, 1, 1),
      lastDate: DateTime(2050, 12, 31),
      helpText: '연/월 선택',
    );
    if (picked == null) return;
    setState(() => _visibleMonth = DateTime(picked.year, picked.month, 1));
  }

  /// [year]의 모든 일정 발생일을 한 번만 계산해 캐시한다. 음력 반복 일정은
  /// [LunarCalendarDataSource]로 그 해의 실제 양력 변환일을 구해 자동 반영한다.
  /// 매일 캘린더 셀마다 반복 규칙을 재계산하지 않도록 하기 위한 성능 최적화이기도 하다
  /// (커스텀 "매 N일" 반복은 년 단위 재계산 비용이 있어 셀당 반복 호출을 피해야 한다).
  void _ensureIndexFor(int year) {
    if (_indexedYear == year) return;
    final index = <String, List<CalendarEvent>>{};
    for (final e in _events) {
      final occs = e.occurrencesInYearResolved(year, lunarSource: widget.lunarSource);
      for (final d in occs) {
        final key = '${d.year}-${d.month}-${d.day}';
        (index[key] ??= []).add(e);
      }
    }
    _eventIndex = index;
    _indexedYear = year;
  }

  List<CalendarEvent> _eventsOn(DateTime date) {
    _ensureIndexFor(date.year);
    return _eventIndex['${date.year}-${date.month}-${date.day}'] ?? const [];
  }

  Future<void> _openDateDetail(DateTime date) async {
    final info = _dayInfoProvider.build(date);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DateDetailSheet(
        dayInfo: info,
        events: _eventsOn(date),
        onOpenBasis: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BasisScreen(date: date, dayInfo: info, lunarSource: widget.lunarSource),
          ),
        ),
        lunarSource: widget.lunarSource,
        onAddEvent: (title) async {
          final event = CalendarEvent(id: _uuid.v4(), title: title, date: date);
          await widget.repository.upsert(event);
          await NotificationService.instance
              .rescheduleForEvent(event, lunarSource: widget.lunarSource);
          await _loadEvents();
          return event;
        },
        onUpdateEvent: (event) async {
          await widget.repository.upsert(event);
          await NotificationService.instance
              .rescheduleForEvent(event, lunarSource: widget.lunarSource);
          await _loadEvents();
        },
        onDeleteEvent: (id) async {
          final event = _events.where((e) => e.id == id).firstOrNull;
          await widget.repository.delete(id);
          if (event != null) {
            await NotificationService.instance
                .cancelForEvent(event, lunarSource: widget.lunarSource);
            await EventPhotoStore.delete(event.photoPath);
          }
          await _loadEvents();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstDayJdn = jdnFromYmd(_visibleMonth.year, _visibleMonth.month, 1);
    final firstWeekday = weekdayFromJdn(firstDayJdn); // 0=일
    final totalDays = daysInMonth(_visibleMonth.year, _visibleMonth.month);
    final leadingBlanks = firstWeekday;
    final cellCount = leadingBlanks + totalDays;
    final rowCount = (cellCount / 7).ceil();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              key: const ValueKey('prev-month-button'),
              tooltip: '이전 달',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _changeMonth(-1),
            ),
            GestureDetector(
              onTap: () => _pickMonth(context),
              child: Text('${_visibleMonth.year}년 ${_visibleMonth.month}월'),
            ),
            IconButton(
              key: const ValueKey('next-month-button'),
              tooltip: '다음 달',
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _changeMonth(1),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.compare_arrows),
            tooltip: '변환기',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ConverterScreen(lunarSource: widget.lunarSource),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.cake_outlined),
            tooltip: '기일 · 생신',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AnniversaryScreen(
                  eventRepository: widget.repository,
                  lunarSource: widget.lunarSource,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SearchScreen(eventRepository: widget.repository),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SettingsScreen(
                  settingsRepository: widget.settingsRepository,
                  eventRepository: widget.repository,
                  onSettingsChanged: widget.onSettingsChanged,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Row(
            children: _weekdayLabels
                .map((w) => Expanded(
                      child: Center(
                        child: Text(
                          w,
                          style: TextStyle(
                            color: w == '일'
                                ? Colors.red
                                : w == '토'
                                    ? Colors.blue
                                    : null,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity < -200) {
                  _changeMonth(1); // 왼쪽으로 스와이프 → 다음 달
                } else if (velocity > 200) {
                  _changeMonth(-1); // 오른쪽으로 스와이프 → 이전 달
                }
              },
              child: GridView.builder(
              padding: EdgeInsets.zero,
              itemCount: rowCount * 7,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
              itemBuilder: (context, index) {
                final dayNum = index - leadingBlanks + 1;
                if (dayNum < 1 || dayNum > totalDays) return const SizedBox.shrink();
                final date = DateTime(_visibleMonth.year, _visibleMonth.month, dayNum);
                final info = _dayInfoProvider.build(date);
                final dayEvents = _eventsOn(date);
                final weekdayIdx = (leadingBlanks + dayNum - 1) % 7;
                final isToday = _isSameDay(date, DateTime.now());

                return InkWell(
                  key: ValueKey('day-$dayNum'),
                  onTap: () => _openDateDetail(date),
                  child: Container(
                    decoration: isToday
                        ? BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.primary))
                        : null,
                    padding: const EdgeInsets.all(2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          '$dayNum',
                          style: TextStyle(
                            color: (widget.settings.showHoliday && info.isHoliday) || weekdayIdx == 0
                                ? Colors.red
                                : weekdayIdx == 6
                                    ? Colors.blue
                                    : null,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (widget.settings.showGanji)
                          Text(
                            info.ilju,
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        if (widget.settings.showLunar && info.lunar != null)
                          Text(
                            '${info.lunar!.month}.${info.lunar!.day}${info.lunar!.isLeapMonth ? '(윤)' : ''}',
                            style: const TextStyle(fontSize: 9, color: Colors.grey),
                          ),
                        if (widget.settings.showSolarTerm && info.solarTerm != null)
                          Text(
                            info.solarTerm!.name,
                            style: const TextStyle(fontSize: 9, color: Colors.green),
                          ),
                        if (widget.settings.showHoliday && info.holidays.isNotEmpty)
                          Text(
                            info.holidays.first.name,
                            style: const TextStyle(fontSize: 9, color: Colors.red),
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (widget.settings.showSonEobsneun && info.isSonEobsneun == true)
                          const Text(
                            '손없는날',
                            style: TextStyle(fontSize: 9, color: Colors.teal),
                          ),
                        if (dayEvents.isNotEmpty)
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              color: dayEvents.any((e) => e.isLunar)
                                  ? Colors.deepPurple
                                  : Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
              ),
            ),
          ),
          const Center(child: AdBannerBar()),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
