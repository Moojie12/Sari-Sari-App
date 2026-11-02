class ExpiryDateCandidate {
  final DateTime date;
  final String rawMatch;
  final int confidenceScore;
  final String contextSnippet;

  const ExpiryDateCandidate({
    required this.date,
    required this.rawMatch,
    required this.confidenceScore,
    required this.contextSnippet,
  });
}

/// Helper utility for extracting and ranking expiration dates from OCR text lines.
class ExpiryDateParser {
  ExpiryDateParser._();

  static const Map<String, int> _monthMap = {
    'jan': 1, 'january': 1,
    'feb': 2, 'february': 2,
    'mar': 3, 'march': 3,
    'apr': 4, 'april': 4,
    'may': 5,
    'jun': 6, 'june': 6,
    'jul': 7, 'july': 7,
    'aug': 8, 'august': 8,
    'sep': 9, 'september': 9, 'sept': 9,
    'oct': 10, 'october': 10,
    'nov': 11, 'november': 11,
    'dec': 12, 'december': 12,
  };

  /// Parse lines of text and extract ranked expiration date candidates
  static List<ExpiryDateCandidate> parseLines(List<String> lines) {
    final List<ExpiryDateCandidate> candidates = [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final upper = line.toUpperCase();
      final isMfg = upper.contains('MFG') ||
          upper.contains('PROD') ||
          upper.contains('PKD') ||
          upper.contains('MFR') ||
          upper.contains('MANUF');

      final isExp = upper.contains('EXP') ||
          upper.contains('BB') ||
          upper.contains('BEST BEFORE') ||
          upper.contains('BEST BY') ||
          upper.contains('USE BY') ||
          upper.contains('CONSUME');

      // 1. Textual Month Formats: "15 OCT 2026", "15-OCT-26", "15.OCT.2026"
      final textMonthRegex = RegExp(
        r'\b(\d{1,2})[\s\./\-_]+([A-Za-z]{3,9})[\s\./\-_]+(\d{2,4})\b',
      );
      for (final match in textMonthRegex.allMatches(line)) {
        final d = int.tryParse(match.group(1)!);
        final mStr = match.group(2)!.toLowerCase();
        final y = _normalizeYear(int.tryParse(match.group(3)!));
        final m = _monthMap[mStr];

        if (d != null && m != null && y != null && _isValidDate(y, m, d)) {
          final dt = DateTime(y, m, d);
          int score = 40;
          if (isExp) score += 40;
          if (isMfg) score -= 30;
          if (dt.isAfter(today)) score += 20;
          candidates.add(ExpiryDateCandidate(
            date: dt,
            rawMatch: match.group(0)!,
            confidenceScore: score,
            contextSnippet: line,
          ));
        }
      }

      // 2. Textual Month First: "OCT 15 2026", "OCT 15, 26"
      final textMonthFirstRegex = RegExp(
        r'\b([A-Za-z]{3,9})[\s\./\-_]+(\d{1,2})[,\s\./\-_]+(\d{2,4})\b',
      );
      for (final match in textMonthFirstRegex.allMatches(line)) {
        final mStr = match.group(1)!.toLowerCase();
        final d = int.tryParse(match.group(2)!);
        final y = _normalizeYear(int.tryParse(match.group(3)!));
        final m = _monthMap[mStr];

        if (d != null && m != null && y != null && _isValidDate(y, m, d)) {
          final dt = DateTime(y, m, d);
          int score = 40;
          if (isExp) score += 40;
          if (isMfg) score -= 30;
          if (dt.isAfter(today)) score += 20;
          candidates.add(ExpiryDateCandidate(
            date: dt,
            rawMatch: match.group(0)!,
            confidenceScore: score,
            contextSnippet: line,
          ));
        }
      }

      // 3. Month & Year Only with Text Month: "OCT 2026", "EXP NOV 25"
      final textMonthYearRegex = RegExp(
        r'\b([A-Za-z]{3,9})[\s\./\-_]+(\d{2,4})\b',
      );
      for (final match in textMonthYearRegex.allMatches(line)) {
        final mStr = match.group(1)!.toLowerCase();
        final y = _normalizeYear(int.tryParse(match.group(2)!));
        final m = _monthMap[mStr];

        if (m != null && y != null) {
          final lastDay = _daysInMonth(y, m);
          final dt = DateTime(y, m, lastDay);
          int score = 30;
          if (isExp) score += 35;
          if (isMfg) score -= 30;
          if (dt.isAfter(today)) score += 15;
          candidates.add(ExpiryDateCandidate(
            date: dt,
            rawMatch: match.group(0)!,
            confidenceScore: score,
            contextSnippet: line,
          ));
        }
      }

      // 4. Numeric 3-part formats: "25/12/2026", "2026-12-25", "25.12.26"
      final num3Regex = RegExp(
        r'\b(\d{1,4})[\./\-_](\d{1,2})[\./\-_](\d{1,4})\b',
      );
      for (final match in num3Regex.allMatches(line)) {
        final p1 = int.tryParse(match.group(1)!);
        final p2 = int.tryParse(match.group(2)!);
        final p3 = int.tryParse(match.group(3)!);

        if (p1 == null || p2 == null || p3 == null) continue;

        int? year, month, day;

        // Case YYYY-MM-DD
        if (p1 > 1000) {
          year = p1;
          month = p2;
          day = p3;
        }
        // Case DD/MM/YYYY or MM/DD/YYYY or DD/MM/YY
        else {
          year = _normalizeYear(p3);
          if (p1 > 12 && p2 <= 12) {
            day = p1;
            month = p2;
          } else if (p2 > 12 && p1 <= 12) {
            month = p1;
            day = p2;
          } else if (p1 <= 31 && p2 <= 12) {
            // Default Philippine format is DD/MM/YYYY
            day = p1;
            month = p2;
          }
        }

        if (year != null && month != null && day != null && _isValidDate(year, month, day)) {
          final dt = DateTime(year, month, day);
          int score = 35;
          if (isExp) score += 40;
          if (isMfg) score -= 35;
          if (dt.isAfter(today)) score += 20;
          candidates.add(ExpiryDateCandidate(
            date: dt,
            rawMatch: match.group(0)!,
            confidenceScore: score,
            contextSnippet: line,
          ));
        }
      }

      // 5. Numeric 2-part format MM/YYYY or MM/YY: "12/2026" or "10/25"
      final num2Regex = RegExp(
        r'\b(\d{1,2})[\./\-_](\d{2,4})\b',
      );
      for (final match in num2Regex.allMatches(line)) {
        final p1 = int.tryParse(match.group(1)!);
        final p2 = int.tryParse(match.group(2)!);

        if (p1 != null && p2 != null && p1 >= 1 && p1 <= 12) {
          final year = _normalizeYear(p2);
          if (year != null && year >= 2020 && year <= 2045) {
            final lastDay = _daysInMonth(year, p1);
            final dt = DateTime(year, p1, lastDay);
            int score = 25;
            if (isExp) score += 35;
            if (isMfg) score -= 30;
            if (dt.isAfter(today)) score += 15;
            candidates.add(ExpiryDateCandidate(
              date: dt,
              rawMatch: match.group(0)!,
              confidenceScore: score,
              contextSnippet: line,
            ));
          }
        }
      }
    }

    // Deduplicate by date and keep highest score
    final Map<DateTime, ExpiryDateCandidate> unique = {};
    for (final c in candidates) {
      if (!unique.containsKey(c.date) || unique[c.date]!.confidenceScore < c.confidenceScore) {
        unique[c.date] = c;
      }
    }

    final sorted = unique.values.toList()
      ..sort((a, b) => b.confidenceScore.compareTo(a.confidenceScore));

    return sorted;
  }

  static int? _normalizeYear(int? y) {
    if (y == null) return null;
    if (y >= 1000) return y;
    if (y >= 0 && y < 70) return 2000 + y;
    if (y >= 70 && y < 100) return 1900 + y;
    return y;
  }

  static bool _isValidDate(int y, int m, int d) {
    if (y < 2000 || y > 2050) return false;
    if (m < 1 || m > 12) return false;
    if (d < 1 || d > _daysInMonth(y, m)) return false;
    return true;
  }

  static int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }
}
