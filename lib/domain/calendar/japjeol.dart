import 'ganji.dart';

/// 잡절 (삼복·한식) — 규칙 계산, 테이블 없음 (§3-3)

/// 하지(또는 입추) 당일 포함 이후 n번째 庚일의 JDN을 구한다.
/// nth=1이면 당일이 庚일일 때 당일을 반환한다 ("당일 포함"이 핵심, C-15).
int nthGyeongDayOnOrAfter(int startJdn, int nth) {
  var count = 0;
  var jdn = startJdn;
  while (true) {
    if (isGyeongDay(jdn)) {
      count++;
      if (count == nth) return jdn;
    }
    jdn++;
  }
}

/// 초복 = 하지 당일 포함 이후 3번째 庚일 (C-15)
int chobokJdn(int hajiJdn) => nthGyeongDayOnOrAfter(hajiJdn, 3);

/// 중복 = 하지 당일 포함 이후 4번째 庚일
int jungbokJdn(int hajiJdn) => nthGyeongDayOnOrAfter(hajiJdn, 4);

/// 말복 = 입추 당일 포함 이후 1번째 庚일 (월복 자동 반영)
int malbokJdn(int ipchuJdn) => nthGyeongDayOnOrAfter(ipchuJdn, 1);

/// 한식 = JDN(전년 동지) + 105 (C-16)
int hansikJdn(int prevYearDongjiJdn) => prevYearDongjiJdn + 105;
