import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 사용자 표시 설정. 다크모드/글자배율/표시항목 온오프(디자인 목업 S8 대응).
class AppSettings {
  final bool darkMode;
  final double fontScale; // 0.85 ~ 1.5
  final bool showGanji; // 일진 표시
  final bool showLunar; // 음력 표시
  final bool showSolarTerm; // 절기 표시
  final bool showHoliday; // 공휴일 표시
  final bool showSonEobsneun; // C-18/C-30: 손없는날 표시, 기본 OFF

  const AppSettings({
    this.darkMode = false,
    this.fontScale = 1.0,
    this.showGanji = true,
    this.showLunar = true,
    this.showSolarTerm = true,
    this.showHoliday = true,
    this.showSonEobsneun = false,
  });

  AppSettings copyWith({
    bool? darkMode,
    double? fontScale,
    bool? showGanji,
    bool? showLunar,
    bool? showSolarTerm,
    bool? showHoliday,
    bool? showSonEobsneun,
  }) {
    return AppSettings(
      darkMode: darkMode ?? this.darkMode,
      fontScale: fontScale ?? this.fontScale,
      showGanji: showGanji ?? this.showGanji,
      showLunar: showLunar ?? this.showLunar,
      showSolarTerm: showSolarTerm ?? this.showSolarTerm,
      showHoliday: showHoliday ?? this.showHoliday,
      showSonEobsneun: showSonEobsneun ?? this.showSonEobsneun,
    );
  }

  Map<String, dynamic> toJson() => {
        'darkMode': darkMode,
        'fontScale': fontScale,
        'showGanji': showGanji,
        'showLunar': showLunar,
        'showSolarTerm': showSolarTerm,
        'showHoliday': showHoliday,
        'showSonEobsneun': showSonEobsneun,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        darkMode: json['darkMode'] as bool? ?? false,
        fontScale: (json['fontScale'] as num?)?.toDouble() ?? 1.0,
        showGanji: json['showGanji'] as bool? ?? true,
        showLunar: json['showLunar'] as bool? ?? true,
        showSolarTerm: json['showSolarTerm'] as bool? ?? true,
        showHoliday: json['showHoliday'] as bool? ?? true,
        showSonEobsneun: json['showSonEobsneun'] as bool? ?? false,
      );
}

abstract class SettingsRepository {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

class SharedPrefsSettingsRepository implements SettingsRepository {
  static const _key = 'barun_calendar.settings.v1';

  @override
  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const AppSettings();
    return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }
}
