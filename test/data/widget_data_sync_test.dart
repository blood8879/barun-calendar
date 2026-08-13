import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:barun_calendar/data/fake/fake_calendar_data_sources.dart';
import 'package:barun_calendar/data/widget/widget_data_sync.dart';
import 'package:barun_calendar/domain/calendar/day_info.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const dayInfoProvider = DayInfoProvider(
    lunar: FakeLunarCalendarDataSource(),
    solarTerm: FakeSolarTermDataSource(),
    holiday: FakeHolidayDataSource(),
  );

  test('위젯 3/3: 이번 달 미니 캘린더 그리드가 요일 헤더와 오늘 표시를 포함해 저장된다', () async {
    final now = DateTime.now();

    await WidgetDataSync.sync(
      dayInfoProvider: dayInfoProvider,
      events: const [],
      now: now,
    );

    final prefs = await SharedPreferences.getInstance();
    final title = prefs.getString('widget_month_mini_title');
    final grid = prefs.getString('widget_month_mini_text');

    expect(title, '${now.year}년 ${now.month}월');
    expect(grid, isNotNull);
    expect(grid, contains('일 월 화 수 목 금 토'));
    expect(grid, contains('${now.day.toString().padLeft(2, ' ')}*'));
  });

  test('MethodChannel 미지원 환경(테스트)에서도 예외 없이 완료된다', () async {
    await expectLater(
      WidgetDataSync.sync(
        dayInfoProvider: dayInfoProvider,
        events: const [],
      ),
      completes,
    );
  });
}
