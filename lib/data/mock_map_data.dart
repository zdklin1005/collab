import '../models/localquest_models.dart';
import '../models/map_location.dart';
import '../models/reward_checkpoint.dart';
import '../models/reward_marker.dart';

import '../core/map_test_config.dart';

import '../services/daily_reward_generator.dart';

class MockMapData {
  // Fictional records for development only.
  static final double _baseLat = MapTestConfig.centre?.latitude ?? 3.1390;

  static final double _baseLng = MapTestConfig.centre?.longitude ?? 101.6869;

  static final businesses = <Business>[
    Business(
      id: 'mock-business-cafe',
      ownerId: 'mock-merchant-1',
      name: 'Demo Local Café',
      category: 'Food & Beverage',
      address: 'Illustrative test location',
      phone: '',
      latitude: _baseLat,
      longitude: _baseLng,
    ),
    Business(
      id: 'mock-business-crafts',
      ownerId: 'mock-merchant-2',
      name: 'Demo Artisan Shop',
      category: 'Arts & Crafts',
      address: 'Illustrative test location',
      phone: '',
      latitude: _baseLat + 0.0020,
      longitude: _baseLng + 0.0021,
    ),
  ];

  static final landmarks = <MapLocation>[
    MapLocation(
      id: 'mock-landmark-1',
      type: MapLocationType.landmark,
      title: 'Demo Heritage Point',
      description: 'Fictional landmark for testing marker presentation.',
      category: 'Heritage',
      latitude: _baseLat - 0.0012,
      longitude: _baseLng + 0.0013,
    ),
  ];

  // These coordinates are illustrative, not verified safe checkpoints.
  static final checkpoints = <RewardCheckpoint>[
    RewardCheckpoint(
      id: 'mock-checkpoint-cafe-1',
      locationType: MapLocationType.business,
      locationId: 'mock-business-cafe',
      label: 'Café checkpoint A',
      latitude: _baseLat + 0.0003,
      longitude: _baseLng + 0.0003,
    ),
    RewardCheckpoint(
      id: 'mock-checkpoint-crafts-1',
      locationType: MapLocationType.business,
      locationId: 'mock-business-crafts',
      label: 'Artisan checkpoint A',
      latitude: _baseLat + 0.0023,
      longitude: _baseLng + 0.0024,
    ),
    RewardCheckpoint(
      id: 'mock-checkpoint-cafe-2',
      locationType: MapLocationType.business,
      locationId: 'mock-business-cafe',
      label: 'Café checkpoint B',
      latitude: _baseLat - 0.0003,
      longitude: _baseLng - 0.0003,
    ),
    RewardCheckpoint(
      id: 'mock-checkpoint-crafts-2',
      locationType: MapLocationType.business,
      locationId: 'mock-business-crafts',
      label: 'Artisan checkpoint B',
      latitude: _baseLat + 0.0017,
      longitude: _baseLng + 0.0018,
    ),

    RewardCheckpoint(
      id: 'mock-checkpoint-landmark-1',
      locationType: MapLocationType.landmark,
      locationId: 'mock-landmark-1',
      label: 'Heritage checkpoint A',
      latitude: _baseLat - 0.0010,
      longitude: _baseLng + 0.0015,
    ),
  ];

  static List<MapLocation> createLocations() {
    final businessLocations = businesses
        .map(MapLocation.fromBusiness)
        .whereType<MapLocation>();

    return [...businessLocations, ...landmarks];
  }

  //Uses a generator exisitng prototype settings with 80% spawn chance, and 10% voucher chance.
  static List<RewardMarker> createDailyRewards(DateTime instant) {
    final start = DailyRewardGenerator.dayStartUtc(instant);
    final end = start.add(const Duration(days: 1));

    // Fictional offers recreated for each demo day.
    // Real merchant offers must retain their actual validity dates and stock.
    final demoOffers = [
      MapVoucherOffer(
        id: 'mock-voucher-cafe-1',
        businessId: 'mock-business-cafe',
        title: 'Demo café voucher',
        validFrom: start,
        expiresAt: end,
        remainingStock: 100,
      ),
      MapVoucherOffer(
        id: 'mock-voucher-artisan-1',
        businessId: 'mock-business-crafts',
        title: 'Demo artisan voucher',
        validFrom: start,
        expiresAt: end,
        remainingStock: 100,
      ),
    ];

    final forceVouchers = MapTestConfig.forceVoucherRewards;

    return DailyRewardGenerator(
      spawnPercent: forceVouchers ? 100 : 80,
      voucherPercent: forceVouchers ? 100 : 10,
    ).generate(
      activeLandmarkIds: landmarks
          .where(
            (landmark) =>
                landmark.type == MapLocationType.landmark &&
                landmark.canDisplay,
          )
          .map((landmark) => landmark.id)
          .toSet(),

      instant: instant,
      checkpoints: checkpoints,
      activeBusinessIds: businesses
          .where((business) => business.active)
          .map((business) => business.id)
          .toSet(),
      voucherOffers: demoOffers,
    );
  }

