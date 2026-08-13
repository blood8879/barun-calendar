import 'dart:math' as math;

import 'day_info.dart';

/// KASI 특일 API가 제공하지 않는 연도(§16 대안 경로 ②) 보완용, 태양 겉보기 황경 기반
/// 24절기 결정론적 계산기.
///
/// Meeus, *Astronomical Algorithms* 25장의 저정밀(low-precision) 태양 좌표 공식을 쓴다.
/// 오차는 각도로 약 0.01° 이내이며, 이는 절기 "날짜"를 결정하는 데는 충분하지만
/// 시:분까지는 KASI 공식 값(±수 분)만큼 정확하지 않을 수 있다. 그래서 이 계산기가
/// 만든 값은 항상 [SolarTerm.isComputedFallback] 등으로 KASI 실측값과 구분해야 한다
/// (아래 [ComputedSolarTermDataSource] 참고).
class SolarTermCalculator {
  static const List<String> _namesByLongitude = [
    '춘분', '청명', '곡우', '입하', '소만', '망종', // 0,15,...75
    '하지', '소서', '대서', '입추', '처서', '백로', // 90..165
    '추분', '한로', '상강', '입동', '소설', '대설', // 180..255
    '동지', '소한', '대한', '입춘', '우수', '경칩', // 270..345
  ];

  static const Duration _kstOffset = Duration(hours: 9);

  /// 주어진 연도(양력, KST 기준)에 발생하는 24절기 전부를 계산한다.
  static List<SolarTerm> termsInYear(int year) {
    final result = <SolarTerm>[];
    for (var i = 0; i < 24; i++) {
      final targetDeg = (i * 15).toDouble();
      // 춘분(0°)은 대략 3/20 근방이므로 탐색 시작점을 절기 순서에 맞춰 잡는다.
      final approxMonth = 3 + (i * 15 ~/ 30);
      final seed = DateTime.utc(year, ((approxMonth - 1) % 12) + 1, 15)
          .subtract(_kstOffset);
      final moment = _findCrossing(seed, targetDeg);
      final kst = moment.add(_kstOffset);
      result.add(SolarTerm(
        name: _namesByLongitude[i],
        exactMoment: kst,
        isComputedFallback: true,
      ));
    }
    result.sort((a, b) => a.exactMoment.compareTo(b.exactMoment));
    return result;
  }

  /// [seedUtc] 근방 ±20일 구간에서 태양 겉보기 황경이 [targetDeg]를 지나는 UTC 시각을
  /// 이분 탐색으로 찾는다.
  static DateTime _findCrossing(DateTime seedUtc, double targetDeg) {
    var lo = seedUtc.subtract(const Duration(days: 20));
    var hi = seedUtc.add(const Duration(days: 20));
    double signedDelta(DateTime t) {
      final lon = apparentSolarLongitudeDeg(t);
      var d = lon - targetDeg;
      while (d > 180) {
        d -= 360;
      }
      while (d < -180) {
        d += 360;
      }
      return d;
    }

    var loD = signedDelta(lo);
    var hiD = signedDelta(hi);
    if (loD.sign == hiD.sign) {
      // 시드가 목표 근방이 아니면(순서 추정이 어긋난 경우) 더 넓게 재탐색.
      lo = seedUtc.subtract(const Duration(days: 40));
      hi = seedUtc.add(const Duration(days: 40));
      loD = signedDelta(lo);
      hiD = signedDelta(hi);
    }
    for (var iter = 0; iter < 60; iter++) {
      final mid = lo.add(hi.difference(lo) ~/ 2);
      final midD = signedDelta(mid);
      if (midD.abs() < 1e-6) return mid;
      if (loD.sign == midD.sign) {
        lo = mid;
        loD = midD;
      } else {
        hi = mid;
      }
    }
    return lo.add(hi.difference(lo) ~/ 2);
  }

  /// 주어진 UTC 시각의 태양 겉보기 황경(도, 0~360). Meeus 저정밀 공식.
  static double apparentSolarLongitudeDeg(DateTime utc) {
    final jd = _julianDay(utc);
    final t = (jd - 2451545.0) / 36525.0;

    final l0 = _norm360(280.46646 + 36000.76983 * t + 0.0003032 * t * t);
    final m = _norm360(357.52911 + 35999.05029 * t - 0.0001537 * t * t);
    final mRad = _deg2rad(m);

    final c = (1.914602 - 0.004817 * t - 0.000014 * t * t) * math.sin(mRad) +
        (0.019993 - 0.000101 * t) * math.sin(2 * mRad) +
        0.000289 * math.sin(3 * mRad);

    final trueLon = l0 + c;
    final omega = 125.04 - 1934.136 * t;
    final apparent = trueLon - 0.00569 - 0.00478 * math.sin(_deg2rad(omega));
    return _norm360(apparent);
  }

  static double _norm360(double deg) {
    var d = deg % 360.0;
    if (d < 0) d += 360.0;
    return d;
  }

  static double _deg2rad(double deg) => deg * math.pi / 180.0;

  static double _julianDay(DateTime utc) {
    var y = utc.year;
    var m = utc.month;
    final d = utc.day +
        (utc.hour + utc.minute / 60.0 + utc.second / 3600.0) / 24.0;
    if (m <= 2) {
      y -= 1;
      m += 12;
    }
    final a = (y / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (y + 4716)).floor() +
        (30.6001 * (m + 1)).floor() +
        d +
        b -
        1524.5;
  }
}

/// KASI 실측 데이터(있는 연도)와 [SolarTermCalculator] 계산값(없는 연도)을 합쳐 제공하는
/// [SolarTermDataSource]. 계산값 사용 여부는 [lastLookupWasComputed]로 확인할 수 있다 —
/// KASI 실측값처럼 오인되지 않도록 UI에서 반드시 구분 표기할 것(OPEN_QUESTIONS.md #1).
class ComputedFallbackSolarTermDataSource implements SolarTermDataSource {
  final SolarTermDataSource primary; // KASI 실측 (범위 밖이면 null 반환)
  final int minKasiYear;
  final int maxKasiYear;

  ComputedFallbackSolarTermDataSource({
    required this.primary,
    required this.minKasiYear,
    required this.maxKasiYear,
  });

  bool lastLookupWasComputed = false;

  @override
  SolarTerm? solarTermOn(DateTime date) {
    final fromKasi = primary.solarTermOn(date);
    if (fromKasi != null) {
      lastLookupWasComputed = false;
      return fromKasi;
    }
    if (date.year < minKasiYear || date.year > maxKasiYear) {
      lastLookupWasComputed = true;
      for (final term in SolarTermCalculator.termsInYear(date.year)) {
        if (term.exactMoment.year == date.year &&
            term.exactMoment.month == date.month &&
            term.exactMoment.day == date.day) {
          return term;
        }
      }
    }
    return null;
  }

  @override
  List<SolarTerm> solarTermsInYear(int year) {
    if (year >= minKasiYear && year <= maxKasiYear) {
      final v = primary.solarTermsInYear(year);
      if (v.isNotEmpty) {
        lastLookupWasComputed = false;
        return v;
      }
    }
    lastLookupWasComputed = true;
    return SolarTermCalculator.termsInYear(year);
  }
}
