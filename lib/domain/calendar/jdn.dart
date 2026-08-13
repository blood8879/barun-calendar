/// 율리우스적일(JDN) 변환 — 모든 날짜 연산의 기본 단위 (K1)
/// domain/은 Flutter·IO에 의존하지 않는다 (K3).

int jdnFromYmd(int y, int m, int d) {
  final a = (14 - m) ~/ 12;
  final yy = y + 4800 - a;
  final mm = m + 12 * a - 3;
  return d + (153 * mm + 2) ~/ 5 + 365 * yy + yy ~/ 4 - yy ~/ 100 + yy ~/ 400 - 32045;
}

class Ymd {
  final int year, month, day;
  const Ymd(this.year, this.month, this.day);

  @override
  bool operator ==(Object other) =>
      other is Ymd && other.year == year && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

Ymd ymdFromJdn(int jdn) {
  final a = jdn + 32044;
  final b = (4 * a + 3) ~/ 146097;
  final c = a - (146097 * b) ~/ 4;
  final d = (4 * c + 3) ~/ 1461;
  final e = c - (1461 * d) ~/ 4;
  final m = (5 * e + 2) ~/ 153;
  final day = e - (153 * m + 2) ~/ 5 + 1;
  final month = m + 3 - 12 * (m ~/ 10);
  final year = 100 * b + d - 4800 + m ~/ 10;
  return Ymd(year, month, day);
}

/// 0=일 1=월 … 6=토
int weekdayFromJdn(int jdn) => (jdn + 1) % 7;

bool isLeapYear(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

const List<int> _daysInMonthCommon = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

int daysInMonth(int y, int m) {
  if (m == 2) return isLeapYear(y) ? 29 : 28;
  return _daysInMonthCommon[m - 1];
}
