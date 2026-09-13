import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/localquest_models.dart';

/// DirectChatService handles real-time 1-on-1 private messaging between tourists.
class DirectChatService {
  DirectChatService({FirebaseFirestore? firestore}) : _db = firestore;
  static DirectChatService instance = DirectChatService();

  final FirebaseFirestore? _db;
  FirebaseFirestore get db => _db ?? FirebaseFirestore.instance;

  Stream<List<ChatMessage>> Function(String chatId)? mockMessagesStream;
  Stream<List<ChatConversation>> Function(String currentUserId)? mockConversationsStream;
  Future<void> Function({required String chatId, required String currentUserId})? mockMarkChatAsRead;
  Future<void> Function({
    required AppUser currentUser,
    required String targetUserId,
    required String targetDisplayName,
    required String targetUsername,
    String? targetPhotoUrl,
    required String text,
  })? mockSendMessage;
  Future<void> Function({
    required AppUser currentUser,
    required String targetUserId,
    required String targetDisplayName,
    required String targetUsername,
    String? targetPhotoUrl,
    required String imageUrl,
    String? caption,
  })? mockSendImageMessage;
  Future<void> Function({
    required AppUser currentUser,
    required String targetUserId,
    required String targetDisplayName,
    required String targetUsername,
    String? targetPhotoUrl,
    required double latitude,
    required double longitude,
    required String locationName,
  })? mockSendLocationMessage;

  /// Deterministic Chat ID for 1-on-1 conversations between two tourists.
  static String getChatId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  /// Stream real-time messages in a conversation
  Stream<List<ChatMessage>> streamMessages(String chatId) {
    if (mockMessagesStream != null) {
      return mockMessagesStream!(chatId);
    }
    if (chatId.isEmpty) return Stream.value([]);
    try {
      return db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('createdAt', descending: false)
          .snapshots()
          .map((snapshot) => snapshot.docs.map(ChatMessage.fromDoc).toList());
    } catch (_) {
      return Stream.value([]);
    }
  }

  /// Stream all conversations for the current user
  Stream<List<ChatConversation>> streamConversations(String currentUserId) {
    if (mockConversationsStream != null) {
      return mockConversationsStream!(currentUserId);
    }
    if (currentUserId.isEmpty) return Stream.value([]);
    try {
      return db
          .collection('chats')
          .where('participants', arrayContains: currentUserId)
          .snapshots()
          .map(
            (snapshot) {
              final list = snapshot.docs
                  .map((doc) => ChatConversation.fromDoc(doc, currentUserId))
                  .toList();
              list.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
              return list;
            },
          );
    } catch (_) {
      return Stream.value([]);
    }
  }

