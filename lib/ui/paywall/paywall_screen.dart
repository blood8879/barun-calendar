import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../data/purchase/purchase_service.dart';

/// 디자인 목업 S11(페이월) 대응 화면.
/// 명세 C-48/C-49: 결제 전 사전 고지 문구 노출, 생애 노출 2회 제한(호출 측에서 관리).
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  ProductDetails? _product;
  bool _storeUnavailable = false;
  bool _adsRemoved = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final removed = await PurchaseService.instance.adsRemoved;
    final response = await PurchaseService.instance.queryProduct();
    if (!mounted) return;
    setState(() {
      _adsRemoved = removed;
      if (response == null || response.productDetails.isEmpty) {
        _storeUnavailable = true;
      } else {
        _product = response.productDetails.first;
      }
    });
  }

  Future<void> _buy() async {
    final product = _product;
    if (product == null) return;
    final started = await PurchaseService.instance.buyLifetime(product);
    setState(() => _message = started ? '결제창을 여는 중입니다...' : '결제를 시작할 수 없습니다.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('평생권')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('바른달력 평생권', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('한 번 결제로 배너 광고를 영구적으로 제거합니다. 구독이 아닌 1회성 구매입니다.'),
            const SizedBox(height: 16),
            if (_adsRemoved)
              const Text('이미 평생권을 보유하고 있습니다.', style: TextStyle(color: Colors.green)),
            if (!_adsRemoved && _storeUnavailable)
              const Text(
                '스토어 상품을 아직 등록 중입니다. 잠시 후 다시 시도해 주세요.',
                style: TextStyle(color: Colors.orange),
              ),
            if (!_adsRemoved && _product != null) ...[
              Text('가격: ${_product!.price}', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              FilledButton(onPressed: _buy, child: const Text('평생권 구매하기')),
            ],
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                await PurchaseService.instance.restorePurchases();
                setState(() => _message = '구매 내역을 복원했습니다.');
                _load();
              },
              child: const Text('구매 복원'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!),
            ],
          ],
        ),
      ),
    );
  }
}
