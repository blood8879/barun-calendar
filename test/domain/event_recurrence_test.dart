import 'package:flutter_test/flutter_test.dart';
import 'package:barun_calendar/domain/calendar/day_info.dart';
import 'package:barun_calendar/domain/event/event.dart';

/// 연도에 따라 같은 음력 월/일이 다른 양력 날짜로 변환되도록(실제 음력의 특징을
/// 흉내 내) 만든 테스트 전용 더미. 등록 연도(2020)의 음력 3/15을 앵커로 고정하고,
/// 대상 연도에 따라 변환되는 양력 일자가 매년 1일씩 밀리도록 해, "매년 자동 변환"이
/// 실제로 lunarSource를 거쳐 계산되는지(단순 양력 반복이 아닌지) 검증한다.
class _DriftingLunarDataSource implements LunarCalendarDataSource {
  const _DriftingLunarDataSource();

  @override
  LunarDate? solarToLunar(DateTime solarDate) {
    if (solarDate.year == 2020 && solarDate.month == 3 && solarDate.day == 15) {
      return const LunarDate(year: 2020, month: 3, day: 15);
    }
    return null;
  }

  @override
  DateTime? lunarToSolar(int year, int month, int day, {bool isLeapMonth = false}) {
    if (month != 3 || day != 15) return null;
    return DateTime(year, 3, 15 + (year - 2020));
  }
}

void main() {
  test('반복 없음 일정은 등록 연도에만 발생한다', () {
    final e = CalendarEvent(id: '1', title: 't', date: DateTime(2026, 3, 5));
    expect(e.occurrencesInYear(2026), [DateTime(2026, 3, 5)]);
    expect(e.occurrencesInYear(2027), isEmpty);
  });

  test('매년 반복 일정은 등록 이후 매년 같은 월/일에 발생한다', () {
    final e = CalendarEvent(
      id: '1',
      title: 't',
      date: DateTime(2020, 2, 29),
      recurrence: RecurrenceType.yearly,
    );
    expect(e.occurrencesInYear(2028), [DateTime(2028, 2, 29)]); // 2028은 윤년
    // 2021은 윤년이 아니라 2/29가 존재하지 않으므로 발생하지 않는다.
    expect(e.occurrencesInYear(2021), isEmpty);
    expect(e.occurrencesInYear(2019), isEmpty);
  });

  test('매월 반복 일정은 등록 연도의 등록월부터, 31일이 없는 달은 건너뛴다', () {
    final e = CalendarEvent(
      id: '1',
      title: 't',
      date: DateTime(2026, 1, 31),
      recurrence: RecurrenceType.monthly,
    );
    final occurrences2026 = e.occurrencesInYear(2026);
    expect(occurrences2026.first, DateTime(2026, 1, 31));
    expect(occurrences2026.any((d) => d.month == 4), isFalse); // 4월엔 31일이 없다
    expect(occurrences2026.length, lessThan(12));
  });

  test('다단 알림 시각은 발생일 자정에서 분 단위로 역산된다', () {
    final e = CalendarEvent(
      id: '1',
      title: 't',
      date: DateTime(2026, 3, 5),
      reminderMinutesBefore: [0, 60, 1440],
    );
    final times = e.reminderTimesFor(DateTime(2026, 3, 5));
    expect(times, [
      DateTime(2026, 3, 5),
      DateTime(2026, 3, 4, 23),
      DateTime(2026, 3, 4),
    ]);
  });

  test('사용자 지정 주기(매 N일) 반복은 등록일부터 고정 간격으로 발생한다', () {
    final e = CalendarEvent(
      id: '1',
      title: 't',
      date: DateTime(2026, 1, 1),
      recurrence: RecurrenceType.custom,
      customUnit: RecurrenceUnit.day,
      customInterval: 10,
    );
    final occurrences = e.occurrencesInYear(2026);
    expect(occurrences.first, DateTime(2026, 1, 1));
    expect(occurrences[1], DateTime(2026, 1, 11));
    expect(occurrences.every((d) => d.difference(DateTime(2026, 1, 1)).inDays % 10 == 0), isTrue);
  });

  test('사용자 지정 주기(매 N개월) 반복은 개월 단위로 진행하며 존재하지 않는 날은 건너뛴다', () {
    final e = CalendarEvent(
      id: '1',
      title: 't',
      date: DateTime(2026, 1, 31),
      recurrence: RecurrenceType.custom,
      customUnit: RecurrenceUnit.month,
      customInterval: 2,
    );
    final occurrences = e.occurrencesInYear(2026);
    expect(occurrences, contains(DateTime(2026, 1, 31)));
    expect(occurrences, contains(DateTime(2026, 3, 31)));
    expect(occurrences.any((d) => d.month == 4), isFalse); // 4/31은 존재하지 않음(2개월 간격이라 대상도 아님)
  });

  test('음력 기준 매년 반복은 occurrencesInYearResolved에서 lunarSource로 실제 매년 변환일을 구한다', () {
    final e = CalendarEvent(
      id: '1',
      title: '생신',
      date: DateTime(2020, 3, 15),
      kind: EventKind.birthday,
      isLunar: true,
      recurrence: RecurrenceType.yearly,
    );
    const source = _DriftingLunarDataSource();

    // 단순 양력 반복(occurrencesInYear)은 lunarSource를 모르므로 매년 같은 월/일을 반환한다.
    expect(e.occurrencesInYear(2023), [DateTime(2023, 3, 15)]);

    // 반면 resolved 버전은 그 해의 실제 음력→양력 변환일(3일 밀린 3/18)을 반환해야 한다.
    expect(
      e.occurrencesInYearResolved(2023, lunarSource: source),
      [DateTime(2023, 3, 18)],
    );

    // lunarSource가 없으면 안전하게 기존 양력 반복으로 폴백한다.
    expect(e.occurrencesInYearResolved(2023), [DateTime(2023, 3, 15)]);
  });

  test('구버전 저장 데이터(customUnit/customInterval 없음)는 하위 호환되어 정상 로드된다', () {
    final legacyJson = {
      'id': '1',
      'title': '옛날 일정',
      'date': DateTime(2026, 5, 1).toIso8601String(),
      'isLunar': false,
      'kind': 'normal',
      'memo': null,
      'recurrence': 'monthly',
      'reminderMinutesBefore': [0],
      'photoPath': null,
    };
    final restored = CalendarEvent.fromJson(legacyJson);
    expect(restored.recurrence, RecurrenceType.monthly);
    expect(restored.customUnit, isNull);
    expect(restored.customInterval, 1);
    expect(restored.occurrencesInYear(2026), isNotEmpty);
  });

  test('첨부 사진 경로는 JSON 직렬화/역직렬화 시 보존된다', () {
    final e = CalendarEvent(
      id: '1',
      title: '결혼기념일',
      date: DateTime(2026, 5, 1),
      kind: EventKind.anniversary,
      photoPath: '/data/user/0/app/files/event_photos/1.jpg',
    );
    final restored = CalendarEvent.fromJson(e.toJson());
    expect(restored.photoPath, e.photoPath);
  });

  test('copyWith(clearPhoto: true)는 첨부 사진을 제거한다', () {
    final e = CalendarEvent(
      id: '1',
      title: 't',
      date: DateTime(2026, 5, 1),
      photoPath: '/some/path.jpg',
    );
    final cleared = e.copyWith(clearPhoto: true);
    expect(cleared.photoPath, isNull);
  });
}
