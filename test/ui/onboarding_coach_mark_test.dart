import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:barun_calendar/data/event/event_repository.dart';
import 'package:barun_calendar/data/fake/fake_calendar_data_sources.dart';
import 'package:barun_calendar/data/onboarding/onboarding_repository.dart';
import 'package:barun_calendar/data/settings/settings_repository.dart';
import 'package:barun_calendar/domain/calendar/day_info.dart';
import 'package:barun_calendar/ui/home/home_screen.dart';

class _InMemoryOnboardingRepository implements OnboardingRepository {
  bool completed;
  _InMemoryOnboardingRepository({this.completed = false});

  @override
  Future<bool> isCompleted() async => completed;

  @override
  Future<void> setCompleted(bool value) async => completed = value;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  HomeScreen buildHome(OnboardingRepository onboardingRepository) => HomeScreen(
        repository: SharedPrefsEventRepository(),
        settingsRepository: SharedPrefsSettingsRepository(),
        onSettingsChanged: (_) {},
        dayInfoProvider: const DayInfoProvider(
          lunar: FakeLunarCalendarDataSource(),
          solarTerm: FakeSolarTermDataSource(),
          holiday: FakeHolidayDataSource(),
        ),
        lunarSource: const FakeLunarCalendarDataSource(),
        onboardingRepository: onboardingRepository,
      );

  testWidgets('최초 실행이면 온보딩 코치마크가 표시된다', (tester) async {
    final repo = _InMemoryOnboardingRepository(completed: false);
    await tester.pumpWidget(MaterialApp(home: buildHome(repo)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('coach-mark-message')), findsOneWidget);
    expect(find.text('좌우로 눌러서 달을 이동해요. 화살표를 탭하거나 좌우로 스와이프할 수 있어요.'), findsOneWidget);
  });

  testWidgets('온보딩을 끝까지 넘기면 완료 상태가 저장되고 다시 실행해도 뜨지 않는다', (tester) async {
    final repo = _InMemoryOnboardingRepository(completed: false);
    await tester.pumpWidget(MaterialApp(home: buildHome(repo)));
    await tester.pumpAndSettle();

    // 5단계를 모두 "다음"으로 넘긴다.
    for (var i = 0; i < 5; i++) {
      final nextButton = find.byKey(const ValueKey('coach-mark-next'));
      expect(nextButton, findsOneWidget);
      await tester.tap(nextButton);
      await tester.pumpAndSettle();
    }

    expect(find.byKey(const ValueKey('coach-mark-message')), findsNothing);
    expect(repo.completed, isTrue);

    // 완료된 상태로 재실행하면 뜨지 않는다.
    await tester.pumpWidget(MaterialApp(home: buildHome(repo)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('coach-mark-message')), findsNothing);
  });

  testWidgets('건너뛰기를 누르면 완료 상태가 저장되고 오버레이가 사라진다', (tester) async {
    final repo = _InMemoryOnboardingRepository(completed: false);
    await tester.pumpWidget(MaterialApp(home: buildHome(repo)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('coach-mark-skip')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('coach-mark-message')), findsNothing);
    expect(repo.completed, isTrue);
  });

  testWidgets('완료된 상태에서도 설정 > 사용법 다시 보기를 누르면 온보딩이 다시 뜬다', (tester) async {
    final repo = _InMemoryOnboardingRepository(completed: true);
    await tester.pumpWidget(MaterialApp(home: buildHome(repo)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('coach-mark-message')), findsNothing);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('사용법 다시 보기'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('사용법 다시 보기'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('coach-mark-message')), findsOneWidget);
  });
}
