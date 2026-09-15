import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:collab/core/localquest_widgets.dart';
import 'package:collab/models/localquest_models.dart';
import 'package:collab/screens/leaderboard_screen.dart';
import 'package:collab/services/leaderboard_service.dart';

void main() {
  const currentUser = AppUser(
    id: 'user-me',
    email: 'me@example.com',
    displayName: 'Oscar Piastri',
    username: '@oscar81',
    role: AccountRole.tourist,
    level: 3,
    exp: 2450,
  );

  final mockGlobalUsers = [
    const LeaderboardEntry(
      userId: 'user-1',
      displayName: 'Lewis Hamilton',
      username: '@lh44',
      level: 5,
      exp: 5200,
      rank: 1,
    ),
    const LeaderboardEntry(
      userId: 'user-2',
      displayName: 'Max Verstappen',
      username: '@max1',
      level: 4,
      exp: 4800,
      rank: 2,
    ),
    const LeaderboardEntry(
      userId: 'user-3',
      displayName: 'Lando Norris',
      username: '@lando4',
      level: 4,
      exp: 3900,
      rank: 3,
    ),
    const LeaderboardEntry(
      userId: 'user-me',
      displayName: 'Oscar Piastri',
      username: '@oscar81',
      level: 3,
      exp: 2450,
      rank: 4,
      isCurrentUser: true,
    ),
    const LeaderboardEntry(
      userId: 'user-5',
      displayName: 'Charles Leclerc',
      username: '@charles16',
      level: 2,
      exp: 1800,
      rank: 5,
    ),
  ];

  final mockFriendsUsers = [
    const LeaderboardEntry(
      userId: 'user-me',
      displayName: 'Oscar Piastri',
      username: '@oscar81',
      level: 3,
      exp: 2450,
      rank: 1,
      isCurrentUser: true,
    ),
    const LeaderboardEntry(
      userId: 'user-friend-1',
      displayName: 'Kai Xian',
      username: '@jjkeunw',
      level: 2,
      exp: 1950,
      rank: 2,
    ),
  ];

  Widget testApp(Widget child) {
    return MaterialApp(
      theme: ThemeData(fontFamily: 'Plus Jakarta Sans'),
      home: child,
    );
  }

  setUp(() {
    LeaderboardService.instance.mockGlobalStream = ({int? limit, String? currentUserId}) {
      return Stream.value(mockGlobalUsers);
    };
    LeaderboardService.instance.mockFriendsStream = ({required currentUserId}) {
      return Stream.value(mockFriendsUsers);
    };
  });

  tearDown(() {
    LeaderboardService.instance.mockGlobalStream = null;
    LeaderboardService.instance.mockFriendsStream = null;
  });

  group('LeaderboardEntry Model', () {
    test('instantiates with expected properties', () {
      const entry = LeaderboardEntry(
        userId: 'u1',
        displayName: 'Test Explorer',
        username: '@test',
        level: 2,
        exp: 800,
        rank: 1,
        isCurrentUser: true,
      );

      expect(entry.userId, 'u1');
      expect(entry.displayName, 'Test Explorer');
      expect(entry.username, '@test');
      expect(entry.level, 2);
      expect(entry.exp, 800);
      expect(entry.rank, 1);
      expect(entry.isCurrentUser, isTrue);
    });

    test('copyWith updates specified fields', () {
      const entry = LeaderboardEntry(
        userId: 'u1',
        displayName: 'Test Explorer',
        username: '@test',
        level: 2,
        exp: 800,
        rank: 1,
      );

      final updated = entry.copyWith(rank: 5, isCurrentUser: true);
      expect(updated.rank, 5);
      expect(updated.isCurrentUser, isTrue);
      expect(updated.displayName, 'Test Explorer');
    });

    test('fromAppUser converts properly', () {
      final entry = LeaderboardEntry.fromAppUser(
        currentUser,
        rank: 3,
        currentUserId: currentUser.id,
      );

      expect(entry.userId, currentUser.id);
      expect(entry.displayName, currentUser.displayName);
      expect(entry.username, currentUser.username);
      expect(entry.level, currentUser.level);
      expect(entry.exp, currentUser.exp);
      expect(entry.rank, 3);
      expect(entry.isCurrentUser, isTrue);
    });
  });

  group('LeaderboardScreen Widget Tests', () {
    testWidgets('renders header, capsule tabs and global podium', (tester) async {
      await tester.pumpWidget(testApp(const LeaderboardScreen(currentUser: currentUser)));
      await tester.pumpAndSettle();

      expect(find.text('Leaderboard'), findsOneWidget);
      expect(find.byType(LqBackButton), findsOneWidget);
      expect(find.text('BACK'), findsOneWidget);
      expect(find.text('Global'), findsOneWidget);
      expect(find.text('Friends'), findsOneWidget);

      // Top 3 Podium in Global
      expect(find.text('Lewis Hamilton'), findsOneWidget);
      expect(find.text('Max Verstappen'), findsOneWidget);
      expect(find.text('Lando Norris'), findsOneWidget);

      // 4th place in list
      expect(find.text('Oscar Piastri'), findsWidgets); // on list and sticky bar
      expect(find.text('You'), findsWidgets);
      expect(find.text('Your Standing'), findsOneWidget);
    });

    testWidgets('switches to Friends tab and displays friends ranking', (tester) async {
      await tester.pumpWidget(testApp(const LeaderboardScreen(currentUser: currentUser)));
      await tester.pumpAndSettle();

      // Tap Friends tab
      await tester.tap(find.byKey(const Key('leaderboard_tab_friends')));
      await tester.pumpAndSettle();

      // Friends podium
      expect(find.text('Oscar Piastri'), findsWidgets);
      expect(find.text('Kai Xian'), findsOneWidget);
    });

    testWidgets('opens directly on Friends tab when initialTab is 1', (tester) async {
      await tester.pumpWidget(
        testApp(
          const LeaderboardScreen(
            currentUser: currentUser,
            initialTab: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kai Xian'), findsOneWidget);
    });

    testWidgets('renders empty state when leaderboard has no entries', (tester) async {
      LeaderboardService.instance.mockGlobalStream = ({int? limit, String? currentUserId}) {
        return Stream.value([]);
      };

      await tester.pumpWidget(testApp(const LeaderboardScreen(currentUser: currentUser)));
      await tester.pumpAndSettle();

      expect(find.text('No Leaderboard Data'), findsOneWidget);
    });

    testWidgets('header does not contain redundant trophy icon and podium avatar frame has rounded square border', (tester) async {
      await tester.pumpWidget(testApp(const LeaderboardScreen(currentUser: currentUser)));
      await tester.pumpAndSettle();

      // No redundant trophy icon in the header
      expect(find.byIcon(Icons.emoji_events_outlined), findsNothing);

      // Verify podium avatar frame container has a rounded rectangle border (BorderRadius)
      final containers = tester.widgetList<Container>(find.byType(Container));
      final podiumFrameContainers = containers.where((c) {
        final dec = c.decoration;
        return dec is BoxDecoration &&
            dec.borderRadius is BorderRadius &&
            dec.border != null;
      });
      expect(podiumFrameContainers.isNotEmpty, isTrue);
    });
  });
}
