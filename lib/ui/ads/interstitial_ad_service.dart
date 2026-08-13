import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/purchase/purchase_service.dart';
import '../../domain/ads/interstitial_ad_policy.dart';

/// Google 공식 테스트 전면 광고 유닛 ID. 디버그 빌드는 항상 이 값을 쓴다.
String get _testInterstitialAdUnitId => Platform.isIOS
    ? 'ca-app-pub-3940256099942544/4411468910'
    : 'ca-app-pub-3940256099942544/1033173712';

/// 실 배포용 전면 광고 단위 ID.
/// TODO(OPEN_QUESTIONS.md): AdMob 콘솔(seolasoft@gmail.com, 바른달력 앱)에서
/// 전면 광고 단위를 새로 만들고 이 값을 실제 ID로 교체해야 한다. 그 전까지
/// 릴리즈 빌드에서도 노출되지 않도록 [InterstitialAdService.isConfigured]가
/// 이 플레이스홀더 여부를 확인해 광고 로드 자체를 시도하지 않는다.
const String _releaseInterstitialAdUnitId = 'REPLACE_WITH_REAL_INTERSTITIAL_AD_UNIT_ID';

String get _interstitialAdUnitId =>
    kReleaseMode ? _releaseInterstitialAdUnitId : _testInterstitialAdUnitId;

/// 일정 저장 완료 시점에 노출하는 전면 광고(F12/C-50 확장).
///
/// - 평생권(광고 제거) 구매자에게는 절대 노출되지 않는다.
/// - 빈도는 [InterstitialAdPolicy](쿨다운 5분 + 일일 상한 3회 + 신규 사용자 유예
///   2회)로 제한한다.
/// - 광고 로드 실패/미준비 시에도 저장 플로우를 막지 않고 조용히 스킵한다.
class InterstitialAdService {
  InterstitialAdService._();
  static final InterstitialAdService instance = InterstitialAdService._();

  static const _prefKey = 'interstitial_ad_policy_state.v1';

  final InterstitialAdPolicy _policy = const InterstitialAdPolicy();
  InterstitialAd? _preloaded;
  bool _loading = false;

  /// 실제 배포용 광고 단위 ID가 아직 플레이스홀더인 동안은 로드를 시도하지 않는다.
  bool get isConfigured =>
      !kReleaseMode || _releaseInterstitialAdUnitId != 'REPLACE_WITH_REAL_INTERSTITIAL_AD_UNIT_ID';

  Future<InterstitialAdPolicyState> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final total = prefs.getInt('$_prefKey.totalSaveCount') ?? 0;
    final lastShownMs = prefs.getInt('$_prefKey.lastShownAt');
    final dailyCount = prefs.getInt('$_prefKey.dailyShownCount') ?? 0;
    final dailyDateMs = prefs.getInt('$_prefKey.dailyCountDate');
    return InterstitialAdPolicyState(
      totalSaveCount: total,
      lastShownAt: lastShownMs != null ? DateTime.fromMillisecondsSinceEpoch(lastShownMs) : null,
      dailyShownCount: dailyCount,
      dailyCountDate: dailyDateMs != null ? DateTime.fromMillisecondsSinceEpoch(dailyDateMs) : null,
    );
  }

  Future<void> _saveState(InterstitialAdPolicyState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_prefKey.totalSaveCount', state.totalSaveCount);
    if (state.lastShownAt != null) {
      await prefs.setInt('$_prefKey.lastShownAt', state.lastShownAt!.millisecondsSinceEpoch);
    }
    await prefs.setInt('$_prefKey.dailyShownCount', state.dailyShownCount);
    if (state.dailyCountDate != null) {
      await prefs.setInt('$_prefKey.dailyCountDate', state.dailyCountDate!.millisecondsSinceEpoch);
    }
  }

  void _preload() {
    if (!isConfigured || _loading || _preloaded != null) return;
    _loading = true;
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _preloaded = ad;
          _loading = false;
        },
        onAdFailedToLoad: (error) {
          _loading = false;
        },
      ),
    );
  }

  /// 일정 저장 완료 콜백에서 호출한다. 저장 자체는 이 호출과 무관하게 이미
  /// 끝난 뒤이므로, 이 메서드는 저장 플로우를 절대 지연/차단하지 않는다.
  Future<void> onEventSaved() async {
    if (await PurchaseService.instance.adsRemoved) return;

    final now = DateTime.now();
    final state = await _loadState();
    final decision = _policy.decide(state, now);
    await _saveState(decision.nextState);

    if (!decision.shouldShow) {
      // 다음 기회를 위해 미리 로드만 해둔다.
      _preload();
      return;
    }

    final ad = _preloaded;
    _preloaded = null;
    if (ad == null || !isConfigured) {
      // 준비된 광고가 없으면 조용히 넘어간다(사용자 플로우 방해 금지).
      _preload();
      return;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _preload();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _preload();
      },
    );
    await ad.show();
  }

  /// 앱 시작 시 미리 한 번 로드해두면 이후 저장 시 대기 없이 바로 보여줄 수 있다.
  void warmUp() => _preload();
}
