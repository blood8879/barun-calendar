import 'package:flutter_test/flutter_test.dart';
import 'package:barun_calendar/domain/calendar/jdn.dart';
import 'package:barun_calendar/domain/calendar/ganji.dart';
import 'package:barun_calendar/domain/calendar/japjeol.dart';

void main() {
  group('JDN 왕복 (K1)', () {
    test('2026-08-12 왕복', () {
      final jdn = jdnFromYmd(2026, 8, 12);
      expect(ymdFromJdn(jdn), Ymd(2026, 8, 12));
    });
    test('요일 계산: 2000-01-01 = 토요일', () {
      final jdn = jdnFromYmd(2000, 1, 1);
      expect(weekdayFromJdn(jdn), 6);
    });
  });

  group('§13-A 고정 테스트 벡터 — 일진 (C-12)', () {
    test('2000-01-01 = 무오(戊午)', () {
      final jdn = jdnFromYmd(2000, 1, 1);
      final g = iljinFromJdn(jdn);
      expect(g.label, '무오');
    });
    test('2023-06-21 = 경술(庚戌)', () {
      final jdn = jdnFromYmd(2023, 6, 21);
      final g = iljinFromJdn(jdn);
      expect(g.label, '경술');
      expect(isGyeongDay(jdn), true);
    });
  });

  group('§13-A 고정 테스트 벡터 — 삼복 (C-15)', () {
    // 하지/입추 절기일은 KASI 확정 테이블에서 와야 하지만 (B-1 미해결),
    // 여기서는 명세에 명시된 절기 날짜를 테스트 벡터로만 고정 사용한다 (K2 예외 허용 범위).
    void checkYear(int year, int hajiM, int hajiD, int ipchuM, int ipchuD,
        String chobok, String jungbok, String malbok) {
      test('$year 삼복', () {
        final haji = jdnFromYmd(year, hajiM, hajiD);
        final ipchu = jdnFromYmd(year, ipchuM, ipchuD);
        expect(ymdFromJdn(chobokJdn(haji)).toString(), '$year-${chobok.padLeft(5, '0')}');
        expect(ymdFromJdn(jungbokJdn(haji)).toString(), '$year-${jungbok.padLeft(5, '0')}');
        expect(ymdFromJdn(malbokJdn(ipchu)).toString(), '$year-${malbok.padLeft(5, '0')}');
      });
    }

    checkYear(2015, 6, 22, 8, 8, '07-13', '07-23', '08-12');
    checkYear(2020, 6, 21, 8, 7, '07-16', '07-26', '08-15');
    checkYear(2023, 6, 21, 8, 8, '07-11', '07-21', '08-10'); // 하지 당일이 庚일인 케이스
    checkYear(2024, 6, 21, 8, 7, '07-15', '07-25', '08-14');
    checkYear(2025, 6, 21, 8, 7, '07-20', '07-30', '08-09');
  });

  group('§13-A 고정 테스트 벡터 — 한식 (C-16)', () {
    test('2022 동지 12/22 → 2023 한식 4/6', () {
      final dongji = jdnFromYmd(2022, 12, 22);
      expect(ymdFromJdn(hansikJdn(dongji)).toString(), '2023-04-06');
    });
  });

  group('§13-A 고정 테스트 벡터 — 세차·월건 (C-13·C-14)', () {
    int ipchunOf(int year) {
      // KASI 확정 테이블 부재로 인해 실측 입춘일을 테스트 상수로 고정 (B-1 참고).
      const known = {2024: [2, 4], 2040: [2, 4], 2023: [2, 4]};
      final md = known[year] ?? [2, 4];
      return jdnFromYmd(year, md[0], md[1]);
    }

    test('2024 = 갑진년', () {
      final target = jdnFromYmd(2024, 6, 1);
      final secha = sechaForYear(2024, ipchunOf, target);
      expect(secha.label, '갑진');
    });
    test('2040 = 경신년', () {
      final target = jdnFromYmd(2040, 6, 1);
      final secha = sechaForYear(2040, ipchunOf, target);
      expect(secha.label, '경신');
    });
    test('2023-10-08(한로) 이후 = 임술월', () {
      final secha2023 = sechaForYear(2023, ipchunOf, jdnFromYmd(2023, 10, 8));
      // 입춘(2/寅)부터 한로(10/8, 戌월)까지 절 순서: 寅卯辰巳午未申酉戌 = +8
      final wolgeon = wolgeonFromSecha(secha2023, 8);
      expect(wolgeon.label, '임술');
    });
  });
}
