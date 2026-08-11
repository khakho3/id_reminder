import '../models/id_scan_result.dart';

class OcrTextParser {
  static final RegExp _schoolWords = RegExp(
    r'\b(school|university|college|institute|academy|polytechnic)\b',
    caseSensitive: false,
  );

  static final RegExp _excludedNameWords = RegExp(
    r'\b(student|identity|identification|card|school|university|college|'
    r'institute|academy|department|faculty|valid|expires?|issued?|number)\b',
    caseSensitive: false,
  );

  IdScanResult parse(String rawText) {
    final lines = rawText
        .split(RegExp(r'[\r\n]+'))
        .map(_cleanLine)
        .where((line) => line.isNotEmpty)
        .toList();

    return IdScanResult(
      rawText: rawText.trim(),
      schoolName: _findSchool(lines),
      studentId: _findStudentId(lines),
      studentName: _findStudentName(lines),
    );
  }

  String _findStudentId(List<String> lines) {
    final labelledPattern = RegExp(
      r'\b(?:student\s*)?(?:id|number|no\.?)(?:\s*(?:number|no\.?))?'
      r'\s*[:#-]?\s*([a-z0-9][a-z0-9\/-]{3,})\b',
      caseSensitive: false,
    );

    for (final line in lines) {
      final match = labelledPattern.firstMatch(line);
      if (match != null && _looksLikeId(match.group(1)!)) {
        return match.group(1)!.toUpperCase();
      }
    }

    final candidates = <({String value, int score})>[];
    final tokenPattern = RegExp(r'\b[A-Za-z0-9][A-Za-z0-9\/-]{4,19}\b');
    for (final line in lines) {
      for (final match in tokenPattern.allMatches(line)) {
        final value = match.group(0)!;
        if (!_looksLikeId(value)) {
          continue;
        }
        final digitCount = RegExp(r'\d').allMatches(value).length;
        final hasLetter = RegExp(r'[A-Za-z]').hasMatch(value);
        final score =
            digitCount + (hasLetter ? 3 : 0) + (line.length < 28 ? 1 : 0);
        candidates.add((value: value, score: score));
      }
    }
    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.isEmpty ? '' : candidates.first.value.toUpperCase();
  }

  String _findSchool(List<String> lines) {
    final labelledPattern = RegExp(
      r'\b(?:school|institution)\s*(?:name)?\s*[:#-]\s*(.+)$',
      caseSensitive: false,
    );
    for (final line in lines) {
      final match = labelledPattern.firstMatch(line);
      if (match != null && match.group(1)!.trim().length >= 3) {
        return match.group(1)!.trim();
      }
    }

    final candidates = lines.where((line) {
      return line.length >= 5 &&
          line.length <= 80 &&
          _schoolWords.hasMatch(line);
    }).toList();
    if (candidates.isEmpty) {
      return '';
    }
    candidates.sort((a, b) => _schoolScore(b).compareTo(_schoolScore(a)));
    return candidates.first;
  }

  String _findStudentName(List<String> lines) {
    final labelledPattern = RegExp(
      "\\b(?:student\\s*)?name\\s*[:#-]\\s*([A-Za-z][A-Za-z .'-]{2,})\$",
      caseSensitive: false,
    );
    for (final line in lines) {
      final match = labelledPattern.firstMatch(line);
      if (match != null) {
        return match.group(1)!.trim();
      }
    }

    for (var index = 0; index < lines.length - 1; index++) {
      if (RegExp(
        r'^(?:student\s*)?name\s*:?$',
        caseSensitive: false,
      ).hasMatch(lines[index])) {
        final followingLine = lines[index + 1];
        if (_looksLikeName(followingLine)) {
          return followingLine;
        }
      }
    }

    final candidates = lines.where(_looksLikeName).toList();
    if (candidates.isEmpty) {
      return '';
    }
    candidates.sort((a, b) => _nameScore(b).compareTo(_nameScore(a)));
    return candidates.first;
  }

  bool _looksLikeId(String value) {
    final digits = RegExp(r'\d').allMatches(value).length;
    if (digits < 3 || value.length < 5 || value.length > 20) {
      return false;
    }
    return !RegExp(r'^(?:19|20)\d{2}[/-]\d{1,2}[/-]\d{1,2}$').hasMatch(value);
  }

  bool _looksLikeName(String line) {
    if (line.length < 5 ||
        line.length > 55 ||
        _excludedNameWords.hasMatch(line)) {
      return false;
    }
    if (RegExp(r'\d').hasMatch(line)) {
      return false;
    }
    final words = line.split(RegExp(r'\s+'));
    return words.length >= 2 &&
        words.length <= 5 &&
        words.every((word) => RegExp(r"^[A-Za-z][A-Za-z.'-]*$").hasMatch(word));
  }

  int _schoolScore(String line) {
    var score = 0;
    if (_schoolWords.hasMatch(line)) score += 5;
    if (line == line.toUpperCase()) score += 2;
    if (line.split(' ').length >= 2) score += 1;
    return score;
  }

  int _nameScore(String line) {
    var score = line.split(RegExp(r'\s+')).length;
    if (line == line.toUpperCase()) score += 2;
    return score;
  }

  String _cleanLine(String line) {
    return line.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
