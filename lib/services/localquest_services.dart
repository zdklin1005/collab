import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/localquest_models.dart';
import '../core/merchant_validation.dart';
import '../core/password_policy.dart';
import 'biometric_auth_service.dart';
import 'cloudinary_images.dart';
import 'voucher_code.dart';

class LocalQuestException implements Exception {
  const LocalQuestException(this.message);
  final String message;
  @override
  String toString() => message;
}

class LoginThrottle {
  static const _maximumAttempts = 5;
  static const _lockDuration = Duration(minutes: 10);

  String _key(String email, String suffix) =>
      'login_${base64Url.encode(utf8.encode(email.trim().toLowerCase()))}_$suffix';

  Future<DateTime?> lockedUntil(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final epoch = prefs.getInt(_key(email, 'until'));
    if (epoch == null) return null;
    final value = DateTime.fromMillisecondsSinceEpoch(epoch);
    if (value.isAfter(DateTime.now())) return value;
    await reset(email);
    return null;
  }

  Future<void> recordFailure(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final attemptsKey = _key(email, 'attempts');
    final attempts = (prefs.getInt(attemptsKey) ?? 0) + 1;
    await prefs.setInt(attemptsKey, attempts);
    if (attempts >= _maximumAttempts) {
      await prefs.setInt(
        _key(email, 'until'),
        DateTime.now().add(_lockDuration).millisecondsSinceEpoch,
      );
    }
  }

  Future<void> reset(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(email, 'attempts'));
    await prefs.remove(_key(email, 'until'));
  }
}

class AccountIdentifierCache {
  static const _prefix = 'lq_cached_user_email_';

  /// Stores a local mapping of normalized username to email.
  static Future<void> cache({
    required String username,
    required String email,
  }) async {
    try {
      final clean =
          username.trim().toLowerCase().replaceFirst(RegExp(r'^@'), '');
      final cleanEmail = email.trim().toLowerCase();
      if (clean.isNotEmpty &&
          cleanEmail.isNotEmpty &&
          cleanEmail.contains('@')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('$_prefix$clean', cleanEmail);
      }
    } catch (_) {}
  }

