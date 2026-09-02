import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:collab/models/localquest_models.dart';
import 'package:collab/services/localquest_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('account roles round-trip through Firestore values', () {
    expect(AccountRoleX.fromValue('tourist'), AccountRole.tourist);
    expect(AccountRoleX.fromValue('merchant'), AccountRole.merchant);
    expect(AccountRole.merchant.value, 'merchant');
  });

  test('five failures create a ten-minute local lock', () async {
    SharedPreferences.setMockInitialValues({});
    final throttle = LoginThrottle();
    const email = 'explorer@localquest.test';

    for (var attempt = 0; attempt < 5; attempt++) {
      await throttle.recordFailure(email);
    }

    final until = await throttle.lockedUntil(email);
    expect(until, isNotNull);
    final remaining = until!.difference(DateTime.now());
    expect(remaining.inMinutes, greaterThanOrEqualTo(9));
    expect(remaining.inMinutes, lessThanOrEqualTo(10));
  });
}
