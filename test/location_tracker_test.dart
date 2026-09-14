import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:collab/models/localquest_models.dart';
import 'package:collab/screens/tourist_screens.dart';
import 'package:collab/services/localquest_services.dart';
import 'package:collab/services/location_service.dart';

Widget testApp(Widget child) => MaterialApp(
  home: child,
);

Position createPosition({
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

  group('LocationTrackerService Automatic Business Proximity Tests', () {
    late LocationTrackerService service;
    late List<Map<String, dynamic>> recordedVisits;

    setUp(() {
      recordedVisits = [];
      service = LocationTrackerService();
      service.clearRecentVisits();

      // Configure UserRepository mock
      UserRepository.instance.mockRecordVisit = ({
        required userId,
        required name,
        required area,
        businessId,
        visitedAt,
        latitude,
        longitude,
      }) async {
        recordedVisits.add({
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

      // Configure mock registered businesses: 1 registered cafe, 1 registered artisan shop
      service.mockRegisteredBusinesses = [
        const Business(
          id: 'biz-heritage-cafe',
          ownerId: 'merchant-1',
          name: 'Penang Heritage Cafe',
          category: 'Food & Beverage',
          address: '12 Beach Street',
          phone: '0123456789',
          area: 'George Town',
          latitude: 5.4164,
          longitude: 100.3327,
        ),
        const Business(
          id: 'biz-artisan-crafts',
          ownerId: 'merchant-2',
          name: 'Penang Batik Workshop',
          category: 'Arts & Crafts',
          address: '45 Armenian Street',
          phone: '0198765432',
          area: 'George Town',
          latitude: 5.4148,
          longitude: 100.3377,
        ),
        const Business(
          id: 'biz-roastery-cafe',
          ownerId: 'merchant-3',
          name: 'Penang Hill Coffee Roasters',
          category: 'Cafe',
          address: '88 Campbell Street',
          phone: '0112233445',
          area: 'George Town',
          latitude: 5.4180,
          longitude: 100.3340,
        ),
      ];
    });

    test('starts and stops automatic vicinity tracking, updating isTrackingNotifier', () async {
      service.mockCheckPermission = () async => true;
      service.mockPositionStream = () => const Stream.empty();
      service.mockGetCurrentPosition = () async => createPosition(latitude: 5.4164, longitude: 100.3327);

      expect(service.isTracking, isFalse);

      final started = await service.startTracking(userId: 'test-tourist');
      expect(started, isTrue);
      expect(service.isTracking, isTrue);
      expect(service.isTrackingNotifier.value, isTrue);

      await service.stopTracking();
      expect(service.isTracking, isFalse);
      expect(service.isTrackingNotifier.value, isFalse);
    });

    test('automatically logs registered business when tourist is in vicinity (<= 75m)', () async {
      // Tourist is ~15m from Penang Heritage Cafe (5.4164, 100.3327)
      final touristPos = createPosition(latitude: 5.4165, longitude: 100.3328);

      final logged = await service.processPosition(touristPos, userId: 'tourist-1');
      expect(logged, isTrue);
      expect(recordedVisits.length, 1);
      expect(recordedVisits.first['name'], 'Penang Heritage Cafe');
      expect(recordedVisits.first['businessId'], 'biz-heritage-cafe');
      expect(recordedVisits.first['area'], 'George Town');
      expect(service.lastVisitedBusinessNotifier.value, 'Penang Heritage Cafe');
    });

    test('visiting multiple different businesses in a row logs each business immediately', () async {
      // 1. Visit Cafe A (Penang Heritage Cafe at 5.4164, 100.3327)
      final posA = createPosition(latitude: 5.4164, longitude: 100.3327);
      final loggedA = await service.processPosition(posA, userId: 'tourist-1');
      expect(loggedA, isTrue);
      expect(recordedVisits.length, 1);
      expect(recordedVisits[0]['name'], 'Penang Heritage Cafe');

      // 2. Walk to Artisan Workshop (Penang Batik Workshop at 5.4148, 100.3377) 10 minutes later
      final posB = createPosition(latitude: 5.4148, longitude: 100.3377);
      final loggedB = await service.processPosition(posB, userId: 'tourist-1');
      expect(loggedB, isTrue);
      expect(recordedVisits.length, 2);
      expect(recordedVisits[1]['name'], 'Penang Batik Workshop');

      // 3. Walk to Cafe B (Penang Hill Coffee Roasters at 5.4180, 100.3340) 15 minutes later
      final posC = createPosition(latitude: 5.4180, longitude: 100.3340);
      final loggedC = await service.processPosition(posC, userId: 'tourist-1');
      expect(loggedC, isTrue);
      expect(recordedVisits.length, 3);
      expect(recordedVisits[2]['name'], 'Penang Hill Coffee Roasters');
    });

    test('strictly does NOT log anything when no registered business is nearby', () async {
      // Tourist is at a random location with no registered business within 75m
      final randomPos = createPosition(latitude: 5.4600, longitude: 100.2800);

      final logged = await service.processPosition(randomPos, userId: 'tourist-1');
      expect(logged, isFalse);
      expect(recordedVisits.isEmpty, isTrue);
      expect(service.lastVisitedBusinessNotifier.value, isNull);
    });

    test('cooldown prevents duplicate visit logging while dwelling at same business', () async {
      final touristPos = createPosition(latitude: 5.4165, longitude: 100.3328);

      // First time entering vicinity logs automatically
      final first = await service.processPosition(touristPos, userId: 'tourist-1');
      expect(first, isTrue);
      expect(recordedVisits.length, 1);

      // Remaining at the business should not trigger duplicate entries
      final second = await service.processPosition(touristPos, userId: 'tourist-1');
      expect(second, isFalse);
      expect(recordedVisits.length, 1);
    });

    test('respects user privacy preference if locationHistory is disabled', () async {
      UserRepository.instance.mockRecordVisit = ({
        required userId,
        required name,
        required area,
        businessId,
        visitedAt,
        latitude,
        longitude,
      }) async => false; // User has locationHistory turned off

      final touristPos = createPosition(latitude: 5.4165, longitude: 100.3328);

      final logged = await service.processPosition(touristPos, userId: 'tourist-1');
      expect(logged, isFalse);
    });

    test('setLocationHistoryEnabled immediately pauses tracking and rejects vicinity checks', () async {
      final touristPos = createPosition(latitude: 5.4165, longitude: 100.3328);

      service.setLocationHistoryEnabled(false);
      expect(service.isLocationHistoryEnabled, isFalse);

      final logged = await service.processPosition(touristPos, userId: 'tourist-1');
      expect(logged, isFalse);

      final sim = await service.simulateArrival(
        businessId: 'biz-heritage-cafe',
        userId: 'tourist-1',
      );
      expect(sim, isFalse);

      service.setLocationHistoryEnabled(true);
      expect(service.isLocationHistoryEnabled, isTrue);

      final loggedAfter = await service.processPosition(touristPos, userId: 'tourist-1');
      expect(loggedAfter, isTrue);
    });
  });

  group('VisitedPlacesScreen Widget Tests', () {
    setUp(() {
      UserRepository.instance.mockVisitedPlacesStream = (uid) => const Stream.empty();
      LocationTrackerService.instance.clearRecentVisits();
      LocationTrackerService.instance.setLocationHistoryEnabled(true);
    });

    testWidgets('renders clean header, status card and empty state without manual check-in buttons', (tester) async {
      LocationTrackerService.instance.isTrackingNotifier.value = true;

      await tester.pumpWidget(testApp(const VisitedPlacesScreen(userId: 'tourist-1')));
      await tester.pumpAndSettle();

      // Clean header without manual check-in button or tracker active card
      expect(find.text('Visited places'), findsOneWidget);
      expect(find.byKey(const Key('visited_places_checkin_btn')), findsNothing);
      expect(find.byKey(const Key('visited_places_empty_checkin_btn')), findsNothing);
      expect(find.text('Check in'), findsNothing);
      expect(find.text('Automatic Visit Tracking Active'), findsNothing);
      expect(find.text('Location History Logging Paused'), findsNothing);

      // Empty state
      expect(find.text('No visited locations found.'), findsOneWidget);
      expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
    });

    testWidgets('SettingsScreen toggles Location history and updates LocationTrackerService', (tester) async {
      LocationTrackerService.instance.setLocationHistoryEnabled(true);

      var updatedKey = '';
      dynamic updatedVal;
      UserRepository.instance.mockUpdatePreference = (uid, key, val) async {
        updatedKey = key;
        updatedVal = val;
      };

      const user = AppUser(
        id: 'tourist-1',
        email: 'tourist@localquest.test',
        displayName: 'Penang Tourist',
        username: '@tourist',
        role: AccountRole.tourist,
        preferences: {'locationHistory': true},
      );

      await tester.pumpWidget(testApp(const SettingsScreen(user: user)));
      await tester.pumpAndSettle();

      expect(find.text('Location history'), findsOneWidget);
      expect(find.text('Automatic visit logging'), findsOneWidget);

      // Find the location history tile's switch
      final locationHistoryTile = find.ancestor(
        of: find.text('Location history'),
        matching: find.byType(ListTile),
      );
      final switchFinder = find.descendant(
        of: locationHistoryTile,
        matching: find.byType(Switch),
      );
      expect(switchFinder, findsOneWidget);

      // Toggle off
      await tester.ensureVisible(switchFinder);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(LocationTrackerService.instance.isLocationHistoryEnabled, isFalse);
      expect(updatedKey, 'locationHistory');
      expect(updatedVal, isFalse);
      expect(find.text('Location history paused: automatic visit logging turned off.'), findsOneWidget);
    });

    test('concurrent processPosition calls are locked and do not produce duplicate records', () async {
      final loggedVisits = <Map<String, dynamic>>[];
      UserRepository.instance.mockRecordVisit = ({
        required userId,
        required name,
        required area,
        businessId,
        visitedAt,
      }) async {
        // Simulate async database latency
        await Future.delayed(const Duration(milliseconds: 20));
        loggedVisits.add({
          'userId': userId,
          'name': name,
          'businessId': businessId,
        });
        return true;
      };

      final service = LocationTrackerService(userRepository: UserRepository.instance);
      service.clearRecentVisits();
      service.mockRegisteredBusinesses = [
        const Business(
          id: 'biz-quadrant',
          ownerId: 'owner-1',
          name: 'Quadrant',
          category: 'Cafe',
          address: 'Permatang Pauh',
          phone: '+60123456789',
          area: 'Permatang Pauh',
          latitude: 5.3900,
          longitude: 100.4100,
        ),
      ];

      final pos = createPosition(latitude: 5.3900, longitude: 100.4100);

      // Fire two concurrent calls as happens when stream and getCurrentPosition race
      final results = await Future.wait([
        service.processPosition(pos, userId: 'tourist-1'),
        service.processPosition(pos, userId: 'tourist-1'),
      ]);

      // Exactly one succeeds, the other is blocked by mutex or dwell lock!
      expect(results.where((r) => r == true).length, equals(1));
      expect(loggedVisits.length, equals(1));
      expect(loggedVisits.first['name'], 'Quadrant');
    });

    test('cleanDuplicateVisitedPlaces hook properly executes', () async {
      var cleanedUserId = '';
      UserRepository.instance.mockCleanDuplicateVisitedPlaces = (userId) async {
        cleanedUserId = userId;
        return 2;
      };

      final cleaned = await UserRepository.instance.cleanDuplicateVisitedPlaces('tourist-1');
      expect(cleaned, equals(2));
      expect(cleanedUserId, equals('tourist-1'));
    });
  });
}

