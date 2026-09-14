import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collab/core/demo_database_seeder.dart';
import 'package:collab/models/localquest_models.dart';
import 'package:collab/screens/tourist_screens.dart';
import 'package:collab/services/ai_tourist_guide_service.dart';
import 'package:collab/services/localquest_services.dart';
import 'package:collab/services/location_service.dart';

import 'package:http/http.dart' as http;

class MockHttpClient extends http.BaseClient {
  MockHttpClient(this._handler);
  final Future<http.Response> Function(http.BaseRequest request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

Position createTestPosition({
  required double latitude,
  required double longitude,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime.now(),
    accuracy: 5.0,
    altitude: 10.0,
    altitudeAccuracy: 1.0,
    heading: 0.0,
    headingAccuracy: 0.0,
    speed: 0.0,
    speedAccuracy: 0.0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AI Tourist Guide Response Diversity & Grounding', () {
    late AiTouristGuideService service;
    late List<Business> sampleBusinesses;
    late List<Campaign> sampleVouchers;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = AiTouristGuideService();
      sampleBusinesses = DemoDatabaseSeeder.sampleMalaysianBusinesses
          .map((b) => b.toBusiness())
          .toList();
      sampleVouchers = DemoDatabaseSeeder.sampleMalaysianBusinesses
          .expand((b) => b.vouchers.map((v) => v.toCampaign(businessId: b.id)))
          .toList();
    });

    test('Answers varied queries with distinct, category-specific responses without repeating', () async {
      // 1. Voucher query (contains "Where", but must match voucher intent)
      final voucherResp = await service.askGuide(
        userPrompt: 'Where can I get Welcome Vouchers and discounts?',
        userLat: 5.4144,
        userLng: 100.3392,
        nearbyBusinesses: sampleBusinesses,
        activeVouchers: sampleVouchers,
      );
      expect(voucherResp, contains('Welcome Voucher'));
      expect(voucherResp, contains('How to get'));

      // 2. Breakfast query (contains "Where", but must match breakfast intent)
      final breakfastResp = await service.askGuide(
        userPrompt: 'Where is the best place for breakfast and kaya toast?',
        userLat: 5.4144,
        userLng: 100.3392,
        nearbyBusinesses: sampleBusinesses,
        activeVouchers: sampleVouchers,
      );
      expect(breakfastResp, contains('Toh Soon Cafe'));
      expect(breakfastResp, contains('charcoal'));
      expect(breakfastResp, isNot(equals(voucherResp)));

      // 3. Cafe & Coffee query (contains "Where", but must match cafe intent)
      final coffeeResp = await service.askGuide(
        userPrompt: 'Where can I find nice artisan coffee and cakes?',
        userLat: 5.4144,
        userLng: 100.3392,
        nearbyBusinesses: sampleBusinesses,
        activeVouchers: sampleVouchers,
      );
      expect(coffeeResp, contains('ChinaHouse'));
      expect(coffeeResp, contains('cake'));
      expect(coffeeResp, isNot(equals(voucherResp)));
      expect(coffeeResp, isNot(equals(breakfastResp)));

      // 4. Halal query
      final halalResp = await service.askGuide(
        userPrompt: 'Can you recommend Halal Nasi Kandar?',
        userLat: 5.4144,
        userLng: 100.3392,
        nearbyBusinesses: sampleBusinesses,
        activeVouchers: sampleVouchers,
      );
      expect(halalResp, contains('Hameediyah'));
      expect(halalResp, contains('1907'));
      expect(halalResp, isNot(equals(coffeeResp)));

      // 5. Laksa / Noodles query
      final laksaResp = await service.askGuide(
        userPrompt: 'Where can I eat authentic Penang Laksa?',
        userLat: 5.4144,
        userLng: 100.3392,
        nearbyBusinesses: sampleBusinesses,
        activeVouchers: sampleVouchers,
      );
      expect(laksaResp, contains('Penang Road Famous Laksa'));
      expect(laksaResp, isNot(equals(halalResp)));

      // 6. Souvenirs / Batik query
      final souvenirResp = await service.askGuide(
        userPrompt: 'Where to buy batik crafts and souvenirs?',
        userLat: 5.4144,
        userLng: 100.3392,
        nearbyBusinesses: sampleBusinesses,
        activeVouchers: sampleVouchers,
      );
      expect(souvenirResp, contains('Batik'));
      expect(souvenirResp, isNot(equals(laksaResp)));

      // 7. Night supper query
      final supperResp = await service.askGuide(
        userPrompt: 'Best street food market for supper tonight?',
        userLat: 5.4144,
        userLng: 100.3392,
        nearbyBusinesses: sampleBusinesses,
        activeVouchers: sampleVouchers,
      );
      expect(supperResp, contains('Chulia Street'));
      expect(supperResp, isNot(equals(souvenirResp)));

      // 8. Heritage murals query
      final heritageResp = await service.askGuide(
        userPrompt: 'Show me the famous street art murals',
        userLat: 5.4144,
        userLng: 100.3392,
        nearbyBusinesses: sampleBusinesses,
        activeVouchers: sampleVouchers,
      );
      expect(heritageResp, contains('Armenian Street Murals'));
      expect(heritageResp, isNot(equals(supperResp)));

      // Verify all 8 responses are completely distinct
      final responses = [
        voucherResp,
        breakfastResp,
        coffeeResp,
        halalResp,
        laksaResp,
        souvenirResp,
        supperResp,
        heritageResp,
      ];
      expect(responses.toSet().length, equals(8));
    });

    test('Custom API key can be saved and retrieved', () async {
      await service.saveCustomApiKey('AIzaSyTestKey123');
      final key = await service.getEffectiveApiKey();
      expect(key, equals('AIzaSyTestKey123'));
    });
  });

  group('Location Tracker Proximity & Simulation Tests', () {
    late LocationTrackerService tracker;
    late List<Map<String, dynamic>> loggedVisits;

    setUp(() {
      loggedVisits = [];
      tracker = LocationTrackerService();
      tracker.clearRecentVisits();

      UserRepository.instance.mockRecordVisit = ({
        required userId,
        required name,
        required area,
        businessId,
        visitedAt,
        latitude,
        longitude,
      }) async {
        loggedVisits.add({
          'userId': userId,
          'name': name,
          'area': area,
          'businessId': businessId,
          'visitedAt': visitedAt,
          'latitude': latitude,
          'longitude': longitude,
        });
        return true;
      };
    });

    tearDown(() {
      UserRepository.instance.mockRecordVisit = null;
    });

    test('getRegisteredBusinesses includes authentic Penang establishments by default', () async {
      final businesses = await tracker.getRegisteredBusinesses();
      expect(businesses.any((b) => b.id == 'demo_biz_chinahouse_penang'), isTrue);
      expect(businesses.any((b) => b.id == 'demo_biz_toh_soon_penang'), isTrue);
      expect(businesses.any((b) => b.id == 'demo_biz_hameediyah_penang'), isTrue);
    });

    test('simulateArrival records visit automatically without manual check-in', () async {
      final ok = await tracker.simulateArrival(
        businessId: 'demo_biz_chinahouse_penang',
        userId: 'tourist-user-42',
      );

      expect(ok, isTrue);
      expect(loggedVisits.length, equals(1));
      expect(loggedVisits.first['name'], contains('ChinaHouse'));
      expect(loggedVisits.first['userId'], equals('tourist-user-42'));
    });

    test('dwelling at same business prevents duplicate logs', () async {
      // First arrival
      final first = await tracker.simulateArrival(
        businessId: 'demo_biz_chinahouse_penang',
        userId: 'tourist-user-42',
      );
      expect(first, isTrue);
      expect(loggedVisits.length, equals(1));

      // Second ping while dwelling at ChinaHouse
      final second = await tracker.simulateArrival(
        businessId: 'demo_biz_chinahouse_penang',
        userId: 'tourist-user-42',
      );
      expect(second, isFalse);
      expect(loggedVisits.length, equals(1));
    });

    test('visiting multiple different Penang businesses logs each immediately', () async {
      // Visit 1: ChinaHouse
      final first = await tracker.simulateArrival(
        businessId: 'demo_biz_chinahouse_penang',
        userId: 'tourist-user-42',
      );
      expect(first, isTrue);

      // User walks over to Toh Soon Kopitiam
      final second = await tracker.simulateArrival(
        businessId: 'demo_biz_toh_soon_penang',
        userId: 'tourist-user-42',
      );
      expect(second, isTrue);

      // User walks over to Hameediyah Restaurant
      final third = await tracker.simulateArrival(
        businessId: 'demo_biz_hameediyah_penang',
        userId: 'tourist-user-42',
      );
      expect(third, isTrue);

      expect(loggedVisits.length, equals(3));
      expect(loggedVisits[0]['name'], contains('ChinaHouse'));
      expect(loggedVisits[1]['name'], contains('Toh Soon'));
      expect(loggedVisits[2]['name'], contains('Hameediyah'));
    });
  });

  group('VisitedPlacesScreen Widget Presentation Tests', () {
    setUp(() {
      UserRepository.instance.mockVisitedPlacesStream = (userId) => const Stream.empty();
    });

    tearDown(() {
      UserRepository.instance.mockVisitedPlacesStream = null;
    });

    testWidgets('Renders tracker card, popup menu, and clean state', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      LocationTrackerService.instance.isTrackingNotifier.value = true;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VisitedPlacesScreen(userId: 'test-user'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header and tracker status
      expect(find.text('Visited places'), findsOneWidget);
      // Clean interface without obtrusive tracker active card
      expect(find.text('Automatic Visit Tracking Active'), findsNothing);

      // Verify popup options menu exists
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    });

    test('compareGeminiModels prioritizes higher versions and Flash tier matching AI Studio dashboard', () {
      final models = [
        'gemini-2.5-pro',
        'gemini-3.1-pro',
        'gemini-3.5-flash-lite',
        'gemini-3.7-flash',
        'gemini-3.8-flash',
        'gemini-3.1-flash-lite',
        'gemini-3.6-flash',
        'gemini-3.5-flash',
        'gemini-2.5-flash',
        'gemini-2.5-flash-lite',
      ];

      models.sort(AiTouristGuideService.compareGeminiModels);

      expect(models, equals([
        'gemini-3.8-flash',
        'gemini-3.7-flash',
        'gemini-3.6-flash',
        'gemini-3.5-flash',
        'gemini-2.5-flash',
        'gemini-3.5-flash-lite',
        'gemini-3.1-flash-lite',
        'gemini-2.5-flash-lite',
        'gemini-3.1-pro',
        'gemini-2.5-pro',
      ]));
    });

    test('multi-model failover seamlessly switches model when gemini-3.8-flash hits 429 quota (RPD/RPM)', () async {
      // Mock client that returns 429 (quota exceeded e.g. 19/20 RPD) for gemini-3.8-flash,
      // 429 for gemini-3.7-flash, and succeeds 200 for gemini-3.6-flash
      var calls = <String>[];
      final mockClient = MockHttpClient((request) async {
        final url = request.url.toString();
        calls.add(url);
        if (url.contains('gemini-3.8-flash:generateContent')) {
          return http.Response(
            '{"error": {"code": 429, "message": "RESOURCE_EXHAUSTED: Quota exceeded for model gemini-3.8-flash (19/20 RPD reached)"}}',
            429,
          );
        } else if (url.contains('gemini-3.7-flash:generateContent')) {
          return http.Response(
            '{"error": {"code": 429, "message": "RESOURCE_EXHAUSTED: Quota exceeded for model gemini-3.7-flash"}}',
            429,
          );
        } else if (url.contains('gemini-3.6-flash:generateContent')) {
          return http.Response(
            '{"candidates": [{"content": {"parts": [{"text": "Welcome to George Town! Recommending ChinaHouse & Toh Soon Kopitiam."}]}}]}',
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final multiModelService = AiTouristGuideService(
        apiKey: 'test-fake-key',
        httpClient: mockClient,
      );

      final sampleBusinesses = DemoDatabaseSeeder.sampleMalaysianBusinesses
          .map((b) => b.toBusiness())
          .toList();
      final sampleVouchers = DemoDatabaseSeeder.sampleMalaysianBusinesses
          .expand((b) => b.vouchers.map((v) => v.toCampaign(businessId: b.id)))
          .toList();

      final resp = await multiModelService.askGuide(
        userPrompt: 'Where should I go for kopitiam and coffee?',
        userLat: 5.4144,
        userLng: 100.3392,
        nearbyBusinesses: sampleBusinesses,
        activeVouchers: sampleVouchers,
      );

      // Verify that gemini-3.8-flash and 3.7-flash were attempted and marked rate-limited
      expect(calls.any((c) => c.contains('gemini-3.8-flash:generateContent')), isTrue);
      expect(calls.any((c) => c.contains('gemini-3.7-flash:generateContent')), isTrue);
      expect(multiModelService.rateLimitedModels.contains('gemini-3.8-flash'), isTrue);
      expect(multiModelService.rateLimitedModels.contains('gemini-3.7-flash'), isTrue);

      // Verify seamless failover to gemini-3.6-flash (which has 8 requests remaining in AI Studio)
      expect(calls.any((c) => c.contains('gemini-3.6-flash:generateContent')), isTrue);
      expect(resp, contains('Welcome to George Town!'));
      expect(multiModelService.lastSuccessfulModel, equals('gemini-3.6-flash'));

      // Test resetRateLimits
      multiModelService.resetRateLimits();
      expect(multiModelService.rateLimitedModels, isEmpty);
      expect(multiModelService.failedModels, isEmpty);
    });
  });
}
