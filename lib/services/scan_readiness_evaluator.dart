class ScanReadiness {
  const ScanReadiness({
    required this.hasEnoughText,
    required this.isHoldingStill,
    required this.isReady,
  });

  final bool hasEnoughText;
  final bool isHoldingStill;
  final bool isReady;
}

/// A deliberately simple first-pass readiness check.
///
/// It can later be replaced with card-edge detection without changing the
/// scanner screen. For now, readable and similar OCR text across three checks
/// is treated as a stable card.
class ScanReadinessEvaluator {
  ScanReadinessEvaluator({this.requiredStableChecks = 3});

  final int requiredStableChecks;
  Set<String>? _previousTokens;
  int _stableChecks = 0;

  ScanReadiness evaluate(String text) {
    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final alphanumericCount = text
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .length;
    final hasEnoughText = lines.length >= 3 && alphanumericCount >= 20;

    if (!hasEnoughText) {
      reset();
      return const ScanReadiness(
        hasEnoughText: false,
        isHoldingStill: false,
        isReady: false,
      );
    }

    final tokens = text
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.length >= 3)
        .toSet();

    final previous = _previousTokens;
    if (previous == null || _similarity(previous, tokens) < 0.55) {
      _stableChecks = 1;
    } else {
      _stableChecks += 1;
    }
    _previousTokens = tokens;

    return ScanReadiness(
      hasEnoughText: true,
      isHoldingStill: _stableChecks >= 2,
      isReady: _stableChecks >= requiredStableChecks,
    );
  }

  void reset() {
    _previousTokens = null;
    _stableChecks = 0;
  }

  double _similarity(Set<String> first, Set<String> second) {
    if (first.isEmpty || second.isEmpty) {
      return 0;
    }
    final intersection = first.intersection(second).length;
    final largestSet = first.length > second.length
        ? first.length
        : second.length;
    return intersection / largestSet;
  }
}
