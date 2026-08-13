/// 간지 (일진·세차·월건) — 규칙 계산, 테이블 없음. K3: 순수 Dart.

const List<String> ganNames = ['갑', '을', '병', '정', '무', '기', '경', '신', '임', '계'];
const List<String> jiNames = ['자', '축', '인', '묘', '진', '사', '오', '미', '신', '유', '술', '해'];

class Ganji {
  final int ganIdx; // 0~9
  final int jiIdx; // 0~11
  const Ganji(this.ganIdx, this.jiIdx);

  String get gan => ganNames[ganIdx];
  String get ji => jiNames[jiIdx];
  String get label => '$gan$ji';

  @override
  String toString() => label;
}

/// 일진: 간 = (jdn + 9) % 10, 지 = (jdn + 1) % 12  (C-12)
Ganji iljinFromJdn(int jdn) {
  final gan = (jdn + 9) % 10;
  final ji = (jdn + 1) % 12;
  return Ganji(gan, ji);
}

bool isGyeongDay(int jdn) => (jdn + 9) % 10 == 6; // 庚 = ganIdx 6 (C-12/C-15)

/// 세차: 기준 = 입춘 절입일. 그 해 입춘 이전이면 기준연 = 연 - 1  (C-13)
/// [ipchunJdn]은 해당 연도의 입춘 절입일(자정 0시 기준일)이다. 호출부가 SolarTerm 테이블에서 주입한다.
Ganji sechaForYear(int year, int Function(int year) ipchunJdnOf, int targetJdn) {
  var refYear = year;
  final ipchun = ipchunJdnOf(year);
  if (targetJdn < ipchun) refYear = year - 1;
  final idx = (refYear - 4) % 60;
  return Ganji(idx % 10, idx % 12);
}

/// 월건 지지: 입춘~경칩=寅(idx2) ... 각 절기 구간마다 +1, 12절 순환.
/// termIdx는 solar_term.dart의 절(節) 인덱스(입춘=2, 경칩=4, ...) 기준.
/// 월건 천간: 寅월 천간idx = ((세차 간idx % 5) * 2 + 2) % 10, 이후 절 순서로 +1  (C-14)
Ganji wolgeonFromSecha(Ganji secha, int monthsAfterIpchun) {
  final inWolGanBase = ((secha.ganIdx % 5) * 2 + 2) % 10;
  final gan = (inWolGanBase + monthsAfterIpchun) % 10;
  final ji = (2 + monthsAfterIpchun) % 12; // 寅=2 시작
  return Ganji(gan, ji);
}
