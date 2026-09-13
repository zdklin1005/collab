import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/localquest_models.dart';

/// Context-aware AI Tourist Assistant powered by Google Gemini API
/// with a comprehensive local Penang Knowledge & Recommendation Engine.
class AiTouristGuideService {
  AiTouristGuideService({
    this.apiKey,
    http.Client? httpClient,
  }) : _client = httpClient ?? http.Client();

  final String? apiKey;
  final http.Client _client;

  static const String defaultApiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  static const List<String> _geminiModels = [
    'gemini-3.8-flash',
    'gemini-3.6-flash',
    'gemini-flash-latest',
  ];

  static const String _prefGeminiKey = 'custom_gemini_api_key';

  /// Save custom Gemini API key entered by user
  Future<void> saveCustomApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefGeminiKey, key.trim());
  }

  /// Get current Gemini API key (from SharedPreferences, constructor, or default)
  Future<String?> getEffectiveApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefGeminiKey);
      if (saved != null && saved.trim().isNotEmpty) {
        return saved.trim();
      }
    } catch (_) {
      // In headless unit tests or before platform init
    }

    if (apiKey != null && apiKey!.trim().isNotEmpty) {
      return apiKey!.trim();
    }

    if (defaultApiKey.trim().isNotEmpty) {
      return defaultApiKey.trim();
    }

    return null;
  }

  /// Generates context-aware travel recommendations by grounding the response
  /// in the tourist's current location, nearby Penang establishments, and active vouchers.
  Future<String> askGuide({
    required String userPrompt,
    required double userLat,
    required double userLng,
    required List<Business> nearbyBusinesses,
    required List<Campaign> activeVouchers,
  }) async {
    final effectiveKey = await getEffectiveApiKey();

    // If a valid Gemini API key is configured, query Google Gemini
    if (effectiveKey != null && effectiveKey.isNotEmpty) {
      final businessesContext = nearbyBusinesses.take(6).map((b) {
        final bizVouchers = activeVouchers.where((v) => v.businessId == b.id).toList();
        final voucherSummaries = bizVouchers.map((v) =>
          '${v.name} [Type: ${v.voucherType.toUpperCase()}, Method: ${v.collectionMethod}]'
        ).join(', ');

        return '- ${b.name} (${b.category}) at ${b.address} (${b.area}, ${b.state}). Vouchers: ${voucherSummaries.isEmpty ? "None" : voucherSummaries}';
      }).join('\n');

      final systemInstruction = '''
You are LocalQuest AI, an authentic Penang, Malaysia local tour guide and culinary expert.
Help tourists discover authentic heritage spots, street food, and artisan craft shops in Penang.
Always prioritize recommending the user's nearby shops and highlight available LocalQuest vouchers:
- Welcome Vouchers (1-time instant discovery gift)
- Promotional Vouchers (discount campaigns)
- Seasonal Vouchers (tied to Penang heritage festivals and national holidays)

Tourist Current Coordinates: ($userLat, $userLng) in Penang, Malaysia.
Verified LocalQuest Penang Establishments & Active Vouchers:
$businessesContext

CRITICAL FORMATTING RULES:
- Do NOT use markdown asterisks (*, **, ***) or backticks (`).
- Use the bullet character (• ) and clean line breaks for lists.
- Highlight titles and shop names with clean text and friendly emojis (e.g. 🎁, 🏷️, ☕, 🍜, 📍) rather than bold asterisks.
''';

      for (final model in _geminiModels) {
        try {
          final uri = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$effectiveKey',
          );
          final response = await _client.post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-goog-api-key': effectiveKey,
            },
            body: jsonEncode({
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': '$systemInstruction\n\nUser Question: $userPrompt'},
                  ],
                },
              ],
              'generationConfig': {
                'temperature': 0.7,
                'maxOutputTokens': 1500,
              },
            }),
          ).timeout(const Duration(seconds: 12));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            final candidates = data['candidates'] as List<dynamic>?;
            if (candidates != null && candidates.isNotEmpty) {
              final content = candidates[0]['content'] as Map<String, dynamic>?;
              final parts = content?['parts'] as List<dynamic>?;
              if (parts != null && parts.isNotEmpty) {
                final textParts = parts
                    .map((p) => p is Map ? (p['text'] as String?) : null)
                    .where((t) => t != null && t.trim().isNotEmpty)
                    .toList();
                if (textParts.isNotEmpty) {
                  // Format text for crisp mobile display
                  final cleaned = textParts
                      .join('\n\n')
                      .replaceAll('**', '')
                      .replaceAll('* ', '• ')
                      .trim();
                  return cleaned;
                }
              }
            }
          }
        } catch (_) {
          // Fall back to next model or local engine
        }
      }
    }

    // Intelligent Penang Local Knowledge & Recommendation Engine
    return _generateLocalContextRecommendation(
      userPrompt: userPrompt,
      userLat: userLat,
      userLng: userLng,
      nearbyBusinesses: nearbyBusinesses,
      activeVouchers: activeVouchers,
    );
  }

  /// High-quality, context-aware Penang tour recommendation engine
  /// tailored specifically to the user's question, location, and verified merchants.
  String _generateLocalContextRecommendation({
    required String userPrompt,
    required double userLat,
    required double userLng,
    required List<Business> nearbyBusinesses,
    required List<Campaign> activeVouchers,
  }) {
    final query = userPrompt.toLowerCase();

    // 1. Penang Laksa
    if (query.contains('laksa')) {
      final bizMatch = nearbyBusinesses.where((b) =>
          b.category.toLowerCase().contains('food') ||
          b.category.toLowerCase().contains('dining') ||
          b.category.toLowerCase().contains('cafe') ||
          b.name.toLowerCase().contains('laksa')).firstOrNull;

      final bizPart = bizMatch != null
          ? '\n\n📍 Nearby Verified LocalQuest Partner:\n• ${bizMatch.name} (${bizMatch.address})\n${_formatVoucherSnippet(bizMatch.id, activeVouchers)}'
          : '';

      return 'Selamat Datang to Penang! 🍜 Here are the most authentic Penang Asam Laksa spots:\n\n'
          '• Penang Road Famous Laksa (Jalan Penang) — Celebrated for its tangy, thick tamarind and mackerel broth garnished with fresh mint, pineapple, and pungent hae ko (prawn paste)!\n\n'
          '• Kim Laksa Balik Pulau — Scenic countryside stall famous for both authentic Asam Laksa and rich coconut-milk Siam Laksa.\n\n'
          '• Air Itam Asam Laksa — Located right at the base of Kek Lok Si Temple, serving traditional spicy and sour bowls since the 1950s!'
          '$bizPart\n\n'
          '💡 Tip: Always mix in a spoonful of dark shrimp paste (hae ko) for the signature Penang umami kick!';
    }

    // 2. Famous Places, Heritage, Sightseeing, Near Me
    if (query.contains('famous') ||
        query.contains('place') ||
        query.contains('attraction') ||
        query.contains('heritage') ||
        query.contains('visit') ||
        query.contains('sight') ||
        query.contains('where') ||
        query.contains('near me')) {

      // Match closest or best business from nearbyBusinesses
      final topBiz = nearbyBusinesses.firstOrNull;
      final bizSnippet = topBiz != null
          ? '\n\n🎁 Featured Local Partner Near You ($userLat, $userLng):\n'
              '• ${topBiz.name} located at ${topBiz.address} (${topBiz.category})\n'
              '${_formatVoucherSnippet(topBiz.id, activeVouchers)}'
          : '';

      return 'Selamat Datang to Penang! 🏛️ Here are the top iconic must-visit heritage spots in Penang:\n\n'
          '• George Town UNESCO Heritage zone along Beach Street and Campbell Street — Walk through vibrant street art murals on Armenian Street (e.g. "Kids on Bicycle") and colonial heritage shophouses.\n\n'
          '• Kek Lok Si Temple (Air Itam) — The largest Buddhist temple complex in Malaysia, featuring the 7-tier Pagoda of 10,000 Buddhas and the grand bronze Kuan Yin statue.\n\n'
          '• Penang Hill (Bukit Bendera) — Board the Swiss funicular railway up 833m for panoramic island views and breezy colonial hilltop trails.\n\n'
          '• Clan Jetties (Weld Quay) — Historic 19th-century Chinese waterfront villages built on wooden stilts over the sea, especially Chew Jetty.'
          '$bizSnippet\n\n'
          'Enjoy exploring the Pearl of the Orient!';
    }

    // 3. Char Kway Teow
    if (query.contains('kway teow') || query.contains('char koay') || query.contains('noodle')) {
      return 'Selamat Datang to Penang! 🥢 For the best Char Kway Teow in town:\n\n'
          '• Siam Road Charcoal Char Kway Teow — World-famous street vendor frying flat rice noodles over fiery charcoal with duck egg, cockles, lap cheong, and smoky wok-hei!\n\n'
          '• Lorong Selamat Char Kway Teow — Generous plate loaded with jumbo prawns and chili paste.\n\n'
          '• Ah Leng Char Kway Teow (Jalan Dato Keramat) — Popular local favorite with special mantis prawns option.'
          '\n\n💡 Pro tip: Request a duck egg (telur itik) for a richer, creamier wok-hei flavor!';
    }

    // 4. Cendol / Desserts
    if (query.contains('cendol') || query.contains('chendul') || query.contains('dessert') || query.contains('ice')) {
      return 'Selamat Datang to Penang! 🍧 Here is where to beat the tropical heat with legendary Penang desserts:\n\n'
          '• Penang Road Famous Teochew Chendul (Lebuh Keng Kwee) — Operating since 1936! Fresh pandan rice jelly noodles, shaved ice, creamy coconut milk, and fragrant caramelized Gula Melaka.\n\n'
          '• Swatow Lane Ais Kacang — Generously topped with roasted peanuts, attap chee (palm seeds), sweet corn, and ice cream scoop.\n\n'
          '• ChinaHouse Cakes (Beach Street) — Over 30 varieties of fresh daily artisanal cakes including tiramisu, walnut brownies, and salted caramel!';
    }

    // 5. Cafes & Coffee
    if (query.contains('cafe') || query.contains('coffee') || query.contains('campbell') || query.contains('tea')) {
      final cafeBiz = nearbyBusinesses.where((b) =>
          b.category.toLowerCase().contains('cafe') ||
          b.category.toLowerCase().contains('coffee')).firstOrNull ?? nearbyBusinesses.firstOrNull;

      final cafeSnippet = cafeBiz != null
          ? '\n\n📍 Verified Partner Cafe:\n• ${cafeBiz.name} at ${cafeBiz.address}\n'
              '${_formatVoucherSnippet(cafeBiz.id, activeVouchers)}'
          : '';

      return 'Selamat Datang to Penang! ☕ Best artisan cafes in George Town:\n\n'
          '• ChinaHouse Penang (Beach Street) — A 400-foot heritage compound connecting three shophouses, famous for artisanal coffee, live music, and legendary cake displays.\n\n'
          '• Narrow Marrow (Carnarvon St) — Cozy retro enclave known for sourdough toasts, specialty matcha, and espresso.\n\n'
          '• Macallum Connoisseurs (Gat Lebuh Macallum) — Spacious warehouse roastery serving craft single-origin pour-overs.'
          '$cafeSnippet';
    }

    // 6. Vouchers & Discounts
    if (query.contains('voucher') || query.contains('discount') || query.contains('promo') || query.contains('free')) {
      if (activeVouchers.isEmpty) {
        return 'Selamat Datang to Penang! 🎁 Currently, local merchants are preparing their seasonal deals. '
            'Explore the George Town UNESCO Heritage zone along Beach Street and Campbell Street to discover partner cafes with Welcome Vouchers!';
      }

      final voucherList = activeVouchers.take(4).map((v) {
        final biz = nearbyBusinesses.where((b) => b.id == v.businessId).firstOrNull;
        final bizName = biz?.name ?? 'Local Partner';
        final typeTag = v.isWelcomeVoucher ? '🎁 [WELCOME VOUCHER]' : '🏷️ [PROMO]';
        return '• $typeTag "${v.name}" by $bizName — ${v.description}';
      }).join('\n\n');

      return 'Selamat Datang to Penang! 🎁 Here are active LocalQuest vouchers available for you:\n\n'
          '$voucherList\n\n'
          'Claim your 1-time Welcome Vouchers to enjoy instant discounts when you visit partner shops!';
    }

    // General default recommendation
    if (nearbyBusinesses.isEmpty) {
      return 'Selamat Datang to Penang! You are currently exploring Penang ($userLat, $userLng). '
          'We recommend visiting the George Town UNESCO Heritage zone along Beach Street and Campbell Street. '
          'Seed Penang demo data in your merchant dashboard to see authentic shops with Welcome & Seasonal vouchers!';
    }

    // Best matching business
    final topBiz = nearbyBusinesses.first;
    return 'Selamat Datang to Penang! Based on your location ($userLat, $userLng), '
        'I highly recommend visiting **${topBiz.name}** located at ${topBiz.address}. '
        'They specialize in ${topBiz.category}.\n\n'
        '${_formatVoucherSnippet(topBiz.id, activeVouchers)}\n\n'
        'Explore Penang UNESCO Heritage Zone and enjoy your heritage adventure!';
  }

  String _formatVoucherSnippet(String businessId, List<Campaign> activeVouchers) {
    final bizVouchers = activeVouchers.where((v) => v.businessId == businessId).toList();
    final welcome = bizVouchers.where((v) => v.isWelcomeVoucher).firstOrNull;
    final promo = bizVouchers.where((v) => v.isPromotionalVoucher).firstOrNull;

    if (welcome != null) {
      return '🎁 Welcome Voucher: "${welcome.name}" (1-time discovery claim)!';
    }
    if (promo != null) {
      return '🏷️ Available Promo: "${promo.name}"!';
    }
    return 'Check their shop profile for the latest promotions.';
  }
}
