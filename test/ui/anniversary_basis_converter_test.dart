import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:barun_calendar/data/event/event_repository.dart';
import 'package:barun_calendar/data/fake/fake_calendar_data_sources.dart';
import 'package:barun_calendar/domain/calendar/day_info.dart';
import 'package:barun_calendar/domain/event/event.dart';
import 'package:barun_calendar/ui/anniversary/anniversary_screen.dart';
import 'package:barun_calendar/ui/basis/basis_screen.dart';
import 'package:barun_calendar/ui/converter/converter_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AnniversaryScreen', () {
    testWidgets('생신/기일 일정만 모아 D-day 순으로 보여준다', (tester) async {
      final repo = SharedPrefsEventRepository();
      await repo.upsert(CalendarEvent(
        id: '1',
        title: '일반 일정',
        date: DateTime(2026, 1, 1),
      ));
      await repo.upsert(CalendarEvent(
        id: '2',
        title: '아버지 기일',
        date: DateTime(2026, 3, 10),
        kind: EventKind.memorial,
      ));
      await repo.upsert(CalendarEvent(
        id: '3',
        title: '어머니 생신',
        date: DateTime(2026, 6, 1),
        kind: EventKind.birthday,
        isLunar: true,
      ));

      await tester.pumpWidget(MaterialApp(
        home: AnniversaryScreen(
          eventRepository: repo,
          lunarSource: const FakeLunarCalendarDataSource(),
          nowOverride: () => DateTime(2026, 1, 1),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('일반 일정'), findsNothing);
      expect(find.text('아버지 기일'), findsOneWidget);
      expect(find.text('어머니 생신'), findsOneWidget);
      expect(find.textContaining('음력 기준'), findsOneWidget);
    });

    testWidgets('등록된 기일·생신이 없으면 안내 문구를 보여준다', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AnniversaryScreen(
          eventRepository: SharedPrefsEventRepository(),
          lunarSource: const FakeLunarCalendarDataSource(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('등록된 기일·생신 일정이 없습니다.'), findsOneWidget);
    });
  });

  group('BasisScreen', () {
    testWidgets('계산 보완 절기는 비공식 배지를 표시한다', (tester) async {
      final date = DateTime(2026, 1, 1);
      final dayInfo = DayInfo(
        date: date,
        ilju: '갑자',
        solarTerm: SolarTerm(
          name: '소한',
          exactMoment: date,
          isComputedFallback: true,
        ),
      );

      await tester.pumpWidget(MaterialApp(
        home: BasisScreen(
          date: date,
          dayInfo: dayInfo,
          lunarSource: const FakeLunarCalendarDataSource(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('계산값·비공식'), findsOneWidget);
      expect(find.textContaining('자체 천문 계산'), findsOneWidget);
    });

    testWidgets('KASI 실측 절기는 비공식 배지를 표시하지 않는다', (tester) async {
      final date = DateTime(2020, 1, 6);
      final dayInfo = DayInfo(
        date: date,
        ilju: '갑자',
        solarTerm: SolarTerm(name: '소한', exactMoment: date),
      );

      await tester.pumpWidget(MaterialApp(
        home: BasisScreen(
          date: date,
          dayInfo: dayInfo,
          lunarSource: const FakeLunarCalendarDataSource(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('계산값·비공식'), findsNothing);
    });
  });

  group('ConverterScreen', () {
    testWidgets('화면이 로드되고 변환기 UI 요소를 보여준다', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ConverterScreen(lunarSource: const FakeLunarCalendarDataSource()),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(ConverterScreen), findsOneWidget);
    });
  });
}
