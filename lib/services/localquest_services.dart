import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/localquest_models.dart';
import '../core/merchant_validation.dart';
import '../core/password_policy.dart';
import 'cloudinary_images.dart';

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

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final LoginThrottle throttle = LoginThrottle();

  Stream<User?> get authChanges => auth.authStateChanges();

  Future<AppUser> signIn({
    required String email,
    required String password,
    required AccountRole expectedRole,
  }) async {
    final locked = await throttle.lockedUntil(email);
    if (locked != null) {
      final minutes = locked.difference(DateTime.now()).inMinutes + 1;
      throw LocalQuestException(
        'Too many failed attempts. Try again in $minutes minute${minutes == 1 ? '' : 's'}.',
      );
    }
    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user!;
      final profileRef = db.collection('users').doc(user.uid);
      var doc = await profileRef.get();
      if (!doc.exists) {
        // Recover accounts whose Authentication record was created while the
        // initial Firestore profile write was unavailable.
        final fallbackName = user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : email.trim().split('@').first;
        await profileRef.set({
          'email': email.trim().toLowerCase(),
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
      await throttle.reset(email);
      await db.collection('users').doc(profile.id).update({
        'email': user.email?.trim().toLowerCase() ?? profile.email,
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
      return profile;
    } on FirebaseAuthException catch (error) {
      await throttle.recordFailure(email);
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
      await db.collection('users').doc(user.uid).set({
        'email': email.trim().toLowerCase(),
        'displayName': displayName.trim(),
        'username': _username(username),
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
    double? latitude,
    double? longitude,
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
      final business = db.collection('businesses').doc();
      final batch = db.batch();
      batch.set(db.collection('users').doc(user.uid), {
        'email': email.trim().toLowerCase(),
        'displayName': businessName.trim(),
        'username':
            '@${businessName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}',
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
        'phone': phone.trim(),
        'registrationNumber': '',
        'active': true,
        'latitude': ?latitude,
        'longitude': ?longitude,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
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

  Future<void> signOut() => auth.signOut();

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
    'user-not-found' => 'Incorrect email or password.',
    'email-already-in-use' => 'An account already uses this email address.',
    'invalid-email' => 'Enter a valid email address.',
    'weak-password' => 'Use a stronger password with at least 8 characters.',
    'too-many-requests' =>
      'Sign-in is temporarily unavailable. Please try again later.',
    'requires-recent-login' =>
      'Please sign in again before changing this security setting.',
    _ => error.message ?? 'Something went wrong. Please try again.',
  };
}

class UserRepository {
  UserRepository._();
  static final instance = UserRepository._();
  final FirebaseFirestore db = FirebaseFirestore.instance;

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

  Stream<AppUser> watch(String uid) =>
      db.collection('users').doc(uid).snapshots().map(AppUser.fromDoc);

  Future<AppUser> get(String uid) async =>
      AppUser.fromDoc(await db.collection('users').doc(uid).get());

  Future<void> updateProfile({
    required String uid,
    required String displayName,
    required String username,
    required String phone,
    DateTime? birthday,
  }) async {
    await db.collection('users').doc(uid).update({
      'displayName': displayName.trim(),
      'username': username.startsWith('@')
          ? username.trim()
          : '@${username.trim()}',
      'phone': phone.trim(),
      'birthday': birthday == null ? null : Timestamp.fromDate(birthday),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await FirebaseAuth.instance.currentUser?.updateDisplayName(
      displayName.trim(),
    );
  }

  Future<void> updatePreference(String uid, String key, bool value) =>
      db.collection('users').doc(uid).update({
        'preferences.$key': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Stream<QuerySnapshot<Map<String, dynamic>>> visitedPlaces(String uid) => db
      .collection('users')
      .doc(uid)
      .collection('visitedPlaces')
      .orderBy('visitedAt', descending: true)
      .snapshots();
}

class MerchantRepository {
  MerchantRepository._();
  static final instance = MerchantRepository._();
  final FirebaseFirestore db = FirebaseFirestore.instance;

  Stream<List<Business>> businesses(String uid) => db
      .collection('businesses')
      .where('ownerId', isEqualTo: uid)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(Business.fromDoc).toList());

  Stream<List<Campaign>> campaigns(String uid, {String? businessId}) => db
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
        'phone': value.phone.trim(),
        'registrationNumber': value.registrationNumber.trim(),
        if (uploaded != null) 'photoUrl': uploaded.url,
        if (uploaded != null) 'photoPublicId': uploaded.publicId,
        'active': value.active,
        'latitude': ?value.latitude,
        'longitude': ?value.longitude,
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

  Future<void> saveCampaign(
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
        'perCustomerLimit': value.perCustomerLimit,
        'updatedAt': FieldValue.serverTimestamp(),
        if (value.id.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      if (uploaded != null) await CloudinaryImages.instance.rollback(uploaded);
      rethrow;
    }
  }

  Future<void> deleteCampaign(String id) =>
      db.collection('campaigns').doc(id).delete();
}
