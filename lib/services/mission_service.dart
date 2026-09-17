import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'city_resolver.dart';
import 'cloudinary_images.dart';
import 'localquest_services.dart';
import 'reward_service.dart';
import '../models/localquest_models.dart';

enum MissionType { visit, photo }

enum MissionRewardType { exp, voucher }

enum MissionStatus { active, completed, expired, failed }

/// A single stop within a mission. A mission with multiple checkpoints
/// (e.g. "Explore Jonker Street") requires all of them to be completed
/// before the mission itself is marked complete.
class MissionCheckpoint {
  const MissionCheckpoint({
    required this.businessId,
    required this.businessName,
    required this.type,
    required this.targetLatitude,
    required this.targetLongitude,
    required this.completed,
    this.photoTargetLabel,
    this.photoUrl,
    this.completedAt,
  });

  final String businessId;
  final String businessName;
  final MissionType type;
  final double targetLatitude;
  final double targetLongitude;
  final bool completed;

  /// Legacy field from when photo checkpoints were content-verified via
  /// ML Kit. No longer read anywhere — kept only so older Firestore
  /// documents that still have this field don't fail to deserialize.
  final String? photoTargetLabel;

  /// Cloudinary URL of the photo the tourist submitted for this
  /// checkpoint, if any. This is a record only — the photo's content is
  /// not verified against anything.
  final String? photoUrl;

  final DateTime? completedAt;

