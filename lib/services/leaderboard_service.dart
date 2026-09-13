import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/localquest_models.dart';

/// LeaderboardService manages global and friends leaderboards based on EXP and Level.
class LeaderboardService {
  LeaderboardService({FirebaseFirestore? firestore}) : _db = firestore;
  static LeaderboardService instance = LeaderboardService();

  final FirebaseFirestore? _db;
  FirebaseFirestore get db => _db ?? FirebaseFirestore.instance;

  Stream<List<LeaderboardEntry>> Function({int? limit, String? currentUserId})?
      mockGlobalStream;
  Stream<List<LeaderboardEntry>> Function({required String currentUserId})?
      mockFriendsStream;

  /// Stream top global explorers ordered by EXP descending
  Stream<List<LeaderboardEntry>> streamGlobalLeaderboard({
    int limit = 50,
    String? currentUserId,
  }) {
    if (mockGlobalStream != null) {
      return mockGlobalStream!(limit: limit, currentUserId: currentUserId);
    }
    try {
      return db
          .collection('users')
          .orderBy('exp', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
            final list = <LeaderboardEntry>[];
            for (var i = 0; i < snapshot.docs.length; i++) {
              final doc = snapshot.docs[i];
              list.add(
                LeaderboardEntry.fromDoc(
                  doc,
                  rank: i + 1,
                  currentUserId: currentUserId,
                ),
              );
            }
            return list;
          });
    } catch (_) {
      return Stream.value([]);
    }
  }

  /// Stream friends leaderboard including the current user, ranked by EXP
  Stream<List<LeaderboardEntry>> streamFriendsLeaderboard({
    required String currentUserId,
  }) {
    if (mockFriendsStream != null) {
      return mockFriendsStream!(currentUserId: currentUserId);
    }
    if (currentUserId.isEmpty) return Stream.value([]);

    try {
      // Listen to the current user's friends subcollection
      return db
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .snapshots()
          .asyncMap((friendsSnap) async {
            final friendIds = friendsSnap.docs
                .map((d) => d.data()['friendUserId'] as String? ?? d.id)
                .where((id) => id.isNotEmpty)
                .toSet();

            // Include current user
            friendIds.add(currentUserId);

            final entries = <LeaderboardEntry>[];

            for (final uid in friendIds) {
              try {
                final userDoc = await db.collection('users').doc(uid).get();
                if (userDoc.exists) {
                  entries.add(
                    LeaderboardEntry.fromDoc(
                      userDoc,
                      currentUserId: currentUserId,
                    ),
                  );
                }
              } catch (_) {}
            }

            // Sort descending by EXP, then by level
            entries.sort((a, b) {
              final expCmp = b.exp.compareTo(a.exp);
              if (expCmp != 0) return expCmp;
              return b.level.compareTo(a.level);
            });

            // Assign ranks (1-based)
            final ranked = <LeaderboardEntry>[];
            for (var i = 0; i < entries.length; i++) {
              ranked.add(entries[i].copyWith(rank: i + 1));
            }
            return ranked;
          });
    } catch (_) {
      return Stream.value([]);
    }
  }
}
