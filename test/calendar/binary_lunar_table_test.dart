import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:barun_calendar/domain/calendar/binary_lunar_table.dart';

void main() {
  late BinaryLunarTable table;

  setUpAll(() {
    final bytes = File('assets/data/lunar_1899_2050.bin').readAsBytesSync();
    table = BinaryLunarTable.decode(Uint8List.fromList(bytes));
  });

  test('헤더 범위가 명세(1899~2050, 152개년)와 일치', () {
    expect(table.startYear, 1899);
    expect(table.count, 152);
  });

  test('2000년: 설날(2/5) 오프셋 = 35일, 12개월(윤달 없음)', () {
    final e = table.forYear(2000);
    expect(e.newYearOffsetDays, 35);
    expect(e.hasLeapMonth, isFalse);
  });

  test('2024년: 설날(2/10) 오프셋 = 40일', () {
    final e = table.forYear(2024);
    expect(e.newYearOffsetDays, 40);
  });

  test('범위 밖 연도 조회는 조용한 폴백 없이 예외', () {
    expect(() => table.forYear(1898), throwsA(isA<BinaryLunarTableException>()));
    expect(() => table.forYear(2051), throwsA(isA<BinaryLunarTableException>()));
  });

  test('CRC32 손상 시 즉시 예외(조용한 폴백 금지, K5)', () {
    final bytes = File('assets/data/lunar_1899_2050.bin').readAsBytesSync();
    final corrupted = Uint8List.fromList(bytes);
    corrupted[20] ^= 0xFF; // 본문 첫 바이트 변조
    expect(() => BinaryLunarTable.decode(corrupted),
        throwsA(isA<BinaryLunarTableException>()));
  });

  test('왕복 항등: 모든 152개년이 예외 없이 디코딩된다', () {
    for (var y = 1899; y <= 2050; y++) {
      final e = table.forYear(y);
      expect(e.year, y);
      expect(e.newYearOffsetDays, inInclusiveRange(0, 63));
    }
  });
}