  MissionCheckpoint copyWith({
    bool? completed,
    DateTime? completedAt,
    String? photoUrl,
  }) {
    return MissionCheckpoint(
      businessId: businessId,
      businessName: businessName,
      type: type,
      targetLatitude: targetLatitude,
      targetLongitude: targetLongitude,
      completed: completed ?? this.completed,
      photoTargetLabel: photoTargetLabel,
      photoUrl: photoUrl ?? this.photoUrl,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  // Defensive/case-insensitive parsing with a safe fallback, so one
  // malformed checkpoint (bad casing, legacy field value) doesn't throw
  // and crash the whole mission list.
  factory MissionCheckpoint.fromMap(Map<String, dynamic> map) {
    final typeStr = (map['type'] as String? ?? 'visit').toLowerCase();
    final type =
        MissionType.values.cast<MissionType?>().firstWhere(
              (t) => t?.name.toLowerCase() == typeStr,
          orElse: () => MissionType.visit,
        ) ??
            MissionType.visit;

    return MissionCheckpoint(
      businessId: map['businessId'] as String? ?? '',
      businessName: map['businessName'] as String? ?? '',
      type: type,
      targetLatitude: (map['targetLatitude'] as num?)?.toDouble() ?? 0,
      targetLongitude: (map['targetLongitude'] as num?)?.toDouble() ?? 0,
      completed: map['completed'] as bool? ?? false,
      photoTargetLabel: map['photoTargetLabel'] as String?,
      photoUrl: map['photoUrl'] as String?,
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'businessId': businessId,
      'businessName': businessName,
      'type': type.name,
      'targetLatitude': targetLatitude,
      'targetLongitude': targetLongitude,
      'completed': completed,
      'photoTargetLabel': photoTargetLabel,
      'photoUrl': photoUrl,
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
    };
  }
}

/// A dynamically generated side quest, made up of one or more
/// [MissionCheckpoint]s.
///
/// Two kinds of missions exist, distinguished by [campaignId]:
///
/// - **Daily missions** (`campaignId == null`): exactly 3 are generated
///   per tourist per calendar day (Malaysia time). A fresh batch fully
///   replaces the previous day's, even if some were left incomplete —
///   there's no carryover. Within a single day, a daily mission that
///   hasn't been started yet (no completed checkpoints) will have its
///   checkpoints re-targeted to the tourist's current city if they've
///   moved since it was generated — see [MissionService.syncDailyMissions].
///   A mission with at least one completed checkpoint is left alone
///   regardless of city changes, so a tourist never loses progress by
///   moving around mid-mission.
///
/// - **Campaign missions** (`campaignId != null`): created once per
///   active merchant [Campaign] the tourist is near, independent of the
///   daily-3 count and the once-per-day generation cycle. A campaign
///   mission persists for as long as its campaign stays active, and is
///   marked expired automatically once the campaign ends. Completing one
///   awards the campaign's real voucher (via
///   [MerchantRepository.claimVoucher]), not a generic placeholder.
class Mission {
  const Mission({
    required this.id,
    required this.title,
    required this.description,
    required this.rewardType,
    required this.status,
    required this.checkpoints,
    required this.generatedAt,
    required this.expiresAt,
    this.expReward = 0,
    this.voucherLabel,
    this.scheduledStartAt,
    this.city,
    this.campaignId,
  });

  final String id;
  final String title;
  final String description;
  final MissionRewardType rewardType;
  final MissionStatus status;
  final List<MissionCheckpoint> checkpoints;
  final DateTime generatedAt;
  final DateTime expiresAt;

  /// Used when rewardType == exp.
  final int expReward;

  /// Used when rewardType == voucher and campaignId is null (the old
  /// generic-placeholder path). Ignored for campaign missions, which
  /// show the campaign's real name/discount instead.
  final String? voucherLabel;

  /// Non-null for scheduled/future missions. Null means the mission is
  /// available to work on immediately. Not currently used by the daily
  /// or campaign generators, kept for forward compatibility.
  final DateTime? scheduledStartAt;

  /// The city this mission's checkpoints currently target. Null for
  /// missions generated before this field existed. Only meaningful for
  /// daily missions — used to detect "tourist moved city, this
  /// not-yet-started mission should be re-targeted."
  final String? city;

  /// Non-null for campaign missions — the id of the [Campaign] this
  /// mission is tied to. Null for ordinary daily missions.
  final String? campaignId;

  bool get isCampaignMission => campaignId != null;

  int get completedCheckpointCount =>
      checkpoints.where((c) => c.completed).length;

  int get totalCheckpointCount => checkpoints.length;

  double get progressFraction => totalCheckpointCount == 0
      ? 0
      : completedCheckpointCount / totalCheckpointCount;

  /// The next checkpoint the tourist needs to reach, or null if all are
  /// already completed.
  MissionCheckpoint? get nextIncompleteCheckpoint {
    for (final c in checkpoints) {
      if (!c.completed) return c;
    }
    return null;
  }

  bool get hasStarted =>
      scheduledStartAt == null || scheduledStartAt!.isBefore(DateTime.now());

  // Defensive parsing: skips individual malformed checkpoints rather
  // than throwing and losing the whole mission, and falls back to safe
  // defaults for rewardType/status on unexpected values.
  factory Mission.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawCheckpoints = data['checkpoints'] as List? ?? const [];
    final checkpoints = <MissionCheckpoint>[];
    for (final item in rawCheckpoints) {
      if (item is Map<String, dynamic>) {
        try {
          checkpoints.add(MissionCheckpoint.fromMap(item));
        } catch (_) {}
      } else if (item is Map) {
        try {
          checkpoints.add(
            MissionCheckpoint.fromMap(Map<String, dynamic>.from(item)),
          );
        } catch (_) {}
      }
    }

    final rewardTypeStr = (data['rewardType'] as String? ?? 'exp')
        .toLowerCase();
    final rewardType =
        MissionRewardType.values.cast<MissionRewardType?>().firstWhere(
              (r) => r?.name.toLowerCase() == rewardTypeStr,
          orElse: () => MissionRewardType.exp,
        ) ??
            MissionRewardType.exp;

    final statusStr = (data['status'] as String? ?? 'active').toLowerCase();
    final status =
        MissionStatus.values.cast<MissionStatus?>().firstWhere(
              (s) => s?.name.toLowerCase() == statusStr,
          orElse: () => MissionStatus.active,
        ) ??
            MissionStatus.active;

    return Mission(
      id: doc.id,
      title: data['title'] as String? ?? 'Mission',
      description: data['description'] as String? ?? '',
      rewardType: rewardType,
      status: status,
      checkpoints: checkpoints,
      generatedAt:
      (data['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt:
      (data['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(days: 1)),
      expReward: (data['expReward'] as num?)?.toInt() ?? 0,
      voucherLabel: data['voucherLabel'] as String?,
      scheduledStartAt: (data['scheduledStartAt'] as Timestamp?)?.toDate(),
      city: data['city'] as String?,
      campaignId: data['campaignId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'rewardType': rewardType.name,
      'status': status.name,
      'checkpoints': checkpoints.map((c) => c.toMap()).toList(),
      'generatedAt': Timestamp.fromDate(generatedAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'expReward': expReward,
      'voucherLabel': voucherLabel,
      'scheduledStartAt': scheduledStartAt != null
          ? Timestamp.fromDate(scheduledStartAt!)
          : null,
      'city': city,
      'campaignId': campaignId,
    };
  }
}

class CheckpointCompletionResult {
  const CheckpointCompletionResult({
    required this.success,
    this.failureReason,
    this.checkpointCompleted = false,
    this.missionCompleted = false,
    this.expAwarded = 0,
    this.voucherAwarded = false,
    this.levelUpResult,
  });

  final bool success;
  final String? failureReason;
  final bool checkpointCompleted;
  final bool missionCompleted;
  final int expAwarded;
  final bool voucherAwarded;
  final ExpAwardResult? levelUpResult;
}

class MissionService {
  MissionService._();
  static final instance = MissionService._();

  FirebaseFirestore? _db;
  FirebaseFirestore get db => _db ?? FirebaseFirestore.instance;
  set db(FirebaseFirestore customDb) => _db = customDb;
  final Random _random = Random();

  // PUBLIC — required by mission_list_screen.dart's pre-camera distance
  // check. Do not make this private again.
  static const double checkpointRadiusMeters = 50;

  static const int _dailyMissionCount = 3;

  // Malaysia is UTC+8 with no DST — matches the day-boundary convention
  // already used elsewhere in the app (see DailyRewardGenerator).
  static const _malaysiaOffset = Duration(hours: 8);

  static DateTime _dayStartUtc(DateTime instant) {
    final malaysiaTime = instant.toUtc().add(_malaysiaOffset);
    return DateTime.utc(
      malaysiaTime.year,
      malaysiaTime.month,
      malaysiaTime.day,
    ).subtract(_malaysiaOffset);
  }

  CollectionReference<Map<String, dynamic>> _missionsRef(String uid) =>
      db.collection('users').doc(uid).collection('missions');

  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
            cos(_degToRad(lat1)) *
                cos(_degToRad(lat2)) *
                sin(dLon / 2) *
                sin(dLon / 2);
    final c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  double _degToRad(double deg) => deg * (pi / 180);

  /// Distance in meters from [currentLat]/[currentLng] to the mission's
  /// next incomplete checkpoint. Returns null if the mission is already
  /// fully completed.
  double? distanceToNextCheckpoint(
      Mission mission,
      double currentLat,
      double currentLng,
      ) {
    final next = mission.nextIncompleteCheckpoint;
    if (next == null) return null;
    return _distanceMeters(
      currentLat,
      currentLng,
      next.targetLatitude,
      next.targetLongitude,
    );
  }

  /// Live stream of a tourist's missions (all statuses) for use in a
  /// StreamBuilder. Defensive: skips individual malformed documents and
  /// guards against an empty uid rather than throwing.
  Stream<List<Mission>> watchMissions(String uid) {
    if (uid.trim().isEmpty) {
      return Stream.value(const <Mission>[]);
    }
    try {
      return _missionsRef(uid)
          .orderBy('generatedAt', descending: true)
          .snapshots()
          .map(
            (snap) => snap.docs
            .map((doc) {
          try {
            return Mission.fromDoc(doc);
          } catch (_) {
            return null;
          }
        })
            .whereType<Mission>()
            .toList(),
      )
          .handleError((_) => const <Mission>[]);
    } catch (_) {
      return Stream.value(const <Mission>[]);
    }
  }

  /// Fetches active businesses (with real coordinates set) whose
  /// `address` mentions [city] (case-insensitive substring match —
  /// `Business` has no dedicated city field, just a free-text address).
  /// Falls back to ALL active, geolocated businesses if none match, so
  /// mission generation doesn't silently stop working in areas with
  /// sparse/inconsistent address data.
  Future<List<Business>> _businessesInCity(String? city) async {
    final snapshot = await db
        .collection('businesses')
        .where('active', isEqualTo: true)
        .limit(50)
        .get();

    final all = snapshot.docs
        .map(Business.fromDoc)
        .where((b) => b.latitude != null && b.longitude != null)
        .toList();

    if (city == null || city.trim().isEmpty) return all;

    final lowerCity = city.toLowerCase();
    final matching = all
        .where((b) => b.address.toLowerCase().contains(lowerCity))
        .toList();

    return matching.isNotEmpty ? matching : all;
  }

  List<MissionCheckpoint> _buildCheckpoints(
      List<Business> businesses,
      int startIndex,
      int checkpointCount,
      ) {
    if (businesses.isEmpty) return const [];
    final checkpoints = <MissionCheckpoint>[];
    for (var c = 0; c < checkpointCount; c++) {
      // Wraps around rather than running out, so a sparse area (as few
      // as 1 business) still fills every checkpoint slot instead of
      // silently generating fewer missions than the daily count.
      final business = businesses[(startIndex + c) % businesses.length];
      final type = _random.nextBool() ? MissionType.visit : MissionType.photo;
      checkpoints.add(
        MissionCheckpoint(
          businessId: business.id,
          businessName: business.name,
          type: type,
          targetLatitude: business.latitude!,
          targetLongitude: business.longitude!,
          completed: false,
        ),
      );
    }
    return checkpoints;
  }

  /// Main entry point — call this whenever the Rewards/Missions screen
  /// loads with a current position. Handles all three responsibilities:
  /// generating today's 3 daily missions if they haven't been generated
  /// yet today, re-targeting not-yet-started daily missions to the
  /// tourist's current city if they've moved, and keeping campaign
  /// missions in sync (creating new ones for newly-eligible campaigns,
  /// expiring ones whose campaign has ended).
  Future<void> ensureMissionsUpToDate(
      String uid, {
        required double currentLat,
        required double currentLng,
      }) async {
    final city = await CityResolver.instance.resolveCity(
      currentLat,
      currentLng,
    );

    await _ensureDailyMissions(uid, city: city);
    await _syncDailyMissionsToCity(uid, city: city);
    await _syncCampaignMissions(uid, city: city);
  }

  /// Backward-compatible alias for [ensureMissionsUpToDate] returning active missions.
  Future<List<Mission>> generateDailyMissions(
    String uid, {
    required double currentLat,
    required double currentLng,
    int count = 3,
  }) async {
    await ensureMissionsUpToDate(
      uid,
      currentLat: currentLat,
      currentLng: currentLng,
    );
    final snap = await _missionsRef(
      uid,
    ).where('status', isEqualTo: MissionStatus.active.name).get();
    return snap.docs.map(Mission.fromDoc).toList();
  }

  /// Generates today's 3 daily missions if they haven't been generated
  /// yet today (Malaysia time). Expires any leftover daily missions
  /// from a previous day — daily missions don't carry over.
  Future<void> _ensureDailyMissions(String uid, {String? city}) async {
    final userRef = db.collection('users').doc(uid);
    final now = DateTime.now();
    final todayStart = _dayStartUtc(now);

    // Transaction so two near-simultaneous app opens (e.g. two tabs)
    // can't both decide "not generated yet" and double-generate.
    final shouldGenerate = await db.runTransaction<bool>((transaction) async {
      final snapshot = await transaction.get(userRef);
      final data = snapshot.data() ?? {};
      final lastGenerated = (data['lastMissionGenerationDate'] as Timestamp?)
          ?.toDate();

      if (lastGenerated != null &&
          !_dayStartUtc(lastGenerated).isBefore(todayStart)) {
        return false; // already generated today
      }

      transaction.update(userRef, {
        'lastMissionGenerationDate': Timestamp.fromDate(now),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });

    if (!shouldGenerate) return;

    // Expire any daily (non-campaign) missions still active from before
    // today — a new day means a fresh set of exactly 3, no carryover.
    final existing = await _missionsRef(
      uid,
    ).where('status', isEqualTo: MissionStatus.active.name).get();

    final batch = db.batch();
    for (final doc in existing.docs) {
      final data = doc.data();
      if (data['campaignId'] != null) continue; // campaign missions persist
      batch.update(doc.reference, {'status': MissionStatus.expired.name});
    }
    await batch.commit();

    final businessDocs = await _businessesInCity(city);
    if (businessDocs.isEmpty) return;

    final businesses = [...businessDocs]..shuffle(_random);
    var businessIndex = 0;

    for (var i = 0; i < _dailyMissionCount; i++) {
      // Capped so a single mission never repeats the same business
      // within itself — separate missions can still reuse it via the
      // wrapping index above.
      final checkpointCount = min(1 + _random.nextInt(3), businesses.length);
      final checkpoints = _buildCheckpoints(
        businesses,
        businessIndex,
        checkpointCount,
      );
      businessIndex += checkpoints.length;

      final areaLabel = checkpoints.first.businessName;
      final expReward = 20 * checkpoints.length + _random.nextInt(20);
      final mission = Mission(
        id: '',
        title: checkpoints.length > 1
            ? 'Explore $areaLabel'
            : 'Visit $areaLabel',
        description: checkpoints.length > 1
            ? 'Complete all ${checkpoints.length} checkpoints around $areaLabel.'
            : 'Head over to $areaLabel to complete this quest.',
        rewardType: MissionRewardType.exp,
        expReward: expReward,
        status: MissionStatus.active,
        checkpoints: checkpoints,
        generatedAt: now,
        expiresAt: todayStart.add(const Duration(days: 1)),
        city: city,
      );

      await _missionsRef(uid).add(mission.toMap());
    }
  }

  /// Re-targets any daily mission that hasn't been started yet (zero
  /// completed checkpoints) and whose stored `city` no longer matches
  /// the tourist's current city. Missions with at least one completed
  /// checkpoint are left untouched, so moving around never costs
  /// progress already made.
  Future<void> _syncDailyMissionsToCity(String uid, {String? city}) async {
    if (city == null || city.trim().isEmpty) return;

    final existing = await _missionsRef(
      uid,
    ).where('status', isEqualTo: MissionStatus.active.name).get();

    final toResync = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final doc in existing.docs) {
      final mission = Mission.fromDoc(doc);
      if (mission.isCampaignMission) continue;
      if (mission.completedCheckpointCount > 0) continue;
      if (mission.city == city) continue;
      toResync.add(doc);
    }
    if (toResync.isEmpty) return;

    final businessDocs = await _businessesInCity(city);
    if (businessDocs.isEmpty) return;

    final businesses = [...businessDocs]..shuffle(_random);
    var businessIndex = 0;

    final batch = db.batch();
    for (final doc in toResync) {
      final mission = Mission.fromDoc(doc);
      final checkpointCount = min(mission.checkpoints.length, businesses.length);
      final newCheckpoints = _buildCheckpoints(
        businesses,
        businessIndex,
        checkpointCount,
      );
      businessIndex += newCheckpoints.length;

      final areaLabel = newCheckpoints.first.businessName;
      batch.update(doc.reference, {
        'checkpoints': newCheckpoints.map((c) => c.toMap()).toList(),
        'city': city,
        'title': checkpointCount > 1
            ? 'Explore $areaLabel'
            : 'Visit $areaLabel',
        'description': checkpointCount > 1
            ? 'Complete all $checkpointCount checkpoints around $areaLabel.'
            : 'Head over to $areaLabel to complete this quest.',
      });
    }
    await batch.commit();
  }

  /// Creates a mission for each active voucher [Campaign] belonging to a
  /// business in the tourist's current city that they don't already have
  /// a mission for (in ANY status — completing one doesn't spawn a
  /// repeat), and expires any existing campaign mission whose campaign
  /// is no longer active. Runs every call, independent of the
  /// once-per-day daily-mission gate.
  Future<void> _syncCampaignMissions(String uid, {String? city}) async {
    final existing = await _missionsRef(uid).get();
    final existingCampaignMissions = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in existing.docs) {
      final campaignId = doc.data()['campaignId'] as String?;
      if (campaignId != null) {
        existingCampaignMissions[campaignId] = doc;
      }
    }

    final campaignSnap = await db
        .collection('campaigns')
        .where('type', isEqualTo: 'voucher')
        .where('status', isEqualTo: 'active')
        .get();
    final activeCampaigns = campaignSnap.docs.map(Campaign.fromDoc).toList();
    final activeCampaignIds = activeCampaigns.map((c) => c.id).toSet();

    final batch = db.batch();
    var hasWrites = false;

    // Expire missions whose campaign is no longer active.
    for (final entry in existingCampaignMissions.entries) {
      final data = entry.value.data();
      if (data['status'] != MissionStatus.active.name) continue;
      if (!activeCampaignIds.contains(entry.key)) {
        batch.update(entry.value.reference, {
          'status': MissionStatus.expired.name,
        });
        hasWrites = true;
      }
    }

    // Create missions for newly-eligible campaigns in this city.
    if (city != null && city.trim().isNotEmpty) {
      final lowerCity = city.toLowerCase();
      for (final campaign in activeCampaigns) {
        if (existingCampaignMissions.containsKey(campaign.id)) continue;

        final businessDoc = await db
            .collection('businesses')
            .doc(campaign.businessId)
            .get();
        if (!businessDoc.exists) continue;
        final business = Business.fromDoc(businessDoc);
        if (business.latitude == null || business.longitude == null) continue;
        // Strict match only — a campaign mission shouldn't appear for a
        // business in a city the tourist isn't currently in, unlike
        // regular missions which fall back to "all" when nothing matches.
        if (!business.address.toLowerCase().contains(lowerCity)) continue;

        final discountLabel = campaign.discountType == 'percentage'
            ? '${campaign.discountValue.toStringAsFixed(0)}% off'
            : 'RM${campaign.discountValue.toStringAsFixed(2)} off';

        final mission = Mission(
          id: '',
          title: 'Special offer: ${campaign.name}',
          description:
          'Visit ${business.name} for $discountLabel — ${campaign.name}.',
          rewardType: MissionRewardType.voucher,
          voucherLabel: discountLabel,
          status: MissionStatus.active,
          checkpoints: [
            MissionCheckpoint(
              businessId: business.id,
              businessName: business.name,
              type: MissionType.visit,
              targetLatitude: business.latitude!,
              targetLongitude: business.longitude!,
              completed: false,
            ),
          ],
          generatedAt: DateTime.now(),
          expiresAt: campaign.endDate,
          city: city,
          campaignId: campaign.id,
        );

        final ref = _missionsRef(uid).doc();
        batch.set(ref, mission.toMap());
        hasWrites = true;
      }
    }

    if (hasWrites) await batch.commit();
  }

  /// Uploads the photo at [imagePath] to Cloudinary as a record of the
  /// checkpoint visit. Returns null (rather than throwing) if the upload
  /// fails, so a flaky connection doesn't block a real physical visit —
  /// the distance check already confirmed the tourist was on location;
  /// this photo is a keepsake/record, not a gatekeeping mechanism.
  Future<String?> _uploadCompletionPhoto(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final uploaded = await CloudinaryImages.instance.upload(bytes);
      return uploaded.url;
    } catch (_) {
      return null;
    }
  }

  /// Attempts to complete the next incomplete checkpoint of [missionId]
  /// for [uid]. If this was the mission's last checkpoint, the mission
  /// itself is marked completed and the reward is awarded: EXP for
  /// daily EXP missions, the real campaign voucher for campaign
  /// missions (via [MerchantRepository.claimVoucher]), or a generic
  /// placeholder voucher for any other voucher-type mission.
  ///
  /// [photoPath] is required (and used) only when the next checkpoint is
  /// a [MissionType.photo] checkpoint — pass the file path returned by
  /// `ImagePicker().pickImage(source: ImageSource.camera)`.
  Future<CheckpointCompletionResult> completeNextCheckpoint(
      String uid,
      String missionId, {
        required double currentLat,
        required double currentLng,
        String? photoPath,
      }) async {
    final missionRef = _missionsRef(uid).doc(missionId);
    final snapshot = await missionRef.get();

    if (!snapshot.exists) {
      return const CheckpointCompletionResult(
        success: false,
        failureReason: 'Mission not found.',
      );
    }

    final mission = Mission.fromDoc(snapshot);

    if (mission.status != MissionStatus.active) {
      return const CheckpointCompletionResult(
        success: false,
        failureReason: 'Mission is no longer active.',
      );
    }

    if (!mission.hasStarted) {
      return const CheckpointCompletionResult(
        success: false,
        failureReason: "This mission hasn't started yet.",
      );
    }

    final checkpointIndex = mission.checkpoints.indexWhere(
          (c) => !c.completed,
    );
    if (checkpointIndex == -1) {
      return const CheckpointCompletionResult(
        success: false,
        failureReason: 'All checkpoints already completed.',
      );
    }

    final checkpoint = mission.checkpoints[checkpointIndex];

    // Distance is checked for BOTH checkpoint types — a photo mission is
    // still a location-based mission, it just also asks for a photo.
    final distance = _distanceMeters(
      currentLat,
      currentLng,
      checkpoint.targetLatitude,
      checkpoint.targetLongitude,
    );
    if (distance > checkpointRadiusMeters) {
      return CheckpointCompletionResult(
        success: false,
        failureReason:
        'Too far away (${distance.round()}m) — get closer to complete this checkpoint.',
      );
    }

    String? uploadedPhotoUrl;
    if (checkpoint.type == MissionType.photo) {
      if (photoPath == null) {
        return const CheckpointCompletionResult(
          success: false,
          failureReason: 'Take a photo to complete this checkpoint.',
        );
      }
      uploadedPhotoUrl = await _uploadCompletionPhoto(photoPath);
    }

    final updatedCheckpoints = List<MissionCheckpoint>.from(
      mission.checkpoints,
    );
    updatedCheckpoints[checkpointIndex] = checkpoint.copyWith(
      completed: true,
      completedAt: DateTime.now(),
      photoUrl: uploadedPhotoUrl,
    );

    final allCompleted = updatedCheckpoints.every((c) => c.completed);

    await missionRef.update({
      'checkpoints': updatedCheckpoints.map((c) => c.toMap()).toList(),
      if (allCompleted) 'status': MissionStatus.completed.name,
    });

    if (!allCompleted) {
      return const CheckpointCompletionResult(
        success: true,
        checkpointCompleted: true,
      );
    }

    if (mission.rewardType == MissionRewardType.exp) {
      final awardResult = await RewardService.instance.awardExp(
        uid,
        mission.expReward,
        reason: 'mission_completed',
      );
      return CheckpointCompletionResult(
        success: true,
        checkpointCompleted: true,
        missionCompleted: true,
        expAwarded: mission.expReward,
        levelUpResult: awardResult.leveledUp ? awardResult : null,
      );
    }

    if (mission.campaignId != null) {
      try {
        final campaignDoc = await db
            .collection('campaigns')
            .doc(mission.campaignId)
            .get();
        if (campaignDoc.exists) {
          final campaign = Campaign.fromDoc(campaignDoc);
          await MerchantRepository.instance.claimVoucher(
            userId: uid,
            voucherId: campaign.id,
            businessId: campaign.businessId,
            voucherType: campaign.voucherType,
          );
        }
      } catch (_) {
        // e.g. already claimed elsewhere — the mission still completes,
        // it just doesn't grant a second copy of the same voucher.
      }
      return const CheckpointCompletionResult(
        success: true,
        checkpointCompleted: true,
        missionCompleted: true,
        voucherAwarded: true,
      );
    }

    // Fallback: generic placeholder voucher for any non-campaign
    // voucher-type mission (kept for backward compatibility with older
    // mission documents; new generation no longer produces these).
    await RewardService.instance.awardVoucher(uid, source: 'mission_completed');
    return const CheckpointCompletionResult(
      success: true,
      checkpointCompleted: true,
      missionCompleted: true,
      voucherAwarded: true,
    );
  }
}