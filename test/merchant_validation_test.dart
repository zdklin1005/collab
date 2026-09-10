import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:collab/core/merchant_validation.dart';
import 'package:collab/core/certificate_scan.dart';

void main() {
  test(
    'voucher amount rejects negative, nonfinite, excessive and fractional precision',
    () {
      for (final v in ['-1', 'NaN', 'Infinity', '1.234', '', '1e2']) {
        expect(MerchantValidation.amount(v), isNotNull, reason: v);
      }
      expect(MerchantValidation.amount('101', percentage: true), isNotNull);
      expect(MerchantValidation.amount('0', percentage: true), isNotNull);
      expect(MerchantValidation.amount('100', percentage: true), isNull);
      expect(MerchantValidation.amount('0', zero: true), isNull);
      expect(MerchantValidation.amount('12.50'), isNull);
    },
  );
  test('quantity must be a positive bounded integer', () {
    for (final v in ['0', '-1', '1.5', '100001', 'abc']) {
      expect(MerchantValidation.quantity(v), isNotNull);
    }
    expect(MerchantValidation.quantity('100'), isNull);
  });
  test('poster validation uses signature and enforces storage limit', () {
    expect(
      MerchantValidation.imageType(
        Uint8List.fromList([255, 216, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
      ),
      'jpeg',
    );
    expect(
      MerchantValidation.imageType(
        Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 0]),
      ),
      'png',
    );
    expect(MerchantValidation.imageType(Uint8List(5 * 1024 * 1024)), isNull);
    expect(
      MerchantValidation.imageType(
        Uint8List.fromList('renamed-file.jpg'.codeUnits),
      ),
      isNull,
    );
  });
  test(
    'certificate parser returns candidates without inventing an identifier',
    () {
      expect(
        registrationCandidate('NO. PENDAFTARAN 202001012345'),
        '202001012345',
      );
      expect(registrationCandidate('Registration 1234567-A'), '1234567-A');
      expect(registrationCandidate('Invoice total RM 123.45'), isNull);
    },
  );
  test('upload errors distinguish access from connection failures', () {
    expect(MerchantValidation.uploadError('unauthorized'), contains('denied'));
    expect(
      MerchantValidation.uploadError('retry-limit-exceeded'),
      contains('timed out'),
    );
    expect(MerchantValidation.uploadError('unknown'), isNot(contains('Blaze')));
  });
}
