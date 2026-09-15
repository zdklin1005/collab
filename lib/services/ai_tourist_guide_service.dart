import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/localquest_models.dart';
import 'reward_proximity.dart';

/// Simple multi-turn chat message representation for Gemini conversation history
class AiChatMessageHistory {
  const AiChatMessageHistory({
    this.isUser = true,
    this.role,
    required this.text,
    this.time,
  });

  final bool isUser;
  final String? role;
  final String text;
  final DateTime? time;

  bool get effectiveIsUser => role != null ? (role == 'user') : isUser;
}

/// Context-aware AI Tourist Assistant powered by Google Gemini API
/// with a comprehensive local Penang Knowledge & Recommendation Engine.
class AiTouristGuideService {
  AiTouristGuideService({
    this.apiKey,
    http.Client? httpClient,
  }) : _client = httpClient ?? http.Client();

  final String? apiKey;
  final http.Client _client;

  static const String userProvidedApiKey = '';
  static const String firebaseApiKey = '';

  static const String defaultApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: userProvidedApiKey,
  );

  static const List<String> defaultApiKeys = [
    userProvidedApiKey,
    firebaseApiKey,
  ];

  static const List<String> defaultFallbackModels = [
    // Active Gemini 3.x Flash models (as listed in AI Studio)
    'gemini-3.8-flash',
    'gemini-3.7-flash',
    'gemini-3.6-flash',
    'gemini-3.5-flash',
    'gemini-3.5-flash-lite',
    'gemini-3.1-flash-lite',
    'gemini-3-flash',
    // Active Gemini 2.5 Flash models
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    // Gemini 2.0 series
    'gemini-2.0-flash',
    'gemini-2.0-flash-lite',
    // Pro series
    'gemini-3.1-pro',
    'gemini-2.5-pro',
    // Legacy fallback series
    'gemini-1.5-flash',
    'gemini-1.5-flash-8b',
    'gemini-1.5-pro',
  ];

  static const String _prefGeminiKey = 'custom_gemini_api_key';

  List<String>? _discoveredModels;
  final Set<String> _rateLimitedModels = {};
  final Set<String> _failedModels = {};
  String? lastSuccessfulModel;

  Set<String> get rateLimitedModels => Set.unmodifiable(_rateLimitedModels);
  Set<String> get failedModels => Set.unmodifiable(_failedModels);
  List<String> get discoveredModels =>
      List.unmodifiable(_discoveredModels ?? defaultFallbackModels);

  /// Clears tracked rate limit and failure states to re-try fresh
  void resetRateLimits() {
    _rateLimitedModels.clear();
    _failedModels.clear();
  }

  /// Utility to prioritize Gemini models:
  /// 1. Higher versions first (3.8 > 3.1 > 3.0 > 2.5 > 2.0 > 1.5 > 1.0)
  /// 2. Flash models before Lite models before Pro models before other models
  static int compareGeminiModels(String a, String b) {
    double extractVersion(String m) {
      final match = RegExp(r'gemini-(\d+(?:\.\d+)?)').firstMatch(m);
      if (match != null) {
        return double.tryParse(match.group(1) ?? '0') ?? 0.0;
      }
      return 0.0;
    }

    int tier(String m) {
      final lower = m.toLowerCase();
      // Tier 1: Main Flash models (fastest, high RPD/RPM)
      if (lower.contains('flash') &&
          !lower.contains('lite') &&
          !lower.contains('8b')) {
        return 1;
      }
      // Tier 2: Lightweight Flash models
      if (lower.contains('lite') || lower.contains('8b')) {
        return 2;
      }
      // Tier 3: Pro models (deeper reasoning)
      if (lower.contains('pro')) {
        return 3;
      }
      // Tier 4: Other conversational / experimental models
      return 4;
    }

    final tierA = tier(a);
    final tierB = tier(b);
    if (tierA != tierB) {
      return tierA.compareTo(tierB);
    }

    final verA = extractVersion(a);
    final verB = extractVersion(b);
    if (verA != verB) {
      // Higher version descending
      return verB.compareTo(verA);
    }

    return a.compareTo(b);
  }

  /// Fetches all available Gemini models for [apiKey] that support text generation.
  Future<List<String>> fetchAvailableModels({String? apiKey}) async {
    final key = apiKey ?? await getEffectiveApiKey();
    if (key == null || key.isEmpty) return defaultFallbackModels;

    try {
      final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$key');
      final response = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = data['models'] as List<dynamic>?;
        if (list != null && list.isNotEmpty) {
          final found = <String>[];
          for (final item in list) {
            if (item is Map<String, dynamic>) {
              final rawName = item['name'] as String? ?? '';
              final name = rawName.replaceFirst('models/', '');
              final methods = (item['supportedGenerationMethods'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ?? [];
              if (methods.contains('generateContent') &&
                  !name.contains('embedding') &&
                  !name.contains('aqa') &&
                  !name.contains('imagen')) {
                found.add(name);
              }
            }
          }
          if (found.isNotEmpty) {
            found.sort(compareGeminiModels);
            _discoveredModels = found;
            return found;
          }
        }
      }
    } catch (_) {}
    return defaultFallbackModels;
  }

  /// Save custom Gemini API key entered by user
  Future<void> saveCustomApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefGeminiKey, key.trim());
    _discoveredModels = null;
    _rateLimitedModels.clear();
    _failedModels.clear();
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

  /// Detects Penang geographic zone and transit advice from GPS coordinates
  static ({String detectedRegion, String regionalTransitTip}) detectPenangRegion(double userLat, double userLng) {
    // Penang Mainland (Seberang Perai, Permatang Pauh, Butterworth, Bukit Mertajam, Batu Kawan)
    // Longitude >= 100.36 is east of the Penang Strait (Mainland Peninsula Malaysia)
    if (userLng >= 100.36 && userLat >= 5.10 && userLat <= 5.65) {
      String specificRegion = 'Seberang Perai / Permatang Pauh (Mainland)';
      if (userLat >= 5.34 && userLat <= 5.44 && userLng >= 100.37 && userLng <= 100.46) {
        specificRegion = 'Seberang Perai / Permatang Pauh (Mainland)';
      } else if (userLat >= 5.38 && userLat <= 5.46 && userLng >= 100.35 && userLng <= 100.41) {
        specificRegion = 'Butterworth (Penang Mainland)';
      } else if (userLat >= 5.28 && userLat <= 5.38 && userLng >= 100.42 && userLng <= 100.56) {
        specificRegion = 'Bukit Mertajam (Penang Mainland)';
      } else if (userLat < 5.30) {
        specificRegion = 'Batu Kawan & Simpang Ampat (Penang Mainland)';
      } else if (userLat > 5.46) {
        specificRegion = 'Kepala Batas (Penang Mainland)';
      }

      return (
        detectedRegion: specificRegion,
        regionalTransitTip:
            '• Note: The tourist is currently on the PENANG MAINLAND in $specificRegion, which is approximately 15 to 25 km away from George Town across the Penang Strait. '
            'If they ask where they are, state clearly that they are in $specificRegion on the mainland, NOT in George Town or on Penang Island! '
            'For local dining right here on the mainland, recommend Sunway Carnival, Raja Uda street food (Tom Yum noodles, Apollo morning market), or BM yam rice. '
            'If they ask about island heritage / George Town sights, explicitly explain how to cross: '
            'via Penang Bridge (15-20 min drive) or the iconic Penang Fast Ferry from Butterworth to Swettenham Pier (10-15 mins)!',
      );
    } else if (userLat >= 5.40 && userLat <= 5.43 && userLng >= 100.31 && userLng <= 100.35) {
      return (
        detectedRegion: 'George Town UNESCO World Heritage Zone',
        regionalTransitTip:
            '• Note: The tourist is in the heart of George Town UNESCO heritage zone. '
            'Walking distance to Beach Street, Campbell Street, Chulia Street, and Armenian Street murals.',
      );
    } else if (userLat >= 5.45 && userLat <= 5.48 && userLng >= 100.23 && userLng <= 100.29) {
      return (
        detectedRegion: 'Batu Ferringhi & Teluk Bahang (Northern Coast)',
        regionalTransitTip:
            '• Note: The tourist is along the scenic northern beach strip. Close to Batu Ferringhi night market, batik craft workshops, and Escape Theme Park.',
      );
    } else if (userLat >= 5.38 && userLat <= 5.42 && userLng >= 100.26 && userLng <= 100.30) {
      return (
        detectedRegion: 'Air Itam & Penang Hill',
        regionalTransitTip:
            '• Note: The tourist is near Kek Lok Si Temple and Penang Hill funicular station. Highlight Air Itam Sister Curry Mee and market Asam Laksa.',
      );
    } else if (userLat >= 5.42 && userLat <= 5.45 && userLng >= 100.30 && userLng <= 100.33) {
      return (
        detectedRegion: 'Gurney Drive & Pulau Tikus',
        regionalTransitTip:
            '• Note: The tourist is along the northern coastal boulevard. Renowned for seaside hawkers, Gurney Plaza, and Pulau Tikus market.',
      );
    } else if (userLat >= 5.28 && userLat <= 5.35 && userLng >= 100.25 && userLng <= 100.32) {
      return (
        detectedRegion: 'Bayan Lepas & Queensbay (Southern Penang)',
        regionalTransitTip:
            '• Note: The tourist is in southern Penang near Queensbay Mall and the Penang International Airport.',
      );
    }
    return (
      detectedRegion: 'Penang, Malaysia',
      regionalTransitTip: '',
    );
  }

  /// Formats a complete, grounded system instruction incorporating user profile,
  /// visited places history, regional geographic context, and nearby businesses.
  static String buildSystemPrompt({
    required double userLat,
    required double userLng,
    required List<Business> nearbyBusinesses,
    required List<Campaign> activeVouchers,
    AppUser? userProfile,
    List<dynamic>? visitedPlacesHistory,
  }) {
    final region = detectPenangRegion(userLat, userLng);
    final detectedRegion = region.detectedRegion;
    final regionalTransitTip = region.regionalTransitTip;

    // User profile personalization
    final userName = userProfile?.displayName.trim().isNotEmpty == true
        ? userProfile!.displayName
        : 'Traveler';
    final userLevel = userProfile != null ? 'Level ${userProfile.level}' : 'Level 1 Explorer';
    final userVouchers = userProfile?.voucherCount ?? 0;
    final userDietary = userProfile?.preferences['dietary'] ??
        userProfile?.preferences['dietaryPreference'] ??
        'No restrictions (All authentic food)';

    // Visited places history summary
    final visitedSummary = (visitedPlacesHistory != null && visitedPlacesHistory.isNotEmpty)
        ? visitedPlacesHistory.map((v) {
            if (v is Map) {
              final name = v['name'] ?? 'Place';
              final area = v['area'] ?? '';
              final time = v['time'] ?? '';
              return '• $name ($area)${time.isNotEmpty ? " visited at $time" : ""}';
            }
            try {
              final dynamic dyn = v;
              final name = dyn.name ?? 'Place';
              final area = dyn.area ?? '';
              return '• $name ($area)';
            } catch (_) {
              return '• ${v.toString()}';
            }
          }).join('\n')
        : 'No locations visited yet today (first stop of the day!).';

    // 1. Sort businesses by proximity to user's coordinates
    final sortedBusinesses = List<Business>.from(nearbyBusinesses);
    sortedBusinesses.sort((a, b) {
      final distA = RewardProximity.distanceMeters(
        userLatitude: userLat,
        userLongitude: userLng,
        rewardLatitude: a.latitude ?? 0.0,
        rewardLongitude: b.longitude ?? 0.0,
      );
      final distB = RewardProximity.distanceMeters(
        userLatitude: userLat,
        userLongitude: userLng,
        rewardLatitude: b.latitude ?? 0.0,
        rewardLongitude: b.longitude ?? 0.0,
      );
      return distA.compareTo(distB);
    });

    // 2. Select the closest shops AND all shops with active Welcome Vouchers
    final selectedBiz = <Business>[];
    for (final b in sortedBusinesses.take(4)) {
      if (!selectedBiz.any((x) => x.id == b.id)) selectedBiz.add(b);
    }
    for (final b in sortedBusinesses) {
      if (activeVouchers.any((v) => v.businessId == b.id && (v.isWelcomeVoucher || v.voucherType.toLowerCase().contains('welcome')))) {
        if (!selectedBiz.any((x) => x.id == b.id)) selectedBiz.add(b);
      }
    }
    final contextList = selectedBiz.take(12).toList();

    final businessesContext = contextList.map((b) {
      final distMeters = RewardProximity.distanceMeters(
        userLatitude: userLat,
        userLongitude: userLng,
        rewardLatitude: b.latitude ?? 0.0,
        rewardLongitude: b.longitude ?? 0.0,
      ).round();
      final distStr = distMeters < 1000
          ? '${distMeters}m away'
          : '${(distMeters / 1000).toStringAsFixed(1)}km away';

      final bizVouchers = activeVouchers.where((v) => v.businessId == b.id).toList();
      final voucherSummaries = bizVouchers.map((v) {
        final isWelcome = v.isWelcomeVoucher || v.voucherType.toLowerCase().contains('welcome');
        final typeLabel = isWelcome ? '🎁 1-Time Welcome Gift' : '🏷️ Discount Promo';
        final claimGuide = v.collectionMethod == 'discovery_claim'
            ? 'Claim in app upon arrival inside shop'
            : 'Walk up to location on interactive map';
        return '• ${v.name} ($typeLabel - $claimGuide)';
      }).join('\n    ');

      final dietaryStr = b.dietaryStatus != null && b.dietaryStatus!.isNotEmpty
          ? ' [Dietary: ${b.dietaryStatus}]'
          : '';

      return '📍 ${b.name} (${b.category})$dietaryStr\n  Location: ${b.address} (${b.area}, ${b.state}) - $distStr\n  Available Rewards:\n    ${voucherSummaries.isEmpty ? "No active vouchers currently" : voucherSummaries}';
    }).join('\n\n');

    return '''
You are LocalQuest AI, an authentic Penang, Malaysia local tour guide and culinary expert built directly into the LocalQuest travel app.
Your mission is to provide deeply knowledgeable, personalized, context-aware advice to tourists exploring Penang and Seberang Perai.

TOURIST PROFILE & STATE:
• Name: $userName
• Explorer Status: $userLevel ($userVouchers vouchers claimed in passport)
• Dietary Preferences: $userDietary
• Current Region: $detectedRegion
$regionalTransitTip

VISITED PLACES & LOCATION HISTORY (VISITED TODAY):
$visitedSummary

VERIFIED LOCALQUEST PENANG PARTNER ESTABLISHMENTS & REAL-TIME REWARDS:
$businessesContext

CORE GROUNDING & PERSONALIZATION RULES:
1. ALWAYS ANSWER DIRECTLY in the very first sentence without preamble or generic travel-brochure clichés.
2. AWARENESS OF VISITED PLACES:
   - If the tourist has already visited a place today (e.g. Quadrant in Permatang Pauh), warmly acknowledge it ("Since you already checked out Quadrant...") and recommend what they should discover NEXT.
   - Do not recommend that they visit a shop they just came from unless they specifically ask about it.
3. REGIONAL & TRANSIT CONTEXT:
   - If the tourist is on the Mainland (Permatang Pauh / Seberang Perai) and asks for nearby food, give mainland recommendations.
   - If they ask for island food or heritage from the mainland, clearly mention how to cross the Penang Bridge (15-20 min drive) or take the iconic Butterworth-George Town fast ferry (10-15 mins)!
4. WELCOME VOUCHERS & DISCOUNTS:
   - When asked where/how to get welcome vouchers or deals, IMMEDIATELY name the exact partner shops with active vouchers from the list above (e.g. ChinaHouse, Toh Soon Kopitiam, Hameediyah, Batu Ferringhi Batik).
   - Detail the exact reward name, distance from tourist, and whether to claim inside the shop upon arrival or on the map.
5. FOOD & LOCAL PENANG EXPERTISE:
   - Recommend authentic Penang institutions and signature dishes (Char Koay Teow with duck egg, spicy sour Assam Laksa with hae ko, Nasi Kandar kuah campur banjir, Teochew Chendul, kaya toast with half-boiled eggs).
   - Respect the user's dietary preferences (highlight Halal / Pork-Free certification when applicable).
6. CLEAN MOBILE FORMATTING & ZERO TECHNICAL JARGON:
   - Do NOT use markdown asterisks (*, **, ***) or backticks (`).
   - NEVER mention raw GPS coordinates (such as numbers like 5.4141, 100.3288, latitude, or longitude) or technical developer terms in your response. Always speak naturally using place names, heritage zones, and local landmarks.
   - Use clean bullet points (• ) and line breaks.
   - Use friendly emojis (🎁, ☕, 🍜, 📍, 🏷️, 🚗, ⛴️).
7. ACCURATE LOCATION IDENTIFICATION:
   - When the user asks "Where am I?", "Where am I right now?", or asks about their current location, answer directly in the first sentence: "You are currently in $detectedRegion."
   - If the tourist is in Seberang Perai / Mainland, explicitly state that they are on the PENANG MAINLAND, NOT on Penang Island or in George Town, and note that George Town is roughly 15 to 25 km away across the Penang Strait.
''';
  }

  /// Generates context-aware travel recommendations by grounding the response
  /// in the tourist's current location, nearby Penang establishments, active vouchers,
  /// user profile preferences, visited places history, and multi-turn conversation memory.
  Future<String> askGuide({
    required String userPrompt,
    required double userLat,
    required double userLng,
    required List<Business> nearbyBusinesses,
    required List<Campaign> activeVouchers,
    AppUser? userProfile,
    List<dynamic>? visitedPlacesHistory,
    List<AiChatMessageHistory>? conversationHistory,
  }) async {
    final effectiveKey = await getEffectiveApiKey();
    final keysToTry = <String>[
      if (effectiveKey != null && effectiveKey.isNotEmpty) effectiveKey,
      for (final k in defaultApiKeys)
        if (k != effectiveKey) k,
    ];

    // If a valid Gemini API key is configured, query Google Gemini
    if (keysToTry.isNotEmpty) {
      final systemInstruction = buildSystemPrompt(
        userLat: userLat,
        userLng: userLng,
        nearbyBusinesses: nearbyBusinesses,
        activeVouchers: activeVouchers,
        userProfile: userProfile,
        visitedPlacesHistory: visitedPlacesHistory,
      );

      // Build multi-turn contents list for Gemini API
      final contents = <Map<String, dynamic>>[];

      if (conversationHistory != null && conversationHistory.isNotEmpty) {
        final recentHistory = conversationHistory.length > 6
            ? conversationHistory.sublist(conversationHistory.length - 6)
            : conversationHistory;

        for (final msg in recentHistory) {
          if (msg.text.trim().isNotEmpty) {
            contents.add({
              'role': msg.effectiveIsUser ? 'user' : 'model',
              'parts': [
                {'text': msg.text.trim()}
              ],
            });
          }
        }
      }

      // Add current turn
      contents.add({
        'role': 'user',
        'parts': [
          {
            'text': contents.isEmpty
                ? '$systemInstruction\n\nUser Question: $userPrompt'
                : userPrompt.trim()
          }
        ],
      });

      for (final currentKey in keysToTry) {
        final models = _discoveredModels ?? await fetchAvailableModels(apiKey: currentKey);
        final orderedModels = [
          ...models.where((m) => !_rateLimitedModels.contains(m) && !_failedModels.contains(m)),
          ...models.where((m) => _rateLimitedModels.contains(m)),
          ...models.where((m) => _failedModels.contains(m)),
        ];

        bool keyInvalid = false;

        for (final model in orderedModels) {
          try {
            final uri = Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$currentKey',
            );

            // Construct payload with system_instruction
            final payload = {
              'system_instruction': {
                'parts': [
                  {'text': systemInstruction}
                ],
              },
              'contents': contents,
              'generationConfig': {
                'temperature': 0.7,
                'maxOutputTokens': 1500,
              },
            };

            final response = await _client.post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'X-goog-api-key': currentKey,
              },
              body: jsonEncode(payload),
            ).timeout(const Duration(seconds: 10));

            if (response.statusCode == 200) {
              _rateLimitedModels.remove(model);
              _failedModels.remove(model);
              lastSuccessfulModel = model;
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
                    return sanitizeTechnicalInformation(cleaned);
                  }
                }
              }
            } else if (response.statusCode == 429) {
              // Model reached daily RPD (Requests Per Day) or RPM quota on AI Studio!
              // Mark model as rate-limited and seamlessly fall over to the next Gemini model
              _rateLimitedModels.add(model);
              continue;
            } else if (response.statusCode == 400 &&
                (response.body.contains('API_KEY_INVALID') ||
                    response.body.contains('not valid') ||
                    response.body.contains('expired'))) {
              keyInvalid = true;
              break;
            } else if (response.statusCode == 404 ||
                response.statusCode == 400 ||
                response.statusCode == 403) {
              // Model not found or not enabled on this API key project
              _failedModels.add(model);
              continue;
            } else {
              // 500, 502, 503 (server overloaded) or temporary error
              _rateLimitedModels.add(model);
              continue;
            }
          } catch (_) {
            // Timeout or connection error - continue to next available model
            continue;
          }
        }

        if (!keyInvalid) {
          break;
        }
      }
    }

    final region = detectPenangRegion(userLat, userLng);

    // Intelligent Penang Local Knowledge & Recommendation Engine
    return sanitizeTechnicalInformation(
      _generateLocalContextRecommendation(
        userPrompt: userPrompt,
        userLat: userLat,
        userLng: userLng,
        nearbyBusinesses: nearbyBusinesses,
        activeVouchers: activeVouchers,
        userProfile: userProfile,
        visitedPlacesHistory: visitedPlacesHistory,
        detectedRegion: region.detectedRegion,
        regionalTransitTip: region.regionalTransitTip,
      ),
    );
  }

  /// Strips raw GPS coordinates, decimal coordinate pairs, and developer jargon
  /// so AI output remains friendly, accessible, and free of overly technical details.
  static String sanitizeTechnicalInformation(String raw) {
    var text = raw;
    // Strip "(near coordinates X, Y)" or "(coordinates: X, Y)" or "(near X, Y)"
    text = text.replaceAll(
      RegExp(r'\s*\((?:near\s+)?(?:coordinates?|gps)?\s*[:=]?\s*[-+]?\d*\.?\d+\s*,\s*[-+]?\d*\.?\d+\s*\)', caseSensitive: false),
      '',
    );
    // Strip any other coordinate patterns like "(near coordinates ...)"
    text = text.replaceAll(
      RegExp(r'\s*\((?:near\s+)?coordinates\s*[^)]+\)', caseSensitive: false),
      '',
    );
    // Strip standalone coordinate brackets e.g. "(5.3959, 100.4054)" or "5.3959, 100.4054"
    text = text.replaceAll(
      RegExp(r'\(?\b[0-9]{1,2}\.[0-9]{3,},\s*[0-9]{2,3}\.[0-9]{3,}\b\)?'),
      '',
    );
    // Strip explicit latitude / longitude labels and values
    text = text.replaceAll(
      RegExp(r'\b(?:lat(?:itude)?|lng|long(?:itude)?)\s*[:=]?\s*[-+]?\d*\.?\d+\b', caseSensitive: false),
      '',
    );
    // Clean up leftover empty parentheses and double spaces
    text = text.replaceAll(RegExp(r'\(\s*\)'), '');
    text = text.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    return text.trim();
  }

  /// High-quality, context-aware Penang tour recommendation engine
  /// tailored specifically to the user's question, location, and verified merchants.
  String _generateLocalContextRecommendation({
    required String userPrompt,
    required double userLat,
    required double userLng,
    required List<Business> nearbyBusinesses,
    required List<Campaign> activeVouchers,
    AppUser? userProfile,
    List<dynamic>? visitedPlacesHistory,
    String? detectedRegion,
    String? regionalTransitTip,
  }) {
    final query = userPrompt.toLowerCase();

    // 0. LOCATION IDENTIFICATION QUERY ("Where am I?", "My location", etc.)
    if (query.contains('where am i') ||
        query.contains('where i am') ||
        query.contains('my location') ||
        query.contains('where are we') ||
        query.contains('current location') ||
        query.contains('dimana saya')) {
      final isMainland = userLng >= 100.36 && userLat >= 5.10 && userLat <= 5.65;
      final mainlandNote = isMainland
          ? 'You are on the PENANG MAINLAND in Seberang Perai, approximately 15 to 25 km from George Town across the Penang Strait. To visit Penang Island, you can cross via the Penang Bridge (15-20 min drive) or the Butterworth Fast Ferry.\n\n'
          : '';
      return '📍 You are currently in $detectedRegion.\n\n'
          '$mainlandNote'
          'Explore nearby local spots or let me know what you are looking for (food, kopitiam, or vouchers)!'
          '${regionalTransitTip != null && regionalTransitTip.isNotEmpty ? "\n\n🗺️ Transit Tip:\n$regionalTransitTip" : ""}';
    }

    // 1. VOUCHERS, DISCOUNTS, PROMOTIONS, WELCOME GIFTS
    if (query.contains('voucher') ||
        query.contains('discount') ||
        query.contains('promo') ||
        query.contains('coupon') ||
        query.contains('deal') ||
        query.contains('free') ||
        query.contains('claim') ||
        query.contains('save') ||
        query.contains('offer') ||
        query.contains('welcome')) {
      if (activeVouchers.isEmpty) {
        return 'Selamat Datang to Penang! 🎁 Currently, local merchants are preparing their seasonal deals.\n\n'
            '• Welcome Vouchers: Claimable 1-time in-app upon discovering a new partner shop!\n'
            '• Walk-Up Vouchers: Collected directly on the interactive map when you walk near the storefront.\n\n'
            'Explore Beach Street and Campbell Street in George Town to find participating partner cafes and shops!';
      }

      final voucherList = activeVouchers.take(5).map((v) {
        final biz = nearbyBusinesses.where((b) => b.id == v.businessId).firstOrNull;
        final bizName = biz?.name ?? 'Verified Partner';
        final isWelcome = v.isWelcomeVoucher;
        final typeTag = isWelcome
            ? '🎁 [WELCOME VOUCHER]'
            : (v.collectionMethod == 'walk_up_collect'
                ? '📍 [MAP WALK-UP]'
                : '🏷️ [PROMOTIONAL]');
        final claimTip = isWelcome
            ? 'Claim digitally inside the business profile!'
            : (v.collectionMethod == 'walk_up_collect'
                ? 'Collect via map GPS pin when standing near the shop.'
                : 'Claim in-app or redeem on-site.');
        return '• $typeTag ${v.name} by $bizName\n'
            '  Details: ${v.description.isNotEmpty ? v.description : "Special visitor offer"}\n'
            '  How to get: $claimTip';
      }).join('\n\n');

      return 'Selamat Datang to Penang! 🎁 Here are active LocalQuest vouchers and partner deals:\n\n'
          '$voucherList\n\n'
          '💡 Tip: Welcome Vouchers can be claimed right inside the shop screen upon discovery, while Walk-Up deals unlock as you explore on foot!';
    }

    // 2. BREAKFAST / KOPITIAM / TOAST / MORNING DINING
    if (query.contains('breakfast') ||
        query.contains('kopitiam') ||
        query.contains('kaya') ||
        query.contains('toast') ||
        query.contains('egg') ||
        query.contains('morning') ||
        query.contains('dim sum')) {
      final kopitiamBiz = nearbyBusinesses.where((b) =>
          b.name.toLowerCase().contains('kopitiam') ||
          b.name.toLowerCase().contains('soon') ||
          b.category.toLowerCase().contains('food') ||
          b.category.toLowerCase().contains('cafe')).firstOrNull;

      final bizSnippet = kopitiamBiz != null
          ? '\n\n📍 Partner Breakfast Spot:\n• ${kopitiamBiz.name} (${kopitiamBiz.address})\n${_formatVoucherSnippet(kopitiamBiz.id, activeVouchers)}'
          : '';

      return 'Selamat Datang to Penang! ☕ Here are the most legendary Penang morning breakfast spots:\n\n'
          '• Toh Soon Cafe (Campbell Street Alley) — Iconic narrow back-alley kopitiam grilling charcoal-toasted Hainan bread, homemade aromatic kaya, half-boiled kampung eggs, and thick Nanyang Robusta Kopi-O!\n\n'
          '• Roti Canai Transfer Road (Jalan Transfer) — Famous roadside stall serving flaky, crispy roti canai drenched in thick mutton or chicken curry since the 1970s.\n\n'
          '• Tai Tong Restaurant (Cintra Street) — Traditional push-cart dim sum parlor serving steaming siew mai, egg tarts, and har gow from 6:00 AM!'
          '$bizSnippet\n\n'
          '💡 Morning tip: Pair your charcoal kaya toast with a cup of hot Kopi Peng or Teh Tarik!';
    }

    // 3. PENANG LAKSA & NOODLES
    if (query.contains('laksa') ||
        query.contains('kway teow') ||
        query.contains('char koay') ||
        query.contains('ckt') ||
        query.contains('curry mee') ||
        query.contains('hokkien mee') ||
        query.contains('prawn mee') ||
        query.contains('har mee') ||
        query.contains('noodle')) {
      final noodleBiz = nearbyBusinesses.where((b) =>
          b.category.toLowerCase().contains('food') ||
          b.category.toLowerCase().contains('dining') ||
          b.name.toLowerCase().contains('laksa') ||
          b.name.toLowerCase().contains('noodle')).firstOrNull;

      final bizPart = noodleBiz != null
          ? '\n\n📍 Verified Partner Establishment:\n• ${noodleBiz.name} (${noodleBiz.address})\n${_formatVoucherSnippet(noodleBiz.id, activeVouchers)}'
          : '';

      return 'Selamat Datang to Penang! 🍜 Here are Penang\'s world-famous noodle institutions:\n\n'
          '• Penang Road Famous Laksa (Lebuh Keng Kwee) — Celebrated for its tangy, thick tamarind and mackerel broth garnished with fresh mint, pineapple, and dark pungent prawn paste (hae ko)!\n\n'
          '• Siam Road Charcoal Char Kway Teow — Legendarily fried over fiery charcoal embers with fresh duck egg, juicy cockles, lap cheong, and unmatched wok-hei aroma.\n\n'
          '• Air Itam Asam Laksa (Kek Lok Si Foot) — Rich and spicy mackerel broth bowl simmered for hours, operating since 1955.\n\n'
          '• Bridge Street Hokkien Mee (Lebuh Cyber) — Robust prawn stock noodle soup topped with pork slices, water spinach, and spicy chili paste.'
          '$bizPart\n\n'
          '💡 Pro tip: Request a duck egg (telur itik) for a richer, creamier wok-hei flavor on your Char Kway Teow!';
    }

    // 4. CENDOL, ICE & DESSERTS
    if (query.contains('cendol') ||
        query.contains('chendul') ||
        query.contains('dessert') ||
        query.contains('ais kacang') ||
        query.contains('ice cream') ||
        query.contains('sweet') ||
        query.contains('ice')) {
      final dessertBiz = nearbyBusinesses.where((b) =>
          b.name.toLowerCase().contains('chendul') ||
          b.name.toLowerCase().contains('chinahouse') ||
          b.category.toLowerCase().contains('food') ||
          b.category.toLowerCase().contains('cafe')).firstOrNull;

      final bizPart = dessertBiz != null
          ? '\n\n📍 Recommended Dessert Partner:\n• ${dessertBiz.name} (${dessertBiz.address})\n${_formatVoucherSnippet(dessertBiz.id, activeVouchers)}'
          : '';

      return 'Selamat Datang to Penang! 🍧 The best places to beat the tropical heat with legendary desserts:\n\n'
          '• Penang Road Famous Teochew Chendul (Lebuh Keng Kwee) — Operating since 1936! Handcrafted green pandan rice jelly noodles, shaved ice, creamy coconut milk, and fragrant caramelized Gula Melaka.\n\n'
          '• Swatow Lane Ais Kacang — Traditional shaved ice loaded with roasted crunchy peanuts, attap chee (palm fruit), red kidney beans, sweet corn, and ice cream.\n\n'
          '• ChinaHouse Bakery (Beach Street) — Penang\'s famous 30-cake counter display featuring artisanal tiramisu, salted caramel walnut brownies, and passionfruit pavlovas!'
          '$bizPart\n\n'
          'Enjoy your sweet heritage treat!';
    }

    // 5. CAFES, COFFEE, TEA & RELAXING SPOTS
    if (query.contains('cafe') ||
        query.contains('coffee') ||
        query.contains('tea') ||
        query.contains('latte') ||
        query.contains('espresso') ||
        query.contains('matcha') ||
        query.contains('cake') ||
        query.contains('bakery') ||
        query.contains('chill') ||
        query.contains('chinahouse')) {
      final cafeBiz = nearbyBusinesses.where((b) =>
          b.category.toLowerCase().contains('cafe') ||
          b.category.toLowerCase().contains('coffee') ||
          b.name.toLowerCase().contains('cafe') ||
          b.name.toLowerCase().contains('chinahouse')).firstOrNull ?? nearbyBusinesses.firstOrNull;

      final cafeSnippet = cafeBiz != null
          ? '\n\n📍 Verified Partner Cafe:\n• ${cafeBiz.name} at ${cafeBiz.address}\n${_formatVoucherSnippet(cafeBiz.id, activeVouchers)}'
          : '';

      return 'Selamat Datang to Penang! ☕ Top artisanal cafes in George Town\'s heritage quarter:\n\n'
          '• ChinaHouse Penang (Beach Street) — A 400-foot heritage compound connecting three historic shophouses, celebrated for specialty coffee, courtyards, live music, and a famous 30-cake counter!\n\n'
          '• Narrow Marrow (Carnarvon Street) — Cozy retro arts enclave known for sourdough toasts, specialty matcha, espresso, and fermented cheesecake.\n\n'
          '• Macallum Connoisseurs (Gat Lebuh Macallum) — Spacious rustic warehouse roastery serving craft single-origin pour-overs, nitro cold brew, and hearty brunch.'
          '$cafeSnippet\n\n'
          '💡 Tip: Stop by in the afternoon for coffee and check if the cafe has a 1-time Welcome Voucher!';
    }

    // 6. HALAL & MUSLIM-FRIENDLY DINING (NASI KANDAR, CURRY)
    if (query.contains('halal') ||
        query.contains('nasi kandar') ||
        query.contains('muslim') ||
        query.contains('pork free') ||
        query.contains('biryani') ||
        query.contains('briyani') ||
        query.contains('curry') ||
        query.contains('mamak') ||
        query.contains('hameediyah')) {
      final halalBiz = nearbyBusinesses.where((b) =>
          (b.dietaryStatus != null && b.dietaryStatus!.toLowerCase().contains('halal')) ||
          b.name.toLowerCase().contains('hameediyah') ||
          b.category.toLowerCase().contains('food')).firstOrNull;

      final bizSnippet = halalBiz != null
          ? '\n\n📍 Verified Muslim-Friendly Partner:\n• ${halalBiz.name} (${halalBiz.address})\n  Certification: ${halalBiz.dietaryStatus ?? "Halal / Muslim-Friendly"}\n${_formatVoucherSnippet(halalBiz.id, activeVouchers)}'
          : '';

      return 'Selamat Datang to Penang! 🍛 Authentic Halal & legendary Nasi Kandar institutions in Penang:\n\n'
          '• Hameediyah Restaurant (164A Campbell Street) — Established in 1907! The oldest Nasi Kandar restaurant in Malaysia, world-renowned for signature mutton mysore, beef rendang, and crispy murtabak.\n\n'
          '• Line Clear Nasi Kandar (Alleyway along Penang Road) — Open 24 hours with fragrant rice drenched in kuah campur banjir (mixed curries), giant spiced fried chicken, and squid.\n\n'
          '• Restoran Kapitan (Chulia Street) — Legendary for sizzling claypot butter chicken, garlic cheese naan, and fragrant Milani biryani.'
          '$bizSnippet\n\n'
          '💡 Pro tip: Always ask for "kuah campur banjir" (flooded mixed gravies) to get the true Penang flavor fusion!';
    }

    // 7. SOUVENIRS, ARTISAN CRAFTS, BATIK & SHOPPING
    if (query.contains('souvenir') ||
        query.contains('craft') ||
        query.contains('batik') ||
        query.contains('shopping') ||
        query.contains('gift') ||
        query.contains('artisan') ||
        query.contains('retail') ||
        query.contains('ferringhi')) {
      final craftBiz = nearbyBusinesses.where((b) =>
          b.category.toLowerCase().contains('retail') ||
          b.category.toLowerCase().contains('art') ||
          b.category.toLowerCase().contains('craft') ||
          b.name.toLowerCase().contains('batik')).firstOrNull;

      final craftSnippet = craftBiz != null
          ? '\n\n📍 Featured Artisan Partner:\n• ${craftBiz.name} (${craftBiz.address})\n${_formatVoucherSnippet(craftBiz.id, activeVouchers)}'
          : '';

      return 'Selamat Datang to Penang! 🛍️ Best spots for authentic handcrafted souvenirs & Penang gifts:\n\n'
          '• Batu Ferringhi Artisan Batik & Craft — Hand-drawn Malaysian silk batiks, traditional sarongs, and wooden heritage crafts along the scenic coast.\n\n'
          '• Armenian Street Heritage Workshops — Charming craft shophouses with pewter trinkets, hand-painted postcards, Peranakan beadwork, and local art prints.\n\n'
          '• Chowrasta Market (Jalan Penang) — Traditional market on the second floor with preserved nutmeg, Tambun biscuits (tau sar piah), and local spices.'
          '$craftSnippet\n\n'
          'Support local Penang artisans and take home a piece of heritage!';
    }

    // 8. NIGHT MARKETS, SUPPER & STREET HAWKERS
    if (query.contains('night') ||
        query.contains('supper') ||
        query.contains('dinner') ||
        query.contains('market') ||
        query.contains('pasar malam') ||
        query.contains('chulia') ||
        query.contains('kimberley') ||
        query.contains('gurney')) {
      return 'Selamat Datang to Penang! 🌙 Top Penang night street food hubs & evening supper spots:\n\n'
          '• Chulia Street Night Hawker Stalls — Bustling open-air evening row famous for wanton mee, curry mee, freshly pressed sugarcane juice, and satay.\n\n'
          '• Kimberley Street Food Night Market — Known as the "Four Heavenly Kings" street, renowned for duck kway chap, braised chicken feet, char kway teow, and almond dessert soup.\n\n'
          '• Gurney Drive Hawker Centre — Vibrant seafront open-air complex offering grilled stingray (ikan bakar), rojak, and oyster omelette with ocean breezes.\n\n'
          '💡 Evening tip: Most night stalls kick off around 6:00 PM and stay lively until late midnight!';
    }

    // 9. HERITAGE SITES, STREET ART, TEMPLES & SIGHTSEEING
    if (query.contains('art') ||
        query.contains('mural') ||
        query.contains('armenian') ||
        query.contains('street art') ||
        query.contains('heritage') ||
        query.contains('temple') ||
        query.contains('kek lok si') ||
        query.contains('penang hill') ||
        query.contains('funicular') ||
        query.contains('clan jetty') ||
        query.contains('museum') ||
        query.contains('sight') ||
        query.contains('attraction')) {
      final topBiz = nearbyBusinesses.firstOrNull;
      final bizSnippet = topBiz != null
          ? '\n\n📍 Partner Nearby Your Sightseeing Route:\n• ${topBiz.name} located at ${topBiz.address}\n${_formatVoucherSnippet(topBiz.id, activeVouchers)}'
          : '';

      return 'Selamat Datang to Penang! 🏛️ Here are iconic must-see cultural and heritage sights:\n\n'
          '• Armenian Street Murals (George Town) — Famous interactive murals by Ernest Zacharevic, including "Kids on Bicycle", "Boy on Motorcycle", and wire sculptures.\n\n'
          '• Clan Jetties (Weld Quay) — 19th-century Chinese waterfront villages built entirely on stilts over the sea, especially the vibrant Chew Jetty.\n\n'
          '• Kek Lok Si Temple (Air Itam) — Malaysia\'s grandest Buddhist temple complex, featuring the 7-tier Pagoda of 10,000 Buddhas and towering bronze Kuan Yin pavilion.\n\n'
          '• Penang Hill (Bukit Bendera) — Ride the historic Swiss funicular railway up to 833 meters for panoramic island views, canopy walks, and cooling breezes.'
          '$bizSnippet\n\n'
          'Enjoy exploring the UNESCO World Heritage site!';
    }

    final dynamic firstVisitedItem = (visitedPlacesHistory != null && visitedPlacesHistory.isNotEmpty)
        ? visitedPlacesHistory.first
        : null;
    final String? lastVisited = firstVisitedItem is Map
        ? firstVisitedItem['name'] as String?
        : (firstVisitedItem != null ? (firstVisitedItem as dynamic).name?.toString() : null);
    final String? lastArea = firstVisitedItem is Map
        ? firstVisitedItem['area'] as String?
        : (firstVisitedItem != null ? (firstVisitedItem as dynamic).area?.toString() : null);

    final visitedNote = (lastVisited != null && lastVisited.isNotEmpty)
        ? '📍 Since you recently stopped by $lastVisited${lastArea != null && lastArea.isNotEmpty ? " in $lastArea" : ""}, here are the best spots to explore next:\n\n'
        : '';

    final transitNote = (regionalTransitTip != null && regionalTransitTip.isNotEmpty)
        ? '\n\n🗺️ Regional Transit Info:\n$regionalTransitTip'
        : '';

    // 10. DYNAMIC PROXIMITY ("Near Me" / Coordinates / Closest Establishments)
    if (nearbyBusinesses.isNotEmpty) {
      // Sort businesses by distance from user's coordinates if valid
      final sortedBusinesses = List<Business>.from(nearbyBusinesses);
      if (userLat.isFinite && userLng.isFinite) {
        sortedBusinesses.sort((a, b) {
          if (a.latitude == null || a.longitude == null) return 1;
          if (b.latitude == null || b.longitude == null) return -1;
          final distA = RewardProximity.distanceMeters(
            userLatitude: userLat,
            userLongitude: userLng,
            rewardLatitude: a.latitude!,
            rewardLongitude: b.longitude!,
          );
          final distB = RewardProximity.distanceMeters(
            userLatitude: userLat,
            userLongitude: userLng,
            rewardLatitude: b.latitude!,
            rewardLongitude: b.longitude!,
          );
          return distA.compareTo(distB);
        });
      }

      final nearestBizList = sortedBusinesses.take(3).map((b) {
        String distanceStr = '';
        if (b.latitude != null && b.longitude != null && userLat.isFinite && userLng.isFinite) {
          final dist = RewardProximity.distanceMeters(
            userLatitude: userLat,
            userLongitude: userLng,
            rewardLatitude: b.latitude!,
            rewardLongitude: b.longitude!,
          );
          distanceStr = dist < 1000
              ? ' (~${dist.round()}m away)'
              : ' (~${(dist / 1000).toStringAsFixed(1)}km away)';
        }
        final vSnippet = _formatVoucherSnippet(b.id, activeVouchers);
        return '• ${b.name}$distanceStr\n'
            '  Category: ${b.category} | ${b.address}\n'
            '  $vSnippet';
      }).join('\n\n');

      return 'Selamat Datang to Penang! 📍 Based on your location in $detectedRegion:\n\n'
          '$visitedNote'
          '$nearestBizList\n\n'
          '💡 You can visit any partner shop to discover exclusive Welcome Vouchers and earn EXP!'
          '$transitNote';
    }

    // General default fallback
    return 'Selamat Datang to Penang, ${userProfile?.displayName ?? "Explorer"}! 🌺 You are currently exploring $detectedRegion.\n\n'
        '$visitedNote'
        '• Top Heritage Spots: Stroll through Beach Street and Campbell Street in the George Town UNESCO Heritage zone, or explore Penang Hill & Kek Lok Si.\n'
        '• Iconic Food: Savor authentic Penang Asam Laksa, Siam Road Char Kway Teow, and refreshing Teochew Chendul.\n'
        '• LocalQuest Rewards: Approach registered partner businesses to automatically record visits and claim Welcome Vouchers!'
        '$transitNote\n\n'
        'Feel free to ask me for recommendations on coffee, food, street art, or vouchers anytime!';
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