  /// Looks up a cached email by username or identifier.
  static Future<String?> lookup(String identifier) async {
    try {
      final clean =
          identifier.trim().toLowerCase().replaceFirst(RegExp(r'^@'), '');
      if (clean.isEmpty) return null;
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_prefix$clean');
    } catch (_) {
      return null;
    }
  }
}

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  FirebaseAuth get auth => _auth ?? FirebaseAuth.instance;
  FirebaseAuth? _auth;
  set mockAuth(FirebaseAuth? value) => _auth = value;

  FirebaseFirestore get db => _db ?? FirebaseFirestore.instance;
  FirebaseFirestore? _db;
  set mockDb(FirebaseFirestore? value) => _db = value;

  final LoginThrottle throttle = LoginThrottle();

  Stream<User?> get authChanges => auth.authStateChanges();

  /// Resolves an email address from either an email or a username.
  /// Supports case-insensitive username matching with or without '@' prefix.
  Future<String> resolveEmailFromIdentifier(String identifier) async {
    final clean = identifier.trim();
    if (clean.isEmpty) return '';

    // If identifier has standard email format (not starting with @, contains @ and a dot afterwards)
    if (!clean.startsWith('@') &&
        clean.contains('@') &&
        clean.indexOf('@') < clean.lastIndexOf('.')) {
      return clean.toLowerCase();
    }

    final raw = clean.startsWith('@') ? clean.substring(1).trim() : clean;
    if (raw.isEmpty) return '';

    // 1. Check local persistent cache first
    final cached = await AccountIdentifierCache.lookup(raw);
    if (cached != null && cached.isNotEmpty && cached.contains('@')) {
      return cached.trim().toLowerCase();
    }

    // 2. Check last saved user from biometric storage
    try {
      final last = await BiometricAuthService.instance.getLastUser();
      final lastEmail = last?['email']?.trim().toLowerCase();
      final lastUsername = last?['username']?.trim().toLowerCase();
      if (lastEmail != null &&
          lastEmail.isNotEmpty &&
          lastEmail.contains('@')) {
        if (lastUsername != null &&
            lastUsername.isNotEmpty &&
            lastUsername.replaceFirst(RegExp(r'^@'), '') ==
                raw.toLowerCase().replaceFirst(RegExp(r'^@'), '')) {
          await AccountIdentifierCache.cache(username: raw, email: lastEmail);
          return lastEmail;
        }
        final prefix = lastEmail.split('@').first.toLowerCase();
        if (prefix == raw.toLowerCase()) {
          await AccountIdentifierCache.cache(username: raw, email: lastEmail);
          return lastEmail;
        }
      }
    } catch (_) {}

    final candidates = <String>{
      clean,
      '@$raw',
      raw,
      '@${raw.toLowerCase()}',
      raw.toLowerCase(),
      '@${raw.toUpperCase()}',
      raw.toUpperCase(),
      if (raw.isNotEmpty)
        '@${raw[0].toUpperCase()}${raw.substring(1).toLowerCase()}',
      if (raw.isNotEmpty)
        '${raw[0].toUpperCase()}${raw.substring(1).toLowerCase()}',
    }.take(10).toList();

    try {
      // 3. Direct match with candidates on username field
      final snap = await db
          .collection('users')
          .where('username', whereIn: candidates)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        final email = snap.docs.first.data()['email'] as String?;
        if (email != null && email.trim().isNotEmpty) {
          final res = email.trim().toLowerCase();
          await AccountIdentifierCache.cache(username: raw, email: res);
          return res;
        }
      }

      // 4. Check usernameLower field
      final snapLower = await db
          .collection('users')
          .where('usernameLower', isEqualTo: raw.toLowerCase())
          .limit(1)
          .get();
      if (snapLower.docs.isNotEmpty) {
        final email = snapLower.docs.first.data()['email'] as String?;
        if (email != null && email.trim().isNotEmpty) {
          final res = email.trim().toLowerCase();
          await AccountIdentifierCache.cache(username: raw, email: res);
          return res;
        }
      }

      // 5. Case-insensitive fallback scan across users
      final allUsers = await db.collection('users').limit(150).get();
      for (final doc in allUsers.docs) {
        final data = doc.data();
        final u = data['username'] as String?;
        final uLower = data['usernameLower'] as String?;
        if (uLower != null && uLower.toLowerCase() == raw.toLowerCase()) {
          final email = data['email'] as String?;
          if (email != null && email.trim().isNotEmpty) {
            final res = email.trim().toLowerCase();
            await AccountIdentifierCache.cache(username: raw, email: res);
            return res;
          }
        }
        if (u != null) {
          final cleanU =
              u.trim().startsWith('@') ? u.trim().substring(1) : u.trim();
          if (cleanU.toLowerCase() == raw.toLowerCase()) {
            final email = data['email'] as String?;
            if (email != null && email.trim().isNotEmpty) {
              final res = email.trim().toLowerCase();
              await AccountIdentifierCache.cache(username: raw, email: res);
              return res;
            }
          }
        }
      }
    } catch (_) {
      // Fall through if database query is not available or blocked
    }
    return '';
  }

  Future<AppUser> signIn({
    required String email,
    required String password,
    required AccountRole expectedRole,
  }) async {
    final resolvedEmail = await resolveEmailFromIdentifier(email);
    if (resolvedEmail.isEmpty || !resolvedEmail.contains('@')) {
      await throttle.recordFailure(email.trim().toLowerCase());
      throw const LocalQuestException(
        'Incorrect email, username, or password.',
      );
    }
    final locked = await throttle.lockedUntil(resolvedEmail);
    if (locked != null) {
      final minutes = locked.difference(DateTime.now()).inMinutes + 1;
      throw LocalQuestException(
        'Too many failed attempts. Try again in $minutes minute${minutes == 1 ? '' : 's'}.',
      );
    }
    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: resolvedEmail,
        password: password,
      );
      final user = credential.user!;
      BiometricAuthService.instance.markSessionAuthenticated(user.uid);
      final profileRef = db.collection('users').doc(user.uid);
      var doc = await profileRef.get();
      if (!doc.exists) {
        // Recover accounts whose Authentication record was created while the
        // initial Firestore profile write was unavailable.
        final fallbackName = user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : resolvedEmail.trim().split('@').first;
        await profileRef.set({
          'email': resolvedEmail.trim().toLowerCase(),
          'displayName': fallbackName,
          'username': _username(
            fallbackName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''),
          ),
          'phone': '',
          'role': expectedRole.value,
          'exp': 0,
          'level': 1,
          'voucherCount': 0,
          'reviewCount': 0,
          'preferences': <String, dynamic>{},
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        doc = await profileRef.get();
      }
      final profile = AppUser.fromDoc(doc);
      if (profile.role != expectedRole) {
        await auth.signOut();
        throw LocalQuestException(
          'This account is registered as a ${profile.role.label}. Change the selected account type.',
        );
      }
      await throttle.reset(resolvedEmail);
      BiometricAuthService.instance.markJustAuthenticated();
      BiometricAuthService.instance.markSessionAuthenticated(profile.id);
      await AccountIdentifierCache.cache(
        username: profile.username,
        email: profile.email,
      );
      if (profile.displayName.isNotEmpty) {
        await AccountIdentifierCache.cache(
          username: profile.displayName,
          email: profile.email,
        );
      }
      await db.collection('users').doc(profile.id).update({
        'email': user.email?.trim().toLowerCase() ?? profile.email,
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
      return profile;
    } on FirebaseAuthException catch (error) {
      await throttle.recordFailure(resolvedEmail);
      throw LocalQuestException(_authMessage(error));
    } on FirebaseException catch (error) {
      await auth.signOut();
      throw LocalQuestException(
        error.code == 'permission-denied'
            ? 'LocalQuest database access is not enabled yet. Publish the Firestore rules, then sign in again.'
            : error.message ?? 'Could not load your LocalQuest profile.',
      );
    }
  }

  Future<void> registerTourist({
    required String email,
    required String password,
    required String displayName,
    required String username,
    required String phone,
    DateTime? birthday,
  }) async {
    final passwordError = PasswordPolicy.validate(password);
    if (passwordError != null) throw LocalQuestException(passwordError);
    try {
      final result = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = result.user!;
      await user.updateDisplayName(displayName.trim());
      final cleanTouristUser =
          username.trim().replaceFirst(RegExp(r'^@'), '');
      await AccountIdentifierCache.cache(
        username: cleanTouristUser,
        email: email,
      );
      await db.collection('users').doc(user.uid).set({
        'email': email.trim().toLowerCase(),
        'displayName': displayName.trim(),
        'username': _username(username),
        'usernameLower': cleanTouristUser.toLowerCase(),
        'phone': phone.trim(),
        'birthday': birthday == null ? null : Timestamp.fromDate(birthday),
        'role': AccountRole.tourist.value,
        'exp': 0,
        'level': 1,
        'voucherCount': 0,
        'reviewCount': 0,
        'preferences': {
          'tripNotifications': true,
          'locationHistory': true,
          'partnerOffers': true,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      BiometricAuthService.instance.markJustAuthenticated();
      BiometricAuthService.instance.markSessionAuthenticated(user.uid);
    } on FirebaseAuthException catch (error) {
      throw LocalQuestException(_authMessage(error));
    } on FirebaseException catch (error) {
      await _discardIncompleteAccount();
      throw LocalQuestException(_databaseMessage(error));
    }
  }

  Future<void> registerMerchant({
    required String email,
    required String password,
    required String businessName,
    required String category,
    required String address,
    required String phone,
    String area = '',
    String postcode = '',
    String state = '',
    double? latitude,
    double? longitude,
    String? dietaryStatus,
  }) async {
    final passwordError = PasswordPolicy.validate(password);
    if (passwordError != null) throw LocalQuestException(passwordError);
    try {
      final result = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = result.user!;
      await user.updateDisplayName(businessName.trim());
      final rawMerchant =
          businessName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      await AccountIdentifierCache.cache(
        username: rawMerchant,
        email: email,
      );
      await AccountIdentifierCache.cache(
        username: businessName,
        email: email,
      );
      final business = db.collection('businesses').doc();
      final batch = db.batch();
      batch.set(db.collection('users').doc(user.uid), {
        'email': email.trim().toLowerCase(),
        'displayName': businessName.trim(),
        'username': '@$rawMerchant',
        'usernameLower': rawMerchant,
        'phone': phone.trim(),
        'role': AccountRole.merchant.value,
        'preferences': {
          'campaignNotifications': true,
          'claimNotifications': true,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(business, {
        'ownerId': user.uid,
        'name': businessName.trim(),
        'category': category.trim(),
        'address': address.trim(),
        'area': area.trim(),
        'postcode': postcode.trim(),
        'state': state.trim(),
        'phone': phone.trim(),
        'registrationNumber': '',
        'active': true,
        'latitude': ?latitude,
        'longitude': ?longitude,
        'dietaryStatus': ?dietaryStatus?.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      BiometricAuthService.instance.markJustAuthenticated();
      BiometricAuthService.instance.markSessionAuthenticated(user.uid);
    } on FirebaseAuthException catch (error) {
      throw LocalQuestException(_authMessage(error));
    } on FirebaseException catch (error) {
      await _discardIncompleteAccount();
      throw LocalQuestException(_databaseMessage(error));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw LocalQuestException(_authMessage(error));
    }
  }

  Future<void> signOut() async {
    final uid = auth.currentUser?.uid;
    BiometricAuthService.instance.clearSessionAuthentication(uid);
    await auth.signOut();
  }

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final passwordError = PasswordPolicy.validate(newPassword);
    if (passwordError != null) throw LocalQuestException(passwordError);
    if (currentPassword == newPassword) {
      throw const LocalQuestException(
        'Choose a different password from your current one.',
      );
    }
    final user = auth.currentUser!;
    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (error) {
      throw LocalQuestException(_authMessage(error));
    }
  }

  Future<void> requestEmailChange({
    required String currentPassword,
    required String newEmail,
  }) async {
    final user = auth.currentUser!;
    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.verifyBeforeUpdateEmail(newEmail.trim());
    } on FirebaseAuthException catch (error) {
      throw LocalQuestException(_authMessage(error));
    }
  }

  Future<void> deleteAccount(String currentPassword) async {
    final user = auth.currentUser!;
    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      final businesses = await db
          .collection('businesses')
          .where('ownerId', isEqualTo: user.uid)
          .get();
      final campaigns = await db
          .collection('campaigns')
          .where('ownerId', isEqualTo: user.uid)
          .get();
      final visits = await db
          .collection('users')
          .doc(user.uid)
          .collection('visitedPlaces')
          .get();
      final batch = db.batch();
      for (final document in businesses.docs) {
        batch.delete(document.reference);
      }
      for (final document in campaigns.docs) {
        batch.delete(document.reference);
      }
      for (final document in visits.docs) {
        batch.delete(document.reference);
      }
      batch.delete(db.collection('users').doc(user.uid));
      await batch.commit();
      await user.delete();
    } on FirebaseAuthException catch (error) {
      throw LocalQuestException(_authMessage(error));
    } on FirebaseException catch (error) {
      throw LocalQuestException(_databaseMessage(error));
    }
  }

  Future<void> _discardIncompleteAccount() async {
    final user = auth.currentUser;
    if (user == null) return;
    try {
      await user.delete();
    } on FirebaseAuthException {
      await auth.signOut();
    }
  }

  String _databaseMessage(FirebaseException error) =>
      error.code == 'permission-denied'
      ? 'LocalQuest database access is not enabled yet. Publish the Firestore rules, then try again.'
      : error.message ?? 'Could not update LocalQuest data. Please try again.';

  String _username(String value) {
    final cleaned = value.trim().replaceFirst(RegExp(r'^@'), '');
    return '@$cleaned';
  }

  String _authMessage(FirebaseAuthException error) => switch (error.code) {
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' ||
    'invalid-email' => 'Incorrect email, username, or password.',
    'email-already-in-use' => 'An account already uses this email address.',
    'weak-password' => 'Use a stronger password with at least 8 characters.',
    'too-many-requests' =>
      'Sign-in is temporarily unavailable. Please try again later.',
    'requires-recent-login' =>
      'Please sign in again before changing this security setting.',
    _ => error.message ?? 'Something went wrong. Please try again.',
  };
}

class UserRepository {
  UserRepository({FirebaseFirestore? firestore}) : _db = firestore;
  static UserRepository instance = UserRepository();
  final FirebaseFirestore? _db;
  FirebaseFirestore get db => _db ?? FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> Function(String uid)?
      mockVisitedPlacesStream;
  Stream<AppUser> Function(String uid)? mockWatch;
  Future<AppUser> Function(String uid)? mockGet;
  Future<bool> Function({
    required String userId,
    required String name,
    required String area,
    String? businessId,
    DateTime? visitedAt,
  })? mockRecordVisit;
  Future<int> Function(String userId)? mockCleanDuplicateVisitedPlaces;
  Future<void> Function(String uid, String key, bool value)? mockUpdatePreference;

  Future<UploadedPhoto> updatePhoto(String uid, Uint8List bytes) async {
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      throw const PhotoUploadException(
        'Sign in again before changing your photo.',
      );
    }
    final photo = await CloudinaryImages.instance.upload(bytes);
    try {
      await db.collection('users').doc(uid).update({
        'photoUrl': photo.url,
        'photoPublicId': photo.publicId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      await CloudinaryImages.instance.rollback(photo);
      rethrow;
    }
    return photo;
  }

  Stream<AppUser> watch(String uid) {
    if (mockWatch != null) return mockWatch!(uid);
    try {
      return db.collection('users').doc(uid).snapshots().map((doc) {
        if (!doc.exists) {
          return AppUser(
            id: uid,
            email: '',
            displayName: 'LocalQuest Explorer',
            username: '@explorer',
            role: AccountRole.tourist,
          );
        }
        final user = AppUser.fromDoc(doc);
        AccountIdentifierCache.cache(
          username: user.username,
          email: user.email,
        );
        return user;
      });
    } catch (_) {
      return Stream.value(
        AppUser(
          id: uid,
          email: '',
          displayName: 'LocalQuest Explorer',
          username: '@explorer',
          role: AccountRole.tourist,
        ),
      );
    }
  }

  Future<AppUser> get(String uid) async {
    if (mockGet != null) return mockGet!(uid);
    try {
      final doc = await db.collection('users').doc(uid).get();
      if (!doc.exists) {
        return AppUser(
          id: uid,
          email: '',
          displayName: 'LocalQuest Explorer',
          username: '@explorer',
          role: AccountRole.tourist,
        );
      }
      final user = AppUser.fromDoc(doc);
      await AccountIdentifierCache.cache(
        username: user.username,
        email: user.email,
      );
      return user;
    } catch (_) {
      return AppUser(
        id: uid,
        email: '',
        displayName: 'LocalQuest Explorer',
        username: '@explorer',
        role: AccountRole.tourist,
      );
    }
  }

  Future<void> updateProfile({
    required String uid,
    required String displayName,
    required String username,
    required String phone,
    DateTime? birthday,
  }) async {
    final cleanUsername =
        username.trim().replaceFirst(RegExp(r'^@'), '');
    await AccountIdentifierCache.cache(
      username: cleanUsername,
      email: FirebaseAuth.instance.currentUser?.email ?? '',
    );
    await db.collection('users').doc(uid).update({
      'displayName': displayName.trim(),
      'username': username.startsWith('@')
          ? username.trim()
          : '@${username.trim()}',
      'usernameLower': cleanUsername.toLowerCase(),
      'phone': phone.trim(),
      'birthday': birthday == null ? null : Timestamp.fromDate(birthday),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await FirebaseAuth.instance.currentUser?.updateDisplayName(
      displayName.trim(),
    );
  }

  Future<void> updatePreference(String uid, String key, bool value) {
    if (mockUpdatePreference != null) {
      return mockUpdatePreference!(uid, key, value);
    }
    return db.collection('users').doc(uid).update({
      'preferences.$key': value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> visitedPlaces(String uid) {
    if (mockVisitedPlacesStream != null) {
      return mockVisitedPlacesStream!(uid);
    }
    return db
        .collection('users')
        .doc(uid)
        .collection('visitedPlaces')
        .orderBy('visitedAt', descending: true)
        .snapshots();
  }

  Future<bool> recordVisit({
    required String userId,
    required String name,
    required String area,
    String? businessId,
    DateTime? visitedAt,
    double? latitude,
    double? longitude,
  }) async {
    if (mockRecordVisit != null) {
      return mockRecordVisit!(
        userId: userId,
        name: name,
        area: area,
        businessId: businessId,
        visitedAt: visitedAt,
      );
    }
    try {
      final doc = await db.collection('users').doc(userId).get();
      final prefs = doc.data()?['preferences'] as Map<String, dynamic>?;
      if (prefs?['locationHistory'] == false) {
        return false;
      }

      final targetTime = visitedAt ?? DateTime.now();

      // Database deduplication: verify whether a visit for this business or name
      // was already recorded within the last 10 minutes.
      try {
        final recentSnap = await db
            .collection('users')
            .doc(userId)
            .collection('visitedPlaces')
            .orderBy('visitedAt', descending: true)
            .limit(3)
            .get();

        for (final existingDoc in recentSnap.docs) {
          final data = existingDoc.data();
          final existingBizId = (data['businessId'] as String? ?? '').trim();
          final existingName = (data['name'] as String? ?? '').trim();
          final existingTime = (data['visitedAt'] as Timestamp?)?.toDate();

          final isSameBusiness = (businessId != null &&
                  businessId.isNotEmpty &&
                  existingBizId == businessId) ||
              existingName.toLowerCase() == name.trim().toLowerCase();

          if (isSameBusiness && existingTime != null) {
            final diff = targetTime.difference(existingTime).abs();
            if (diff < const Duration(minutes: 10)) {
              // Existing record found within 10 minutes - drop duplicate!
              return false;
            }
          }
        }
      } catch (_) {
        // Continue safely if recent query encounters index or transient error
      }

      await db.collection('users').doc(userId).collection('visitedPlaces').add({
        'name': name.trim(),
        'area': area.trim(),
        'businessId': businessId ?? '',
        'latitude': latitude,
        'longitude': longitude,
        'visitedAt': visitedAt != null
            ? Timestamp.fromDate(visitedAt)
            : FieldValue.serverTimestamp(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Remove duplicate visited place records (same business/name within 3 minutes of each other).
  Future<int> cleanDuplicateVisitedPlaces(String userId) async {
    if (mockCleanDuplicateVisitedPlaces != null) {
      return mockCleanDuplicateVisitedPlaces!(userId);
    }
    try {
      final snap = await db
          .collection('users')
          .doc(userId)
          .collection('visitedPlaces')
          .orderBy('visitedAt', descending: true)
          .get();

      final seen = <String>{};
      final duplicatesToDelete = <DocumentReference>[];

      for (final doc in snap.docs) {
        final data = doc.data();
        final name = (data['name'] as String? ?? '').trim().toLowerCase();
        final bizId = (data['businessId'] as String? ?? '').trim();
        final date = (data['visitedAt'] as Timestamp?)?.toDate();
        final timeKey = date != null
            ? '${date.year}-${date.month}-${date.day}_${date.hour}:${date.minute}'
            : '';
        final key = '${bizId.isNotEmpty ? bizId : name}_$timeKey';

        if (key.isNotEmpty && seen.contains(key)) {
          duplicatesToDelete.add(doc.reference);
        } else if (key.isNotEmpty) {
          seen.add(key);
        }
      }

      if (duplicatesToDelete.isNotEmpty) {
        final batch = db.batch();
        for (final ref in duplicatesToDelete) {
          batch.delete(ref);
        }
        await batch.commit();
      }

      return duplicatesToDelete.length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> deleteVisitedPlace(String userId, String placeId) =>
      db.collection('users').doc(userId).collection('visitedPlaces').doc(placeId).delete();
}

class MerchantRepository {
  MerchantRepository({FirebaseFirestore? firestore}) : _db = firestore;
  static MerchantRepository instance = MerchantRepository();
  final FirebaseFirestore? _db;
  FirebaseFirestore get db => _db ?? FirebaseFirestore.instance;

  Stream<List<Business>> Function(String uid)? mockBusinessesStream;
  Stream<List<Campaign>> Function(String uid, {String? businessId})? mockCampaignsStream;

  Stream<List<Business>> businesses(String uid) {
    if (mockBusinessesStream != null) {
      return mockBusinessesStream!(uid);
    }
    try {
      return db
          .collection('businesses')
          .where('ownerId', isEqualTo: uid)
          .snapshots()
          .map((snapshot) => snapshot.docs.map(Business.fromDoc).toList());
    } catch (_) {
      return Stream.value(const <Business>[]);
    }
  }

  Stream<List<Campaign>> campaigns(String uid, {String? businessId}) {
    if (mockCampaignsStream != null) {
      return mockCampaignsStream!(uid, businessId: businessId);
    }
    try {
      return db
          .collection('campaigns')
          .where('ownerId', isEqualTo: uid)
          .snapshots()
          .map((snapshot) {
            final values = snapshot.docs
                .map(Campaign.fromDoc)
                .where(
                  (campaign) =>
                      businessId == null || campaign.businessId == businessId,
                )
                .toList();
            values.sort((a, b) => b.startDate.compareTo(a.startDate));
            return values;
          });
    } catch (_) {
      return Stream.value(const <Campaign>[]);
    }
  }

  Future<void> saveBusiness(Business value, {Uint8List? photoBytes}) async {
    if (FirebaseAuth.instance.currentUser?.uid != value.ownerId) {
      throw const LocalQuestException(
        'Sign in again before saving your business.',
      );
    }
    final ref = value.id.isEmpty
        ? db.collection('businesses').doc()
        : db.collection('businesses').doc(value.id);
    UploadedPhoto? uploaded;
    if (photoBytes != null) {
      try {
        uploaded = await CloudinaryImages.instance.upload(photoBytes);
      } on PhotoUploadException catch (error) {
        throw LocalQuestException(error.message);
      }
    }
    try {
      await ref.set({
        'ownerId': value.ownerId,
        'name': value.name.trim(),
        'category': value.category.trim(),
        'address': value.address.trim(),
        'area': value.area.trim(),
        'postcode': value.postcode.trim(),
        'state': value.state.trim(),
        'phone': value.phone.trim(),
        'registrationNumber': value.registrationNumber.trim(),
        'verificationStatus': value.verificationStatus,
        if (uploaded != null) 'photoUrl': uploaded.url,
        if (uploaded != null) 'photoPublicId': uploaded.publicId,
        'active': value.active,
        'latitude': ?value.latitude,
        'longitude': ?value.longitude,
        if (value.operatingHours != null && value.operatingHours!.trim().isNotEmpty)
          'operatingHours': value.operatingHours!.trim(),
        if (value.dietaryStatus != null && value.dietaryStatus!.trim().isNotEmpty)
          'dietaryStatus': value.dietaryStatus!.trim()
        else if (value.id.isNotEmpty)
          'dietaryStatus': FieldValue.delete(),
        if (value.website != null && value.website!.trim().isNotEmpty)
          'website': value.website!.trim(),
        if (value.description != null && value.description!.trim().isNotEmpty)
          'description': value.description!.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (value.id.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      if (uploaded != null) await CloudinaryImages.instance.rollback(uploaded);
      rethrow;
    }
  }

  Future<void> deleteBusiness(String id) =>
      db.collection('businesses').doc(id).delete();

  Future<void> setCampaignStatus(String id, bool active) async {
    await db.collection('campaigns').doc(id).update({
      'status': active ? 'active' : 'inactive',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> saveCampaign(
    Campaign value, {
    Uint8List? posterBytes,
    String? posterExtension,
  }) async {
    if (value.businessId.isEmpty) {
      throw const LocalQuestException(
        'Select a business before creating a campaign.',
      );
    }
    final validation =
        MerchantValidation.text(value.name, 'Name', 3, 80) ??
        MerchantValidation.text(value.description, 'Description', 20, 1500) ??
        MerchantValidation.text(value.terms, 'Terms', 10, 2000);
    if (validation != null) throw LocalQuestException(validation);
    if (!['ad', 'voucher'].contains(value.type) ||
        !['active', 'scheduled', 'inactive'].contains(value.status) ||
        value.endDate.isBefore(value.startDate)) {
      throw const LocalQuestException(
        'Check the offer type, status and date range.',
      );
    }
    if (value.type == 'voucher' &&
        (!['percentage', 'fixed'].contains(value.discountType) ||
            !value.discountValue.isFinite ||
            value.discountValue <= 0 ||
            value.discountValue >
                (value.discountType == 'percentage' ? 100 : 100000) ||
            !value.minimumSpend.isFinite ||
            value.minimumSpend < 0 ||
            value.minimumSpend > 100000 ||
            value.quantity < 1 ||
            value.quantity > 100000 ||
            value.perCustomerLimit < 1 ||
            value.perCustomerLimit > value.quantity)) {
      throw const LocalQuestException(
        'Check voucher value, minimum spend and quantity limits.',
      );
    }
    final business = await db
        .collection('businesses')
        .doc(value.businessId)
        .get();
    if (business.data()?['ownerId'] != value.ownerId ||
        business.data()?['active'] != true) {
      throw const LocalQuestException(
        'Choose an active business that belongs to your account.',
      );
    }
    final ref = value.id.isEmpty
        ? db.collection('campaigns').doc()
        : db.collection('campaigns').doc(value.id);
    String? imageUrl = value.imageUrl;
    UploadedPhoto? uploaded;
    if (posterBytes != null) {
      try {
        uploaded = await CloudinaryImages.instance.upload(posterBytes);
        imageUrl = uploaded.url;
      } on PhotoUploadException catch (error) {
        throw LocalQuestException(error.message);
      }
    }
    try {
      await ref.set({
        'ownerId': value.ownerId,
        'businessId': value.businessId,
        'name': value.name.trim(),
        'description': value.description.trim(),
        'type': value.type,
        'startDate': Timestamp.fromDate(value.startDate),
        'endDate': Timestamp.fromDate(value.endDate),
        'status': value.status,
        if (value.id.isEmpty) 'views': value.views,
        if (value.id.isEmpty) 'claims': value.claims,
        'imageUrl': imageUrl,
        if (uploaded != null) 'imagePublicId': uploaded.publicId,
        'terms': value.terms.trim(),
        'discountType': value.discountType,
        'discountValue': value.discountValue,
        'minimumSpend': value.minimumSpend,
        'quantity': value.quantity,
        'perCustomerLimit': value.voucherType == 'welcome' ? 1 : value.perCustomerLimit,
        'voucherType': ['welcome', 'promotional', 'seasonal'].contains(value.voucherType)
            ? value.voucherType
            : 'promotional',
        'collectionMethod': ['discovery_claim', 'walk_up_collect', 'both'].contains(value.collectionMethod)
            ? value.collectionMethod
            : 'both',
        if (value.seasonName != null && value.seasonName!.trim().isNotEmpty)
          'seasonName': value.seasonName!.trim(),
        if (value.linkedAdId != null && value.linkedAdId!.trim().isNotEmpty)
          'linkedAdId': value.linkedAdId!.trim(),
        if (value.validDays != null && value.validDays!.trim().isNotEmpty)
          'validDays': value.validDays!.trim(),
        if (value.validHours != null && value.validHours!.trim().isNotEmpty)
          'validHours': value.validHours!.trim(),
        if (value.redemptionHours != null && value.redemptionHours!.trim().isNotEmpty)
          'redemptionHours': value.redemptionHours!.trim(),
        if (value.dailyQuota != null && value.dailyQuota! > 0)
          'dailyQuota': value.dailyQuota,
        'updatedAt': FieldValue.serverTimestamp(),
        if (value.id.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return ref.id;
    } catch (_) {
      if (uploaded != null) await CloudinaryImages.instance.rollback(uploaded);
      rethrow;
    }
  }

  Future<void> deleteCampaign(String id) =>
      db.collection('campaigns').doc(id).delete();

  Future<void> attachVouchersToAd(
    String adId,
    Set<String> voucherIds,
    String businessId,
  ) async {
    final snap = await db
        .collection('campaigns')
        .where('businessId', isEqualTo: businessId)
        .where('type', isEqualTo: 'voucher')
        .get();
    final batch = db.batch();
    for (final doc in snap.docs) {
      final shouldBeAttached = voucherIds.contains(doc.id);
      final currentLinked = doc.data()['linkedAdId'] as String?;
      if (shouldBeAttached && currentLinked != adId) {
        batch.update(doc.reference, {
          'linkedAdId': adId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else if (!shouldBeAttached && currentLinked == adId) {
        batch.update(doc.reference, {
          'linkedAdId': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
  }

  Future<void> markClaimedVoucherRedeemed(String userId, String voucherId) {
    return db
        .collection('users').doc(userId).collection('claimedVouchers').doc(voucherId)
        .update({'redeemed': true, 'redeemedAt': FieldValue.serverTimestamp()});
  }

  /// Looks up a claimed campaign voucher by its code. Any merchant can
  /// run this query, but the security rule only lets them actually READ
  /// the matching document if they own the business it belongs to —
  /// so a code for someone else's business silently returns no match
  /// rather than leaking another merchant's voucher data.
  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> findClaimedVoucherByCode(
      String code,
      ) async {
    final snap = await db
        .collectionGroup('claimedVouchers')
        .where('code', isEqualTo: code.trim().toUpperCase())
        .limit(1)
        .get();
    return snap.docs.isEmpty ? null : snap.docs.first;
  }

  Future<bool> claimVoucher({
    required String userId,
    required String voucherId,
    required String businessId,
    required String voucherType,
  }) async {
    final claimDoc = db
        .collection('users')
        .doc(userId)
        .collection('claimedVouchers')
        .doc(voucherId);

    final existing = await claimDoc.get();
    if (existing.exists && voucherType == 'welcome') {
      throw const LocalQuestException(
        'You have already claimed this welcome voucher.',
      );
    }

    if (voucherType == 'welcome') {
      final bizWelcomeQuery = await db
          .collection('users')
          .doc(userId)
          .collection('claimedVouchers')
          .where('businessId', isEqualTo: businessId)
          .where('voucherType', isEqualTo: 'welcome')
          .limit(1)
          .get();
      if (bizWelcomeQuery.docs.isNotEmpty) {
        throw const LocalQuestException(
          'You have already claimed a welcome voucher for this business.',
        );
      }
    }

    await claimDoc.set({
      'voucherId': voucherId,
      'businessId': businessId,
      'voucherType': voucherType,
      'claimedAt': FieldValue.serverTimestamp(),
      'redeemed': false,
      'code': VoucherCode.generate(),
    });

    try {
      await db.collection('campaigns').doc(voucherId).update({
        'claims': FieldValue.increment(1),
      });
    } catch (_) {
      // Best-effort counter increment
    }

    return true;
  }

  Stream<List<Map<String, dynamic>>> touristClaimedVouchers(String userId) => db
      .collection('users')
      .doc(userId)
      .collection('claimedVouchers')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
}
