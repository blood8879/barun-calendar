import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../domain/calendar/day_info.dart';

/// KASI(한국천문연구원) 공공데이터포털 「음양력 정보」·「특일 정보」로 빌드타임에 구운
/// `assets/data/*_table.json` 을 읽어 제공하는 실 데이터소스.
///
/// 데이터는 런타임에 API를 호출하지 않는다(명세 C-9/C-22) — `tool/fetch_kasi_data.py` +
/// `tool/build_kasi_assets.py` 로 미리 구워 에셋에 포함시킨 값만 읽는다.
/// 음력(lunar_table.json)은 명세 요구 범위 1899~2050 전체를 KASI 실측으로 확보했다.
/// 절기/공휴일/기념일(solarterm·holiday·anniversary_table.json)은 KASI 특일 API 자체가
/// 2000~2028년(공휴일·기념일은 2004~2028년)만 데이터를 제공해 그 범위로 제한된다
/// (OPEN_QUESTIONS.md #1 참고 — 절기는 범위 밖을 `ComputedFallbackSolarTermDataSource`가
/// 검증된 천문 계산으로 보완).
/// 범위를 벗어난 날짜는 null/빈 값을 반환한다(조용한 폴백 금지, 명세 K5).
class KasiCalendarTables {
  final Map<String, List<dynamic>> _lunarBySolarKey;
  final Map<String, Map<String, dynamic>> _termsByDateKey;
  final Map<String, List<dynamic>> _holidaysByDateKey;
  final Map<String, List<dynamic>> _anniversariesByDateKey;

  KasiCalendarTables._(
    this._lunarBySolarKey,
    this._termsByDateKey,
    this._holidaysByDateKey,
    this._anniversariesByDateKey,
  );

  static KasiCalendarTables? _cached;

  /// 앱 시작 시 한 번 호출해 에셋을 메모리에 적재한다.
  static Future<KasiCalendarTables> load() async {
    if (_cached != null) return _cached!;
    final lunarRaw = await rootBundle.loadString('assets/data/lunar_table.json');
    final termsRaw = await rootBundle.loadString('assets/data/solarterm_table.json');
    final holidaysRaw = await rootBundle.loadString('assets/data/holiday_table.json');
    final annivRaw = await rootBundle.loadString('assets/data/anniversary_table.json');

    final tables = KasiCalendarTables._(
      (jsonDecode(lunarRaw) as Map<String, dynamic>).cast<String, List<dynamic>>(),
      (jsonDecode(termsRaw) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as Map<String, dynamic>))),
      (jsonDecode(holidaysRaw) as Map<String, dynamic>).cast<String, List<dynamic>>(),
      (jsonDecode(annivRaw) as Map<String, dynamic>).cast<String, List<dynamic>>(),
    );
    _cached = tables;
    return tables;
  }
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

class KasiLunarCalendarDataSource implements LunarCalendarDataSource {
  final KasiCalendarTables tables;
  late final Map<String, List<dynamic>> _bySolar = tables._lunarBySolarKey;
  late final Map<String, DateTime> _byLunar = _buildReverseIndex();

  KasiLunarCalendarDataSource(this.tables);

  Map<String, DateTime> _buildReverseIndex() {
    final map = <String, DateTime>{};
    for (final entry in _bySolar.entries) {
      final v = entry.value;
      final leap = v[3] == 1;
      final key = '${v[0]}-${v[1]}-${v[2]}-${leap ? 1 : 0}';
      final y = int.parse(entry.key.substring(0, 4));
      final m = int.parse(entry.key.substring(4, 6));
      final d = int.parse(entry.key.substring(6, 8));
      map[key] = DateTime(y, m, d);
    }
    return map;
  }

  @override
  LunarDate? solarToLunar(DateTime solarDate) {
    final v = _bySolar[_ymd(solarDate)];
    if (v == null) return null;
    return LunarDate(
      year: v[0] as int,
      month: v[1] as int,
      day: v[2] as int,
      isLeapMonth: v[3] == 1,
    );
  }

  @override
  DateTime? lunarToSolar(int year, int month, int day, {bool isLeapMonth = false}) {
    return _byLunar['$year-$month-$day-${isLeapMonth ? 1 : 0}'];
  }

  /// 근거 화면(F2/S3)용: 해당 양력일의 일진/세차/월건 원문(KASI 공표값)을 반환.
  Map<String, String>? ganjiOn(DateTime solarDate) {
    final v = _bySolar[_ymd(solarDate)];
    if (v == null) return null;
    return {'ilju': v[4] as String, 'secha': v[5] as String, 'wolgeon': v[6] as String};
  }
}

class KasiSolarTermDataSource implements SolarTermDataSource {
  final KasiCalendarTables tables;
  KasiSolarTermDataSource(this.tables);

  @override
  SolarTerm? solarTermOn(DateTime date) {
    final v = tables._termsByDateKey[_ymd(date)];
    if (v == null) return null;
    final hh = v['hh'] as int;
    final mm = v['mm'] as int;
    return SolarTerm(
      name: v['name'] as String,
      exactMoment: DateTime(date.year, date.month, date.day, hh, mm),
    );
  }

  @override
  List<SolarTerm> solarTermsInYear(int year) {
    final result = <SolarTerm>[];
    for (final entry in tables._termsByDateKey.entries) {
      if (!entry.key.startsWith(year.toString())) continue;
      final y = int.parse(entry.key.substring(0, 4));
      final m = int.parse(entry.key.substring(4, 6));
      final d = int.parse(entry.key.substring(6, 8));
      final hh = entry.value['hh'] as int;
      final mm = entry.value['mm'] as int;
      result.add(SolarTerm(name: entry.value['name'] as String, exactMoment: DateTime(y, m, d, hh, mm)));
    }
    result.sort((a, b) => a.exactMoment.compareTo(b.exactMoment));
    return result;
  }
}

class KasiHolidayDataSource implements HolidayDataSource {
  final KasiCalendarTables tables;
  KasiHolidayDataSource(this.tables);

  @override
  List<HolidayInfo> holidaysOn(DateTime date) {
    final key = _ymd(date);
    final result = <HolidayInfo>[];
    for (final name in tables._holidaysByDateKey[key] ?? const []) {
      result.add(HolidayInfo(name: name as String, isOffDay: true));
    }
    for (final name in tables._anniversariesByDateKey[key] ?? const []) {
      result.add(HolidayInfo(name: name as String, isOffDay: false));
    }
    return result;
  }
}
