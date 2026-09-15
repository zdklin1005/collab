import 'package:collab/models/map_location.dart';
import 'package:collab/models/reward_marker.dart';
import 'package:collab/services/live_exp_preview_generator.dart';
import 'package:collab/services/live_map_exp_claim_service.dart';
import 'package:collab/services/map_exp_claim_store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late LiveMapExpClaimService service;
  late MapLocation source;
  late RewardMarker reward;
  late String? signedInUid;

  final now = DateTime.utc(2026, 9, 15, 10);

  setUp(() async {
    db = FakeFirebaseFirestore();
    signedInUid = 'tourist-1';

    service = LiveMapExpClaimService(
      firestore: db,
      currentUserId: () => signedInUid,
      clock: () => now,
    );

    // Find a source selected by the real default generation settings.
    final places = List.generate(
      100,
      (index) => MapLocation(
        id: 'landmark:park-$index',
        sourceDocumentId: 'park-$index',
        type: MapLocationType.landmark,
        title: 'Test park',
        latitude: 5,
        longitude: 100,
        active: true,
        rewardPlacementApproved: true,
      ),
    );

    final generated = generateLiveExpPreviews(places: places, instant: now);

    expect(generated, isNotEmpty);

    reward = generated.first;
    source = places.firstWhere(
      (place) => place.sourceDocumentId == reward.locationId,
    );

    await db.collection('users').doc('tourist-1').set({
      'role': 'tourist',
      'exp': 45,
      'level': 1,
    });

    await db.collection('landmarks').doc(reward.locationId).set({
      'title': source.title,
      'latitude': source.latitude,
      'longitude': source.longitude,
      'active': true,
      'rewardPlacementApproved': true,
    });
  });

  Future<MapExpClaimResult> collect({
    bool simulated = false,
    Future<void> Function()? revalidate,
  }) {
    return service.collect(
      uid: 'tourist-1',
      reward: reward,
      simulationActive: simulated,
      revalidateDeviceAndReward: revalidate ?? () async {},
    );
  }

  Future<int> balance() async {
    final snapshot = await db.collection('users').doc('tourist-1').get();
    return snapshot.data()!['exp'] as int;
  }

  test('approved current source records one real EXP award', () async {
    final result = await collect();

    expect(result.status, MapExpClaimStatus.recorded);
    expect(await balance(), 145);
  });

  test('retrying a collected marker does not award twice', () async {
    await collect();
    final repeated = await collect();

    expect(repeated.status, MapExpClaimStatus.alreadyClaimed);
    expect(await balance(), 145);
  });

  test('removed approval blocks the award', () async {
    await db.collection('landmarks').doc(reward.locationId).update({
      'rewardPlacementApproved': false,
    });

    await expectLater(collect(), throwsA(isA<MapExpClaimBlocked>()));
    expect(await balance(), 45);
  });

  test('moved source rejects the old reward coordinates', () async {
    await db.collection('landmarks').doc(reward.locationId).update({
      'latitude': 5.1,
    });

    await expectLater(collect(), throwsA(isA<MapExpClaimBlocked>()));
    expect(await balance(), 45);
  });

  test('failed final device check leaves no claim or award', () async {
    await expectLater(
      collect(
        revalidate: () async {
          throw const MapExpClaimBlocked('GPS is no longer accurate.');
        },
      ),
      throwsA(isA<MapExpClaimBlocked>()),
    );

    expect(await balance(), 45);

    final user = db.collection('users').doc('tourist-1');
    expect((await user.collection('rewardClaims').get()).docs, isEmpty);
    expect((await user.collection('expLog').get()).docs, isEmpty);
    expect((await user.collection('checkpointCooldowns').get()).docs, isEmpty);
  });

  test('account switch during validation blocks the award', () async {
    await expectLater(
      collect(
        revalidate: () async {
          signedInUid = 'tourist-2';
        },
      ),
      throwsA(isA<MapExpClaimBlocked>()),
    );

    expect(await balance(), 45);
  });

  test('movement simulation cannot award real EXP', () async {
    final result = await collect(simulated: true);

    expect(result.status, MapExpClaimStatus.simulationBlocked);
    expect(await balance(), 45);
  });
}
