import 'dart:convert';
import 'package:collab/core/localquest_theme.dart';
import 'package:collab/data/mock_map_data.dart';
import 'package:collab/models/localquest_models.dart';
import 'package:collab/screens/ai_assistant_sheet.dart';
import 'package:collab/screens/direct_chat_screen.dart';
import 'package:collab/screens/friends_screen.dart';
import 'package:collab/screens/tourist_screens.dart';
import 'package:collab/services/ai_tourist_guide_service.dart';
import 'package:collab/services/direct_chat_service.dart';
import 'package:collab/services/in_app_notification_service.dart';
import 'package:collab/services/localquest_services.dart';
import 'package:collab/services/social_service.dart';
import 'package:collab/services/spotify_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const testTourist = AppUser(
    id: 'test_tourist_1',
    email: 'tourist@example.com',
    displayName: 'Ahmad Explorer',
    username: '@ahmad_penang',
    role: AccountRole.tourist,
    level: 2,
    exp: 1200,
    voucherCount: 3,
    reviewCount: 5,
  );

  Widget app(Widget home) => MaterialApp(
        theme: localQuestTheme(),
        home: Scaffold(body: home),
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SocialService.instance.mockFriendsStream = (uid) => Stream.value([
          Friend(
            id: 'f1',
            friendUserId: 'target_tourist_2',
            displayName: 'Sarah Tan',
            username: '@sarah_t',
            level: 3,
            createdAt: DateTime.now(),
          ),
        ]);
    SocialService.instance.mockFriendRequestsStream = (uid) => Stream.value([
          FriendRequest(
            id: 'r1',
            fromUserId: 'user_aiman',
            toUserId: uid,
            fromDisplayName: 'Aiman Hakim',
            fromUsername: '@aiman_h',
            status: 'pending',
            createdAt: DateTime.now(),
          ),
        ]);
    SocialService.instance.mockUserNoteStream = (uid) => Stream.value(
          UserNote(
            userId: uid,
            text: 'Exploring Penang 🎨',
            songTitle: 'Golden Hour',
            songArtist: 'JVKE',
            albumArtUrl: 'https://example.com/art.jpg',
            spotifyUrl: 'https://open.spotify.com/search/JVKE',
            createdAt: DateTime.now(),
          ),
        );
    DirectChatService.instance.mockMessagesStream = (chatId) => Stream.value([
          ChatMessage(
            id: 'm1',
            chatId: chatId,
            senderId: 'target_tourist_2',
            text: 'Hello from George Town!',
            createdAt: DateTime.now(),
          ),
        ]);
    DirectChatService.instance.mockConversationsStream = (uid) => Stream.value([
          ChatConversation(
            id: 'c1',
            participants: [uid, 'target_tourist_2'],
            otherUserId: 'target_tourist_2',
            otherDisplayName: 'Sarah Tan',
            otherUsername: '@sarah_t',
            lastMessage: 'Hello from George Town!',
            lastMessageTime: DateTime.now(),
            unreadCount: 1,
          ),
        ]);
    DirectChatService.instance.mockMarkChatAsRead =
        ({required chatId, required currentUserId}) async {};
  });

  tearDown(() {
    SocialService.instance.mockFriendsStream = null;
    SocialService.instance.mockFriendRequestsStream = null;
    SocialService.instance.mockUserNoteStream = null;
    DirectChatService.instance.mockMessagesStream = null;
    DirectChatService.instance.mockConversationsStream = null;
    DirectChatService.instance.mockMarkChatAsRead = null;
  });

  group('DirectChatService deterministic chatId tests', () {
    test('chatId is deterministic regardless of caller order', () {
      final id1 = DirectChatService.getChatId('user_alpha', 'user_beta');
      final id2 = DirectChatService.getChatId('user_beta', 'user_alpha');
      expect(id1, equals('user_alpha_user_beta'));
      expect(id2, equals('user_alpha_user_beta'));
      expect(id1, equals(id2));
    });
  });

  group('Social and Chat Models', () {
    test('Friend model properties', () {
      final now = DateTime.now();
      final friend = Friend(
        id: 'f_123',
        friendUserId: 'user_target',
        displayName: 'Sarah Tan',
        username: '@sarah_t',
        level: 3,
        createdAt: now,
      );

      expect(friend.displayName, 'Sarah Tan');
      expect(friend.username, '@sarah_t');
      expect(friend.level, 3);
    });

    test('FriendRequest model properties', () {
      final now = DateTime.now();
      final req = FriendRequest(
        id: 'req_123',
        fromUserId: 'user_source',
        toUserId: 'user_target',
        fromDisplayName: 'Marcus Wong',
        fromUsername: '@marcus_w',
        fromLevel: 2,
        status: 'pending',
        createdAt: now,
      );

      expect(req.fromUserId, 'user_source');
      expect(req.toUserId, 'user_target');
      expect(req.status, 'pending');
    });

    test('UserNote model properties with Spotify music', () {
      final now = DateTime.now();
      final note = UserNote(
        userId: 'user_1',
        text: 'Eating Cendol at Penang Road 🍧',
        songTitle: 'Golden Hour',
        songArtist: 'JVKE',
        albumArtUrl: 'https://example.com/art.jpg',
        spotifyUrl: 'https://open.spotify.com/search/JVKE',
        createdAt: now,
      );

      expect(note.userId, 'user_1');
      expect(note.text, contains('Cendol'));
      expect(note.hasMusic, isTrue);
      expect(note.songTitle, 'Golden Hour');
      expect(note.songArtist, 'JVKE');
      expect(note.spotifyUrl, contains('open.spotify.com'));
    });

    test('SpotifyService configuration and curated tracks', () {
      expect(SpotifyService.clientId, 'f7ebb503ee4d4265b1dee2884042a53e');
      expect(SpotifyService.clientSecret, '7b7545ff84f6411d90249147671fd6e8');

      final tracks = SpotifyService.instance.getCuratedPenangVibes();
      expect(tracks.isNotEmpty, isTrue);
      expect(tracks.first.title, isNotEmpty);
      expect(tracks.first.artist, isNotEmpty);
      expect(tracks.first.spotifyUrl, contains('open.spotify.com'));
    });

    test('SpotifyService currently playing track fetch', () async {
      SpotifyService.instance.mockFetchCurrentlyPlaying = () async => const SpotifyTrack(
            id: 'live_track_1',
            title: 'Birds of a Feather',
            artist: 'Billie Eilish',
            albumArtUrl: 'https://example.com/billie.jpg',
            spotifyUrl: 'https://open.spotify.com/track/live',
            isPlaying: true,
          );

      final track = await SpotifyService.instance.fetchCurrentlyPlaying();
      expect(track, isNotNull);
      expect(track!.title, 'Birds of a Feather');
      expect(track.artist, 'Billie Eilish');
      expect(track.isPlaying, isTrue);

      SpotifyService.instance.mockFetchCurrentlyPlaying = null;
    });

    test('ChatMessage model properties', () {
      final now = DateTime.now();
      final msg = ChatMessage(
        id: 'msg_1',
        chatId: 'chat_1',
        senderId: 'user_1',
        text: 'Meet you at ChinaHouse at 3pm!',
        createdAt: now,
      );

      expect(msg.text, 'Meet you at ChinaHouse at 3pm!');
      expect(msg.isRead, isFalse);
    });

    test('ChatConversation model properties', () {
      final now = DateTime.now();
      final convo = ChatConversation(
        id: 'chat_1',
        participants: ['user_1', 'user_2'],
        otherUserId: 'user_2',
        otherDisplayName: 'Sarah Tan',
        otherUsername: '@sarah_t',
        lastMessage: 'See you there!',
        lastMessageTime: now,
        unreadCount: 2,
        lastSenderId: 'user_1',
      );

      expect(convo.otherDisplayName, 'Sarah Tan');
      expect(convo.unreadCount, 2);
      expect(convo.lastSenderId, 'user_1');

      final updated = convo.copyWith(
        otherPhotoUrl: 'https://example.com/sarah_live.jpg',
        otherDisplayName: 'Sarah Tan (Updated)',
      );
      expect(updated.otherPhotoUrl, 'https://example.com/sarah_live.jpg');
      expect(updated.otherDisplayName, 'Sarah Tan (Updated)');
      expect(updated.otherUsername, '@sarah_t');
    });

    test('Friend copyWith updates photoUrl, displayName, and level', () {
      final now = DateTime.now();
      final friend = Friend(
        id: 'f_1',
        friendUserId: 'u_1',
        displayName: 'Old Name',
        username: '@old_handle',
        level: 1,
        createdAt: now,
      );

      final enriched = friend.copyWith(
        photoUrl: 'https://res.cloudinary.com/test/image/upload/sample.jpg',
        displayName: 'New Name',
        level: 5,
      );

      expect(enriched.photoUrl, 'https://res.cloudinary.com/test/image/upload/sample.jpg');
      expect(enriched.displayName, 'New Name');
      expect(enriched.username, '@old_handle');
      expect(enriched.level, 5);
      expect(enriched.createdAt, now);
    });

    test('FriendRequest copyWith updates fromPhotoUrl and details', () {
      final now = DateTime.now();
      final req = FriendRequest(
        id: 'r_1',
        fromUserId: 'u_from',
        toUserId: 'u_to',
        fromDisplayName: 'Old Sender',
        fromUsername: '@old_sender',
        createdAt: now,
      );

      final enriched = req.copyWith(
        fromPhotoUrl: 'https://res.cloudinary.com/test/photo.jpg',
        fromDisplayName: 'Fresh Sender',
        fromLevel: 4,
      );

      expect(enriched.fromPhotoUrl, 'https://res.cloudinary.com/test/photo.jpg');
      expect(enriched.fromDisplayName, 'Fresh Sender');
      expect(enriched.fromUsername, '@old_sender');
      expect(enriched.fromLevel, 4);
    });

    test('InAppNotificationService formatSenderTitle displays actual sender name and username', () {
      // 1. Both display name and @username present
      final title1 = InAppNotificationService.formatSenderTitle(
        displayName: 'Ahmad Explorer',
        username: '@ahmad_penang',
        senderId: 'user_ahmad',
      );
      expect(title1, 'Ahmad Explorer (@ahmad_penang)');

      // 2. Only username present (with @)
      final title2 = InAppNotificationService.formatSenderTitle(
        displayName: '',
        username: '@aiman_h',
        senderId: 'user_aiman',
      );
      expect(title2, '@aiman_h');

      // 3. Username without @ prefix
      final title3 = InAppNotificationService.formatSenderTitle(
        displayName: '',
        username: 'sarah_t',
        senderId: 'user_sarah',
      );
      expect(title3, '@sarah_t');

      // 4. Only display name present
      final title4 = InAppNotificationService.formatSenderTitle(
        displayName: 'Marcus Wong',
        username: '',
        senderId: 'user_marcus',
      );
      expect(title4, 'Marcus Wong');

      // 5. Fallback with valid senderId (never empty @user_)
      final title5 = InAppNotificationService.formatSenderTitle(
        displayName: '',
        username: '',
        senderId: 'usr987654321',
      );
      expect(title5, '@user_usr98');

      // 6. Complete empty fallback (never an empty '@user_')
      final title6 = InAppNotificationService.formatSenderTitle(
        displayName: '',
        username: '',
        senderId: '',
      );
      expect(title6, 'LocalQuest Friend');
      expect(title6, isNot(equals('@user_')));
    });
  });

  group('AiTouristGuideService Penang Grounding', () {
    test('provides authentic Penang guide recommendations without API key', () async {
      final service = AiTouristGuideService();
      final business = Business(
        id: 'chinahouse',
        ownerId: 'owner_1',
        name: 'ChinaHouse Penang',
        category: 'Heritage Cafe & Bakery',
        address: '153 Beach Street',
        area: 'George Town',
        postcode: '10300',
        state: 'Penang',
        phone: '+60 4-263 7299',
        registrationNumber: '201101009876',
        verificationStatus: 'verified',
        latitude: 5.4147,
        longitude: 100.3392,
      );

      final voucher = Campaign(
        id: 'v_welcome',
        businessId: 'chinahouse',
        ownerId: 'owner_1',
        name: 'Complimentary Artisanal Tiramisu Slice',
        description: 'Free signature tiramisu slice on your first visit',
        type: 'voucher',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
        status: 'active',
        discountType: 'freebie',
        discountValue: 18,
        minimumSpend: 0,
        quantity: 100,
        perCustomerLimit: 1,
        voucherType: 'welcome',
        collectionMethod: 'claim',
      );

      final recommendation = await service.askGuide(
        userPrompt: 'Where is good to visit near Beach Street?',
        userLat: 5.4147,
        userLng: 100.3392,
        nearbyBusinesses: [business],
        activeVouchers: [voucher],
      );

      expect(recommendation, contains('Selamat Datang to Penang!'));
      expect(recommendation, contains('ChinaHouse Penang'));
      expect(recommendation, contains('Welcome Voucher'));
    });

    test('handles empty businesses gracefully', () async {
      final service = AiTouristGuideService();
      final recommendation = await service.askGuide(
        userPrompt: 'Tell me about Penang',
        userLat: 5.4141,
        userLng: 100.3288,
        nearbyBusinesses: [],
        activeVouchers: [],
      );

      expect(recommendation, contains('George Town UNESCO Heritage zone'));
    });
  });

  group('UI Screen Widgets', () {
    testWidgets('AiAssistantSheet displays header, prompt chips, and message thread',
        (tester) async {
      await tester.pumpWidget(
        app(
          const AiAssistantSheet(user: testTourist),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('LocalQuest AI Guide'), findsOneWidget);
      expect(find.textContaining('Authentic Penang Laksa'), findsOneWidget);
      expect(find.textContaining('Where can I get Welcome Vouchers?'), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
      expect(find.textContaining('Hello Ahmad Explorer!'), findsOneWidget);
    });

    testWidgets('AiAssistantSheet accepts tapping a prompt chip and updates thread',
        (tester) async {
      await tester.pumpWidget(
        app(
          const AiAssistantSheet(user: testTourist),
        ),
      );
      await tester.pumpAndSettle();

      final chipFinder = find.textContaining('Where can I get Welcome Vouchers?');
      expect(chipFinder, findsOneWidget);

      await tester.tap(chipFinder);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.textContaining('Where can I get Welcome Vouchers?'), findsWidgets);
    });

    testWidgets('DirectChatScreen displays recipient details, messages, and input',
        (tester) async {
      await tester.pumpWidget(
        app(
          const DirectChatScreen(
            currentUser: testTourist,
            targetUserId: 'target_tourist_2',
            targetDisplayName: 'Sarah Tan',
            targetUsername: '@sarah_t',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sarah Tan'), findsOneWidget);
      expect(find.text('@sarah_t'), findsOneWidget);
      expect(find.text('Hello from George Town!'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    });

    testWidgets('FriendsScreen displays tabs, friends list, and 24-hr notes bar',
        (tester) async {
      await tester.pumpWidget(
        app(
          const FriendsScreen(currentUser: testTourist),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Friends & Social'), findsOneWidget);
      expect(find.text('Friends'), findsOneWidget);
      expect(find.text('Chats'), findsOneWidget);
      expect(find.text('Requests'), findsOneWidget);
      expect(find.text('Your Note'), findsOneWidget);
      expect(find.text('Sarah Tan'), findsOneWidget);
      expect(find.text('Lv.3'), findsOneWidget);
      expect(find.byIcon(Icons.person_add_alt_1_outlined), findsOneWidget);
    });

    testWidgets('TouristProfileScreen displays My Friends header and Journey entry',
        (tester) async {
      await tester.pumpWidget(
        app(
          const TouristProfileScreen(user: testTourist),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Direct Chat'), findsOneWidget);
      expect(find.text('My Friends'), findsOneWidget);
      expect(find.text('Connect & share vibes with friends'), findsOneWidget);
    });

    test('ChatMessage model supports image and location payloads', () {
      final now = DateTime.now();
      final imgMsg = ChatMessage(
        id: 'msg_img',
        chatId: 'chat_1',
        senderId: 'user_1',
        text: 'Beach sunset 🌅',
        type: 'image',
        imageUrl: 'https://example.com/photo.jpg',
        createdAt: now,
      );
      expect(imgMsg.isImage, isTrue);
      expect(imgMsg.imageUrl, 'https://example.com/photo.jpg');
      expect(imgMsg.text, 'Beach sunset 🌅');

      final locMsg = ChatMessage(
        id: 'msg_loc',
        chatId: 'chat_1',
        senderId: 'user_1',
        text: '📍 Penang Hill',
        type: 'location',
        latitude: 5.4243,
        longitude: 100.2690,
        locationName: 'Penang Hill Summit',
        createdAt: now,
      );
      expect(locMsg.isLocation, isTrue);
      expect(locMsg.latitude, 5.4243);
      expect(locMsg.longitude, 100.2690);
      expect(locMsg.locationName, 'Penang Hill Summit');
    });

    test('DirectChatService sendImageMessage and sendLocationMessage invoke mock handlers', () async {
      bool sentImage = false;
      bool sentLoc = false;

      DirectChatService.instance.mockSendImageMessage = ({
        required currentUser,
        required targetUserId,
        required targetDisplayName,
        required targetUsername,
        targetPhotoUrl,
        required imageUrl,
        caption,
      }) async {
        sentImage = true;
        expect(imageUrl, 'https://example.com/test.jpg');
        expect(caption, 'Nice view');
      };

      DirectChatService.instance.mockSendLocationMessage = ({
        required currentUser,
        required targetUserId,
        required targetDisplayName,
        required targetUsername,
        targetPhotoUrl,
        required latitude,
        required longitude,
        required locationName,
      }) async {
        sentLoc = true;
        expect(latitude, 5.4164);
        expect(locationName, contains('Penang'));
      };

      await DirectChatService.instance.sendImageMessage(
        currentUser: testTourist,
        targetUserId: 'target_tourist_2',
        targetDisplayName: 'Sarah Tan',
        targetUsername: '@sarah_t',
        imageUrl: 'https://example.com/test.jpg',
        caption: 'Nice view',
      );
      expect(sentImage, isTrue);

      await DirectChatService.instance.sendLocationMessage(
        currentUser: testTourist,
        targetUserId: 'target_tourist_2',
        targetDisplayName: 'Sarah Tan',
        targetUsername: '@sarah_t',
        latitude: 5.4164,
        longitude: 100.3327,
        locationName: 'George Town, Penang',
      );
      expect(sentLoc, isTrue);

      DirectChatService.instance.mockSendImageMessage = null;
      DirectChatService.instance.mockSendLocationMessage = null;
    });

    testWidgets('TouristHome renders floating bottom-right AI Assistant button',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: localQuestTheme(),
          home: const TouristHome(
            user: testTourist,
            initialIndex: 2, // Load profile page directly
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });

    testWidgets('DirectChatScreen renders attachment button and opens attachment sheet',
        (tester) async {
      await tester.pumpWidget(
        app(
          const DirectChatScreen(
            currentUser: testTourist,
            targetUserId: 'target_tourist_2',
            targetDisplayName: 'Sarah Tan',
            targetUsername: '@sarah_t',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final attachButton = find.byTooltip('Share photo or location');
      expect(attachButton, findsOneWidget);

      await tester.tap(attachButton);
      await tester.pumpAndSettle();

      expect(find.text('Share with friend'), findsOneWidget);
      expect(find.text('Gallery'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
    });

    testWidgets('DirectChatScreen renders image and location bubbles',
        (tester) async {
      final now = DateTime.now();
      DirectChatService.instance.mockMessagesStream = (_) => Stream.value([
            ChatMessage(
              id: 'm1',
              chatId: 'c1',
              senderId: 'target_tourist_2',
              text: 'Look at this photo',
              type: 'image',
              imageUrl:
                  'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
              createdAt: now,
            ),
            ChatMessage(
              id: 'm2',
              chatId: 'c1',
              senderId: testTourist.id,
              text: '📍 Penang Hill',
              type: 'location',
              latitude: 5.4243,
              longitude: 100.2690,
              locationName: 'Penang Hill Summit',
              createdAt: now,
            ),
          ]);

      await tester.pumpWidget(
        app(
          const DirectChatScreen(
            currentUser: testTourist,
            targetUserId: 'target_tourist_2',
            targetDisplayName: 'Sarah Tan',
            targetUsername: '@sarah_t',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Look at this photo'), findsOneWidget);
      expect(find.text('Shared Location'), findsOneWidget);
      expect(find.text('Penang Hill Summit'), findsOneWidget);
      expect(find.text('Tap to open map'), findsOneWidget);
    });

    testWidgets('SettingsScreen separates Preferences and Connected Accounts with 24px spacing',
        (tester) async {
      await tester.pumpWidget(
        app(
          const SettingsScreen(user: testTourist),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PREFERENCES'), findsOneWidget);
      expect(find.text('CONNECTED ACCOUNTS'), findsOneWidget);
      expect(find.text('Spotify Music'), findsOneWidget);
    });

    testWidgets('DirectChatScreen tapping header profile opens recipient info sheet with tier, exp, status and stats',
        (tester) async {
      UserRepository.instance.mockWatch = (uid) => Stream.value(
            const AppUser(
              id: 'target_tourist_2',
              email: 'sarah@example.com',
              displayName: 'Sarah Tan',
              username: '@sarah_t',
              role: AccountRole.tourist,
              level: 3,
              exp: 2450,
              voucherCount: 4,
              reviewCount: 7,
            ),
          );
      SocialService.instance.mockUserNoteStream = (uid) => Stream.value(
            UserNote(
              userId: uid,
              text: 'Exploring Armenian Street!',
              songTitle: 'Island in the Sun',
              songArtist: 'Weezer',
              createdAt: DateTime.now(),
            ),
          );

      await tester.pumpWidget(
        app(
          const DirectChatScreen(
            currentUser: testTourist,
            targetUserId: 'target_tourist_2',
            targetDisplayName: 'Sarah Tan',
            targetUsername: '@sarah_t',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on recipient header
      await tester.tap(find.text('Sarah Tan'));
      await tester.pumpAndSettle();

      // Verify recipient sheet content
      expect(find.text('EXPLORER · LEVEL 3'), findsOneWidget);
      expect(find.text('2450 XP'), findsOneWidget);
      expect(find.text('Level 3 Explorer • Next tier at 9000 XP'), findsOneWidget);
      expect(find.text('"Exploring Armenian Street!"'), findsOneWidget);
      expect(find.text('Island in the Sun'), findsOneWidget);
      expect(find.text('Weezer'), findsOneWidget);
      expect(find.text('Vouchers'), findsNothing);
      expect(find.text('Reviews'), findsNothing);
      expect(find.byKey(const Key('direct_chat_remove_friend_button')), findsOneWidget);
      expect(find.text('Remove Friend'), findsOneWidget);
      expect(find.text('Direct messages are private between tourists within Penang LocalQuest.'), findsOneWidget);

      UserRepository.instance.mockWatch = null;
      SocialService.instance.mockUserNoteStream = null;
    });

    testWidgets('FriendsScreen Add Friend button has StadiumBorder capsule shape',
        (tester) async {
      await tester.pumpWidget(
        app(
          const FriendsScreen(currentUser: testTourist),
        ),
      );
      await tester.pumpAndSettle();

      final fabFinder = find.byType(FloatingActionButton);
      expect(fabFinder, findsOneWidget);
      final fab = tester.widget<FloatingActionButton>(fabFinder);
      expect(fab.shape, isA<StadiumBorder>());
      expect(find.text('Add Friend'), findsOneWidget);
    });

    testWidgets('DirectChatScreen displays inline image preview with remove button',
        (tester) async {
      final sampleImageBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
      );

      await tester.pumpWidget(
        app(
          DirectChatScreen(
            currentUser: testTourist,
            targetUserId: 'target_tourist_2',
            targetDisplayName: 'Sarah Tan',
            targetUsername: '@sarah_t',
            initialSelectedImageBytes: sampleImageBytes,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check that the inline image preview and remove button are visible
      expect(find.byKey(const Key('remove_selected_image_btn')), findsOneWidget);
      expect(find.text('Add a caption...'), findsOneWidget);

      // Tap remove button
      await tester.tap(find.byKey(const Key('remove_selected_image_btn')));
      await tester.pumpAndSettle();

      // Verify the image preview is dismissed and hint reverts to 'Type a message...'
      expect(find.byKey(const Key('remove_selected_image_btn')), findsNothing);
      expect(find.text('Type a message...'), findsOneWidget);
    });

    testWidgets('DirectChatScreen sends inline image with text caption',
        (tester) async {
      final sampleImageBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
      );

      bool sent = false;
      String? sentCaption;
      String? sentImageUrl;

      DirectChatService.instance.mockSendImageMessage = ({
        required currentUser,
        required targetUserId,
        required targetDisplayName,
        required targetUsername,
        targetPhotoUrl,
        required imageUrl,
        caption,
      }) async {
        sent = true;
        sentCaption = caption;
        sentImageUrl = imageUrl;
      };

      await tester.pumpWidget(
        app(
          DirectChatScreen(
            currentUser: testTourist,
            targetUserId: 'target_tourist_2',
            targetDisplayName: 'Sarah Tan',
            targetUsername: '@sarah_t',
            initialSelectedImageBytes: sampleImageBytes,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter caption in text field
      await tester.enterText(find.byType(TextField), 'Check out this heritage spot!');
      await tester.pumpAndSettle();

      // Tap send button
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(sent, isTrue);
      expect(sentCaption, 'Check out this heritage spot!');
      expect(sentImageUrl, isNotNull);

      DirectChatService.instance.mockSendImageMessage = null;
    });

    testWidgets('DirectChatScreen opens Location modal and shares selected business',
        (tester) async {
      bool sentLoc = false;
      String? sentLocName;
      double? sentLat;
      double? sentLng;

      DirectChatService.instance.mockSendLocationMessage = ({
        required currentUser,
        required targetUserId,
        required targetDisplayName,
        required targetUsername,
        targetPhotoUrl,
        required latitude,
        required longitude,
        required locationName,
      }) async {
        sentLoc = true;
        sentLocName = locationName;
        sentLat = latitude;
        sentLng = longitude;
      };

      await tester.pumpWidget(
        app(
          const DirectChatScreen(
            currentUser: testTourist,
            targetUserId: 'target_tourist_2',
            targetDisplayName: 'Sarah Tan',
            targetUsername: '@sarah_t',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap attachment button
      await tester.tap(find.byTooltip('Share photo or location'));
      await tester.pumpAndSettle();

      // Tap Location option
      await tester.tap(find.text('Location'));
      await tester.pumpAndSettle();

      // Verify Share Location modal opened
      expect(find.text('Share Location'), findsOneWidget);
      expect(find.text('My Current Location'), findsOneWidget);
      expect(find.text('OR SHARE A BUSINESS / PLACE'), findsOneWidget);

      // Search for Demo Local Café
      final searchField = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.hintText == 'Search businesses, cafes, heritage...',
      );
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'Café');
      await tester.pumpAndSettle();

      expect(find.text('Demo Local Café'), findsOneWidget);

      // Tap the Demo Local Café item
      await tester.tap(find.text('Demo Local Café'));
      await tester.pumpAndSettle();

      // Verify sendLocationMessage was triggered with business name and coordinates
      expect(sentLoc, isTrue);
      expect(sentLocName, contains('Demo Local Café'));
      expect(sentLat, closeTo(MockMapData.businesses.first.latitude!, 0.001));
      expect(sentLng, closeTo(MockMapData.businesses.first.longitude!, 0.001));

      DirectChatService.instance.mockSendLocationMessage = null;
    });

    testWidgets('FriendsScreen note editor shows Connect Spotify for unlinked users',
        (tester) async {
      await SpotifyService.instance.disconnectUser('unlinked_user');

      await tester.pumpWidget(
        app(
          const FriendsScreen(
            currentUser: AppUser(
              id: 'unlinked_user',
              email: 'unlinked@example.com',
              displayName: 'Oscar Piastri',
              username: '@oscar_p',
              role: AccountRole.tourist,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Your Note to open the editor
      await tester.tap(find.text('Your Note'));
      await tester.pumpAndSettle();

      // Verify unlinked state UI
      expect(find.text('Spotify Not Connected'), findsOneWidget);
      expect(find.text('Connect Spotify Account'), findsOneWidget);
      expect(find.text('Connect Spotify to share music'), findsOneWidget);
      expect(find.text('Unlink Spotify Account'), findsNothing);

      // Close dialog
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    });

    test('streamFriends omits deleted friends and only returns active users', () async {
      SocialService.instance.mockFriendsStream = (uid) => Stream.value([
        Friend(
          id: 'active_friend_doc',
          friendUserId: 'active_friend_uid',
          displayName: 'Active Explorer',
          username: '@active_user',
          level: 3,
          createdAt: DateTime.now(),
        ),
      ]);

      final friends = await SocialService.instance.streamFriends('current_user_1').first;

      expect(friends.length, equals(1));
      expect(friends.first.friendUserId, equals('active_friend_uid'));
      expect(friends.first.displayName, equals('Active Explorer'));

      SocialService.instance.mockFriendsStream = null;
    });

    test('streamConversations marks deleted participants as Deleted Account', () async {
      DirectChatService.instance.mockConversationsStream = (uid) => Stream.value([
        ChatConversation(
          id: 'chat_with_deleted',
          participants: [uid, 'deleted_user_uid'],
          otherUserId: 'deleted_user_uid',
          otherDisplayName: 'Deleted Account',
          otherUsername: 'deleted_user',
          otherPhotoUrl: null,
          lastMessage: 'Goodbye!',
          lastMessageTime: DateTime.now(),
          unreadCount: 0,
        ),
      ]);

      final convos =
          await DirectChatService.instance.streamConversations('current_user_1').first;

      expect(convos.length, equals(1));
      expect(convos.first.otherDisplayName, equals('Deleted Account'));
      expect(convos.first.otherUsername, equals('deleted_user'));
      expect(convos.first.otherPhotoUrl, isNull);

      DirectChatService.instance.mockConversationsStream = null;
    });
  });
}
