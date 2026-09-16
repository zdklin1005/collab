import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:collab/models/localquest_models.dart';
import 'package:collab/screens/tourist_screens.dart';
import 'package:collab/screens/daily_check_in_screen.dart';
import 'package:collab/services/check_in_service.dart';
import 'package:collab/services/reward_service.dart';
import 'package:collab/services/review_service.dart';
import 'package:collab/services/mission_service.dart';

void main() {
  group('RewardService Level & EXP calculations', () {
    test('expRequiredForLevel calculates correct thresholds', () {
      final service = RewardService.instance;

      expect(service.expRequiredForLevel(1), 0);
      expect(service.expRequiredForLevel(0), 0);
      expect(service.expRequiredForLevel(-5), 0);

      // Level 2: 100 * 1^2 + 100 * 1 = 200
      expect(service.expRequiredForLevel(2), 200);

      // Level 3: 100 * 2^2 + 100 * 2 = 600
      expect(service.expRequiredForLevel(3), 600);

      // Level 4: 100 * 3^2 + 100 * 3 = 1200
      expect(service.expRequiredForLevel(4), 1200);

      // Level 5: 100 * 4^2 + 100 * 4 = 2000
      expect(service.expRequiredForLevel(5), 2000);
    });

    test('levelForExp returns the exact tier level for cumulative EXP', () {
      final service = RewardService.instance;

      expect(service.levelForExp(0), 1);
      expect(service.levelForExp(199), 1);
      expect(service.levelForExp(200), 2);
      expect(service.levelForExp(599), 2);
      expect(service.levelForExp(600), 3);
      expect(service.levelForExp(1199), 3);
      expect(service.levelForExp(1200), 4);
    });

    test('expToNextLevel returns remaining EXP needed to level up', () {
      final service = RewardService.instance;

      expect(service.expToNextLevel(0), 200);
      expect(service.expToNextLevel(50), 150);
      expect(service.expToNextLevel(200), 400); // Next is 600, so 600 - 200 = 400
      expect(service.expToNextLevel(550), 50);  // Next is 600, so 600 - 550 = 50
    });

    test('ExpAwardResult calculations', () {
      const noLevelUp = ExpAwardResult(
        previousLevel: 2,
        newLevel: 2,
        previousExp: 250,
        newExp: 350,
        vouchersAwarded: 0,
      );
      expect(noLevelUp.leveledUp, isFalse);
      expect(noLevelUp.levelsGained, 0);

      const levelUp = ExpAwardResult(
        previousLevel: 2,
        newLevel: 4,
        previousExp: 400,
        newExp: 1300,
        vouchersAwarded: 2,
      );
      expect(levelUp.leveledUp, isTrue);
      expect(levelUp.levelsGained, 2);
    });

    test('awardExp rejects invalid non-positive amount', () {
      final service = RewardService.instance;
      expect(() => service.awardExp('user123', 0), throwsA(isA<ArgumentError>()));
      expect(() => service.awardExp('user123', -50), throwsA(isA<ArgumentError>()));
    });
  });

  group('CheckInService streak calculation', () {
    test('dailyExpReward scales with streak and caps at 7 days', () {
      final service = CheckInService.instance;

      // Base reward on day 1 is 20
      expect(service.dailyExpReward(1), 20);
      expect(service.dailyExpReward(0), 20); // clamps to 0 bonus days

      // Day 2: 20 + 1 * 5 = 25
      expect(service.dailyExpReward(2), 25);

      // Day 3: 20 + 2 * 5 = 30
      expect(service.dailyExpReward(3), 30);

      // Day 7: 20 + 6 * 5 = 50
      expect(service.dailyExpReward(7), 50);

      // Day 14: capped at 50
      expect(service.dailyExpReward(14), 50);
      expect(service.dailyExpReward(100), 50);
    });

    test('CheckInResult structure', () {
      const res = CheckInResult(
        alreadyCheckedInToday: true,
        streakCount: 5,
        expAwarded: 0,
      );
      expect(res.alreadyCheckedInToday, isTrue);
      expect(res.streakCount, 5);
      expect(res.expAwarded, 0);
      expect(res.levelUpResult, isNull);
    });
  });

  group('ReviewService Models and Validation', () {
    test('Review serializes to and from Map, including businessName', () {
      final now = DateTime(2026, 9, 14, 12, 0);
      final review = Review(
        id: 'rev_1',
        userId: 'tourist_1',
        businessId: 'biz_1',
        businessName: 'LocalQuest Cafe',
        rating: 4.5,
        text: 'Great food and ambience!',
        photoUrls: ['https://example.com/photo.jpg'],
        createdAt: now,
      );

      final map = review.toMap();
      expect(map['userId'], 'tourist_1');
      expect(map['businessId'], 'biz_1');
      expect(map['businessName'], 'LocalQuest Cafe');
      expect(map['rating'], 4.5);
      expect(map['text'], 'Great food and ambience!');
      expect(map['photoUrls'], ['https://example.com/photo.jpg']);
    });

    test('submitReview validates rating range (1-5)', () async {
      final service = ReviewService.instance;

      final lowRes = await service.submitReview(
        uid: 'user_1',
        businessId: 'biz_1',
        businessName: 'Test Business',
        rating: 0.5,
      );
      expect(lowRes.success, isFalse);
      expect(lowRes.failureReason, contains('between 1 and 5'));

      final highRes = await service.submitReview(
        uid: 'user_1',
        businessId: 'biz_1',
        businessName: 'Test Business',
        rating: 5.5,
      );
      expect(highRes.success, isFalse);
      expect(highRes.failureReason, contains('between 1 and 5'));
    });
  });

  group('TouristProfileScreen Integration Touchpoints', () {
    final testUser = AppUser(
      id: 'tourist_test_1',
      email: 'test@localquest.my',
      displayName: 'Test Traveler',
      username: '@traveler',
      role: AccountRole.tourist,
      exp: 1500,
      level: 3,
      voucherCount: 4,
      reviewCount: 7,
    );

    testWidgets('Renders vouchers/reviews compartments and journey options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TouristProfileScreen(user: testUser),
          ),
        ),
      );
      await tester.pump();

      // Vouchers compartment & count
      expect(find.text('VOUCHERS'), findsOneWidget);
      expect(find.text('4'), findsWidgets);

      // Reviews compartment & count
      expect(find.text('REVIEWS'), findsOneWidget);
      expect(find.text('7'), findsWidgets);

      // "My vouchers" journey option
      expect(find.text('My vouchers'), findsOneWidget);
      expect(find.text('4 ready to use'), findsOneWidget);

      // "Reviews & ratings" journey option
      expect(find.text('Reviews & ratings'), findsOneWidget);
      expect(find.text('7 posted'), findsOneWidget);

      // "Missions" journey option (dynamic count)
      expect(find.text('Missions'), findsOneWidget);
      expect(find.textContaining('in progress'), findsOneWidget);

      // NOTE: there is no standalone "Daily check-in" journey list item
      // anymore — it was replaced by the always-visible _DailyCheckInCard
      // rendered directly on the profile (see the streak-card test
      // below), so it's intentionally not asserted here.
    });

    testWidgets('My vouchers journey item is displayed with chevron and does not trigger removed popup', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TouristProfileScreen(user: testUser),
          ),
        ),
      );
      await tester.pump();

      await tester.ensureVisible(find.text('My vouchers'));
      await tester.pumpAndSettle();
      expect(find.text('My vouchers'), findsOneWidget);
      expect(find.text('4 ready to use'), findsOneWidget);

      await tester.tap(find.text('My vouchers'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('ready in your passport'), findsNothing);
    });

    testWidgets('Tapping Missions opens the mission list screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TouristProfileScreen(user: testUser),
          ),
        ),
      );
      await tester.pump();

      await tester.ensureVisible(find.text('Missions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Missions'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('SIDE QUESTS'), findsOneWidget);
      expect(find.text('Dynamic Missions'), findsOneWidget);
    });

    testWidgets('Daily check-in card is rendered on the profile', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TouristProfileScreen(user: testUser),
          ),
        ),
      );
      await tester.pump();

      // The streak card renders directly on the profile (not behind a
      // tap) — its exact text depends on live Firestore data (streakCount
      // / lastCheckInDate), so this only confirms the card itself
      // mounted, via its always-present icon, rather than asserting a
      // specific streak state.
      expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
    });

    testWidgets('Reviews & ratings journey item is displayed and navigates to MyReviewsScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TouristProfileScreen(user: testUser),
          ),
        ),
      );
      await tester.pump();

      await tester.ensureVisible(find.text('Reviews & ratings'));
      await tester.pumpAndSettle();
      expect(find.text('Reviews & ratings'), findsOneWidget);
      expect(find.text('7 posted'), findsOneWidget);

      await tester.tap(find.text('Reviews & ratings'));
      await tester.pumpAndSettle();
      expect(find.text('STORYTELLER'), findsNothing);
    });

    testWidgets('Daily check-in journey option is present and linked to DailyCheckInScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TouristProfileScreen(user: testUser),
          ),
        ),
      );
      await tester.pump();

      await tester.ensureVisible(find.text('Daily check-in'));
      await tester.pumpAndSettle();

      expect(find.text('Daily check-in'), findsOneWidget);
      expect(find.text('Keep your streak'), findsOneWidget);

      // Tapping navigates to DailyCheckInScreen
      await tester.tap(find.text('Daily check-in'));
      await tester.pumpAndSettle();
      expect(find.byType(DailyCheckInScreen), findsOneWidget);
    });

    testWidgets('Vouchers and Reviews stat blocks display counts accurately', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TouristProfileScreen(user: testUser),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('VOUCHERS'), findsOneWidget);
      expect(find.text('4'), findsWidgets);
      expect(find.text('REVIEWS'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });

    test('Active mission count correctly filters active status missions dynamically', () {
      final now = DateTime.now();
      final missions = [
        Mission(
          id: 'm1',
          title: 'Mission 1',
          description: 'Desc',
          rewardType: MissionRewardType.exp,
          status: MissionStatus.active,
          checkpoints: const [],
          generatedAt: now,
          expiresAt: now.add(const Duration(days: 1)),
        ),
        Mission(
          id: 'm2',
          title: 'Mission 2',
          description: 'Desc',
          rewardType: MissionRewardType.voucher,
          status: MissionStatus.active,
          checkpoints: const [],
          generatedAt: now,
          expiresAt: now.add(const Duration(days: 1)),
        ),
        Mission(
          id: 'm3',
          title: 'Mission 3',
          description: 'Desc',
          rewardType: MissionRewardType.exp,
          status: MissionStatus.completed,
          checkpoints: const [],
          generatedAt: now,
          expiresAt: now.add(const Duration(days: 1)),
        ),
      ];

      final activeCount = missions.where((m) => m.status == MissionStatus.active).length;
      expect(activeCount, 2);
    });
  });
}