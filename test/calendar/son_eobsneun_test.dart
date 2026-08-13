import 'package:barun_calendar/domain/calendar/day_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isSonEobsneunDay (C-18)', () {
    test('음력 일자 끝자리 9 또는 0인 날은 손없는날이다', () {
      for (final day in [9, 10, 19, 20, 29, 30]) {
        final lunar = LunarDate(year: 2026, month: 3, day: day);
        expect(isSonEobsneunDay(lunar), isTrue, reason: '$day일은 손없는날이어야 함');
      }
    });

    test('그 외 날짜는 손없는날이 아니다', () {
      for (final day in [1, 2, 8, 11, 18, 21, 28]) {
        final lunar = LunarDate(year: 2026, month: 3, day: day);
        expect(isSonEobsneunDay(lunar), isFalse, reason: '$day일은 손없는날이 아니어야 함');
      }
    });

    test('윤달 여부와 무관하게 동일 규칙이 적용된다', () {
      final leap = LunarDate(year: 2026, month: 6, day: 10, isLeapMonth: true);
      expect(isSonEobsneunDay(leap), isTrue);
    });
  });

  group('DayInfo.isSonEobsneun', () {
    final dummyDate = DateTime(2026, 3, 20);

    test('음력 정보가 없으면 null을 반환한다', () {
      final info = DayInfo(date: dummyDate, ilju: '갑자');
      expect(info.isSonEobsneun, isNull);
    });

    test('음력 정보가 있으면 판정값을 반환한다', () {
      final info = DayInfo(
        date: dummyDate,
        ilju: '갑자',
        lunar: const LunarDate(year: 2026, month: 3, day: 20),
      );
      expect(info.isSonEobsneun, isTrue);
    });
  });
}
