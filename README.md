# LocalQuest

LocalQuest is a Flutter and Firebase application for tourists and local merchants. This repository currently implements the complete User Management module:

- Tourist and merchant role selection, registration, sign-in, password reset, and role-based routing.
- Five-attempt sign-in throttling with a ten-minute device lock.
- Tourist profile, account details, settings, preferences, password/email security, privacy, help, and visited-place history.
- Merchant overview, business registrations, campaign and voucher management, poster upload, and profile.
- Firebase Authentication, Cloud Firestore, Cloud Storage, and least-privilege security rules.

## Firebase setup

The Android application ID is `com.localquest.app`. Register that Android app in the `localquest-d9625` Firebase project, place `google-services.json` in `android/app/`, enable Email/Password Authentication, create Cloud Firestore and Cloud Storage, then deploy `firestore.rules` and `storage.rules`.

Run locally with:

```sh
flutter pub get
flutter run
```
