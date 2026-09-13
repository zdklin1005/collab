import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// InAppNotificationService monitors incoming Firestore chat messages
/// and friend requests, triggering native Android heads-up notifications.
class InAppNotificationService {
  InAppNotificationService._();
  static final InAppNotificationService instance = InAppNotificationService._();

  static const MethodChannel _channel =
      MethodChannel('com.localquest.app/notifications');

  /// Currently open chat room ID (notifications suppressed for active chat)
  String? activeChatId;

  String? _currentUserId;
  StreamSubscription<QuerySnapshot>? _chatsSubscription;
  StreamSubscription<QuerySnapshot>? _requestsSubscription;

  final Set<String> _seenChatTimestamps = {};
  final Set<String> _seenRequestIds = {};
  bool _isInitialSync = true;

  /// Trigger native Android status-bar notification
  Future<void> showNotification({
    int? id,
    required String title,
    required String body,
  }) async {
    try {
      await _channel.invokeMethod('showNotification', {
        'id': id ?? (DateTime.now().millisecondsSinceEpoch % 100000),
        'title': title,
        'body': body,
      });
    } catch (e) {
      debugPrint('Notification error: $e');
    }
  }

  final Map<String, Map<String, String>> _senderCache = {};

  /// Start listening for incoming messages and friend requests for a user
  void startListening(String userId) {
    if (_currentUserId == userId && _chatsSubscription != null) return;
    stopListening();
    _currentUserId = userId;
    _isInitialSync = true;

    // 1. Listen for new chat messages across all user's conversations
    _chatsSubscription = FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .listen((snapshot) async {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final chatId = doc.id;
        final lastMessage = data['lastMessage'] as String? ?? '';
        final lastSenderId = data['lastSenderId'] as String? ?? '';
        final lastMessageTime = data['lastMessageTime'] as Timestamp?;
        final userSummaries = Map<String, dynamic>.from(data['userSummaries'] as Map? ?? {});

        if (lastMessage.isEmpty || lastSenderId == userId) continue;

        final timeKey = '${chatId}_${lastMessageTime?.millisecondsSinceEpoch ?? 0}';
        if (_seenChatTimestamps.contains(timeKey)) continue;
        _seenChatTimestamps.add(timeKey);

        // Don't show notifications during initial cold load
        if (_isInitialSync) continue;

        // If user is currently looking at this specific chat, skip notification
        if (activeChatId == chatId) continue;

        // Find sender's name & username
        final senderInfo = Map<String, dynamic>.from(userSummaries[lastSenderId] as Map? ?? {});
        String displayName = (senderInfo['displayName'] as String? ?? '').trim();
        String username = (senderInfo['username'] as String? ?? '').trim();

        // Fallback: If missing from summaries, check cache or fetch from Firestore
        if (username.isEmpty || displayName.isEmpty || displayName.toLowerCase() == 'friend') {
          if (_senderCache.containsKey(lastSenderId)) {
            final cached = _senderCache[lastSenderId]!;
            if (displayName.isEmpty || displayName.toLowerCase() == 'friend') {
              displayName = cached['displayName'] ?? '';
            }
            if (username.isEmpty) {
              username = cached['username'] ?? '';
            }
          } else {
            try {
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(lastSenderId)
                  .get();
              if (userDoc.exists) {
                final uData = userDoc.data() ?? {};
                final fetchedName = (uData['displayName'] as String? ?? uData['name'] as String? ?? '').trim();
                final fetchedUsername = (uData['username'] as String? ?? '').trim();
                _senderCache[lastSenderId] = {
                  'displayName': fetchedName,
                  'username': fetchedUsername,
                };
                if (displayName.isEmpty || displayName.toLowerCase() == 'friend') {
                  displayName = fetchedName;
                }
                if (username.isEmpty) {
                  username = fetchedUsername;
                }
              }
            } catch (e) {
              debugPrint('Error fetching sender profile: $e');
            }
          }
        }

        final cleanUsername =
            username.startsWith('@') ? username.substring(1) : username;

        final String notificationTitle;
        if (cleanUsername.isNotEmpty) {
          if (displayName.isNotEmpty && displayName.toLowerCase() != 'friend') {
            notificationTitle = '$displayName (@$cleanUsername)';
          } else {
            notificationTitle = '@$cleanUsername';
          }
        } else if (displayName.isNotEmpty && displayName.toLowerCase() != 'friend') {
          notificationTitle = displayName;
        } else {
          final fallbackId = lastSenderId.length > 5 ? lastSenderId.substring(0, 5) : lastSenderId;
          notificationTitle = '@user_$fallbackId';
        }

        showNotification(
          id: chatId.hashCode,
          title: notificationTitle,
          body: lastMessage,
        );
      }
      _isInitialSync = false;
    }, onError: (e) => debugPrint('Chat notification error: $e'));

    // 2. Listen for incoming friend requests
    _requestsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('friendRequests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      for (final doc in snapshot.docs) {
        final reqId = doc.id;
        final data = doc.data();
        if (_seenRequestIds.contains(reqId)) continue;
        _seenRequestIds.add(reqId);

        if (_isInitialSync) continue;

        final fromName = (data['fromDisplayName'] as String? ?? '').trim();
        final rawUsername = (data['fromUsername'] as String? ?? '').trim();
        final cleanUsername =
            rawUsername.startsWith('@') ? rawUsername.substring(1) : rawUsername;
        final String senderLabel;
        if (cleanUsername.isNotEmpty) {
          if (fromName.isNotEmpty && fromName.toLowerCase() != 'friend') {
            senderLabel = '$fromName (@$cleanUsername)';
          } else {
            senderLabel = '@$cleanUsername';
          }
        } else if (fromName.isNotEmpty && fromName.toLowerCase() != 'friend') {
          senderLabel = fromName;
        } else {
          senderLabel = 'A fellow tourist';
        }

        showNotification(
          id: reqId.hashCode,
          title: 'Friend Request',
          body: '$senderLabel sent you a friend request!',
        );
      }
    }, onError: (e) => debugPrint('Friend request notification error: $e'));
  }

  /// Stop listening when user signs out
  void stopListening() {
    _chatsSubscription?.cancel();
    _chatsSubscription = null;
    _requestsSubscription?.cancel();
    _requestsSubscription = null;
    _currentUserId = null;
    _seenChatTimestamps.clear();
    _seenRequestIds.clear();
    _senderCache.clear();
  }
}
