import 'package:shared_preferences/shared_preferences.dart';

import '../core/map_test_config.dart';

import '../models/localquest_models.dart';

import 'daily_reward_generator.dart';
import 'demo_business_voucher_claim_store.dart';

import 'package:flutter/foundation.dart';

class DemoBusinessVoucherSaveResult {
  const DemoBusinessVoucherSaveResult({
    required this.status,
    required this.store,
  });

  final DemoBusinessVoucherClaimStatus status;
  final DemoBusinessVoucherClaimStore store;
}

/// Local demo history only. No real voucher issuance or Firebase writes.
class DemoBusinessVoucherClaimPersistence {
  // Separate from map-marker collection history.
  static const _storageKey = 'localquest.map.demo.business_voucher_claims.v1';

  static bool _failNextWrite = const bool.fromEnvironment(
    'MAP_DEMO_BUSINESS_VOUCHER_FAIL_WRITE_ONCE',
  );

  static const _delaySave = bool.fromEnvironment(
    'MAP_DEMO_BUSINESS_VOUCHER_DELAY_SAVE',
  );

  static Future<void> _writePhoneStorage(String value) async {
    // MapTestConfig.enabled is restricted to debug builds.
    if (MapTestConfig.enabled && _failNextWrite) {
      _failNextWrite = false;
      throw StateError('Simulated business-voucher claim save failure.');
    }

    await _preferences.setString(_storageKey, value);

    if (MapTestConfig.enabled && _delaySave) {
      debugPrint('Business-voucher demo save started: waiting 8 seconds.');
      await Future<void>.delayed(const Duration(seconds: 8));
    }

    if (MapTestConfig.enabled && _delaySave) {
      debugPrint('Business-voucher demo save completed.');
    }
  }

  static final _preferences = SharedPreferencesAsync();

  static final _instance = DemoBusinessVoucherClaimPersistence.withStorage(
    read: () => _preferences.getString(_storageKey),
    write: _writePhoneStorage,
  );

  factory DemoBusinessVoucherClaimPersistence() => _instance;

  DemoBusinessVoucherClaimPersistence.withStorage({
    required Future<String?> Function() read,
    required Future<void> Function(String) write,
  }) : _read = read,
       _write = write;

  final Future<String?> Function() _read;
  final Future<void> Function(String) _write;

  Future<void> _pendingWrite = Future<void>.value();
  bool _loadedSuccessfully = false;

  Future<DemoBusinessVoucherClaimStore> load() async {
    await _pendingWrite;
    _loadedSuccessfully = false;

    final saved = await _read();

    // Corrupt data must not silently become empty claim history.
    final store = saved == null
        ? DemoBusinessVoucherClaimStore()
        : DemoBusinessVoucherClaimStore.fromSnapshot(saved);

    _loadedSuccessfully = true;
    return store;
  }

  /// Caller must check fresh eligibility first and serialize claim attempts.
  ///
  /// The supplied history is never mutated. On success, the caller must
  /// replace its shared history with the returned store before another claim.
  /// Storage failures propagate to the caller; no success is returned.
  Future<DemoBusinessVoucherSaveResult> recordAndSave({
    required DemoBusinessVoucherClaimStore currentStore,
    required String touristId,
    required Business business,
    required MapVoucherOffer offer,
    required DateTime now,
  }) async {
    final candidate = DemoBusinessVoucherClaimStore.fromSnapshot(
      currentStore.exportSnapshot(),
    );

    final status = candidate.recordDemoClaim(
      touristId: touristId,
      business: business,
      offer: offer,
      now: now,
    );

    if (status != DemoBusinessVoucherClaimStatus.recorded) {
      return DemoBusinessVoucherSaveResult(status: status, store: currentStore);
    }

    await save(candidate);

    return DemoBusinessVoucherSaveResult(status: status, store: candidate);
  }

  Future<void> save(DemoBusinessVoucherClaimStore store) async {
    if (!_loadedSuccessfully) {
      throw StateError(
        'Load business-voucher claim history successfully before saving.',
      );
    }

    // Capture now, so later changes cannot alter a queued snapshot.
    final snapshot = store.exportSnapshot();
    final operation = _pendingWrite.then((_) => _write(snapshot));

    // A failed write reaches its caller without blocking future retries.
    _pendingWrite = operation.catchError((Object _) {});

    await operation;
  }
}
