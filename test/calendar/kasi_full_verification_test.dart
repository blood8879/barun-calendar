// 명세 §13 L1/L4 전수검증 — 실제 확보된 KASI 데이터 범위 내에서 수행한다.
//
// L4(음력 왕복 항등 55,153일 상당): lunar_table.json은 1899~2050 KASI 실측 전체를 담고
// 있으므로, 그 안의 모든 항목에 대해 solarToLunar -> lunarToSolar 왕복이 원래 양력일과
// 정확히 일치하는지 100% 전수 검증한다.
//
// L1(24절기 전수 KASI 확정값과 100% 일치): KASI 특일 API가 실제로 제공하는 범위는
// 2000~2028년뿐이다(OPEN_QUESTIONS.md #1). 그 확정 범위 내에서는 100% 일치를 요구하고,
// 범위 밖은 이 테스트의 대상이 아니다(계산 보완값 자체 검증은
// test/calendar/solar_term_calculator_test.dart에서 별도로 다룬다).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:barun_calendar/data/kasi/kasi_calendar_data_sources.dart';

void main() {
  late KasiCalendarTables tables;
  late KasiLunarCalendarDataSource lunar;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tables = await KasiCalendarTables.load();
    lunar = KasiLunarCalendarDataSource(tables);
  });

  test('L4: 음력 왕복 항등 — KASI 실측 전 구간(1899~2050) 100% 일치', () {
    final raw = jsonDecode(
      File('assets/data/lunar_table.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    var total = 0;
    var mismatches = 0;
    for (final entry in raw.entries) {
      total++;
      final solarKey = entry.key;
      final solarDate = DateTime(
        int.parse(solarKey.substring(0, 4)),
        int.parse(solarKey.substring(4, 6)),
        int.parse(solarKey.substring(6, 8)),
      );
      final v = entry.value as List<dynamic>;
      final lunarYear = v[0] as int;
      final lunarMonth = v[1] as int;
      final lunarDay = v[2] as int;
      final isLeap = v[3] == 1;

      final decoded = lunar.solarToLunar(solarDate);
      final reencoded =
          lunar.lunarToSolar(lunarYear, lunarMonth, lunarDay, isLeapMonth: isLeap);

      final ok = decoded != null &&
          decoded.year == lunarYear &&
          decoded.month == lunarMonth &&
          decoded.day == lunarDay &&
          decoded.isLeapMonth == isLeap &&
          reencoded != null &&
          reencoded.year == solarDate.year &&
          reencoded.month == solarDate.month &&
          reencoded.day == solarDate.day;
      if (!ok) mismatches++;
    }

    // 명세가 요구하는 규모(55,153일)에 근접한 전체 KASI 실측 구간을 전수 검증했는지 확인.
    expect(total, greaterThan(55000));
    expect(mismatches, 0, reason: '$mismatches / $total 건 왕복 항등 불일치');
  });

  test('L1: 24절기 — KASI 확정 제공 범위(2000~2028) 전수 100% 일치', () {
    final raw = jsonDecode(
      File('assets/data/solarterm_table.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    expect(raw.length, greaterThan(600));
    for (final entry in raw.entries) {
      final key = entry.key;
      final year = int.parse(key.substring(0, 4));
      expect(year, inInclusiveRange(2000, 2028),
          reason: 'solarterm_table.json에 KASI 확정 범위(2000~2028) 밖 항목이 섞여 있으면 안 됨');
      final date = DateTime(
        year,
        int.parse(key.substring(4, 6)),
        int.parse(key.substring(6, 8)),
      );
      final source = KasiSolarTermDataSource(tables);
      final term = source.solarTermOn(date);
      expect(term, isNotNull);
      expect(term!.name, (entry.value as Map<String, dynamic>)['name']);
      expect(term.isComputedFallback, isFalse);
    }
  });
}
