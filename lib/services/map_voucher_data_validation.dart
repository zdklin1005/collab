import 'package:cloud_firestore/cloud_firestore.dart';

bool hasValidMapVoucherData(Map<String, dynamic> data) {
  bool hasText(String field) {
    final value = data[field];
    return value is String && value.trim().isNotEmpty;
  }

  if (data['type'] != 'voucher' ||
      data['status'] != 'active' ||
      !hasText('ownerId') ||
      !hasText('businessId') ||
      !hasText('name')) {
    return false;
  }

  final start = data['startDate'];
  final end = data['endDate'];

  // Do not invent dates when a shared record is incomplete.
  if (start is! Timestamp || end is! Timestamp) {
    return false;
  }

  if (!end.toDate().isAfter(start.toDate())) {
    return false;
  }

  final quantity = data['quantity'];
  final claims = data['claims'];
  final perCustomerLimit = data['perCustomerLimit'];

  if (quantity is! int ||
      quantity < 0 ||
      claims is! int ||
      claims < 0 ||
      perCustomerLimit is! int ||
      perCustomerLimit < 1) {
    return false;
  }

  if (!const {
    'welcome',
    'promotional',
    'seasonal',
  }.contains(data['voucherType'])) {
    return false;
  }

  if (!const {
    'discovery_claim',
    'walk_up_collect',
    'both',
  }.contains(data['collectionMethod'])) {
    return false;
  }

  return true;
}
