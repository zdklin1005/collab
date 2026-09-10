import 'dart:async';

import 'package:collab/models/map_location.dart';
import 'package:collab/models/reward_marker.dart';
import 'package:collab/services/demo_map_claim_persistence.dart';
import 'package:collab/services/demo_map_claim_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 10, 2);

  RewardMarker makeReward() {
    return RewardMarker(
      id: 'test-spawn',
      checkpointId: 'test-checkpoint',
      locationType: MapLocationType.business,
      locationId: 'test-business',
      type: RewardType.exp,
      title: 'Demo EXP',
      latitude: 5,
      longitude: 100,
      expAmount: 100,
      availableFrom: now.subtract(const Duration(hours: 1)),
      expiresAt: now.add(const Duration(hours: 1)),
    );
  }

  void addClaim(DemoMapClaimStore store) {
    expect(
      store.recordDemoClaim(
        touristId: 'tourist-a',
        reward: makeReward(),
        now: now,
      ),
      DemoMapClaimStatus.recorded,
    );
  }

  test('missing storage loads an empty store', () async {
    final persistence = DemoMapClaimPersistence.withStorage(
      read: () async => null,
      write: (_) async {},
    );

    final store = await persistence.load();

    expect(store.claimsFor('tourist-a'), isEmpty);
  });

  test('a new service restores saved claims and cooldown', () async {
    String? saved;

    DemoMapClaimPersistence createService() {
      return DemoMapClaimPersistence.withStorage(
        read: () async => saved,
        write: (value) async {
          saved = value;
        },
      );
    }

    final firstService = createService();
    final store = await firstService.load();
    addClaim(store);

    await firstService.save(store);

    final restored = await createService().load();

    expect(
      restored.hasClaimed(touristId: 'tourist-a', spawnId: 'test-spawn'),
      isTrue,
    );
    expect(
      restored.nextEligibleAt(
        touristId: 'tourist-a',
        checkpointId: 'test-checkpoint',
      ),
      now.add(const Duration(hours: 24)),
    );
    expect(restored.claimsFor('tourist-b'), isEmpty);
  });

  test('saving before loading is rejected', () async {
    var writes = 0;

    final persistence = DemoMapClaimPersistence.withStorage(
      read: () async => null,
      write: (_) async {
        writes++;
      },
    );

    await expectLater(persistence.save(DemoMapClaimStore()), throwsStateError);

    expect(writes, 0);
  });

  test('corrupt storage is not replaced with empty history', () async {
    String? saved = 'broken snapshot';

    final persistence = DemoMapClaimPersistence.withStorage(
      read: () async => saved,
      write: (value) async {
        saved = value;
      },
    );

    await expectLater(persistence.load(), throwsFormatException);

    await expectLater(persistence.save(DemoMapClaimStore()), throwsStateError);

    expect(saved, 'broken snapshot');
  });

  test('read failure is reported and blocks saving', () async {
    final persistence = DemoMapClaimPersistence.withStorage(
      read: () async => throw StateError('Read failed'),
      write: (_) async {},
    );

    await expectLater(persistence.load(), throwsStateError);
    await expectLater(persistence.save(DemoMapClaimStore()), throwsStateError);
  });

  test('a failed save reports the error and allows retry', () async {
    String? saved;
    var shouldFail = true;

    final persistence = DemoMapClaimPersistence.withStorage(
      read: () async => saved,
      write: (value) async {
        if (shouldFail) {
          throw StateError('Write failed');
        }
        saved = value;
      },
    );

    final store = await persistence.load();
    addClaim(store);

    await expectLater(persistence.save(store), throwsStateError);
    expect(saved, isNull);

    shouldFail = false;
    await persistence.save(store);

    final restored = await persistence.load();
    expect(restored.claimsFor('tourist-a'), hasLength(1));
  });

  test('queued saves preserve order and capture separate snapshots', () async {
    final firstWriteStarted = Completer<void>();
    final releaseFirstWrite = Completer<void>();
    final writes = <String>[];

    final persistence = DemoMapClaimPersistence.withStorage(
      read: () async => null,
      write: (value) async {
        if (!firstWriteStarted.isCompleted) {
          firstWriteStarted.complete();
          await releaseFirstWrite.future;
        }
        writes.add(value);
      },
    );

    final store = await persistence.load();

    final firstSave = persistence.save(store);
    await firstWriteStarted.future;

    addClaim(store);
    final secondSave = persistence.save(store);

    releaseFirstWrite.complete();
    await Future.wait([firstSave, secondSave]);

    expect(writes, hasLength(2));
    expect(
      DemoMapClaimStore.fromSnapshot(writes.first).claimsFor('tourist-a'),
      isEmpty,
    );
    expect(
      DemoMapClaimStore.fromSnapshot(writes.last).claimsFor('tourist-a'),
      hasLength(1),
    );
  });
}
