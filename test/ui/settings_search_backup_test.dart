import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:barun_calendar/data/event/event_repository.dart';
import 'package:barun_calendar/data/settings/settings_repository.dart';
import 'package:barun_calendar/domain/event/event.dart';
import 'package:barun_calendar/ui/backup/backup_restore_screen.dart';
import 'package:barun_calendar/ui/search/search_screen.dart';
import 'package:barun_calendar/ui/settings/settings_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') return null;
      return null;
    });
  });

  testWidgets('설정 화면에서 다크모드 토글이 저장된다', (tester) async {
    final settingsRepo = SharedPrefsSettingsRepository();
    AppSettings? changed;
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        settingsRepository: settingsRepo,
        eventRepository: SharedPrefsEventRepository(),
        onSettingsChanged: (s) => changed = s,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('다크 모드'), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    expect(changed?.darkMode, isTrue);
    expect((await settingsRepo.load()).darkMode, isTrue);
  });

  testWidgets('검색 화면에서 제목으로 일정을 찾는다', (tester) async {
    final repo = SharedPrefsEventRepository();
    await repo.upsert(CalendarEvent(id: '1', title: '엄마 생신', date: DateTime(2026, 3, 1)));
    await repo.upsert(CalendarEvent(id: '2', title: '회의', date: DateTime(2026, 3, 2)));

    await tester.pumpWidget(MaterialApp(home: SearchScreen(eventRepository: repo)));
    await tester.pumpAndSettle();

    expect(find.text('엄마 생신'), findsOneWidget);
    expect(find.text('회의'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '생신');
    await tester.pumpAndSettle();

    expect(find.text('엄마 생신'), findsOneWidget);
    expect(find.text('회의'), findsNothing);
  });

  testWidgets('백업 화면에서 내보내기 후 문구가 표시된다', (tester) async {
    final repo = SharedPrefsEventRepository();
    await repo.upsert(CalendarEvent(id: '1', title: '테스트', date: DateTime(2026, 1, 1)));

    await tester.pumpWidget(MaterialApp(home: BackupRestoreScreen(eventRepository: repo)));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('클립보드로 내보내기'));
    await tester.tap(find.text('클립보드로 내보내기'), warnIfMissed: false);
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('클립보드에 복사했습니다'), findsOneWidget);
  });

  testWidgets('백업 화면에서 잘못된 형식 붙여넣기는 오류 문구를 보여준다', (tester) async {
    final repo = SharedPrefsEventRepository();
    await tester.pumpWidget(MaterialApp(home: BackupRestoreScreen(eventRepository: repo)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '이건 JSON이 아님');
    await tester.tap(find.text('붙여넣은 내용으로 복원'));
    await tester.pumpAndSettle();

    expect(find.textContaining('확인할 수 없습니다'), findsOneWidget);
  });
}
