import 'ganji.dart';
import 'jdn.dart';

String iljuOf(DateTime date) =>
    iljinFromJdn(jdnFromYmd(date.year, date.month, date.day)).label;

/// 특정 양력일에 대해 화면에 표시할 부가 정보 묶음.
/// 음력/24절기/공휴일 필드는 [LunarCalendarDataSource] 등 외부 데이터소스 구현체에 따라
/// 값이 없을 수 있다(§16 KASI 데이터 미확보 상태에서는 Fake 구현체만 존재).
class DayInfo {
  final DateTime date;
  final String ilju; // 일진 (규칙 기반, 항상 정확)
  final LunarDate? lunar;
  final SolarTerm? solarTerm;
  final List<HolidayInfo> holidays;

  const DayInfo({
    required this.date,
    required this.ilju,
    this.lunar,
    this.solarTerm,
    this.holidays = const [],
  });

  bool get isHoliday => holidays.any((h) => h.isOffDay);

  /// C-18: 손없는날 여부. 음력 정보가 없으면(데이터소스 미확보) null.
  bool? get isSonEobsneun => lunar == null ? null : isSonEobsneunDay(lunar!);
}

class LunarDate {
  final int year;
  final int month;
  final int day;
  final bool isLeapMonth;

  const LunarDate({
    required this.year,
    required this.month,
    required this.day,
    this.isLeapMonth = false,
  });

  String get label => '음력 $year.${month.toString().padLeft(2, '0')}'
      '${isLeapMonth ? '(윤)' : ''}.${day.toString().padLeft(2, '0')}';
}

/// C-18: 손없는날 = 음력 일자 끝자리가 9 또는 0인 날(9·10·19·20·29·30일).
/// 윤달 여부와 무관하게 동일 규칙 적용.
bool isSonEobsneunDay(LunarDate lunar) {
  final lastDigit = lunar.day % 10;
  return lastDigit == 9 || lastDigit == 0;
}

class SolarTerm {
  final String name; // 예: 입춘, 하지
  final DateTime exactMoment;

  /// true면 KASI 실측값이 아니라 [SolarTermCalculator] 자체 계산 보완값이다
  /// (KASI 특일 API 제공 범위 밖 연도). UI는 이 값을 실측과 구분해 표시해야 한다.
  final bool isComputedFallback;

  const SolarTerm({
    required this.name,
    required this.exactMoment,
    this.isComputedFallback = false,
  });
}

class HolidayInfo {
  final String name;
  final bool isOffDay; // 공휴일(쉬는 날) 여부 — 절기/기념일은 false일 수 있음

  const HolidayInfo({required this.name, this.isOffDay = true});
}

/// 음력 변환 데이터 소스 추상화.
/// 실제 구현체(KASI 연동)는 서비스키 확보 후 작성한다 (OPEN_QUESTIONS.md #1).
abstract class LunarCalendarDataSource {
  LunarDate? solarToLunar(DateTime solarDate);
  DateTime? lunarToSolar(int year, int month, int day, {bool isLeapMonth = false});
}

/// 24절기 데이터 소스 추상화.
abstract class SolarTermDataSource {
  SolarTerm? solarTermOn(DateTime date);
  List<SolarTerm> solarTermsInYear(int year);
}

/// 공휴일/기념일 데이터 소스 추상화.
abstract class HolidayDataSource {
  List<HolidayInfo> holidaysOn(DateTime date);
}

/// 위 세 데이터소스를 조합해 [DayInfo]를 만드는 조합기.
/// 데이터소스가 null을 반환하면(즉 알 수 없으면) 해당 필드는 비워둔다 — 조용한 폴백으로
/// 가짜 값을 채우지 않는다(명세 §1-3 K5).
class DayInfoProvider {
  final LunarCalendarDataSource lunar;
  final SolarTermDataSource solarTerm;
  final HolidayDataSource holiday;

  const DayInfoProvider({
    required this.lunar,
    required this.solarTerm,
    required this.holiday,
  });

  DayInfo build(DateTime date) {
    return DayInfo(
      date: date,
      ilju: iljuOf(date),
      lunar: lunar.solarToLunar(date),
      solarTerm: solarTerm.solarTermOn(date),
      holidays: holiday.holidaysOn(date),
    );
  }
}
