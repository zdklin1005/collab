import 'package:flutter/material.dart';
import 'localquest_theme.dart';

class SsmAnalysisResult {
  const SsmAnalysisResult({
    required this.isAuthenticSsm,
    required this.status,
    required this.statusExplanation,
    required this.confidenceScore,
    this.modernRegistrationNumber,
    this.legacyRegistrationNumber,
    this.formattedRegistrationNumber,
    this.extractedBusinessName,
    this.businessNameMatchScore = 0.0,
    this.expiryDate,
    this.isExpired = false,
    this.matchedKeywords = const [],
    this.rawText = '',
  });

  final bool isAuthenticSsm;
  final String status; // 'verified', 'pending_review', 'rejected'
  final String statusExplanation;
  final double confidenceScore; // 0.0 to 1.0
  final String? modernRegistrationNumber;
  final String? legacyRegistrationNumber;
  final String? formattedRegistrationNumber;
  final String? extractedBusinessName;
  final double businessNameMatchScore; // 0.0 to 1.0
  final DateTime? expiryDate;
  final bool isExpired;
  final List<String> matchedKeywords;
  final String rawText;

  bool get isVerified => status == 'verified';
}

class SsmVerificationEngine {
  static const List<String> _statutoryKeywords = [
    'SURUHANJAYA SYARIKAT MALAYSIA',
    'COMPANIES COMMISSION OF MALAYSIA',
    'PERAKUAN PENDAFTARAN',
    'PERAKUAN PEMBAHARUAN PENDAFTARAN',
    'PEMBAHARUAN PENDAFTARAN',
    'BORANG D',
    'BORANG E',
    'BORANG A',
    'BORANG B',
    'BORANG 9',
    'BORANG 13',
    'BORANG 8',
    'AKTA PENDAFTARAN PERNIAGAAN 1956',
    'AKTA PENDAFTARAN PERNIAGAAN',
    'AKTA SYARIKAT 2016',
    'AKTA SYARIKAT 1965',
    'KAEDAH-KAEDAH PENDAFTARAN PERNIAGAAN',
    'KAEDAH 13',
    'CERTIFICATE OF INCORPORATION',
    'CERTIFICATE OF RENEWAL',
  ];

  static final List<RegExp> _statutoryRegexes = [
    RegExp(r'SURUHAN[A-Z\s]{0,12}MALAYS[A-Z]{0,4}', caseSensitive: false),
    RegExp(r'PERAKUAN\s+(?:PEMBAHARUAN\s+)?PENDAFTARAN', caseSensitive: false),
    RegExp(r'BORANG\s+[A-Z0-9]', caseSensitive: false),
    RegExp(r'AKTA\s+PENDAFTARAN\s+PERNIA\s*GAAN', caseSensitive: false),
    RegExp(r'AKTA\s+SYARIKAT', caseSensitive: false),
    RegExp(r'KAEDAH\s*(?:-\s*KAEDAH)?\s*\d*', caseSensitive: false),
  ];

  static final RegExp _modernSsmPattern = RegExp(
    r'\b(19\d{2}|20\d{2})\d{8}\b',
  );

  static final RegExp _legacySsmPattern = RegExp(
    r'\b(?:[A-Z]{1,4}\s*\d{4,10}|\d{5,10})\s*-\s*[A-Z0-9]\b',
    caseSensitive: false,
  );

  static final RegExp _datePattern = RegExp(
    r'\b(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{4})\b',
  );

