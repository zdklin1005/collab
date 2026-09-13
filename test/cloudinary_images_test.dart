import 'dart:convert';
import 'dart:typed_data';
import 'package:collab/services/cloudinary_images.dart';
import 'package:collab/core/localquest_widgets.dart';
import 'package:collab/core/profile_photo_editor.dart';
import 'package:collab/models/localquest_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
);
void main() {
  test('unsigned upload sends preset and bytes, never an API secret', () async {
    final service = CloudinaryImages(
      clientFactory: () => MockClient((request) async {
        expect(
          request.url.toString(),
          'https://api.cloudinary.com/v1_1/g9podhp8/image/upload',
        );
        final body = latin1.decode(request.bodyBytes);
        expect(body, contains('localquest_photos'));
        expect(body, isNot(contains('api_secret')));
        expect(body, isNot(contains('signature')));
        return http.Response(
          jsonEncode({
            'resource_type': 'image',
            'public_id': 'photo-1',
            'secure_url':
                'https://res.cloudinary.com/g9podhp8/image/upload/v1/photo-1.png',
          }),
          200,
        );
      }),
    );
    final uploaded = await service.upload(png);
    expect(uploaded.publicId, 'photo-1');
  });
  test('bad files are rejected before making a network request', () async {
    var called = false;
    final service = CloudinaryImages(
      clientFactory: () {
        called = true;
        return MockClient((_) async => http.Response('', 500));
      },
    );
    await expectLater(
      service.upload(Uint8List(12)),
      throwsA(isA<PhotoUploadException>()),
    );
    expect(called, false);
  });
  test(
    'rejected uploads give a useful error, not a raw provider stack',
    () async {
      final service = CloudinaryImages(
        clientFactory: () => MockClient(
          (_) async => http.Response('{"error":"internal config"}', 400),
        ),
      );
      await expectLater(
        service.upload(png),
        throwsA(
          isA<PhotoUploadException>().having(
            (e) => e.message,
            'message',
            contains('configuration'),
          ),
        ),
      );
    },
  );
  test('only expected HTTPS image URLs are accepted', () async {
    final service = CloudinaryImages(
      clientFactory: () => MockClient(
        (_) async => http.Response(
          jsonEncode({
            'resource_type': 'image',
            'public_id': 'photo-1',
            'secure_url': 'https://example.com/photo.png',
          }),
          200,
        ),
      ),
    );
    await expectLater(
      service.upload(png),
      throwsA(isA<PhotoUploadException>()),
    );
  });
  testWidgets(
    'both roles get profile photo controls without starting Firebase',
    (tester) async {
      for (final role in AccountRole.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ProfilePhotoEditor(
                user: AppUser(
                  id: role.name,
                  email: 'test@example.com',
                  displayName: 'Photo User',
                  username: '@photo',
                  role: role,
                ),
              ),
            ),
          ),
        );
        expect(find.byTooltip('Add profile photo'), findsOneWidget);
        expect(find.text('PU'), findsOneWidget);
      }
    },
  );
  testWidgets('profile bubble keeps photo fallback and Profile label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LqFloatingNavBar(
            selectedIndex: 2,
            onSelected: (_) {},
            items: const [
              (Icons.home, 'Home'),
              (Icons.campaign, 'Campaigns'),
              (Icons.person, 'Profile'),
            ],
            profileInitials: 'PU',
            profilePhotoUrl: 'invalid',
          ),
        ),
      ),
    );
    expect(find.text('PU'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
