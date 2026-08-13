import 'package:flutter_test/flutter_test.dart';
import 'package:barun_calendar/data/import/ics_parser.dart';

void main() {
  test('VEVENT의 SUMMARY/DTSTART를 파싱해 일정으로 변환한다', () {
    const ics = '''
BEGIN:VCALENDAR
BEGIN:VEVENT
SUMMARY:팀 회의
DTSTART:20260305T090000
END:VEVENT
BEGIN:VEVENT
SUMMARY:생일
DTSTART:20260812
END:VEVENT
END:VCALENDAR
''';
    var counter = 0;
    final result = parseIcs(ics, () => 'id-${counter++}');
    expect(result.events.length, 2);
    expect(result.events[0].title, '팀 회의');
    expect(result.events[0].date, DateTime(2026, 3, 5));
    expect(result.events[1].title, '생일');
    expect(result.events[1].date, DateTime(2026, 8, 12));
    expect(result.skippedCount, 0);
  });

  test('SUMMARY나 DTSTART가 없는 VEVENT는 건너뛴다', () {
    const ics = '''
BEGIN:VEVENT
SUMMARY:제목만 있음
END:VEVENT
''';
    final result = parseIcs(ics, () => 'x');
    expect(result.events, isEmpty);
    expect(result.skippedCount, 1);
  });
}
