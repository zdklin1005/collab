import 'package:collab/models/localquest_models.dart';
import 'package:collab/services/map_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Business exampleBusiness({
  bool active = true,
  double? latitude = 5.4,
  double? longitude = 100.3,
}) {
  return Business(
    id: 'test-business',
    ownerId: 'test-merchant',
    name: 'Test Business',
    category: 'Retail',
    address: 'Test address',
    phone: '',
    active: active,
    latitude: latitude,
    longitude: longitude,
  );
}

void main() {
  test('accepts an active business with valid coordinates', () {
    expect(isMappableBusiness(exampleBusiness()), isTrue);
  });

  test('rejects inactive businesses', () {
    expect(isMappableBusiness(exampleBusiness(active: false)), isFalse);
  });

  test('rejects missing coordinates', () {
    expect(isMappableBusiness(exampleBusiness(latitude: null)), isFalse);
    expect(isMappableBusiness(exampleBusiness(longitude: null)), isFalse);
  });

  test('rejects out-of-range and non-finite coordinates', () {
    expect(isMappableBusiness(exampleBusiness(latitude: 91)), isFalse);
    expect(isMappableBusiness(exampleBusiness(longitude: 181)), isFalse);
    expect(isMappableBusiness(exampleBusiness(latitude: double.nan)), isFalse);
    expect(
      isMappableBusiness(exampleBusiness(longitude: double.infinity)),
      isFalse,
    );
  });
}
