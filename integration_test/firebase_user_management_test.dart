import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:collab/models/localquest_models.dart';
import 'package:collab/services/localquest_services.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('live Firebase user-management workflow', (tester) async {
    await Firebase.initializeApp();

    final authService = AuthService.instance;
    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final touristEmail = 'localquest.qa.tourist.$stamp@example.com';
    final merchantEmail = 'localquest.qa.merchant.$stamp@example.com';
    const password = 'LocalQuest!Qa2026';

    String? touristUid;
    String? merchantUid;

    Future<void> deleteCurrentQaAccount() async {
      if (auth.currentUser == null) return;
      try {
        await authService.deleteAccount(password);
      } catch (_) {
        await auth.signOut();
      }
    }

    await auth.signOut();
    try {
      // Tourist registration creates both an Authentication account and a
      // complete users/{uid} Firestore profile.
      await authService.registerTourist(
        email: touristEmail,
        password: password,
        displayName: 'LocalQuest QA Tourist',
        username: 'localquestqatourist$stamp',
        phone: '+601100000001',
        birthday: DateTime(2000, 1, 2),
      );
      touristUid = auth.currentUser!.uid;
      var tourist = await db.collection('users').doc(touristUid).get();
      expect(tourist.exists, isTrue);
      expect(tourist.data()!['role'], 'tourist');
      expect(tourist.data()!['email'], touristEmail);

      // Profile and preferences persist to Firestore.
      await UserRepository.instance.updateProfile(
        uid: touristUid,
        displayName: 'Updated QA Tourist',
        username: '@updatedqatourist',
        phone: '+601100000009',
        birthday: DateTime(2001, 3, 4),
      );
      await UserRepository.instance.updatePreference(
        touristUid,
        'tripNotifications',
        false,
      );
      tourist = await db.collection('users').doc(touristUid).get();
      expect(tourist.data()!['displayName'], 'Updated QA Tourist');
      expect(tourist.data()!['preferences']['tripNotifications'], isFalse);

      // Location-history storage is owner-only.
      final visit = db
          .collection('users')
          .doc(touristUid)
          .collection('visitedPlaces')
          .doc();
      await visit.set({
        'name': 'QA Heritage Stop',
        'visitedAt': FieldValue.serverTimestamp(),
      });
      expect((await visit.get()).exists, isTrue);

      // Firebase accepts both outbound account-security email requests.
      await auth.currentUser!.sendEmailVerification();
      await authService.sendPasswordReset(touristEmail);

      // A tourist cannot elevate their role or create merchant data.
      await expectLater(
        db.collection('users').doc(touristUid).update({'role': 'merchant'}),
        throwsA(isA<FirebaseException>()),
      );
      await expectLater(
        db.collection('businesses').add({
          'ownerId': touristUid,
          'name': 'Forbidden Tourist Business',
        }),
        throwsA(isA<FirebaseException>()),
      );

      await auth.signOut();

      // Merchant registration atomically creates its profile and first
      // business, then the repositories provide live business/campaign CRUD.
      await authService.registerMerchant(
        email: merchantEmail,
        password: password,
        businessName: 'LocalQuest QA Merchant',
        category: 'Cafe',
        address: '1 QA Street, Kuala Lumpur',
        phone: '+601100000002',
      );
      merchantUid = auth.currentUser!.uid;
      final merchant = await db.collection('users').doc(merchantUid).get();
      expect(merchant.data()!['role'], 'merchant');

      final initialBusinesses = await db
          .collection('businesses')
          .where('ownerId', isEqualTo: merchantUid)
          .get();
      expect(initialBusinesses.docs, hasLength(1));
      final initialBusinessId = initialBusinesses.docs.single.id;

      await MerchantRepository.instance.saveBusiness(
        Business(
          id: initialBusinessId,
          ownerId: merchantUid,
          name: 'Updated LocalQuest QA Merchant',
          category: 'Restaurant',
          address: '2 QA Street, Kuala Lumpur',
          phone: '+601100000003',
          registrationNumber: 'QA-$stamp',
        ),
      );
      expect(
        (await db.collection('businesses').doc(initialBusinessId).get())
            .data()!['category'],
        'Restaurant',
      );

      final adRef = db.collection('campaigns').doc();
      final voucherRef = db.collection('campaigns').doc();
      final start = DateTime.now();
      final end = start.add(const Duration(days: 14));
      await MerchantRepository.instance.saveCampaign(
        Campaign(
          id: adRef.id,
          ownerId: merchantUid,
          name: 'QA Advertisement',
          description: 'Live advertisement CRUD test',
          type: 'ad',
          startDate: start,
          endDate: end,
        ),
      );
      await MerchantRepository.instance.saveCampaign(
        Campaign(
          id: voucherRef.id,
          ownerId: merchantUid,
          name: 'QA Voucher',
          description: 'Live voucher CRUD test',
          type: 'voucher',
          startDate: start,
          endDate: end,
        ),
      );
      await MerchantRepository.instance.saveCampaign(
        Campaign(
          id: voucherRef.id,
          ownerId: merchantUid,
          name: 'Updated QA Voucher',
          description: 'Updated live voucher CRUD test',
          type: 'voucher',
          startDate: start,
          endDate: end,
          status: 'paused',
        ),
      );
      expect((await adRef.get()).exists, isTrue);
      expect((await voucherRef.get()).data()!['status'], 'paused');
      await MerchantRepository.instance.deleteCampaign(adRef.id);
      await MerchantRepository.instance.deleteCampaign(voucherRef.id);
      expect((await adRef.get()).exists, isFalse);
      expect((await voucherRef.get()).exists, isFalse);

      // Different users' private profiles are isolated.
      await expectLater(
        db.collection('users').doc(touristUid).get(),
        throwsA(isA<FirebaseException>()),
      );
      await expectLater(
        db.collection('businesses').add({
          'ownerId': touristUid,
          'name': 'Spoofed Owner',
        }),
        throwsA(isA<FirebaseException>()),
      );

      // Complete merchant deletion removes owned Firestore records and Auth.
      await authService.deleteAccount(password);
      expect(auth.currentUser, isNull);
      merchantUid = null;

      // The tourist can still sign in, and complete deletion removes its
      // profile, nested history, and Authentication account.
      final signedInTourist = await authService.signIn(
        email: touristEmail,
        password: password,
        expectedRole: AccountRole.tourist,
      );
      expect(signedInTourist.id, touristUid);
      await authService.deleteAccount(password);
      expect(auth.currentUser, isNull);
      touristUid = null;
    } finally {
      // Cleanup is limited to the temporary QA account currently signed in.
      if (auth.currentUser?.email == touristEmail ||
          auth.currentUser?.email == merchantEmail) {
        await deleteCurrentQaAccount();
      }
    }
  });
}
