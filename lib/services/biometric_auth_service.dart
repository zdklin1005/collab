import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class BiometricAuthService {
  static BiometricAuthService instance = LocalBiometricAuthService();

  Future<bool> isSupported();
  Future<bool> isEnabled([String? userId]);
  Future<void> setEnabled(bool enabled, [String? userId]);
  Future<bool> authenticate({required String localizedReason});
  Future<void> saveLastUser({
    required String email,
    required String role,
    String? token,
  });
  Future<Map<String, String>?> getLastUser();
  Future<void> clearLastUser();
  bool consumeJustAuthenticated();
  void markJustAuthenticated();
  bool isSessionAuthenticated(String userId);
  void markSessionAuthenticated(String userId);
  void clearSessionAuthentication([String? userId]);
}

class LocalBiometricAuthService implements BiometricAuthService {
  LocalBiometricAuthService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;
  bool _justAuthenticated = false;
  final Set<String> _sessionAuthenticatedUserIds = {};

  @override
  bool isSessionAuthenticated(String userId) =>
      _sessionAuthenticatedUserIds.contains(userId);

  @override
  void markSessionAuthenticated(String userId) {
    _sessionAuthenticatedUserIds.add(userId);
  }

  @override
  void clearSessionAuthentication([String? userId]) {
    if (userId != null) {
      _sessionAuthenticatedUserIds.remove(userId);
    } else {
      _sessionAuthenticatedUserIds.clear();
    }
  }

  @override
  bool consumeJustAuthenticated() {
    final val = _justAuthenticated;
    _justAuthenticated = false;
    return val;
  }

  @override
  void markJustAuthenticated() {
    _justAuthenticated = true;
  }

  static const _enabledKey = 'lq_biometrics_enabled';
  static const _savedEmailKey = 'lq_biometrics_email';
  static const _savedRoleKey = 'lq_biometrics_role';
  static const _savedTokenKey = 'lq_biometrics_token';

  @override
  Future<bool> isSupported() async {
    if (kIsWeb) return false;
    try {
      final isDeviceSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return isDeviceSupported || canCheck;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isEnabled([String? userId]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (userId != null && userId.isNotEmpty) {
        final userVal = prefs.getBool('${_enabledKey}_$userId');
        if (userVal != null) return userVal;
      }
      return prefs.getBool(_enabledKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> setEnabled(bool enabled, [String? userId]) async {
    final prefs = await SharedPreferences.getInstance();
    if (userId != null && userId.isNotEmpty) {
      await prefs.setBool('${_enabledKey}_$userId', enabled);
    }
    await prefs.setBool(_enabledKey, enabled);
    if (!enabled) {
      await clearLastUser();
    }
  }

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    try {
      final supported = await isSupported();
      if (!supported) return false;

      return await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> saveLastUser({
    required String email,
    required String role,
    String? token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedEmailKey, email);
    await prefs.setString(_savedRoleKey, role);
    if (token != null) {
      await prefs.setString(_savedTokenKey, token);
    }
  }

  @override
  Future<Map<String, String>?> getLastUser() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_savedEmailKey);
    final role = prefs.getString(_savedRoleKey);
    if (email == null || role == null) return null;
    return {
      'email': email,
      'role': role,
      'token': prefs.getString(_savedTokenKey) ?? '',
    };
  }

  @override
  Future<void> clearLastUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedEmailKey);
    await prefs.remove(_savedRoleKey);
    await prefs.remove(_savedTokenKey);
  }
}

/// In-memory mock for automated widget and unit testing.
class MockBiometricAuthService implements BiometricAuthService {
  MockBiometricAuthService({
    this.supported = true,
    this.enabled = false,
    this.authSucceeds = true,
    Map<String, String>? initialUser,
  }) : _user = initialUser;

  bool supported;
  bool enabled;
  bool authSucceeds;
  Map<String, String>? _user;

  final Map<String, bool> _userEnabled = {};

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<bool> isEnabled([String? userId]) async {
    if (userId != null && userId.isNotEmpty) {
      if (_userEnabled.containsKey(userId)) {
        return _userEnabled[userId]!;
      }
      return enabled;
    }
    return enabled || _userEnabled.values.any((v) => v);
  }

  @override
  Future<void> setEnabled(bool value, [String? userId]) async {
    if (userId != null && userId.isNotEmpty) {
      _userEnabled[userId] = value;
    } else {
      enabled = value;
    }
    if (!value) _user = null;
  }

  @override
  Future<bool> authenticate({required String localizedReason}) async =>
      authSucceeds;

  @override
  Future<void> saveLastUser({
    required String email,
    required String role,
    String? token,
  }) async {
    _user = {'email': email, 'role': role, 'token': token ?? ''};
  }

  @override
  Future<Map<String, String>?> getLastUser() async => _user;

  @override
  Future<void> clearLastUser() async {
    _user = null;
  }

  bool _justAuthenticated = false;
  final Set<String> _sessionAuthenticatedUserIds = {};

  @override
  bool isSessionAuthenticated(String userId) =>
      _sessionAuthenticatedUserIds.contains(userId);

  @override
  void markSessionAuthenticated(String userId) {
    _sessionAuthenticatedUserIds.add(userId);
  }

  @override
  void clearSessionAuthentication([String? userId]) {
    if (userId != null) {
      _sessionAuthenticatedUserIds.remove(userId);
    } else {
      _sessionAuthenticatedUserIds.clear();
    }
  }

  @override
  bool consumeJustAuthenticated() {
    final val = _justAuthenticated;
    _justAuthenticated = false;
    return val;
  }

  @override
  void markJustAuthenticated() {
    _justAuthenticated = true;
  }
}
