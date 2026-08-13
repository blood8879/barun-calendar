import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/event/event_photo_store.dart';
import '../../domain/calendar/day_info.dart';
import '../../domain/event/event.dart';

const _reminderOptions = <int, String>{
  0: '당일',
  60: '1시간 전',
  1440: '1일 전',
  10080: '1주 전',
};

const _recurrenceLabels = <RecurrenceType, String>{
  RecurrenceType.none: '반복 안 함',
  RecurrenceType.yearly: '매년',
  RecurrenceType.monthly: '매월',
  RecurrenceType.custom: '사용자 지정 주기',
};

const _customUnitLabels = <RecurrenceUnit, String>{
  RecurrenceUnit.day: '일마다',
  RecurrenceUnit.week: '주마다',
  RecurrenceUnit.month: '개월마다',
};

const _kindLabels = <EventKind, String>{
  EventKind.normal: '일반',
  EventKind.anniversary: '기념일',
  EventKind.birthday: '생신',
  EventKind.memorial: '기일',
};

/// 명세 디자인 목업의 "S2 날짜상세시트"에 대응하는 바텀시트.
class DateDetailSheet extends StatefulWidget {
  final DayInfo dayInfo;
  final List<CalendarEvent> events;
  final Future<CalendarEvent> Function(String title) onAddEvent;
  final Future<void> Function(CalendarEvent event) onUpdateEvent;
  final Future<void> Function(String id) onDeleteEvent;
  final VoidCallback? onOpenBasis;
  // 음력 날짜 직접 선택 UI(윤달 포함) 및 "음력 O월 O일 기준" 표시에 사용.
  final LunarCalendarDataSource? lunarSource;

  const DateDetailSheet({
    super.key,
    required this.dayInfo,
    required this.events,
    required this.onAddEvent,
    required this.onUpdateEvent,
    required this.onDeleteEvent,
    this.onOpenBasis,
    this.lunarSource,
  });

  @override
  State<DateDetailSheet> createState() => _DateDetailSheetState();
}

class _DateDetailSheetState extends State<DateDetailSheet> {
  final _controller = TextEditingController();
  late List<CalendarEvent> _events;
  RecurrenceType _newRecurrence = RecurrenceType.none;
  RecurrenceUnit _newCustomUnit = RecurrenceUnit.month;
  int _newCustomInterval = 1;
  final Set<int> _newReminders = {};

