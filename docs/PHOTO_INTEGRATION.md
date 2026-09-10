# LocalQuest prototype photos

Cloudinary cloud: `g9podhp8`. The app uses the separate unsigned preset
`localquest_photos`. Neither value is a secret. Do not put an API secret in
Flutter, Firestore, an APK, or the repository.

## Setup status

The user approved unsigned prototype uploads and the preset was saved on
10 September 2026. Live Cloudinary/Firebase photo checks passed for both role
avatars, business photos and ad/voucher posters, including retrieval from saved
URLs. Firebase's disabled Storage bucket is no longer used for app photos.

Preset settings: unsigned; asset folder `localquest/prototype`; generated unique
public IDs; no overwrites; allowed formats JPG/JPEG/PNG/WEBP; return delete token.
Explicit public IDs are disallowed. The existing ml_default preset was untouched.
The app rejects files at or above 5 MiB and resizes picker images before upload.
Do not mistake app validation for a server-side quota/ownership restriction.

## Included

- Tourist and merchant: Account details > Add/Change profile photo > preview >
  Upload photo. Firestore stores photoUrl and photoPublicId under users/{uid}.
- Profile cards and the separate navigation profile bubble display the saved
  photo with initials as a loading/error fallback.
- Business editor: optional business photo, uploaded on Save business.
  Business list and workspace selector display it. Firestore stores photoUrl
  and photoPublicId in the business document.
- Ads/vouchers: the existing poster picker uploads to Cloudinary on offer save;
  Firestore stores imageUrl/imagePublicId in the campaign document.
- Failed Firestore saves attempt rollback using the short-lived delete token.
  A failed rollback can leave an orphan that needs dashboard cleanup.
- Normal edits preserve existing images and live view/claim counters.

## Prototype limitations

An unsigned preset can be extracted and used outside the app, consuming quota.
Firebase rules control database edits but do not authorize Cloudinary uploads.
Photos are publicly retrievable by URL. Only use non-sensitive prototype media.
Certificates remain on-device for OCR and are NOT uploaded by these photo flows.
Removing an account/campaign or replacing an image does not permanently delete
older Cloudinary assets. Administrator cleanup is required until an authenticated
backend is added. Delete tokens only work for ten minutes after upload and are
used for immediate rollback, not as permanent deletion credentials.

## Verification

`flutter test` covers client request construction, invalid-file/provider failure
handling, and photo UI controls. These tests do not establish live upload success.

After preset approval/setup, `dart run tool/photo_smoke_test.dart --live` uploads
generated non-personal images, creates two disposable Firebase test accounts,
checks persisted tourist/merchant avatars, business photo and ad/voucher posters,
checks a cross-user profile edit is denied, then removes those test assets and
records. Do not run against a different project without explicit permission.
This backend smoke test does not replace gallery-picker testing on a phone.

Live result (10 September 2026): both avatars survived a fresh login and database
read; business/ad/voucher image references and image downloads passed; a
cross-user profile-photo edit was denied. All generated test images, test
documents and two test accounts were cleaned up. No Android device was connected
at the final check, so actual gallery selection on the user's phone remains to
be checked. The local suite previously passed 32 tests.
