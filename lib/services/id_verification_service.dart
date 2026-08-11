import '../models/id_scan_result.dart';
import '../models/registered_id.dart';

class IdVerificationResult {
  const IdVerificationResult({required this.isVerified, required this.message});

  final bool isVerified;
  final String message;
}

class IdVerificationService {
  const IdVerificationService();

  IdVerificationResult verify({
    required RegisteredId registeredId,
    required IdScanResult scannedId,
  }) {
    final scannedStudentId = _normalizeStudentId(scannedId.studentId);
    final registeredStudentId = _normalizeStudentId(registeredId.studentId);
    final studentIdMatches = _studentIdsMatch(
      registeredStudentId,
      scannedStudentId,
    );
    final schoolMatches = _schoolNamesMatch(
      registeredId.schoolName,
      scannedId.schoolName,
    );

    if (studentIdMatches && schoolMatches) {
      return const IdVerificationResult(
        isVerified: true,
        message: 'Your school ID matches the registered card.',
      );
    }
    if (!studentIdMatches) {
      return const IdVerificationResult(
        isVerified: false,
        message: "This doesn't appear to be your registered ID.",
      );
    }
    return const IdVerificationResult(
      isVerified: false,
      message: 'The school name on this card could not be verified.',
    );
  }

  String _normalizeStudentId(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  bool _studentIdsMatch(String registered, String scanned) {
    if (registered.isEmpty ||
        scanned.isEmpty ||
        registered.length != scanned.length) {
      return false;
    }
    if (registered == scanned) return true;

    // OCR occasionally confuses these pairs. Allow only such substitutions,
    // and only where the rest of this strong identifier is identical.
    var ambiguousDifferences = 0;
    for (var index = 0; index < registered.length; index++) {
      final expected = registered[index];
      final actual = scanned[index];
      if (expected == actual) continue;
      if (!_isOcrPair(expected, actual)) return false;
      ambiguousDifferences++;
    }
    return ambiguousDifferences > 0 && ambiguousDifferences <= 2;
  }

  bool _isOcrPair(String first, String second) {
    const pairs = {'O0', '0O', 'I1', '1I', 'L1', '1L', 'S5', '5S'};
    return pairs.contains('$first$second');
  }

  bool _schoolNamesMatch(String registered, String scanned) {
    final expected = _schoolTokens(registered);
    final actual = _schoolTokens(scanned);
    if (expected.isEmpty || actual.isEmpty) return false;
    if (expected.join() == actual.join()) return true;

    final expectedSet = expected.toSet();
    final actualSet = actual.toSet();
    final overlap = expectedSet.intersection(actualSet).length;
    final smaller = expectedSet.length < actualSet.length
        ? expectedSet.length
        : actualSet.length;
    return smaller >= 2 && overlap / smaller >= .75;
  }

  List<String> _schoolTokens(String value) {
    const ignored = {'the', 'of', 'and', 'school', 'university', 'college'};
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty && !ignored.contains(token))
        .toList();
  }
}
