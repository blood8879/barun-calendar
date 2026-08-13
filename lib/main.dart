import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'data/event/event_repository.dart';
import 'data/kasi/kasi_calendar_data_sources.dart';
import 'data/notification/notification_service.dart';
import 'data/purchase/purchase_service.dart';
import 'data/settings/settings_repository.dart';
import 'data/widget/widget_data_sync.dart';
import 'domain/calendar/day_info.dart';
import 'domain/calendar/solar_term_calculator.dart';
import 'ui/home/home_screen.dart';

/// KASI 특일 API(SpcdeInfoService)의 24절기 자체 제공 범위. 이 범위 밖은
/// [ComputedFallbackSolarTermDataSource]가 §16 대안 경로 ②(천문 계산)로 보완한다.
/// (OPEN_QUESTIONS.md #1 참고 — 재요청으로 해소되는 제약이 아니라 API 자체 한계.)
const int kKasiSolarTermMinYear = 2000;
const int kKasiSolarTermMaxYear = 2028;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  NotificationService.instance.init();
  MobileAds.instance.initialize();
  PurchaseService.instance.listenForPurchases();
  runApp(const BarunCalendarApp());
}

class BarunCalendarApp extends StatefulWidget {
  const BarunCalendarApp({super.key});

  @override
  State<BarunCalendarApp> createState() => _BarunCalendarAppState();
}

class _BarunCalendarAppState extends State<BarunCalendarApp> {
  final _eventRepository = SharedPrefsEventRepository();
  final _settingsRepository = SharedPrefsSettingsRepository();

  AppSettings _settings = const AppSettings();
  DayInfoProvider? _dayInfoProvider;
  KasiLunarCalendarDataSource? _lunarSource;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    Future.wait([_settingsRepository.load(), KasiCalendarTables.load()]).then((results) {
      if (!mounted) return;
      final settings = results[0] as AppSettings;
      final tables = results[1] as KasiCalendarTables;
      final lunarSource = KasiLunarCalendarDataSource(tables);
      setState(() {
        _settings = settings;
        _lunarSource = lunarSource;
        _dayInfoProvider = DayInfoProvider(
          lunar: lunarSource,
          solarTerm: ComputedFallbackSolarTermDataSource(
            primary: KasiSolarTermDataSource(tables),
            minKasiYear: kKasiSolarTermMinYear,
            maxKasiYear: kKasiSolarTermMaxYear,
          ),
          holiday: KasiHolidayDataSource(tables),
        );
        _loaded = true;
      });
      _syncWidgets();
    });
  }

  /// 홈 화면 위젯(F5)이 읽을 요약값을 갱신한다. 일정 변경 시에도 [HomeScreen]에서
  /// [onEventsChanged]를 통해 다시 호출된다(C-39 — 위젯은 이 캐시만 읽는다).
  Future<void> _syncWidgets() async {
    final provider = _dayInfoProvider;
    if (provider == null) return;
    final events = await _eventRepository.loadAll();
    await WidgetDataSync.sync(dayInfoProvider: provider, events: events);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
    }
    return MaterialApp(
      title: '바른달력',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
      darkTheme: ThemeData.dark(),
      themeMode: _settings.darkMode ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(_settings.fontScale)),
          child: child!,
        );
      },
      home: HomeScreen(
        repository: _eventRepository,
        settingsRepository: _settingsRepository,
        onSettingsChanged: (s) => setState(() => _settings = s),
        dayInfoProvider: _dayInfoProvider!,
        lunarSource: _lunarSource!,
        settings: _settings,
        onEventsChanged: (events) => WidgetDataSync.sync(
          dayInfoProvider: _dayInfoProvider!,
          events: events,
        ),
      ),
    );
  }
}
