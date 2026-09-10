import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'city_resolver.dart';
import 'reward_service.dart';

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
    return MissionCheckpoint(
      businessId: map['businessId'] as String? ?? '',
      businessName: map['businessName'] as String? ?? '',
      type: MissionType.values.byName(map['type'] as String? ?? 'visit'),
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
/// STUB WARNING: checkpoint coordinates are NOT real business locations —
/// see `_stubNearbyOffset()` in [MissionService]. Swap once `Business`
/// has real lat/lng fields.
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
    final checkpointMaps = (data['checkpoints'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    return Mission(
      id: doc.id,
      title: data['title'] as String? ?? 'Mission',
      description: data['description'] as String? ?? '',
      rewardType: MissionRewardType.values.byName(
        data['rewardType'] as String? ?? 'exp',
      ),
      status: MissionStatus.values.byName(
        data['status'] as String? ?? 'active',
      ),
      checkpoints: checkpointMaps.map(MissionCheckpoint.fromMap).toList(),
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
    this.missionCompleted = false,
    this.expAwarded = 0,
    this.voucherAwarded = false,
    this.levelUpResult,
  });

  final bool success;
  final String? failureReason;
  final bool missionCompleted;
  final int expAwarded;
  final bool voucherAwarded;
  final ExpAwardResult? levelUpResult;
}

class MissionService {
  MissionService._();
  static final instance = MissionService._();

  final FirebaseFirestore db = FirebaseFirestore.instance;
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

  /// STUB: fake target coordinate near the tourist's current position.
  /// Replace with real business lat/lng once available.
  _StubCoords _stubNearbyOffset(
      double lat,
      double lng,
      double minM,
      double maxM,
      ) {
    final distanceMeters = minM + _random.nextDouble() * (maxM - minM);
    final angle = _random.nextDouble() * 2 * pi;
    final dLat = (distanceMeters * cos(angle)) / 111320;
    final dLng =
        (distanceMeters * sin(angle)) /
            (111320 * cos(_degToRad(lat)).abs().clamp(0.01, 1.0));
    return _StubCoords(lat + dLat, lng + dLng);
  }

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
    return _missionsRef(uid)
        .orderBy('generatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Mission.fromDoc).toList());
  }

  /// Fetches active businesses whose `address` mentions [city]
  /// (case-insensitive substring match — `Business` has no dedicated
  /// city field, just a free-text address, so this is the best filter
  /// available without a schema change). Falls back to ALL active
  /// businesses if none match, so mission generation doesn't silently
  /// stop working in areas with sparse/inconsistent address data.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _businessesInCity(String? city) async {
    final snapshot = await db
        .collection('businesses')
        .where('active', isEqualTo: true)
        .limit(50)
        .get();

    if (city == null || city.trim().isEmpty) return snapshot.docs;

    final lowerCity = city.toLowerCase();
    final matching = snapshot.docs.where((doc) {
      final address = (doc.data()['address'] as String? ?? '').toLowerCase();
      return address.contains(lowerCity);
    }).toList();

    // If address text doesn't actually contain the city name for any
    // business (inconsistent data entry, or businesses just outside the
    // resolved city), fall back to the unfiltered list rather than
    // generating zero missions.
    return matching.isNotEmpty ? matching : snapshot.docs;
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

    final businesses = businessDocs.toList()..shuffle(_random);
    final toGenerate = count - existingActive.docs.length;
    final newMissions = <Mission>[];
    var businessIndex = 0;

    for (var i = 0; i < toGenerate; i++) {
      if (businessIndex >= businesses.length) break;

      // Every third generated mission is a scheduled voucher mission;
      // the rest are immediate EXP missions with 1-3 checkpoints.
      final isVoucherMission = i % 3 == 2;

      if (isVoucherMission) {
        final businessDoc = businesses[businessIndex++];
        final businessData = businessDoc.data();
        final businessName = businessData['name'] as String? ?? 'a business';
        final coords = _stubNearbyOffset(currentLat, currentLng, 400, 900);
        final nextSaturday = _nextWeekday(DateTime.saturday);

        final mission = Mission(
          id: '',
          title: 'Weekend Market Walk',
          description: 'Visit $businessName during the weekend market event.',
          rewardType: MissionRewardType.voucher,
          voucherLabel: 'Voucher',
          status: MissionStatus.active,
          scheduledStartAt: nextSaturday,
          checkpoints: [
            MissionCheckpoint(
              businessId: businessDoc.id,
              businessName: businessName,
              type: MissionType.visit,
              targetLatitude: coords.lat,
              targetLongitude: coords.lng,
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
        final businessDoc = businesses[businessIndex++];
        final businessData = businessDoc.data();
        final businessName = businessData['name'] as String? ?? 'a business';
        if (c == 0) areaLabel = businessName;
        final coords = _stubNearbyOffset(currentLat, currentLng, 30, 400);
        final type = _random.nextBool()
            ? MissionType.visit
            : MissionType.photo;

        checkpoints.add(
          MissionCheckpoint(
            businessId: businessDoc.id,
            businessName: businessName,
            type: type,
            targetLatitude: coords.lat,
            targetLongitude: coords.lng,
            completed: false,
            photoTargetLabel: type == MissionType.photo ? businessName : null,
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

  /// STUB: always passes. Swap for real ML Kit / image-labeling logic
  /// later — nothing else in [completeNextCheckpoint] needs to change.
  bool _stubVerifyPhoto(MissionCheckpoint checkpoint) => true;

  /// Attempts to complete the next incomplete checkpoint of [missionId]
  /// for [uid]. If this was the mission's last checkpoint, the mission
  /// itself is marked completed and the reward (EXP or voucher) is
  /// awarded via [RewardService].
  Future<CheckpointCompletionResult> completeNextCheckpoint(
      String uid,
      String missionId, {
        required double currentLat,
        required double currentLng,
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
      if (!_stubVerifyPhoto(checkpoint)) {
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

class _StubCoords {
  const _StubCoords(this.lat, this.lng);
  final double lat;
  final double lng;
}