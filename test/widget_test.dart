import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:barun_calendar/data/event/event_repository.dart';
import 'package:barun_calendar/data/fake/fake_calendar_data_sources.dart';
import 'package:barun_calendar/data/onboarding/onboarding_repository.dart';
import 'package:barun_calendar/data/settings/settings_repository.dart';
import 'package:barun_calendar/domain/calendar/day_info.dart';
import 'package:barun_calendar/ui/home/home_screen.dart';

class _AlreadyCompletedOnboardingRepository implements OnboardingRepository {
  const _AlreadyCompletedOnboardingRepository();

  @override
  Future<bool> isCompleted() async => true;

  @override
  Future<void> setCompleted(bool completed) async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  HomeScreen buildHome() => HomeScreen(
        repository: SharedPrefsEventRepository(),
        settingsRepository: SharedPrefsSettingsRepository(),
        onSettingsChanged: (_) {},
        dayInfoProvider: const DayInfoProvider(
          lunar: FakeLunarCalendarDataSource(),
          solarTerm: FakeSolarTermDataSource(),
          holiday: FakeHolidayDataSource(),
        ),
        lunarSource: const FakeLunarCalendarDataSource(),
        // 온보딩 코치마크 오버레이는 별도 테스트(onboarding_coach_mark_test.dart)에서
        // 검증한다. 여기서는 기존 화면 상호작용 테스트가 오버레이에 가려지지 않도록
        // 완료 상태를 주입한다.
        onboardingRepository: const _AlreadyCompletedOnboardingRepository(),
      );

  testWidgets('홈 화면이 월 달력과 오늘 날짜를 렌더링한다', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: buildHome(),
    ));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    expect(find.text('${now.year}년 ${now.month}월'), findsOneWidget);
    expect(find.text('일'), findsOneWidget);
  });

  testWidgets('날짜를 탭하면 상세 시트가 열리고 일정을 추가할 수 있다', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: buildHome(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('day-1')));
    await tester.pumpAndSettle();

    expect(find.text('일정'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '테스트 일정');
    await tester.tap(find.byIcon(Icons.add_circle));
    await tester.pumpAndSettle();

    expect(find.text('테스트 일정'), findsOneWidget);
  });
}
