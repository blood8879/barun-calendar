import 'package:flutter/material.dart';

import '../../data/event/event_repository.dart';
import '../../domain/calendar/day_info.dart';
import '../../domain/event/event.dart';

/// 디자인 목업 S5(기일/생신) 대응 화면.
/// [EventKind.birthday]/[EventKind.memorial] 일정을 모아, 다가오는 순서로 정렬해 보여준다.
/// 음력 기준(`isLunar`) 일정은 [lunarSource]로 매년 실제 발생 양력 날짜를 다시 계산한다
/// (윤달은 평달로 취급 — OPEN_QUESTIONS.md 참고. 데이터 범위 밖이면 조용한 폴백 없이 안내만 표시).
class AnniversaryScreen extends StatefulWidget {
  final EventRepository eventRepository;
  final LunarCalendarDataSource lunarSource;
  final DateTime Function()? nowOverride; // 테스트용

  const AnniversaryScreen({
    super.key,
    required this.eventRepository,
    required this.lunarSource,
    this.nowOverride,
  });

  @override
  State<AnniversaryScreen> createState() => _AnniversaryScreenState();
}

class _AnniversaryRow {
  final CalendarEvent event;
  final DateTime? nextOccurrence; // null이면 데이터 범위 밖이라 계산 불가
  final int? dDay;

  _AnniversaryRow({required this.event, required this.nextOccurrence, required this.dDay});
}

class _AnniversaryScreenState extends State<AnniversaryScreen> {
  bool _loading = true;
  List<_AnniversaryRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime get _today {
    final now = (widget.nowOverride ?? DateTime.now)();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime? _nextOccurrenceFor(CalendarEvent e) {
    final today = _today;
    for (final year in [today.year, today.year + 1]) {
      final occurrence = e.isLunar
          ? e.lunarOccurrenceInYear(widget.lunarSource, year)
          : (e.date.month == 0
              ? null
              : DateTime(year, e.date.month, e.date.day));
      if (occurrence == null) continue;
      final d = DateTime(occurrence.year, occurrence.month, occurrence.day);
      if (!d.isBefore(today)) return d;
    }
    return null;
  }

  Future<void> _load() async {
    final all = await widget.eventRepository.loadAll();
    final anniversaries = all
        .where((e) => e.kind == EventKind.birthday || e.kind == EventKind.memorial)
        .toList();
    final today = _today;
    final rows = anniversaries.map((e) {
      final next = _nextOccurrenceFor(e);
      final dDay = next?.difference(today).inDays;
      return _AnniversaryRow(event: e, nextOccurrence: next, dDay: dDay);
    }).toList();
    rows.sort((a, b) {
      if (a.dDay == null && b.dDay == null) return 0;
      if (a.dDay == null) return 1; // 계산 불가 항목은 뒤로
      if (b.dDay == null) return -1;
      return a.dDay!.compareTo(b.dDay!);
    });
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  String _formatDate(DateTime d) {
    final w = _weekdays[d.weekday - 1];
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}.$mm.$dd ($w)';
  }

  String _kindLabel(EventKind k) => switch (k) {
        EventKind.birthday => '생신',
        EventKind.memorial => '기일',
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('기일 · 생신')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? const Center(child: Text('등록된 기일·생신 일정이 없습니다.'))
              : ListView.separated(
                  itemCount: _rows.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final row = _rows[index];
                    final e = row.event;
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(_kindLabel(e.kind)),
                      ),
                      title: Text(e.title),
                      subtitle: Text(
                        row.nextOccurrence == null
                            ? (e.isLunar
                                ? '음력 데이터 범위 밖이라 다음 발생일을 계산할 수 없습니다.'
                                : '다음 발생일을 계산할 수 없습니다.')
                            : '${_formatDate(row.nextOccurrence!)}'
                                '${e.isLunar ? ' · 음력 기준' : ''}',
                      ),
                      trailing: row.dDay == null
                          ? null
                          : Text(
                              row.dDay == 0 ? 'D-DAY' : 'D-${row.dDay}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                    );
                  },
                ),
    );
  }
}
