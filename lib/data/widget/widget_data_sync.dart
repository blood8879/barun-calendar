import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/calendar/day_info.dart';
import '../../domain/event/event.dart';

/// C-39: 위젯은 Flutter 엔진을 기동하지 않는다. 여기서 계산한 요약 문자열을
/// shared_preferences(네이티브에서는 "FlutterSharedPreferences" 파일)에 미리 써 두면,
/// Android `AppWidgetProvider`가 그 값만 읽어 렌더한다. 값을 쓴 뒤에는 MethodChannel로
/// 네이티브에 즉시 갱신을 요청한다(그렇지 않으면 최대 updatePeriodMillis만큼 지연됨).
class WidgetDataSync {
  static const _channel = MethodChannel('com.baruncal.barun_calendar/widget');

  static Future<void> sync({
    required DayInfoProvider dayInfoProvider,
    required List<CalendarEvent> events,
    DateTime? now,
  }) async {
    final today = now ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();

    final info = dayInfoProvider.build(today);
    final lunar = info.lunar;
    final lunarSummary = lunar == null
        ? '음력 정보 없음(데이터 범위 밖) · ${info.ilju}'
        : '${lunar.label} · ${info.ilju}';
    await prefs.setString('widget_lunar_summary', lunarSummary);

    final upcoming = _nextAnniversary(dayInfoProvider, events, today);
    await prefs.setString('widget_next_anniversary', upcoming);

    final monthGrid = _monthMiniGrid(dayInfoProvider, today);
    await prefs.setString('widget_month_mini_text', monthGrid);
    await prefs.setString('widget_month_mini_title', '${today.year}년 ${today.month}월');

    try {
      await _channel.invokeMethod('refresh');
    } on MissingPluginException {
      // 테스트/미지원 플랫폼에서는 조용히 무시(위젯은 Android 전용 부가 기능).
    } on PlatformException {
      // 네이티브 갱신 실패는 치명적이지 않음 — 다음 updatePeriodMillis 주기에 반영됨.
    }
  }

  static String _nextAnniversary(
    DayInfoProvider dayInfoProvider,
    List<CalendarEvent> events,
    DateTime today,
  ) {
    DateTime? bestDate;
    String? bestTitle;
    for (final e in events) {
      if (e.kind != EventKind.anniversary &&
          e.kind != EventKind.birthday &&
          e.kind != EventKind.memorial) {
        continue;
      }
      for (final year in [today.year, today.year + 1]) {
        final occurrence = e.isLunar
            ? e.lunarOccurrenceInYear(dayInfoProvider.lunar, year)
            : (e.date.month == 0 ? null : DateTime(year, e.date.month, e.date.day));
        if (occurrence == null) continue;
        if (occurrence.isBefore(DateTime(today.year, today.month, today.day))) continue;
        if (bestDate == null || occurrence.isBefore(bestDate)) {
          bestDate = occurrence;
          bestTitle = e.title;
        }
      }
    }
    if (bestDate == null || bestTitle == null) return '다가오는 기일·생신이 없습니다';
    final dDay = DateTime(bestDate.year, bestDate.month, bestDate.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    return '$bestTitle · D-$dDay (${bestDate.month}/${bestDate.day})';
  }

  /// 위젯 3/3(§7 W3 월간): 이번 달 미니 캘린더를 고정폭 텍스트 그리드로 렌더한다.
  /// C-42는 W3의 기본 경로로 비트맵 합성 렌더를 요구하지만(RemoteViews 셀 폭발·
  /// TransactionTooLarge 방지), 이번 라운드에서는 단일 monospace TextView 한 줄짜리
  /// 뷰트리로 같은 문제를 피하면서 우선 텍스트 그리드로 구현했다 — 값이 결국
  /// C-42가 우려하는 "위젯마다 셀 개수만큼 RemoteViews 자식 뷰"를 만들지 않으므로
  /// TransactionTooLarge 위험은 없다. 진짜 픽셀 격자(요일 헤더 정렬, 일요일 강조 등)가
  /// 필요해지면 Canvas/Bitmap 렌더로 교체(OPEN_QUESTIONS.md에 후속 과제로 기록).
  static String _monthMiniGrid(DayInfoProvider dayInfoProvider, DateTime today) {
    final first = DateTime(today.year, today.month, 1);
    final daysInMonth = DateTime(today.year, today.month + 1, 0).day;
    final leadingBlanks = first.weekday % 7; // Dart weekday: Mon=1..Sun=7 → Sun=0칸 시작 맞춤
    final buffer = StringBuffer('일 월 화 수 목 금 토\n');
    buffer.write('   ' * leadingBlanks);
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(today.year, today.month, day);
      final info = dayInfoProvider.build(date);
      final marker = date.day == today.day ? '*' : (info.isHoliday ? '.' : ' ');
      buffer.write(day.toString().padLeft(2, ' ') + marker);
      final column = (leadingBlanks + day) % 7;
      buffer.write(column == 0 ? '\n' : ' ');
    }
    return buffer.toString().trimRight();
  }
}
