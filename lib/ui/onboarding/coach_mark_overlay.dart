import 'package:flutter/material.dart';

/// 코치마크 한 단계: 강조할 위젯의 [targetKey]와 설명 [message].
class CoachMarkStep {
  final GlobalKey targetKey;
  final String message;

  const CoachMarkStep({required this.targetKey, required this.message});
}

/// [steps]를 순서대로 하나씩 스포트라이트로 강조하는 전체 화면 오버레이를 띄운다.
/// 대상 위젯이 현재 화면에 없으면(레이아웃 전) 해당 단계는 건너뛴다.
void showCoachMarks(
  BuildContext context, {
  required List<CoachMarkStep> steps,
  VoidCallback? onFinished,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  int index = 0;

  void close() {
    entry.remove();
    onFinished?.call();
  }

  void advance() {
    index++;
    if (index >= steps.length) {
      close();
      return;
    }
    entry.markNeedsBuild();
  }

  entry = OverlayEntry(
    builder: (overlayContext) {
      final step = steps[index];
      final renderObject = step.targetKey.currentContext?.findRenderObject();
      Rect targetRect;
      if (renderObject is RenderBox && renderObject.attached) {
        final topLeft = renderObject.localToGlobal(Offset.zero);
        targetRect = topLeft & renderObject.size;
      } else {
        // 대상을 찾을 수 없으면 이 단계는 자동으로 건너뛴다.
        WidgetsBinding.instance.addPostFrameCallback((_) => advance());
        targetRect = Rect.zero;
      }

      return _CoachMarkFrame(
        targetRect: targetRect,
        message: step.message,
        stepIndex: index,
        stepCount: steps.length,
        isLast: index == steps.length - 1,
        onNext: advance,
        onSkip: close,
      );
    },
  );

  overlay.insert(entry);
}

class _CoachMarkFrame extends StatelessWidget {
  final Rect targetRect;
  final String message;
  final int stepIndex;
  final int stepCount;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _CoachMarkFrame({
    required this.targetRect,
    required this.message,
    required this.stepIndex,
    required this.stepCount,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;
    const padding = 8.0;
    final spotlightRect = targetRect.isEmpty
        ? Rect.zero
        : targetRect.inflate(padding);

    final showBelow = spotlightRect.bottom + 140 < screenSize.height;
    final bubbleTop = showBelow
        ? spotlightRect.bottom + 12
        : (spotlightRect.top - 140).clamp(48.0, screenSize.height - 200);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onNext,
            child: CustomPaint(
              painter: _SpotlightPainter(
                spotlightRect: spotlightRect,
                color: Colors.black.withValues(alpha: 0.72),
              ),
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          top: bubbleTop,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    key: const ValueKey('coach-mark-message'),
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${stepIndex + 1} / $stepCount',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        key: const ValueKey('coach-mark-skip'),
                        onPressed: onSkip,
                        child: const Text('건너뛰기'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        key: const ValueKey('coach-mark-next'),
                        onPressed: onNext,
                        child: Text(isLast ? '시작하기' : '다음'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect spotlightRect;
  final Color color;

  _SpotlightPainter({required this.spotlightRect, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    if (spotlightRect.isEmpty) {
      canvas.drawPath(backgroundPath, Paint()..color = color);
      return;
    }
    final holePath = Path()
      ..addRRect(RRect.fromRectAndRadius(spotlightRect, const Radius.circular(12)));
    final combined = Path.combine(PathOperation.difference, backgroundPath, holePath);
    canvas.drawPath(combined, Paint()..color = color);
    canvas.drawRRect(
      RRect.fromRectAndRadius(spotlightRect, const Radius.circular(12)),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.spotlightRect != spotlightRect || oldDelegate.color != color;
}
