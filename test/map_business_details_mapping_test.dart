import 'package:collab/models/localquest_models.dart';
import 'package:collab/models/map_location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('business details are preserved in the map model', () {
    const business = Business(
      id: 'business-test',
      ownerId: 'merchant-test',
      name: 'Test Cafe',
      category: 'Cafe',
      address: 'Test address',
      phone: ' 0123456789 ',
      latitude: 5,
      longitude: 100,
      description: ' A neighbourhood cafe. ',
      operatingHours: ' Mon–Fri: 8 AM–5 PM ',
      website: ' https://example.com ',
      dietaryStatus: ' Vegetarian options ',
      photoUrl: ' https://example.com/business.jpg ',
    );

    final location = MapLocation.fromBusiness(business);

    expect(location, isNotNull);
    expect(location!.description, 'A neighbourhood cafe.');
    expect(location.operatingHours, 'Mon–Fri: 8 AM–5 PM');
    expect(location.phone, '0123456789');
    expect(location.website, 'https://example.com');
    expect(location.dietaryStatus, 'Vegetarian options');
    expect(location.photoUrl, 'https://example.com/business.jpg');
  });

  test('missing optional business details remain safe', () {
    const business = Business(
      id: 'business-test',
      ownerId: 'merchant-test',
      name: 'Test Cafe',
      category: 'Cafe',
      address: '',
      phone: '',
      latitude: 5,
      longitude: 100,
    );

    final location = MapLocation.fromBusiness(business)!;

    expect(location.description, isEmpty);
    expect(location.operatingHours, isEmpty);
    expect(location.website, isEmpty);
    expect(location.dietaryStatus, isEmpty);
    expect(location.photoUrl, isNull);
  });
}
