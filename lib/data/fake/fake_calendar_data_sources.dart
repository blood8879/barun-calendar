import '../../domain/calendar/day_info.dart';

/// ⚠ 개발/테스트 전용 가짜(Fake) 데이터소스.
/// KASI 공공데이터포털 서비스키가 없어 실제 음력/24절기/공휴일 값을 계산할 수 없는 동안
/// UI·저장소·알림 등 나머지 기능을 개발/테스트하기 위한 자리 표시자다.
/// 실제 서비스 빌드에 절대 사용하지 말 것 (OPEN_QUESTIONS.md #1 참고).
/// KASI 서비스키가 확보되면 이 파일 대신 `data/kasi/kasi_calendar_data_sources.dart`
/// (KasiLunarCalendarDataSource 등)를 [DayInfoProvider]에 주입하기만 하면 된다.
class FakeLunarCalendarDataSource implements LunarCalendarDataSource {
  const FakeLunarCalendarDataSource();

  @override
  LunarDate? solarToLunar(DateTime solarDate) {
    // 실제 음력 계산이 아님: 대략적인 자리 표시 값(양력일 - 30일 근방)만 제공한다.
    final approx = solarDate.subtract(const Duration(days: 30));
    return LunarDate(year: approx.year, month: approx.month, day: approx.day);
  }

  @override
  DateTime? lunarToSolar(int year, int month, int day, {bool isLeapMonth = false}) {
    return DateTime(year, month, day).add(const Duration(days: 30));
  }
}

class FakeSolarTermDataSource implements SolarTermDataSource {
  const FakeSolarTermDataSource();

  static const _names = [
    '소한', '대한', '입춘', '우수', '경칩', '춘분', '청명', '곡우', '입하', '소만',
    '망종', '하지', '소서', '대서', '입추', '처서', '백로', '추분', '한로', '상강',
    '입동', '소설', '대설', '동지',
  ];

  @override
  SolarTerm? solarTermOn(DateTime date) {
    // 실제 절입 순간 계산이 아님: 매월 6일/21일 근처에만 임의 배치한 자리 표시 값.
    if (date.day == 6) {
      final idx = ((date.month - 1) * 2) % _names.length;
      return SolarTerm(name: _names[idx], exactMoment: date);
    }
    if (date.day == 21) {
      final idx = ((date.month - 1) * 2 + 1) % _names.length;
      return SolarTerm(name: _names[idx], exactMoment: date);
    }
    return null;
  }

  @override
  List<SolarTerm> solarTermsInYear(int year) {
    final result = <SolarTerm>[];
    for (var m = 1; m <= 12; m++) {
      final a = solarTermOn(DateTime(year, m, 6));
      final b = solarTermOn(DateTime(year, m, 21));
      if (a != null) result.add(a);
      if (b != null) result.add(b);
    }
    return result;
  }
}

class FakeHolidayDataSource implements HolidayDataSource {
  const FakeHolidayDataSource();

  // 날짜 고정 공휴일(양력 기준)만 자리 표시로 제공. 음력 기반(설날/추석 등)은
  // 음력 데이터 없이는 계산 불가하므로 비워둔다(조용한 폴백 금지 — 명세 K5).
  static const Map<String, String> _fixed = {
    '01-01': '신정',
    '03-01': '삼일절',
    '05-05': '어린이날',
    '06-06': '현충일',
    '08-15': '광복절',
    '10-03': '개천절',
    '10-09': '한글날',
    '12-25': '크리스마스',
  };

  @override
  List<HolidayInfo> holidaysOn(DateTime date) {
    final key =
        '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final name = _fixed[key];
    if (name == null) return const [];
    return [HolidayInfo(name: name)];
  }
}
