import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:barun_calendar/domain/calendar/solar_term_calculator.dart';

void main() {
  group('SolarTermCalculator vs KASI 실측 (2000~2028) 교차검증', () {
    late Map<String, dynamic> kasi;

    setUpAll(() {
      final raw = File('assets/data/solarterm_table.json').readAsStringSync();
      kasi = jsonDecode(raw) as Map<String, dynamic>;
    });

    test('계산값 날짜가 KASI 실측 날짜와 대부분 일치한다(연도 표본)', () {
      var checked = 0;
      var dateMismatches = 0;
      for (final year in [2000, 2005, 2012, 2020, 2024, 2028]) {
        final computed = SolarTermCalculator.termsInYear(year);
        final byName = <String, DateTime>{};
        for (final entry in kasi.entries) {
          if (!entry.key.startsWith(year.toString())) continue;
          final v = entry.value as Map<String, dynamic>;
          final name = v['name'] as String;
          final y = int.parse(entry.key.substring(0, 4));
          final m = int.parse(entry.key.substring(4, 6));
          final d = int.parse(entry.key.substring(6, 8));
          byName[name] = DateTime(y, m, d);
        }
        for (final term in computed) {
          final expected = byName[term.name];
          if (expected == null) continue;
          checked++;
          final gotDate =
              DateTime(term.exactMoment.year, term.exactMoment.month, term.exactMoment.day);
          if (gotDate != expected) dateMismatches++;
        }
      }
      expect(checked, greaterThan(100));
      // 저정밀 공식은 자정 근처 절기의 날짜가 하루 어긋날 수 있음을 허용.
      expect(dateMismatches / checked, lessThan(0.05));
    });
  });
}
