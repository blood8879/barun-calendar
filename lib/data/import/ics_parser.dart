import '../../domain/event/event.dart';

/// 최소 ICS(iCalendar) VEVENT 파서 (F19 가져오기).
/// SUMMARY/DTSTART만 지원한다 — 반복 규칙(RRULE)이나 시간대는 다루지 않고
/// 날짜만 뽑아 단발성 일정으로 가져온다.
class IcsParseResult {
  final List<CalendarEvent> events;
  final int skippedCount;
  const IcsParseResult({required this.events, required this.skippedCount});
}

IcsParseResult parseIcs(String raw, String Function() newId) {
  final events = <CalendarEvent>[];
  var skipped = 0;

  final blocks = raw.split('BEGIN:VEVENT');
  for (var i = 1; i < blocks.length; i++) {
    final block = blocks[i].split('END:VEVENT').first;
    final lines = block.split(RegExp(r'\r\n|\n|\r'));
    String? summary;
    DateTime? date;
    for (final line in lines) {
      if (line.startsWith('SUMMARY')) {
        final idx = line.indexOf(':');
        if (idx != -1) summary = line.substring(idx + 1).trim();
      } else if (line.startsWith('DTSTART')) {
        final idx = line.indexOf(':');
        if (idx != -1) date = _parseIcsDate(line.substring(idx + 1).trim());
      }
    }
    if (summary != null && date != null) {
      events.add(CalendarEvent(id: newId(), title: summary, date: date));
    } else {
      skipped++;
    }
  }
  return IcsParseResult(events: events, skippedCount: skipped);
}

DateTime? _parseIcsDate(String value) {
  // YYYYMMDD 또는 YYYYMMDDTHHMMSS[Z]
  final digits = value.replaceAll('Z', '');
  if (digits.length < 8) return null;
  final year = int.tryParse(digits.substring(0, 4));
  final month = int.tryParse(digits.substring(4, 6));
  final day = int.tryParse(digits.substring(6, 8));
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}
