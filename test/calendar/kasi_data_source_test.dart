import 'package:flutter_test/flutter_test.dart';

import 'package:barun_calendar/data/kasi/kasi_calendar_data_sources.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KasiCalendarTables tables;

  setUpAll(() async {
    tables = await KasiCalendarTables.load();
  });

  test('KASI 음양력: 2024-01-01은 계묘년 11월 20일(평달)이다', () {
    final ds = KasiLunarCalendarDataSource(tables);
    final lunar = ds.solarToLunar(DateTime(2024, 1, 1));
    expect(lunar, isNotNull);
    expect(lunar!.year, 2023);
    expect(lunar.month, 11);
    expect(lunar.day, 20);
    expect(lunar.isLeapMonth, false);
  });

  test('KASI 음양력: 왕복 변환 항등', () {
    final ds = KasiLunarCalendarDataSource(tables);
    final back = ds.lunarToSolar(2023, 11, 20, isLeapMonth: false);
    expect(back, DateTime(2024, 1, 1));
  });

  test('KASI 24절기: 2024년 하지는 6/21', () {
    final ds = KasiSolarTermDataSource(tables);
    final terms = ds.solarTermsInYear(2024);
    final hajji = terms.firstWhere((t) => t.name == '하지');
    expect(hajji.exactMoment.month, 6);
    expect(hajji.exactMoment.day, 21);
  });

  test('KASI 공휴일: 2024-02-09~11 설날 연휴', () {
    final ds = KasiHolidayDataSource(tables);
    expect(ds.holidaysOn(DateTime(2024, 2, 9)).any((h) => h.name.contains('설날')), true);
  });
}