  /// Analyzes raw OCR text from a Malaysian SSM certificate
  static SsmAnalysisResult analyze({
    required String text,
    String? userEnteredBusinessName,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    // Normalize OCR variations such as spaced words
    final normalizedText = text
        .replaceAll(RegExp(r'PERNIA\s+GAAN', caseSensitive: false), 'PERNIAGAAN')
        .replaceAll(RegExp(r'PENDAF\s+TARAN', caseSensitive: false), 'PENDAFTARAN');
    final upperText = normalizedText.toUpperCase();

    // 1. Detect statutory keywords and regex patterns
    final matchedKeywords = <String>[];
    for (final kw in _statutoryKeywords) {
      if (upperText.contains(kw)) {
        matchedKeywords.add(kw);
      }
    }
    for (final reg in _statutoryRegexes) {
      final m = reg.firstMatch(upperText);
      if (m != null) {
        final matchedStr = m.group(0)!;
        if (!matchedKeywords.contains(matchedStr)) {
          matchedKeywords.add(matchedStr);
        }
      }
    }

    // 2. Extract registration numbers
    final modernMatch = _modernSsmPattern.firstMatch(upperText)?.group(0);
    final rawLegacy = _legacySsmPattern.firstMatch(upperText)?.group(0);
    final legacyMatch = rawLegacy?.replaceAll(RegExp(r'\s+'), '');

    String? formattedRegNumber;
    if (modernMatch != null && legacyMatch != null) {
      formattedRegNumber = '$modernMatch ($legacyMatch)';
    } else if (modernMatch != null) {
      formattedRegNumber = modernMatch;
    } else if (legacyMatch != null) {
      formattedRegNumber = legacyMatch;
    }

    // 3. Extract expiration date
    DateTime? expiryDate;
    bool isExpired = false;

    final expiryIndicators = [
      'TARIKH LUPUT',
      'EXPIRY DATE',
      'SEHINGGA',
      'TEMPOH PERAKUAN',
      'VALID UNTIL',
    ];

    for (final indicator in expiryIndicators) {
      final index = upperText.indexOf(indicator);
      if (index != -1) {
        final snippet = upperText.substring(
          index,
          (index + 80).clamp(0, upperText.length),
        );
        final dateMatch = _datePattern.firstMatch(snippet);
        if (dateMatch != null) {
          final day = int.tryParse(dateMatch.group(1) ?? '');
          final month = int.tryParse(dateMatch.group(2) ?? '');
          final year = int.tryParse(dateMatch.group(3) ?? '');
          if (day != null && month != null && year != null) {
            try {
              expiryDate = DateTime(year, month, day);
              isExpired = expiryDate.isBefore(now);
              break;
            } catch (_) {}
          }
        }
      }
    }

    // 4. Extract business name and match similarity
    String? extractedName;
    double nameMatchScore = 0.0;

    final nameIndicators = [
      'NAMA PERNIAGAAN',
      'NAMA SYARIKAT',
      'BUSINESS NAME',
      'COMPANY NAME',
    ];

    for (final indicator in nameIndicators) {
      final index = upperText.indexOf(indicator);
      if (index != -1) {
        final after = text.substring(
          (index + indicator.length).clamp(0, text.length),
        );
        final lines = after.split(RegExp(r'[\r\n]+'));
        for (final line in lines) {
          final clean = line
              .replaceAll(RegExp(r'^[\s\:\-]+'), '')
              .replaceAll(RegExp(r'[\s\:\-]+$'), '')
              .trim();
          if (clean.length > 3 && !clean.contains('ALAMAT')) {
            extractedName = clean;
            break;
          }
        }
        if (extractedName != null) break;
      }
    }

    if (userEnteredBusinessName != null &&
        userEnteredBusinessName.trim().isNotEmpty) {
      final target = extractedName ?? text;
      nameMatchScore = calculateBusinessNameSimilarity(
        userEnteredBusinessName,
        target,
      );
    }

    // 5. Calculate Authenticity & Verification Confidence Score
    double score = 0.0;

    // Header score (up to 0.40)
    if (matchedKeywords.isNotEmpty) {
      final headerRatio = (matchedKeywords.length / 3).clamp(0.0, 1.0);
      score += headerRatio * 0.40;
    }

    // Registration number score (up to 0.30)
    if (modernMatch != null && legacyMatch != null) {
      score += 0.30;
    } else if (modernMatch != null || legacyMatch != null) {
      score += 0.30;
    }

    // Business name match (up to 0.20)
    if (userEnteredBusinessName != null) {
      score += (nameMatchScore * 0.20);
    } else if (extractedName != null) {
      score += 0.15;
    }

    // License expiry score (up to 0.10)
    if (expiryDate != null && !isExpired) {
      score += 0.10;
    }

    final isAuthentic = matchedKeywords.isNotEmpty || modernMatch != null || legacyMatch != null;

    final isSampleOrDemo = upperText.contains('CONTOH') ||
        upperText.contains('SPECIMEN') ||
        upperText.contains('SAMPLE') ||
        upperText.contains('DEMO') ||
        upperText.contains('TEST');

    final String status;
    final String explanation;

    if (isExpired && !isSampleOrDemo) {
      status = 'rejected';
      explanation =
          'SSM registration expired on ${_formatDate(expiryDate)}. Please renew your license with SSM.';
    } else if (score >= 0.55 && formattedRegNumber != null) {
      status = 'verified';
      explanation = isSampleOrDemo
          ? 'Sample / Demo Malaysian SSM certificate authenticated for prototype testing.'
          : 'Official Malaysian SSM certificate authenticated. Business is verified active.';
    } else if (isAuthentic && formattedRegNumber != null) {
      status = 'pending_review';
      explanation =
          'SSM registration number detected ($formattedRegNumber). Ready to apply to business profile.';
    } else {
      status = 'rejected';
      explanation =
          'Could not detect an official Malaysian SSM certificate header or valid registration number.';
    }

    return SsmAnalysisResult(
      isAuthenticSsm: isAuthentic,
      status: status,
      statusExplanation: explanation,
      confidenceScore: (score * 100).roundToDouble() / 100,
      modernRegistrationNumber: modernMatch,
      legacyRegistrationNumber: legacyMatch,
      formattedRegistrationNumber: formattedRegNumber,
      extractedBusinessName: extractedName,
      businessNameMatchScore: nameMatchScore,
      expiryDate: expiryDate,
      isExpired: isExpired,
      matchedKeywords: matchedKeywords,
      rawText: text,
    );
  }

  /// Calculates normalized business name similarity stripping common Malaysian suffixes
  static double calculateBusinessNameSimilarity(String name1, String name2) {
    final clean1 = _normalizeBusinessName(name1);
    final clean2 = _normalizeBusinessName(name2);

    if (clean1.isEmpty || clean2.isEmpty) return 0.0;
    if (clean1 == clean2) return 1.0;
    if (clean2.contains(clean1) || clean1.contains(clean2)) return 0.90;

    final tokens1 = clean1.split(' ').where((t) => t.length > 1).toSet();
    final tokens2 = clean2.split(' ').where((t) => t.length > 1).toSet();

    if (tokens1.isEmpty || tokens2.isEmpty) return 0.0;
    final intersection = tokens1.intersection(tokens2).length;
    final union = tokens1.union(tokens2).length;
    return intersection / union;
  }

  static String _normalizeBusinessName(String name) {
    var s = name.toLowerCase();
    // Strip common Malaysian business entity suffixes
    final suffixes = [
      'sdn. bhd.',
      'sdn bhd',
      'bhd.',
      'bhd',
      'enterprise',
      'trading',
      'services',
      'syarikat',
      'perniagaan',
      'restoran',
      'cafe',
      'plh',
    ];
    for (final suf in suffixes) {
      s = s.replaceAll(suf, '');
    }
    return s.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
  }

  static String _formatDate(DateTime? dt) {
    if (dt == null) return 'Unknown';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}

/// Official SSM Verified shield badge
class SsmVerifiedBadge extends StatelessWidget {
  const SsmVerifiedBadge({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: LqColors.greenSoft,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified, size: 12, color: Color(0xFF42723B)),
            SizedBox(width: 4),
            Text(
              'SSM VERIFIED',
              style: TextStyle(
                color: Color(0xFF42723B),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: LqColors.greenSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB7E4A8)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 16, color: Color(0xFF42723B)),
          SizedBox(width: 6),
          Text(
            'SSM Verified Merchant',
            style: TextStyle(
              color: Color(0xFF42723B),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