  /// Send a text message in 1-on-1 chat
  Future<void> sendMessage({
    required AppUser currentUser,
    required String targetUserId,
    required String targetDisplayName,
    required String targetUsername,
    String? targetPhotoUrl,
    required String text,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    if (mockSendMessage != null) {
      return mockSendMessage!(
        currentUser: currentUser,
        targetUserId: targetUserId,
        targetDisplayName: targetDisplayName,
        targetUsername: targetUsername,
        targetPhotoUrl: targetPhotoUrl,
        text: cleanText,
      );
    }

    final chatId = getChatId(currentUser.id, targetUserId);
    final chatDocRef = db.collection('chats').doc(chatId);
    final messagesColRef = chatDocRef.collection('messages');

    // 1. Add message subdocument
    await messagesColRef.add({
      'chatId': chatId,
      'senderId': currentUser.id,
      'text': cleanText,
      'type': 'text',
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    // 2. Update conversation summary doc
    await chatDocRef.set({
      'participants': [currentUser.id, targetUserId],
      'userSummaries': {
        currentUser.id: {
          'displayName': currentUser.displayName,
          'username': currentUser.username,
          'photoUrl': currentUser.photoUrl,
        },
        targetUserId: {
          'displayName': targetDisplayName,
          'username': targetUsername,
          'photoUrl': targetPhotoUrl,
        },
      },
      'lastMessage': cleanText,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount_$targetUserId': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  /// Send an image/photo message in 1-on-1 chat
  Future<void> sendImageMessage({
    required AppUser currentUser,
    required String targetUserId,
    required String targetDisplayName,
    required String targetUsername,
    String? targetPhotoUrl,
    required String imageUrl,
    String? caption,
  }) async {
    if (mockSendImageMessage != null) {
      return mockSendImageMessage!(
        currentUser: currentUser,
        targetUserId: targetUserId,
        targetDisplayName: targetDisplayName,
        targetUsername: targetUsername,
        targetPhotoUrl: targetPhotoUrl,
        imageUrl: imageUrl,
        caption: caption,
      );
    }
    final cleanCaption = caption?.trim() ?? '';
    final displayText = cleanCaption.isNotEmpty ? cleanCaption : '📷 Photo';

    final chatId = getChatId(currentUser.id, targetUserId);
    final chatDocRef = db.collection('chats').doc(chatId);
    final messagesColRef = chatDocRef.collection('messages');

    await messagesColRef.add({
      'chatId': chatId,
      'senderId': currentUser.id,
      'text': displayText,
      'type': 'image',
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    await chatDocRef.set({
      'participants': [currentUser.id, targetUserId],
      'userSummaries': {
        currentUser.id: {
          'displayName': currentUser.displayName,
          'username': currentUser.username,
          'photoUrl': currentUser.photoUrl,
        },
        targetUserId: {
          'displayName': targetDisplayName,
          'username': targetUsername,
          'photoUrl': targetPhotoUrl,
        },
      },
      'lastMessage': displayText,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount_$targetUserId': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  /// Send a location message in 1-on-1 chat
  Future<void> sendLocationMessage({
    required AppUser currentUser,
    required String targetUserId,
    required String targetDisplayName,
    required String targetUsername,
    String? targetPhotoUrl,
    required double latitude,
    required double longitude,
    required String locationName,
  }) async {
    if (mockSendLocationMessage != null) {
      return mockSendLocationMessage!(
        currentUser: currentUser,
        targetUserId: targetUserId,
        targetDisplayName: targetDisplayName,
        targetUsername: targetUsername,
        targetPhotoUrl: targetPhotoUrl,
        latitude: latitude,
        longitude: longitude,
        locationName: locationName,
      );
    }
    final displayText = '📍 $locationName';
    final chatId = getChatId(currentUser.id, targetUserId);
    final chatDocRef = db.collection('chats').doc(chatId);
    final messagesColRef = chatDocRef.collection('messages');

    await messagesColRef.add({
      'chatId': chatId,
      'senderId': currentUser.id,
      'text': displayText,
      'type': 'location',
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    await chatDocRef.set({
      'participants': [currentUser.id, targetUserId],
      'userSummaries': {
        currentUser.id: {
          'displayName': currentUser.displayName,
          'username': currentUser.username,
          'photoUrl': currentUser.photoUrl,
        },
        targetUserId: {
          'displayName': targetDisplayName,
          'username': targetUsername,
          'photoUrl': targetPhotoUrl,
        },
      },
      'lastMessage': displayText,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount_$targetUserId': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  /// Mark conversation as read by resetting the unread count for the current user
  Future<void> markChatAsRead({
    required String chatId,
    required String currentUserId,
  }) async {
    if (mockMarkChatAsRead != null) {
      return mockMarkChatAsRead!(chatId: chatId, currentUserId: currentUserId);
    }
    try {
      if (chatId.isEmpty || currentUserId.isEmpty) return;
      await db.collection('chats').doc(chatId).set({
        'unreadCount_$currentUserId': 0,
      }, SetOptions(merge: true));
    } catch (_) {
      // In test or offline environments where Firebase is not initialized, don't crash
    }
  }
}
