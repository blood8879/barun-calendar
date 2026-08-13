import 'package:flutter_test/flutter_test.dart';

import 'package:barun_calendar/domain/ads/interstitial_ad_policy.dart';

void main() {
  final policy = const InterstitialAdPolicy();

  test('신규 사용자의 첫 2회 저장은 광고를 면제한다', () {
    var state = const InterstitialAdPolicyState();
    final now = DateTime(2026, 1, 1, 10);

    final first = policy.decide(state, now);
    expect(first.shouldShow, isFalse);
    state = first.nextState;
    expect(state.totalSaveCount, 1);

    final second = policy.decide(state, now);
    expect(second.shouldShow, isFalse);
    state = second.nextState;
    expect(state.totalSaveCount, 2);
  });

  test('유예 이후 첫 저장은 쿨다운/일일상한이 비어있으면 노출한다', () {
    var state = const InterstitialAdPolicyState(totalSaveCount: 2);
    final now = DateTime(2026, 1, 1, 10);

    final decision = policy.decide(state, now);
    expect(decision.shouldShow, isTrue);
    expect(decision.nextState.lastShownAt, now);
    expect(decision.nextState.dailyShownCount, 1);
  });

  test('쿨다운 시간 이내 재저장은 광고를 건너뛴다', () {
    final now = DateTime(2026, 1, 1, 10);
    var state = InterstitialAdPolicyState(
      totalSaveCount: 3,
      lastShownAt: now,
      dailyShownCount: 1,
      dailyCountDate: now,
    );

    final soon = now.add(const Duration(minutes: 4));
    final decision = policy.decide(state, soon);
    expect(decision.shouldShow, isFalse);
  });

  test('쿨다운 시간이 지나면 다시 노출한다', () {
    final now = DateTime(2026, 1, 1, 10);
    var state = InterstitialAdPolicyState(
      totalSaveCount: 3,
      lastShownAt: now,
      dailyShownCount: 1,
      dailyCountDate: now,
    );

    final later = now.add(const Duration(minutes: 6));
    final decision = policy.decide(state, later);
    expect(decision.shouldShow, isTrue);
    expect(decision.nextState.dailyShownCount, 2);
  });

  test('하루 상한(3회)에 도달하면 쿨다운이 지나도 노출하지 않는다', () {
    final now = DateTime(2026, 1, 1, 10);
    var state = InterstitialAdPolicyState(
      totalSaveCount: 5,
      lastShownAt: now,
      dailyShownCount: 3,
      dailyCountDate: now,
    );

    final later = now.add(const Duration(hours: 2));
    final decision = policy.decide(state, later);
    expect(decision.shouldShow, isFalse);
  });

  test('날짜가 바뀌면 일일 카운터가 리셋되어 다시 노출 가능하다', () {
    final day1 = DateTime(2026, 1, 1, 23, 59);
    var state = InterstitialAdPolicyState(
      totalSaveCount: 5,
      lastShownAt: day1,
      dailyShownCount: 3,
      dailyCountDate: day1,
    );

    final day2 = DateTime(2026, 1, 2, 0, 5);
    final decision = policy.decide(state, day2);
    expect(decision.shouldShow, isTrue);
    expect(decision.nextState.dailyShownCount, 1);
  });
}
