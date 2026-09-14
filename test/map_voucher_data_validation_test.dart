import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collab/services/map_voucher_data_validation.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> voucherData() => {
  'ownerId': 'merchant-1',
  'businessId': 'business-1',
  'name': 'Coffee discount',
  'type': 'voucher',
  'status': 'active',
  'startDate': Timestamp.fromDate(DateTime.utc(2026, 9, 1)),
  'endDate': Timestamp.fromDate(DateTime.utc(2026, 10, 1)),
  'quantity': 50,
  'claims': 3,
  'perCustomerLimit': 1,
  'voucherType': 'promotional',
  'collectionMethod': 'both',
};

void main() {
  test('accepts a complete active voucher record', () {
    expect(hasValidMapVoucherData(voucherData()), isTrue);
  });

  test('rejects ads and inactive campaigns', () {
    expect(hasValidMapVoucherData({...voucherData(), 'type': 'ad'}), isFalse);

    expect(
      hasValidMapVoucherData({...voucherData(), 'status': 'inactive'}),
      isFalse,
    );
  });

  test('rejects missing identity or dates instead of inventing values', () {
    for (final field in [
      'ownerId',
      'businessId',
      'name',
      'startDate',
      'endDate',
    ]) {
      final data = voucherData()..remove(field);
      expect(hasValidMapVoucherData(data), isFalse, reason: field);
    }
  });

  test('rejects invalid date order', () {
    final data = voucherData();
    data['endDate'] = data['startDate'];

    expect(hasValidMapVoucherData(data), isFalse);
  });

  test('rejects malformed quantities and limits', () {
    for (final change in <Map<String, dynamic>>[
      {'quantity': -1},
      {'quantity': '50'},
      {'claims': -1},
      {'claims': 1.5},
      {'perCustomerLimit': 0},
    ]) {
      expect(
        hasValidMapVoucherData({...voucherData(), ...change}),
        isFalse,
        reason: change.toString(),
      );
    }
  });

  test('requires a recognised collection method and voucher type', () {
    expect(
      hasValidMapVoucherData({...voucherData(), 'collectionMethod': 'unknown'}),
      isFalse,
    );

    expect(
      hasValidMapVoucherData({...voucherData(), 'voucherType': 'unknown'}),
      isFalse,
    );
  });

  test(
    'structurally valid sold-out offers still require eligibility checks',
    () {
      expect(
        hasValidMapVoucherData({
          ...voucherData(),
          'quantity': 50,
          'claims': 50,
        }),
        isTrue,
      );
    },
  );
}