  // Creates a predictable test snapshot, not the production spawner.
  // Pass the time explicitly so tests do not depend on today's date.
  static List<RewardMarker> createRewards(DateTime referenceTime) {
    final now = referenceTime.toUtc();

    RewardMarker createReward({
      required RewardCheckpoint checkpoint,
      required String id,
      required String title,
      int expAmount = 0,
      String? voucherId,
      bool active = true,
      bool expired = false,
    }) {
      return RewardMarker(
        id: id,
        checkpointId: checkpoint.id,
        locationType: checkpoint.locationType,
        locationId: checkpoint.locationId,
        type: voucherId == null ? RewardType.exp : RewardType.voucher,
        title: title,
        description: 'Development sample only. Not a real reward.',
        latitude: checkpoint.latitude,
        longitude: checkpoint.longitude,
        expAmount: expAmount,
        voucherId: voucherId,
        availableFrom: now.subtract(const Duration(days: 2)),
        expiresAt: expired
            ? now.subtract(const Duration(days: 1))
            : now.add(const Duration(days: 1)),
        active: active,
      );
    }

    return [
      createReward(
        checkpoint: checkpoints[0],
        id: 'mock-spawn-exp-active',
        title: '100 EXP',
        expAmount: 100,
      ),
      createReward(
        checkpoint: checkpoints[1],
        id: 'mock-spawn-voucher-active',
        title: 'Demo artisan voucher',
        voucherId: 'mock-voucher-artisan-1',
      ),
      createReward(
        checkpoint: checkpoints[2],
        id: 'mock-spawn-exp-expired',
        title: 'Expired EXP sample',
        expAmount: 50,
        expired: true,
      ),
      createReward(
        checkpoint: checkpoints[3],
        id: 'mock-spawn-exp-inactive',
        title: 'Inactive EXP sample',
        expAmount: 50,
        active: false,
      ),
    ];
  }

  // One fixture per app run. Reopening Discover does not renew it.
  static RewardMarker? _expiryTestReward;

  static RewardMarker createExpiryTestReward(DateTime instant) {
    if (!MapTestConfig.expiryRewardEnabled) {
      throw StateError('Expiry test mode is not enabled.');
    }

    return _expiryTestReward ??= _buildExpiryTestReward(instant);
  }

  static RewardMarker _buildExpiryTestReward(DateTime instant) {
    final start = instant.toUtc();
    final isVoucher = MapTestConfig.expiryRewardType == 'voucher';

    return RewardMarker(
      id: 'debug-expiry-${start.microsecondsSinceEpoch}',
      checkpointId: 'debug-expiry-checkpoint',
      locationType: MapLocationType.business,
      locationId: 'mock-business-cafe',
      type: isVoucher ? RewardType.voucher : RewardType.exp,
      title: isVoucher ? 'Expiry test voucher' : 'Expiry test EXP',
      description: 'Debug fixture only. Expires after 90 seconds.',
      latitude: _baseLat - 0.0006,
      longitude: _baseLng + 0.0006,
      expAmount: isVoucher ? 0 : 1,
      voucherId: isVoucher ? 'debug-expiry-offer' : null,
      availableFrom: start,
      expiresAt: start.add(const Duration(seconds: 20)),
    );
  }

  static RewardMarker? _cooldownTestReward;

  static RewardMarker createCooldownTestReward(DateTime instant) {
    if (!MapTestConfig.cooldownTestEnabled) {
      throw StateError('Cooldown test mode is not enabled.');
    }

    return _cooldownTestReward ??= _buildCooldownTestReward(instant);
  }

  static RewardMarker _buildCooldownTestReward(DateTime instant) {
    final start = instant.toUtc();

    return RewardMarker(
      // New spawn on each full app run.
      id: 'debug-cooldown-${start.microsecondsSinceEpoch}',

      // Same checkpoint across runs: the cooldown belongs here.
      checkpointId: 'debug-cooldown-checkpoint',
      locationType: MapLocationType.business,
      locationId: 'mock-business-cafe',
      type: RewardType.exp,
      title: 'Cooldown test EXP',
      description: 'Debug fixture for restart cooldown verification.',
      latitude: _baseLat + 0.0006,
      longitude: _baseLng - 0.0006,
      expAmount: 1,
      availableFrom: start,
      expiresAt: start.add(const Duration(days: 2)),
    );
  }
}
