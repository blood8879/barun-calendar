import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../data/purchase/purchase_service.dart';

/// Google 공식 테스트 배너 광고 유닛 ID. 디버그 빌드에서 실수로 실광고를 클릭해
/// 무효 트래픽으로 계정이 정지되는 걸 막기 위해 디버그 빌드는 항상 이 값을 쓴다.
String get _testBannerAdUnitId => Platform.isIOS
    ? 'ca-app-pub-3940256099942544/2934735716'
    : 'ca-app-pub-3940256099942544/6300978111';

/// 실 배포용(seolasoft@gmail.com, 바른달력 앱) 배너 광고 단위 ID.
/// 광고 단위 ID는 APK를 디컴파일하면 누구나 볼 수 있는 공개 식별자라
/// KASI 서비스키 같은 비밀값과 달리 하드코딩해도 안전하다(Google 공식 샘플도 동일 방식).
/// iOS 프로젝트는 아직 없으므로 Android 값만 존재.
const String _releaseBannerAdUnitId = 'ca-app-pub-6861868748362641/2876092653';

/// 릴리즈 빌드에서만 실제 광고 단위를 쓰고, 디버그/프로파일 빌드는 항상 테스트 광고를 쓴다.
String get _bannerAdUnitId => kReleaseMode ? _releaseBannerAdUnitId : _testBannerAdUnitId;

/// 하단 배너 광고(F12/C-50). 평생권 구매 시(광고 제거) 렌더링하지 않는다.
class AdBannerBar extends StatefulWidget {
  const AdBannerBar({super.key});

  @override
  State<AdBannerBar> createState() => _AdBannerBarState();
}

class _AdBannerBarState extends State<AdBannerBar> {
  BannerAd? _bannerAd;
  bool _adsRemoved = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final removed = await PurchaseService.instance.adsRemoved;
    if (!mounted) return;
    setState(() => _adsRemoved = removed);
    if (removed) return;

    final ad = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    );
    _bannerAd = ad;
    ad.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_adsRemoved || !_loaded || _bannerAd == null) return const SizedBox.shrink();
    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
