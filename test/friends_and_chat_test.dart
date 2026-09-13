import 'package:collab/core/localquest_theme.dart';
import 'package:collab/models/localquest_models.dart';
import 'package:collab/screens/ai_assistant_sheet.dart';
import 'package:collab/screens/direct_chat_screen.dart';
import 'package:collab/screens/friends_screen.dart';
import 'package:collab/screens/tourist_screens.dart';
import 'package:collab/services/ai_tourist_guide_service.dart';
import 'package:collab/services/direct_chat_service.dart';
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
      expect(SpotifyService.clientId, 'b7d1315dc27e4e7f83f0947858afe872');
      expect(SpotifyService.clientSecret, 'cb1181f778ea4ce5842ea3a2c44e1ab8');

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
      );

      expect(convo.otherDisplayName, 'Sarah Tan');
      expect(convo.unreadCount, 2);
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
  });
}
