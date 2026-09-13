import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/localquest_models.dart';

/// SocialService manages friends, friend requests, user search,
/// and 24-hour "Insta Notes" within the Tourist / User Management module.
class SocialService {
  SocialService({FirebaseFirestore? firestore}) : _db = firestore;
  static SocialService instance = SocialService();

  final FirebaseFirestore? _db;
  FirebaseFirestore get db => _db ?? FirebaseFirestore.instance;

  Stream<List<Friend>> Function(String uid)? mockFriendsStream;
  Stream<List<FriendRequest>> Function(String uid)? mockFriendRequestsStream;
  Stream<UserNote?> Function(String uid)? mockUserNoteStream;

  /// Stream list of friends for a tourist
  Stream<List<Friend>> streamFriends(String uid) {
    if (mockFriendsStream != null) return mockFriendsStream!(uid);
    if (uid.isEmpty) return Stream.value([]);
    try {
      return db
          .collection('users')
          .doc(uid)
          .collection('friends')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map(Friend.fromDoc).toList());
    } catch (_) {
      return Stream.value([]);
    }
  }

  /// Stream pending incoming friend requests
  Stream<List<FriendRequest>> streamFriendRequests(String uid) {
    if (mockFriendRequestsStream != null) return mockFriendRequestsStream!(uid);
    if (uid.isEmpty) return Stream.value([]);
    try {
      return db
          .collection('users')
          .doc(uid)
          .collection('friendRequests')
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs.map(FriendRequest.fromDoc).toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
          );
    } catch (_) {
      return Stream.value([]);
    }
  }

  /// Stream current status / 24-hour Insta Note for a user
  Stream<UserNote?> streamUserNote(String uid) {
    if (mockUserNoteStream != null) return mockUserNoteStream!(uid);
    if (uid.isEmpty) return Stream.value(null);
    try {
      return db
          .collection('users')
          .doc(uid)
          .collection('notes')
          .doc('status')
          .snapshots()
          .map((doc) {
            if (!doc.exists) return null;
            final note = UserNote.fromDoc(doc);
            // Check if expired (> 24 hours)
            if (DateTime.now().difference(note.createdAt).inHours >= 24) {
              return null;
            }
            return note;
          });
    } catch (_) {
      return Stream.value(null);
    }
  }

  /// Update user's 24-hour vibe note (Insta Notes style with optional Spotify music)
  Future<void> updateUserNote({
    required String uid,
    required String text,
    String? songTitle,
    String? songArtist,
    String? albumArtUrl,
    String? spotifyUrl,
  }) async {
    final noteRef = db.collection('users').doc(uid).collection('notes').doc('status');
    final cleanText = text.trim();
    final hasMusic = songTitle != null && songTitle.trim().isNotEmpty;

    if (cleanText.isEmpty && !hasMusic) {
      await noteRef.delete();
    } else {
      await noteRef.set({
        'text': cleanText,
        'songTitle': songTitle?.trim(),
        'songArtist': songArtist?.trim(),
        'albumArtUrl': albumArtUrl?.trim(),
        'spotifyUrl': spotifyUrl?.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Delete / clear user's vibe note
  Future<void> clearUserNote(String uid) async {
    await db.collection('users').doc(uid).collection('notes').doc('status').delete();
  }

  /// Send a friend request to another tourist
  Future<void> sendFriendRequest({
    required AppUser currentUser,
    required String targetUserId,
    required String targetDisplayName,
    required String targetUsername,
    String? targetPhotoUrl,
    int targetLevel = 1,
  }) async {
    if (currentUser.id == targetUserId) {
      throw Exception('You cannot add yourself as a friend.');
    }

    // Check if already friends
    final friendDoc = await db
        .collection('users')
        .doc(currentUser.id)
        .collection('friends')
        .doc(targetUserId)
        .get();
    if (friendDoc.exists) {
      throw Exception('You are already friends with this explorer!');
    }

    // Check if request already pending
    try {
      final reqDoc = await db
          .collection('users')
          .doc(targetUserId)
          .collection('friendRequests')
          .doc(currentUser.id)
          .get();
      if (reqDoc.exists && reqDoc.data()?['status'] == 'pending') {
        throw Exception('Friend request already sent.');
      }
    } catch (e) {
      if (e.toString().contains('Friend request already sent')) rethrow;
    }

    // Write request to target user's friendRequests subcollection
    await db
        .collection('users')
        .doc(targetUserId)
        .collection('friendRequests')
        .doc(currentUser.id)
        .set({
          'fromUserId': currentUser.id,
          'toUserId': targetUserId,
          'fromDisplayName': currentUser.displayName,
          'fromUsername': currentUser.username,
          'fromPhotoUrl': currentUser.photoUrl,
          'fromLevel': currentUser.level,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  /// Accept incoming friend request
  Future<void> acceptFriendRequest({
    required AppUser currentUser,
    required FriendRequest request,
  }) async {
    final batch = db.batch();

    // 1. Add sender to current user's friends list
    final myFriendRef = db
        .collection('users')
        .doc(currentUser.id)
        .collection('friends')
        .doc(request.fromUserId);
    batch.set(myFriendRef, {
      'friendUserId': request.fromUserId,
      'displayName': request.fromDisplayName,
      'username': request.fromUsername,
      'photoUrl': request.fromPhotoUrl,
      'level': request.fromLevel,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Add current user to sender's friends list
    final theirFriendRef = db
        .collection('users')
        .doc(request.fromUserId)
        .collection('friends')
        .doc(currentUser.id);
    batch.set(theirFriendRef, {
      'friendUserId': currentUser.id,
      'displayName': currentUser.displayName,
      'username': currentUser.username,
      'photoUrl': currentUser.photoUrl,
      'level': currentUser.level,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 3. Mark request as accepted / remove request
    final reqRef = db
        .collection('users')
        .doc(currentUser.id)
        .collection('friendRequests')
        .doc(request.id);
    batch.delete(reqRef);

    await batch.commit();
  }

  /// Reject incoming friend request
  Future<void> rejectFriendRequest({
    required String currentUserId,
    required String requestId,
  }) async {
    await db
        .collection('users')
        .doc(currentUserId)
        .collection('friendRequests')
        .doc(requestId)
        .delete();
  }

  /// Remove a friend from both users' friend lists
  Future<void> removeFriend({
    required String currentUserId,
    required String friendUserId,
  }) async {
    final batch = db.batch();
    batch.delete(
      db.collection('users').doc(currentUserId).collection('friends').doc(friendUserId),
    );
    batch.delete(
      db.collection('users').doc(friendUserId).collection('friends').doc(currentUserId),
    );
    await batch.commit();
  }

  /// Search tourists by username or display name
  Future<List<AppUser>> searchUsers({
    required String query,
    required String currentUserId,
  }) async {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return [];

    final snapshot = await db.collection('users').limit(50).get();
    final results = <AppUser>[];

    for (final doc in snapshot.docs) {
      if (doc.id == currentUserId) continue;
      final user = AppUser.fromDoc(doc);
      if (user.role != AccountRole.tourist) continue;

      final nameMatch = user.displayName.toLowerCase().contains(cleanQuery);
      final usernameMatch = user.username.toLowerCase().contains(cleanQuery);

      if (nameMatch || usernameMatch) {
        results.add(user);
      }
    }
    return results;
  }
}