  @override
  void initState() {
    super.initState();
    _events = List.of(widget.events);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _editEvent(CalendarEvent event) async {
    var recurrence = event.recurrence;
    var kind = event.kind;
    var isLunar = event.isLunar;
    var photoPath = event.photoPath;
    var customUnit = event.customUnit ?? RecurrenceUnit.month;
    var customInterval = event.customInterval < 1 ? 1 : event.customInterval;
    final reminders = Set<int>.from(event.reminderMinutesBefore);
    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(event.title),
          content: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (photoPath != null && photoPath!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(photoPath!),
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.photo_outlined),
                    label: Text(photoPath == null ? '사진 추가' : '사진 변경'),
                    onPressed: () async {
                      final picked = await EventPhotoStore.pickAndStore();
                      if (picked == null) return;
                      final old = photoPath;
                      setDialogState(() => photoPath = picked);
                      await EventPhotoStore.delete(old);
                    },
                  ),
                  if (photoPath != null)
                    TextButton(
                      onPressed: () async {
                        final old = photoPath;
                        setDialogState(() => photoPath = null);
                        await EventPhotoStore.delete(old);
                      },
                      child: const Text('삭제'),
                    ),
                ],
              ),
              DropdownButton<EventKind>(
                value: kind,
                items: EventKind.values
                    .map((k) => DropdownMenuItem(value: k, child: Text(_kindLabels[k]!)))
                    .toList(),
                onChanged: (v) => setDialogState(() => kind = v ?? EventKind.normal),
              ),
              if (kind == EventKind.birthday || kind == EventKind.memorial) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('음력 기준 (매년 음력 날짜로 반복)'),
                  value: isLunar,
                  onChanged: (v) => setDialogState(() => isLunar = v),
                ),
                if (isLunar && widget.lunarSource != null)
                  Builder(builder: (context) {
                    final lunar = widget.lunarSource!.solarToLunar(event.date);
                    return Text(
                      lunar != null
                          ? '이 날은 ${lunar.label} 기준 반복 일정입니다.'
                          : '음력 변환 정보를 찾을 수 없습니다.',
                      style: const TextStyle(color: Colors.deepPurple, fontSize: 12),
                    );
                  }),
              ],
              DropdownButton<RecurrenceType>(
                value: recurrence,
                items: RecurrenceType.values
                    .map((r) => DropdownMenuItem(value: r, child: Text(_recurrenceLabels[r]!)))
                    .toList(),
                onChanged: (v) => setDialogState(() => recurrence = v ?? RecurrenceType.none),
              ),
              if (recurrence == RecurrenceType.custom)
                Row(
                  children: [
                    const Text('매 '),
                    SizedBox(
                      width: 56,
                      child: TextFormField(
                        initialValue: '$customInterval',
                        keyboardType: TextInputType.number,
                        onChanged: (v) => customInterval = int.tryParse(v) ?? 1,
                      ),
                    ),
                    DropdownButton<RecurrenceUnit>(
                      value: customUnit,
                      items: RecurrenceUnit.values
                          .map((u) => DropdownMenuItem(value: u, child: Text(_customUnitLabels[u]!)))
                          .toList(),
                      onChanged: (v) => setDialogState(() => customUnit = v ?? RecurrenceUnit.month),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: _reminderOptions.entries
                    .map((entry) => FilterChip(
                          label: Text(entry.value),
                          selected: reminders.contains(entry.key),
                          onSelected: (sel) => setDialogState(() {
                            if (sel) {
                              reminders.add(entry.key);
                            } else {
                              reminders.remove(entry.key);
                            }
                          }),
                        ))
                    .toList(),
              ),
            ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('저장')),
          ],
        ),
      ),
    );
    if (updated != true) return;
    final result = event.copyWith(
      kind: kind,
      isLunar: kind == EventKind.birthday || kind == EventKind.memorial ? isLunar : false,
      recurrence: recurrence,
      customUnit: recurrence == RecurrenceType.custom ? customUnit : null,
      clearCustomUnit: recurrence != RecurrenceType.custom,
      customInterval: customInterval < 1 ? 1 : customInterval,
      reminderMinutesBefore: reminders.toList()..sort(),
      photoPath: photoPath,
      clearPhoto: photoPath == null,
    );
    await widget.onUpdateEvent(result);
    setState(() {
      final idx = _events.indexWhere((e) => e.id == event.id);
      if (idx != -1) _events[idx] = result;
    });
  }

  /// 사용자가 "음력 O월 O일"을 직접 골라 등록하면, 매년 양력으로 재변환해 입력할 필요 없이
  /// 그 자리에서 올해의 실제 양력 날짜로 변환해 등록하고, 이후 매년 자동으로 그 해의
  /// 음력→양력 변환일에 표시/알림 가도록(recurrence=yearly, isLunar=true) 만든다.
  Future<void> _addLunarEvent() async {
    final source = widget.lunarSource;
    if (source == null) return;
    final anchorYear = widget.dayInfo.date.year;
    final titleController = TextEditingController();
    var month = 1;
    var day = 1;
    var isLeap = false;
    var kind = EventKind.birthday;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final preview = source.lunarToSolar(anchorYear, month, day, isLeapMonth: isLeap);
          return AlertDialog(
            title: const Text('음력 날짜로 등록'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(hintText: '제목 (예: 어머니 생신)'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<EventKind>(
                    value: kind,
                    items: const [EventKind.birthday, EventKind.memorial, EventKind.anniversary]
                        .map((k) => DropdownMenuItem(value: k, child: Text(_kindLabels[k]!)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => kind = v ?? EventKind.birthday),
                  ),
                  Row(
                    children: [
                      const Text('음력 '),
                      DropdownButton<int>(
                        value: month,
                        items: List.generate(12, (i) => i + 1)
                            .map((m) => DropdownMenuItem(value: m, child: Text('$m월')))
                            .toList(),
                        onChanged: (v) => setDialogState(() => month = v ?? 1),
                      ),
                      DropdownButton<int>(
                        value: day,
                        items: List.generate(30, (i) => i + 1)
                            .map((d) => DropdownMenuItem(value: d, child: Text('$d일')))
                            .toList(),
                        onChanged: (v) => setDialogState(() => day = v ?? 1),
                      ),
                    ],
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('윤달'),
                    value: isLeap,
                    onChanged: (v) => setDialogState(() => isLeap = v ?? false),
                  ),
                  Text(
                    preview != null
                        ? '$anchorYear년 양력: ${preview.year}.${preview.month.toString().padLeft(2, '0')}.'
                            '${preview.day.toString().padLeft(2, '0')} — 이후 매년 자동으로 그 해 양력 날짜에 표시됩니다.'
                        : '$anchorYear년에는 이 음력 날짜가 없습니다(데이터 범위 밖이거나 존재하지 않는 날짜).',
                    style: TextStyle(
                      color: preview == null ? Colors.red : Colors.deepPurple,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
              FilledButton(
                onPressed: preview == null ? null : () => Navigator.pop(context, true),
                child: const Text('등록'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true) return;
    final title = titleController.text.trim();
    if (title.isEmpty) return;
    final solar = source.lunarToSolar(anchorYear, month, day, isLeapMonth: isLeap);
    if (solar == null) return;

    var created = await widget.onAddEvent(title);
    created = created.copyWith(
      date: solar,
      isLunar: true,
      kind: kind,
      recurrence: RecurrenceType.yearly,
    );
    await widget.onUpdateEvent(created);
    setState(() => _events.add(created));
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.dayInfo;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              Text(
                '${info.date.year}.${info.date.month.toString().padLeft(2, '0')}.'
                '${info.date.day.toString().padLeft(2, '0')} (${info.ilju})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              if (info.lunar != null)
                Text(info.lunar!.label, style: Theme.of(context).textTheme.bodyMedium),
              if (info.isSonEobsneun == true)
                const Text('오늘은 손없는날입니다', style: TextStyle(color: Colors.teal)),
              if (info.solarTerm != null)
                Text(
                  info.solarTerm!.isComputedFallback
                      ? '절기: ${info.solarTerm!.name} (계산값·비공식)'
                      : '절기: ${info.solarTerm!.name}',
                  style: info.solarTerm!.isComputedFallback
                      ? const TextStyle(color: Colors.orange)
                      : null,
                ),
              for (final h in info.holidays)
                Text(h.name, style: const TextStyle(color: Colors.red)),
              if (widget.onOpenBasis != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: widget.onOpenBasis,
                    child: const Text('근거 보기'),
                  ),
                ),
              const Divider(height: 24),
              Text('일정', style: Theme.of(context).textTheme.titleMedium),
              for (final e in _events)
                ListTile(
                  key: ValueKey('event-${e.id}'),
                  leading: (e.photoPath != null && e.photoPath!.isNotEmpty)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.file(
                            File(e.photoPath!),
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          ),
                        )
                      : null,
                  title: Text(e.title),
                  subtitle: Text([
                    if (e.recurrence == RecurrenceType.custom)
                      '매 ${e.customInterval}${_customUnitLabels[e.customUnit ?? RecurrenceUnit.month]}'
                    else if (e.recurrence != RecurrenceType.none)
                      _recurrenceLabels[e.recurrence]!,
                    if (e.isLunar && widget.lunarSource != null)
                      () {
                        final lunar = widget.lunarSource!.solarToLunar(e.date);
                        return lunar != null ? '음력 ${lunar.month}월 ${lunar.day}일 기준' : '음력 기준';
                      }(),
                    if (e.reminderMinutesBefore.isNotEmpty) '알림 ${e.reminderMinutesBefore.length}건',
                  ].join(' · ')),
                  onTap: () => _editEvent(e),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await widget.onDeleteEvent(e.id);
                      setState(() => _events.removeWhere((ev) => ev.id == e.id));
                    },
                  ),
                ),
              if (_events.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('등록된 일정이 없습니다.', style: TextStyle(color: Colors.grey)),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(hintText: '새 일정 제목'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle),
                    onPressed: () async {
                      final title = _controller.text.trim();
                      if (title.isEmpty) return;
                      var created = await widget.onAddEvent(title);
                      if (_newRecurrence != RecurrenceType.none || _newReminders.isNotEmpty) {
                        created = created.copyWith(
                          recurrence: _newRecurrence,
                          customUnit: _newRecurrence == RecurrenceType.custom ? _newCustomUnit : null,
                          clearCustomUnit: _newRecurrence != RecurrenceType.custom,
                          customInterval: _newCustomInterval < 1 ? 1 : _newCustomInterval,
                          reminderMinutesBefore: _newReminders.toList()..sort(),
                        );
                        await widget.onUpdateEvent(created);
                      }
                      _controller.clear();
                      setState(() {
                        _events.add(created);
                        _newRecurrence = RecurrenceType.none;
                        _newCustomUnit = RecurrenceUnit.month;
                        _newCustomInterval = 1;
                        _newReminders.clear();
                      });
                    },
                  ),
                ],
              ),
              if (widget.lunarSource != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.brightness_2_outlined),
                    label: const Text('음력 날짜로 생신·기일 등록'),
                    onPressed: _addLunarEvent,
                  ),
                ),
              Row(
                children: [
                  const Text('반복: '),
                  DropdownButton<RecurrenceType>(
                    value: _newRecurrence,
                    items: RecurrenceType.values
                        .map((r) => DropdownMenuItem(value: r, child: Text(_recurrenceLabels[r]!)))
                        .toList(),
                    onChanged: (v) => setState(() => _newRecurrence = v ?? RecurrenceType.none),
                  ),
                ],
              ),
              if (_newRecurrence == RecurrenceType.custom)
                Row(
                  children: [
                    const Text('매 '),
                    SizedBox(
                      width: 56,
                      child: TextFormField(
                        initialValue: '$_newCustomInterval',
                        keyboardType: TextInputType.number,
                        onChanged: (v) => _newCustomInterval = int.tryParse(v) ?? 1,
                      ),
                    ),
                    DropdownButton<RecurrenceUnit>(
                      value: _newCustomUnit,
                      items: RecurrenceUnit.values
                          .map((u) => DropdownMenuItem(value: u, child: Text(_customUnitLabels[u]!)))
                          .toList(),
                      onChanged: (v) => setState(() => _newCustomUnit = v ?? RecurrenceUnit.month),
                    ),
                  ],
                ),
              Wrap(
                spacing: 6,
                children: _reminderOptions.entries
                    .map((entry) => FilterChip(
                          label: Text(entry.value),
                          selected: _newReminders.contains(entry.key),
                          onSelected: (sel) => setState(() {
                            if (sel) {
                              _newReminders.add(entry.key);
                            } else {
                              _newReminders.remove(entry.key);
                            }
                          }),
                        ))
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}
