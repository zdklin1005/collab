// Opt-in live test. Creates only disposable accounts/documents and tiny images.
// Tokens/passwords are held in memory, never printed or written to disk.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:collab/services/cloudinary_images.dart';

Future<void> main(List<String> args) async {
  if (!args.contains('--live')) {
    stdout.writeln(
      'Not run. Use --live only after approving the prototype preset and disposable test data.',
    );
    return;
  }
  final config = jsonDecode(
    await File('android/app/google-services.json').readAsString(),
  );
  final apiKey = config['client'][0]['api_key'][0]['current_key'] as String;
  final project = config['project_info']['project_id'] as String;
  final client = http.Client();
  final service = CloudinaryImages();
  final photos = <UploadedPhoto>[];
  final accounts = <Map<String, dynamic>>[];
  final docs = <(String, String)>[];
  final suffix = DateTime.now().microsecondsSinceEpoch.toString();
  final random = Random.secure();

  Future<Map<String, dynamic>> auth(
    String action,
    Map<String, dynamic> body,
  ) async {
    final response = await client
        .post(
          Uri.https('identitytoolkit.googleapis.com', '/v1/accounts:$action', {
            'key': apiKey,
          }),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw StateError(
        'Authentication $action failed (${response.statusCode}).',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Uri docUrl(String path) => Uri.parse(
    'https://firestore.googleapis.com/v1/projects/$project/databases/(default)/documents/$path',
  );
  Map<String, String> headers(String token) => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };
  Map<String, dynamic> fields(Map<String, Object> values) => values.map(
    (k, v) => MapEntry(
      k,
      v is bool
          ? {'booleanValue': v}
          : v is int
          ? {'integerValue': '$v'}
          : {'stringValue': '$v'},
    ),
  );
  Future<void> write(
    String path,
    String token,
    Map<String, Object> values,
  ) async {
    docs.add((path, token));
    final response = await client.patch(
      docUrl(path),
      headers: headers(token),
      body: jsonEncode({'fields': fields(values)}),
    );
    if (response.statusCode != 200) {
      throw StateError(
        'Firestore write failed (${response.statusCode}) for ${path.split('/').first}.',
      );
    }
  }

  Future<void> checkPhoto(
    String path,
    String token,
    String field,
    String expected,
  ) async {
    final response = await client.get(docUrl(path), headers: headers(token));
    if (response.statusCode != 200 ||
        jsonDecode(response.body)['fields'][field]['stringValue'] != expected) {
      throw StateError(
        'Photo reference did not survive a fresh database read.',
      );
    }
    final image = await client.get(Uri.parse(expected));
    if (image.statusCode != 200 ||
        !image.headers['content-type']!.startsWith('image/')) {
      throw StateError('Saved photo URL is not a retrievable image.');
    }
  }

  try {
    for (final role in ['tourist', 'merchant']) {
      final password = base64UrlEncode(
        List.generate(24, (_) => random.nextInt(256)),
      );
      final account = await auth('signUp', {
        'email': 'photo-$role-$suffix@example.com',
        'password': password,
        'returnSecureToken': true,
      });
      accounts.add(account);
      final uid = account['localId'] as String;
      final token = account['idToken'] as String;
      final avatar = await service.upload(testPng());
      photos.add(avatar);
      await write('users/$uid', token, {
        'role': role,
        'displayName': 'Disposable photo test',
        'email': 'photo-$role-$suffix@example.com',
        'photoUrl': avatar.url,
        'photoPublicId': avatar.publicId,
      });
      // Fresh sign-in simulates persistence after a new session, not cached data.
      final login = await auth('signInWithPassword', {
        'email': 'photo-$role-$suffix@example.com',
        'password': password,
        'returnSecureToken': true,
      });
      await checkPhoto(
        'users/$uid',
        login['idToken'] as String,
        'photoUrl',
        avatar.url,
      );
      stdout.writeln(
        'PASS: $role avatar upload, save, fresh login/read and image download',
      );
      if (role == 'merchant') {
        final businessId = 'photo-test-$suffix';
        final businessPhoto = await service.upload(testPng());
        photos.add(businessPhoto);
        await write('businesses/$businessId', token, {
          'ownerId': uid,
          'name': 'Disposable photo test',
          'active': true,
          'photoUrl': businessPhoto.url,
          'photoPublicId': businessPhoto.publicId,
        });
        await checkPhoto(
          'businesses/$businessId',
          token,
          'photoUrl',
          businessPhoto.url,
        );
        stdout.writeln('PASS: business photo upload, save and reload');
        for (final type in ['ad', 'voucher']) {
          final poster = await service.upload(testPng());
          photos.add(poster);
          final path = 'campaigns/photo-test-$type-$suffix';
          await write(path, token, {
            'ownerId': uid,
            'businessId': businessId,
            'name': 'Disposable $type photo test',
            'type': type,
            'imageUrl': poster.url,
            'imagePublicId': poster.publicId,
          });
          await checkPhoto(path, token, 'imageUrl', poster.url);
          stdout.writeln('PASS: $type photo upload, save and reload');
        }
        final denied = await client.patch(
          docUrl('users/${accounts.first['localId']}'),
          headers: headers(token),
          body: jsonEncode({
            'fields': fields({'role': 'tourist', 'photoUrl': avatar.url}),
          }),
        );
        if (denied.statusCode != 403) {
          throw StateError('Cross-user profile write was not denied.');
        }
        stdout.writeln(
          'PASS: another user cannot replace the tourist profile photo in Firestore',
        );
      }
    }
  } finally {
    var failures = 0;
    for (final entry in docs.reversed) {
      try {
        final response = await client.delete(
          docUrl(entry.$1),
          headers: headers(entry.$2),
        );
        if (response.statusCode != 200 && response.statusCode != 404) {
          failures++;
        }
      } catch (_) {
        failures++;
      }
    }
    for (final account in accounts) {
      try {
        await auth('delete', {'idToken': account['idToken']});
      } catch (_) {
        failures++;
      }
    }
    for (final photo in photos) {
      if (photo.deleteToken == null) {
        failures++;
        continue;
      }
      try {
        final response = await client.post(
          Uri.https(
            'api.cloudinary.com',
            '/v1_1/${service.cloudName}/delete_by_token',
          ),
          body: {'token': photo.deleteToken!},
        );
        if (response.statusCode != 200 ||
            jsonDecode(response.body)['result'] != 'ok') {
          failures++;
        }
      } catch (_) {
        failures++;
      }
    }
    client.close();
    stdout.writeln(
      failures == 0
          ? 'Cleanup complete: disposable test records/accounts/images removed.'
          : 'Cleanup needs attention: $failures operation(s) failed.',
    );
    if (failures > 0) exitCode = 1;
  }
}

Uint8List testPng() {
  // A generated 2x2 blue square, no personal files or metadata.
  List<int> uint32(int n) =>
      (ByteData(4)..setUint32(0, n)).buffer.asUint8List();
  List<int> chunk(String type, List<int> data) {
    final content = [...ascii.encode(type), ...data];
    var crc = 0xffffffff;
    for (final byte in content) {
      crc ^= byte;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc >>> 1) ^ ((crc & 1) != 0 ? 0xedb88320 : 0);
      }
    }
    return [
      ...uint32(data.length),
      ...content,
      ...uint32((crc ^ 0xffffffff) & 0xffffffff),
    ];
  }

  return Uint8List.fromList([
    137,
    80,
    78,
    71,
    13,
    10,
    26,
    10,
    ...chunk('IHDR', [...uint32(2), ...uint32(2), 8, 2, 0, 0, 0]),
    ...chunk(
      'IDAT',
      zlib.encode([
        0,
        50,
        103,
        212,
        50,
        103,
        212,
        0,
        50,
        103,
        212,
        50,
        103,
        212,
      ]),
    ),
    ...chunk('IEND', []),
  ]);
}
