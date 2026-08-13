import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 평생권(F20/C-48/C-49) 인앱결제 서비스.
/// 상품 ID는 Play Console 등록이 선행되어야 하며(OPEN_QUESTIONS.md #3),
/// 등록 전까지는 [queryProduct]가 store unavailable을 반환하므로 UI에서 이를 안내한다.
class PurchaseService {
  PurchaseService._();
  static final PurchaseService instance = PurchaseService._();

  static const String lifetimeProductId = 'barun_lifetime_v1';
  static const _prefKeyAdsRemoved = 'ads_removed';

  final _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  Future<bool> get adsRemoved async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKeyAdsRemoved) ?? false;
  }

  Future<void> _markPurchased() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyAdsRemoved, true);
  }

  void listenForPurchases() {
    _subscription ??= _iap.purchaseStream.listen((purchases) async {
      for (final p in purchases) {
        if (p.productID == lifetimeProductId &&
            (p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored)) {
          await _markPurchased();
          if (p.pendingCompletePurchase) {
            await _iap.completePurchase(p);
          }
        }
      }
    });
  }

  Future<ProductDetailsResponse?> queryProduct() async {
    final available = await _iap.isAvailable();
    if (!available) return null;
    return _iap.queryProductDetails({lifetimeProductId});
  }

  Future<bool> buyLifetime(ProductDetails product) {
    final param = PurchaseParam(productDetails: product);
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restorePurchases() => _iap.restorePurchases();

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
