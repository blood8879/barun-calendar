import 'package:shared_preferences/shared_preferences.dart';

/// 최초 실행 온보딩(코치마크) 완료 여부 저장소.
abstract class OnboardingRepository {
  Future<bool> isCompleted();
  Future<void> setCompleted(bool completed);
}

class SharedPrefsOnboardingRepository implements OnboardingRepository {
  static const _key = 'barun_calendar.onboarding.completed.v1';

  @override
  Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  @override
  Future<void> setCompleted(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, completed);
  }
}
