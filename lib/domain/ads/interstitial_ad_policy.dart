/// 전면 광고(F12/C-50 확장) 노출 빈도 정책.
///
/// AdMob SDK/SharedPreferences에 의존하지 않는 순수 상태 전이 함수로 만들어
/// 단위 테스트로 쿨다운·일일 상한·신규 사용자 유예를 검증할 수 있게 한다.
class InterstitialAdPolicyState {
  /// 지금까지 저장(일정 추가/수정) 완료 콜백이 호출된 총 횟수.
  final int totalSaveCount;

  /// 마지막으로 전면 광고를 실제로 노출한 시각. 노출한 적 없으면 null.
  final DateTime? lastShownAt;

  /// 오늘 노출한 횟수(자정 기준으로 리셋).
  final int dailyShownCount;

  /// [dailyShownCount]가 집계된 날짜(연-월-일만 의미 있음).
  final DateTime? dailyCountDate;

  const InterstitialAdPolicyState({
    this.totalSaveCount = 0,
    this.lastShownAt,
    this.dailyShownCount = 0,
    this.dailyCountDate,
  });

  InterstitialAdPolicyState copyWith({
    int? totalSaveCount,
    DateTime? lastShownAt,
    int? dailyShownCount,
    DateTime? dailyCountDate,
  }) {
    return InterstitialAdPolicyState(
      totalSaveCount: totalSaveCount ?? this.totalSaveCount,
      lastShownAt: lastShownAt ?? this.lastShownAt,
      dailyShownCount: dailyShownCount ?? this.dailyShownCount,
      dailyCountDate: dailyCountDate ?? this.dailyCountDate,
    );
  }
}

class InterstitialAdDecision {
  final bool shouldShow;
  final InterstitialAdPolicyState nextState;

  const InterstitialAdDecision({required this.shouldShow, required this.nextState});
}

class InterstitialAdPolicy {
  /// 신규 설치 후 처음 몇 번의 저장은 광고를 면제한다(첫 경험 방해 방지).
  static const int graceSaves = 2;

  /// 같은 기기에서 광고를 다시 보여주기까지 최소 대기 시간.
  static const Duration cooldown = Duration(minutes: 5);

  /// 하루 최대 노출 횟수(자정 기준 리셋).
  static const int dailyCap = 3;

  const InterstitialAdPolicy();

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 저장 완료 시점마다 호출한다. 횟수 기반이 아니라 시간 쿨다운 기반으로 제한하며,
  /// 저장 자체(로컬 데이터 반영)는 이 결정과 무관하게 항상 정상 처리되어야 한다 —
  /// 이 함수는 광고를 "보여줄지"만 결정하고 부수효과가 없다.
  InterstitialAdDecision decide(InterstitialAdPolicyState state, DateTime now) {
    final totalSaveCount = state.totalSaveCount + 1;

    // 신규 사용자 유예: 설치 후 첫 N회 저장에는 광고를 띄우지 않는다.
    if (totalSaveCount <= graceSaves) {
      return InterstitialAdDecision(
        shouldShow: false,
        nextState: state.copyWith(totalSaveCount: totalSaveCount),
      );
    }

    // 쿨다운: 마지막 노출로부터 최소 대기 시간이 지나지 않았으면 스킵.
    final last = state.lastShownAt;
    if (last != null && now.difference(last) < cooldown) {
      return InterstitialAdDecision(
        shouldShow: false,
        nextState: state.copyWith(totalSaveCount: totalSaveCount),
      );
    }

    // 일일 상한: 날짜가 바뀌었으면 카운터를 리셋한 값을 기준으로 판단.
    final sameDay = state.dailyCountDate != null && _isSameDay(state.dailyCountDate!, now);
    final effectiveDailyCount = sameDay ? state.dailyShownCount : 0;
    if (effectiveDailyCount >= dailyCap) {
      return InterstitialAdDecision(
        shouldShow: false,
        nextState: state.copyWith(
          totalSaveCount: totalSaveCount,
          dailyShownCount: effectiveDailyCount,
          dailyCountDate: now,
        ),
      );
    }

    // 노출 허용: 쿨다운/일일 카운터를 갱신한 새 상태를 반환한다.
    return InterstitialAdDecision(
      shouldShow: true,
      nextState: state.copyWith(
        totalSaveCount: totalSaveCount,
        lastShownAt: now,
        dailyShownCount: effectiveDailyCount + 1,
        dailyCountDate: now,
      ),
    );
  }
}
