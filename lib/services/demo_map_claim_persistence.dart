import 'package:shared_preferences/shared_preferences.dart';

import 'demo_map_claim_store.dart';

import '../core/map_test_config.dart';

/// Local storage for simulated map claims only.
/// Does not credit EXP, issue vouchers, or update Firebase.
class DemoMapClaimPersistence {
  static const _storageKey = 'localquest.map.demo.claims.v1';

  static bool _failNextRead = const bool.fromEnvironment(
    'MAP_DEMO_FAIL_READ_ONCE',
  );

  static bool _failNextWrite = const bool.fromEnvironment(
    'MAP_DEMO_FAIL_WRITE_ONCE',
  );

  static Future<String?> _readPhoneStorage() async {
    // MapTestConfig.enabled is already restricted to debug builds.
    if (MapTestConfig.enabled && _failNextRead) {
      _failNextRead = false;
      throw StateError('Simulated demo claim read failure.');
    }

    return _preferences.getString(_storageKey);
  }

  static Future<void> _writePhoneStorage(String value) async {
    if (MapTestConfig.enabled && _failNextWrite) {
      _failNextWrite = false;
      throw StateError('Simulated demo claim write failure.');
    }

    await _preferences.setString(_storageKey, value);
  }

  static final _preferences = SharedPreferencesAsync();

  // One shared instance keeps app writes in order.
  static final _instance = DemoMapClaimPersistence.withStorage(
    read: _readPhoneStorage,
    write: _writePhoneStorage,
  );

  factory DemoMapClaimPersistence() => _instance;

  /// Allows tests to substitute storage without using a physical phone.
  DemoMapClaimPersistence.withStorage({
    required Future<String?> Function() read,
    required Future<void> Function(String) write,
  }) : _read = read,
       _write = write;

  final Future<String?> Function() _read;
  final Future<void> Function(String) _write;

  Future<void> _pendingWrite = Future<void>.value();
  bool _loadedSuccessfully = false;

  Future<DemoMapClaimStore> load() async {
    await _pendingWrite;
    _loadedSuccessfully = false;

    final saved = await _read();

    // Only a missing value means a fresh installation.
    // Corrupt data must report an error, not erase claim history.
    final store = saved == null
        ? DemoMapClaimStore()
        : DemoMapClaimStore.fromSnapshot(saved);

    _loadedSuccessfully = true;
    return store;
  }

  Future<void> save(DemoMapClaimStore store) async {
    if (!_loadedSuccessfully) {
      throw StateError('Load demo claim history successfully before saving.');
    }

    // Capture the current state immediately, before waiting in the queue.
    final snapshot = store.exportSnapshot();

    final operation = _pendingWrite.then((_) => _write(snapshot));

    // Keep later attempts usable after a failed write.
    // The original failure still reaches the caller below.
    _pendingWrite = operation.catchError((Object _) {});

    await operation;
  }
}
