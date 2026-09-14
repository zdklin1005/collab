import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:collab/core/demo_database_seeder.dart';
import 'package:collab/models/localquest_models.dart';
import 'package:collab/services/ai_tourist_guide_service.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AI Tourist Guide Deep Context & Grounding Tests', () {
    late List<Business> sampleBusinesses;
    late List<Campaign> sampleVouchers;

    setUp(() {
      sampleBusinesses = DemoDatabaseSeeder.sampleMalaysianBusinesses
          .map((b) => b.toBusiness())
          .toList();
      sampleVouchers = DemoDatabaseSeeder.sampleMalaysianBusinesses
          .expand((b) => b.vouchers.map((v) => v.toCampaign(businessId: b.id)))
          .toList();
    });

    test('buildSystemPrompt injects user profile, visited places, and regional transit info', () {
      const user = AppUser(
        id: 'kai-test-user',
        email: 'kai@localquest.test',
        displayName: 'Kai Explorer',
        username: '@kai',
        role: AccountRole.tourist,
        level: 5,
        exp: 450,
        preferences: {
          'dietary': ['Halal', 'Vegetarian'],
          'interests': ['Heritage', 'Local Coffee'],
        },
      );

      final visitedPlaces = [
        {
          'id': 'visit-1',
          'name': 'Quadrant',
          'area': 'Permatang Pauh',
          'businessId': 'biz-quadrant',
          'time': '10:30 AM',
          'latitude': 5.3912,
          'longitude': 100.4123,
        },
      ];

      // Tourist is at Permatang Pauh (Mainland Penang)
      final systemPrompt = AiTouristGuideService.buildSystemPrompt(
        userLat: 5.3912,
        userLng: 100.4123,
        nearbyBusinesses: sampleBusinesses,
        activeVouchers: sampleVouchers,
        userProfile: user,
        visitedPlacesHistory: visitedPlaces,
      );

      // Verify user profile grounding
      expect(systemPrompt, contains('Kai Explorer'));
      expect(systemPrompt, contains('Level 5'));
      expect(systemPrompt, contains('Halal'));
      expect(systemPrompt, contains('Vegetarian'));

      // Verify visited places history grounding (User was at Quadrant!)
      expect(systemPrompt, contains('Quadrant'));
      expect(systemPrompt, contains('Permatang Pauh'));
      expect(systemPrompt, contains('VISITED PLACES & LOCATION HISTORY'));

      // Verify regional awareness (Mainland / Seberang Perai transit tip)
      expect(systemPrompt, contains('Seberang Perai / Permatang Pauh (Mainland)'));
      expect(systemPrompt, contains('Penang Bridge'));
      expect(systemPrompt, contains('Fast Ferry'));

      // Verify registered partner businesses and vouchers are injected
      expect(systemPrompt, contains('Toh Soon Cafe'));
      expect(systemPrompt, contains('ChinaHouse'));
      expect(systemPrompt, contains('1-Time Welcome Gift'));
    });

    test('askGuide sends multi-turn chat history in Gemini API payload', () async {
      String? sentRequestBody;

      final mockClient = MockHttpClient((request) async {
        if (request is http.Request) {
          sentRequestBody = request.body;
        }
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text':
                          'Since you recently checked out Quadrant in Permatang Pauh, if you cross the Penang Bridge into George Town, you should stop by ChinaHouse or Toh Soon Kopitiam!'
                    }
                  ]
                }
              }
            ]
          }),
          200,
        );
      });

      final service = AiTouristGuideService(
        apiKey: 'test-api-key',
        httpClient: mockClient,
      );

      final conversationHistory = [
        const AiChatMessageHistory(
          role: 'user',
          text: 'Hi, where am I right now?',
        ),
        const AiChatMessageHistory(
          role: 'model',
          text: 'You are currently in Permatang Pauh on the Penang mainland!',
        ),
      ];

      final response = await service.askGuide(
        userPrompt: 'Where should I explore next and can I get a voucher?',
        userLat: 5.3912,
        userLng: 100.4123,
        nearbyBusinesses: sampleBusinesses,
        activeVouchers: sampleVouchers,
        conversationHistory: conversationHistory,
        visitedPlacesHistory: [
          {
            'id': 'visit-1',
            'name': 'Quadrant',
            'area': 'Permatang Pauh',
            'time': '10:30 AM',
          },
        ],
      );

      expect(response, contains('Quadrant'));
      expect(response, contains('George Town'));

      // Verify the JSON payload sent to Gemini API
      expect(sentRequestBody, isNotNull);
      final decoded = jsonDecode(sentRequestBody!) as Map<String, dynamic>;

      // Check system instruction
      expect(decoded.containsKey('system_instruction'), isTrue);
      final systemInstructionText =
          decoded['system_instruction']['parts'][0]['text'] as String;
      expect(systemInstructionText, contains('Quadrant'));
      expect(systemInstructionText, contains('Seberang Perai / Permatang Pauh (Mainland)'));

      // Check multi-turn contents
      final contents = decoded['contents'] as List<dynamic>;
      expect(contents.length, equals(3)); // 2 from history + 1 current prompt

      expect(contents[0]['role'], equals('user'));
      expect(contents[0]['parts'][0]['text'], equals('Hi, where am I right now?'));

      expect(contents[1]['role'], equals('model'));
      expect(contents[1]['parts'][0]['text'], equals('You are currently in Permatang Pauh on the Penang mainland!'));

      expect(contents[2]['role'], equals('user'));
      expect(contents[2]['parts'][0]['text'], equals('Where should I explore next and can I get a voucher?'));
    });

    test('offline fallback recommendation reflects visited places and mainland location', () async {
      // Mock client that fails to simulate offline mode
      final mockClient = MockHttpClient((request) async {
        return http.Response('Network timeout', 500);
      });

      final offlineService = AiTouristGuideService(
        apiKey: 'test-api-key',
        httpClient: mockClient,
      );

      final visited = [
        {
          'id': 'v1',
          'name': 'Quadrant',
          'area': 'Permatang Pauh',
          'time': '10:30 AM',
        },
      ];

      final offlineResp = await offlineService.askGuide(
        userPrompt: 'Where should I go after Quadrant?',
        userLat: 5.3912,
        userLng: 100.4123,
        nearbyBusinesses: sampleBusinesses,
        activeVouchers: sampleVouchers,
        visitedPlacesHistory: visited,
      );

      // Offline fallback should still acknowledge visited place and mainland transit
      expect(offlineResp, contains('Quadrant'));
      expect(offlineResp, contains('Permatang Pauh'));
      expect(offlineResp, contains('Penang Bridge'));
    });

    test('offline fallback location query tells user they are in mainland Seberang Perai', () async {
      final mockClient = MockHttpClient((request) async {
        return http.Response('Network timeout', 500);
      });

      final service = AiTouristGuideService(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      final resp = await service.askGuide(
        userPrompt: 'Where am I now?',
        userLat: 5.3912,
        userLng: 100.4123,
        nearbyBusinesses: sampleBusinesses,
        activeVouchers: sampleVouchers,
      );

      expect(resp, contains('Seberang Perai / Permatang Pauh (Mainland)'));
      expect(resp, contains('PENANG MAINLAND'));
      expect(resp, contains('Penang Bridge'));
    });
  });
}
