import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/calendar/day_info.dart';
import '../../domain/event/event.dart';

/// 일정 알림(F4, 다단 알림) 스케줄링을 담당한다.
/// 실기기 권한/정확한 알람 권한 요청은 [init]에서 처리한다.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
    _initialized = true;
  }

  /// 이번 일정의 기존 예약을 모두 지우고 향후 2년치 발생분에 대해 다시 예약한다.
  /// [lunarSource]를 주면 음력 기준 매년 반복 일정도 그 해의 실제 양력 변환일로
  /// 자동 재계산되어 알림이 나간다(사용자가 매년 재등록할 필요 없음).
  Future<void> rescheduleForEvent(
    CalendarEvent event, {
    LunarCalendarDataSource? lunarSource,
  }) async {
    if (!_initialized) return;
    await cancelForEvent(event, lunarSource: lunarSource);
    if (event.reminderMinutesBefore.isEmpty) return;

    final now = DateTime.now();
    final occurrences = <DateTime>[
      ...event.occurrencesInYearResolved(now.year, lunarSource: lunarSource),
      ...event.occurrencesInYearResolved(now.year + 1, lunarSource: lunarSource),
    ];

    for (final occurrence in occurrences) {
      for (var i = 0; i < event.reminderMinutesBefore.length; i++) {
        final fireAt = event.reminderTimesFor(occurrence)[i];
        if (fireAt.isBefore(now)) continue;
        final id = event.notificationIdFor(occurrence, i);
        await _plugin.zonedSchedule(
          id: id,
          title: event.title,
          body: event.memo?.isNotEmpty == true ? event.memo : '바른달력 일정 알림',
          scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'baruncal_events',
              '일정 알림',
              channelDescription: '바른달력 일정 알림',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      }
    }
  }

  Future<void> cancelForEvent(
    CalendarEvent event, {
    LunarCalendarDataSource? lunarSource,
  }) async {
    if (!_initialized) return;
    final now = DateTime.now();
    final occurrences = <DateTime>[
      ...event.occurrencesInYearResolved(now.year, lunarSource: lunarSource),
      ...event.occurrencesInYearResolved(now.year + 1, lunarSource: lunarSource),
      ...event.occurrencesInYearResolved(now.year - 1, lunarSource: lunarSource),
    ];
    for (final occurrence in occurrences) {
      for (var i = 0; i < 8; i++) {
        await _plugin.cancel(id: event.notificationIdFor(occurrence, i));
      }
    }
  }
}
