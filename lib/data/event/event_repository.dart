import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/event/event.dart';

/// 일정 CRUD 저장소. shared_preferences(JSON 직렬화) 기반 로컬 저장소를 쓴다.
/// 데이터량이 커지면 sqlite로 교체 가능하도록 인터페이스를 분리해 둔다.
abstract class EventRepository {
  Future<List<CalendarEvent>> loadAll();
  Future<void> upsert(CalendarEvent event);
  Future<void> delete(String id);
  Future<void> replaceAll(List<CalendarEvent> events); // 백업 복원/가져오기용
}

class SharedPrefsEventRepository implements EventRepository {
  static const _key = 'barun_calendar.events.v1';

  @override
  Future<List<CalendarEvent>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _save(List<CalendarEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(events.map((e) => e.toJson()).toList());
    await prefs.setString(_key, raw);
  }

  @override
  Future<void> upsert(CalendarEvent event) async {
    final events = await loadAll();
    final idx = events.indexWhere((e) => e.id == event.id);
    if (idx >= 0) {
      events[idx] = event;
    } else {
      events.add(event);
    }
    await _save(events);
  }

  @override
  Future<void> delete(String id) async {
    final events = await loadAll();
    events.removeWhere((e) => e.id == id);
    await _save(events);
  }

  @override
  Future<void> replaceAll(List<CalendarEvent> events) => _save(events);
}
