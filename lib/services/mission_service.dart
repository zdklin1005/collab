import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import 'city_resolver.dart';
import 'reward_service.dart';
import '../models/localquest_models.dart';

enum MissionType { visit, photo }

enum MissionRewardType { exp, voucher }

enum MissionStatus { active, completed, expired, failed }

// Generic ML Kit image-labeling categories acceptable for each business
// category's photo mission. ML Kit returns broad object labels (e.g.
// "food", "building"), never proper nouns, so this can't check against
// a business's actual name — see _acceptablePhotoLabels() below.
const _photoLabelsByCategory = <String, List<String>>{
  'food & beverage': ['food', 'dish', 'meal', 'cuisine', 'tableware'],
  'cafe': ['coffee', 'food', 'cup'],
  'retail': ['building', 'shop', 'signage'],
};
const _defaultPhotoLabels = ['building', 'signage', 'storefront'];

List<String> _acceptablePhotoLabels(String category) =>
    _photoLabelsByCategory[category.toLowerCase()] ?? _defaultPhotoLabels;

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
    this.completedAt,
  });

  final String businessId;
  final String businessName;
  final MissionType type;
  final double targetLatitude;
  final double targetLongitude;
  final bool completed;
  final String? photoTargetLabel;
  final DateTime? completedAt;

  MissionCheckpoint copyWith({bool? completed, DateTime? completedAt}) {
    return MissionCheckpoint(
      businessId: businessId,
      businessName: businessName,
      type: type,
      targetLatitude: targetLatitude,
      targetLongitude: targetLongitude,
      completed: completed ?? this.completed,
      photoTargetLabel: photoTargetLabel,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  factory MissionCheckpoint.fromMap(Map<String, dynamic> map) {
    final typeStr = (map['type'] as String? ?? 'visit').toLowerCase();
    final type = MissionType.values.cast<MissionType?>().firstWhere(
      (t) => t?.name.toLowerCase() == typeStr,
      orElse: () => MissionType.visit,
    ) ?? MissionType.visit;

    return MissionCheckpoint(
      businessId: map['businessId'] as String? ?? '',
      businessName: map['businessName'] as String? ?? '',
      type: type,
      targetLatitude: (map['targetLatitude'] as num?)?.toDouble() ?? 0,
      targetLongitude: (map['targetLongitude'] as num?)?.toDouble() ?? 0,
      completed: map['completed'] as bool? ?? false,
      photoTargetLabel: map['photoTargetLabel'] as String?,
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
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
    };
  }
}

/// A dynamically generated side quest, made up of one or more
/// [MissionCheckpoint]s.
///
/// Checkpoint coordinates are real business locations, sourced from
/// `Business.latitude`/`Business.longitude` in [MissionService].
/// Businesses without coordinates set are excluded from mission
/// generation entirely (see `_businessesInCity`).
///
/// NOTE ON STATUS: there is no "available/not yet accepted" state by
/// design — a mission exists in Firestore as [MissionStatus.active] the
/// moment it's generated. The UI's "Available" tab is a discovery/refresh
/// affordance (see the mission list screen), not a queue of unaccepted
/// missions.
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

  /// Used when rewardType == voucher, e.g. "Voucher" or a short label.
  final String? voucherLabel;

  /// Non-null for scheduled/future missions (e.g. "Starts Sat"). Null
  /// means the mission is available to work on immediately.
  final DateTime? scheduledStartAt;

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
          checkpoints.add(MissionCheckpoint.fromMap(Map<String, dynamic>.from(item)));
        } catch (_) {}
      }
    }

    final rewardTypeStr = (data['rewardType'] as String? ?? 'exp').toLowerCase();
    final rewardType = MissionRewardType.values.cast<MissionRewardType?>().firstWhere(
      (r) => r?.name.toLowerCase() == rewardTypeStr,
      orElse: () => MissionRewardType.exp,
    ) ?? MissionRewardType.exp;

    final statusStr = (data['status'] as String? ?? 'active').toLowerCase();
    final status = MissionStatus.values.cast<MissionStatus?>().firstWhere(
      (s) => s?.name.toLowerCase() == statusStr,
      orElse: () => MissionStatus.active,
    ) ?? MissionStatus.active;

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

  static const double _checkpointRadiusMeters = 50;

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
  /// StreamBuilder — the "In progress" list stays up to date as
  /// checkpoints are completed elsewhere.
  Stream<List<Mission>> watchMissions(String uid) {
    if (uid.trim().isEmpty) {
      return Stream.value(const <Mission>[]);
    }
    try {
      return _missionsRef(uid)
          .orderBy('generatedAt', descending: true)
          .snapshots()
          .map((snap) => snap.docs.map((doc) {
                try {
                  return Mission.fromDoc(doc);
                } catch (_) {
                  return null;
                }
              }).whereType<Mission>().toList())
          .handleError((_) => const <Mission>[]);
    } catch (_) {
      return Stream.value(const <Mission>[]);
    }
  }

  /// Fetches active businesses (with real coordinates set) whose
  /// `address` mentions [city] (case-insensitive substring match —
  /// `Business` has no dedicated city field, just a free-text address,
  /// so this is the best filter available without a schema change).
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

  /// Generates a mix of missions for [uid] near their current position:
  /// a couple of single/multi-checkpoint EXP missions, and occasionally
  /// a scheduled voucher mission. Skips generation if the tourist already
  /// has [count] or more active missions.
  ///
  /// Businesses are filtered to the tourist's current city, resolved via
  /// reverse-geocoding [currentLat]/[currentLng] (see [CityResolver]) —
  /// see [_businessesInCity] for the matching/fallback behavior, since
  /// `Business` only has a free-text address rather than a proper city
  /// field.
  Future<List<Mission>> generateDailyMissions(
      String uid, {
        required double currentLat,
        required double currentLng,
        int count = 3,
      }) async {
    final existingActive = await _missionsRef(
      uid,
    ).where('status', isEqualTo: MissionStatus.active.name).get();

    if (existingActive.docs.length >= count) {
      return existingActive.docs.map(Mission.fromDoc).toList();
    }

    final city = await CityResolver.instance.resolveCity(
      currentLat,
      currentLng,
    );
    final businessDocs = await _businessesInCity(city);

    if (businessDocs.isEmpty) return [];

    final businesses = [...businessDocs]..shuffle(_random);
    final toGenerate = count - existingActive.docs.length;
    final newMissions = <Mission>[];
    var businessIndex = 0;

    for (var i = 0; i < toGenerate; i++) {
      if (businessIndex >= businesses.length) break;

      // Every third generated mission is a scheduled voucher mission;
      // the rest are immediate EXP missions with 1-3 checkpoints.
      final isVoucherMission = i % 3 == 2;

      if (isVoucherMission) {
        final business = businesses[businessIndex++];
        final nextSaturday = _nextWeekday(DateTime.saturday);

        final mission = Mission(
          id: '',
          title: 'Weekend Market Walk',
          description:
          'Visit ${business.name} during the weekend market event.',
          rewardType: MissionRewardType.voucher,
          voucherLabel: 'Voucher',
          status: MissionStatus.active,
          scheduledStartAt: nextSaturday,
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
          expiresAt: nextSaturday.add(const Duration(days: 2)),
        );

        final docRef = await _missionsRef(uid).add(mission.toMap());
        newMissions.add(Mission.fromDoc(await docRef.get()));
        continue;
      }

      final checkpointCount = 1 + _random.nextInt(3); // 1-3 checkpoints
      final checkpoints = <MissionCheckpoint>[];
      var areaLabel = 'the area';

      for (var c = 0; c < checkpointCount; c++) {
        if (businessIndex >= businesses.length) break;
        final business = businesses[businessIndex++];
        if (c == 0) areaLabel = business.name;
        final type = _random.nextBool()
            ? MissionType.visit
            : MissionType.photo;

        checkpoints.add(
          MissionCheckpoint(
            businessId: business.id,
            businessName: business.name,
            type: type,
            targetLatitude: business.latitude!,
            targetLongitude: business.longitude!,
            completed: false,
            photoTargetLabel: type == MissionType.photo
                ? _acceptablePhotoLabels(business.category).join(',')
                : null,
          ),
        );
      }

      if (checkpoints.isEmpty) break;

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
        generatedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 1)),
      );

      final docRef = await _missionsRef(uid).add(mission.toMap());
      newMissions.add(Mission.fromDoc(await docRef.get()));
    }

    return [...existingActive.docs.map(Mission.fromDoc), ...newMissions];
  }

  DateTime _nextWeekday(int weekday) {
    final now = DateTime.now();
    var daysUntil = (weekday - now.weekday) % 7;
    if (daysUntil == 0) daysUntil = 7;
    return DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: daysUntil));
  }

  /// Runs on-device ML Kit image labeling on the photo at [imagePath] and
  /// checks whether any detected label matches [checkpoint]'s acceptable
  /// labels. The image itself is never uploaded or persisted anywhere —
  /// only this true/false result leaves this function.
  Future<bool> _verifyPhoto(
      MissionCheckpoint checkpoint,
      String imagePath,
      ) async {
    final acceptable = (checkpoint.photoTargetLabel ?? '')
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toSet();
    if (acceptable.isEmpty) return true; // no requirement configured

    final labeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.6),
    );
    try {
      final labels = await labeler.processImage(
        InputImage.fromFilePath(imagePath),
      );
      final detected = labels.map((l) => l.label.toLowerCase()).toSet();
      return detected.any(
            (d) => acceptable.any((a) => d.contains(a) || a.contains(d)),
      );
    } finally {
      await labeler.close(); // release the model; nothing else to clean up
    }
  }

  /// Attempts to complete the next incomplete checkpoint of [missionId]
  /// for [uid]. If this was the mission's last checkpoint, the mission
  /// itself is marked completed and the reward (EXP or voucher) is
  /// awarded via [RewardService].
  ///
  /// [photoPath] is required (and used) only when the next checkpoint is
  /// a [MissionType.photo] checkpoint — pass the file path returned by
  /// `ImagePicker().pickImage(source: ImageSource.camera)`. The file is
  /// only read for on-device labeling here; nothing about it is stored.
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

    if (checkpoint.type == MissionType.visit) {
      final distance = _distanceMeters(
        currentLat,
        currentLng,
        checkpoint.targetLatitude,
        checkpoint.targetLongitude,
      );
      if (distance > _checkpointRadiusMeters) {
        return CheckpointCompletionResult(
          success: false,
          failureReason:
          'Too far away (${distance.round()}m) — get closer to complete this checkpoint.',
        );
      }
    } else {
      if (photoPath == null || !await _verifyPhoto(checkpoint, photoPath)) {
        return const CheckpointCompletionResult(
          success: false,
          failureReason: 'Photo verification failed.',
        );
      }
    }

    final updatedCheckpoints = List<MissionCheckpoint>.from(
      mission.checkpoints,
    );
    updatedCheckpoints[checkpointIndex] = checkpoint.copyWith(
      completed: true,
      completedAt: DateTime.now(),
    );

    final allCompleted = updatedCheckpoints.every((c) => c.completed);

    await missionRef.update({
      'checkpoints': updatedCheckpoints.map((c) => c.toMap()).toList(),
      if (allCompleted) 'status': MissionStatus.completed.name,
    });

    if (!allCompleted) {
      return const CheckpointCompletionResult(success: true);
    }

    if (mission.rewardType == MissionRewardType.exp) {
      final awardResult = await RewardService.instance.awardExp(
        uid,
        mission.expReward,
        reason: 'mission_completed',
      );
      return CheckpointCompletionResult(
        success: true,
        missionCompleted: true,
        expAwarded: mission.expReward,
        levelUpResult: awardResult.leveledUp ? awardResult : null,
      );
    } else {
      await RewardService.instance.awardVoucher(
        uid,
        source: 'mission_completed',
      );
      return const CheckpointCompletionResult(
        success: true,
        missionCompleted: true,
        voucherAwarded: true,
      );
    }
  }
}