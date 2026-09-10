import 'package:cloud_firestore/cloud_firestore.dart';

enum AccountRole { tourist, merchant }

extension AccountRoleX on AccountRole {
  String get value => name;
  String get label => this == AccountRole.tourist ? 'Tourist' : 'Merchant';

  static AccountRole fromValue(String? value) =>
      value == AccountRole.merchant.name
      ? AccountRole.merchant
      : AccountRole.tourist;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.username,
    required this.role,
    this.phone = '',
    this.birthday,
    this.exp = 0,
    this.level = 1,
    this.voucherCount = 0,
    this.reviewCount = 0,
    this.preferences = const {},
    this.photoUrl,
    this.photoPublicId,
  });

  final String id;
  final String email;
  final String displayName;
  final String username;
  final AccountRole role;
  final String phone;
  final DateTime? birthday;
  final int exp;
  final int level;
  final int voucherCount;
  final int reviewCount;
  final Map<String, dynamic> preferences;
  final String? photoUrl;
  final String? photoPublicId;

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppUser(
      id: doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'LocalQuest Explorer',
      username: data['username'] as String? ?? '@explorer',
      role: AccountRoleX.fromValue(data['role'] as String?),
      phone: data['phone'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      photoPublicId: data['photoPublicId'] as String?,
      birthday: (data['birthday'] as Timestamp?)?.toDate(),
      exp: (data['exp'] as num?)?.toInt() ?? 0,
      level: (data['level'] as num?)?.toInt() ?? 1,
      voucherCount: (data['voucherCount'] as num?)?.toInt() ?? 0,
      reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
      preferences: Map<String, dynamic>.from(
        data['preferences'] as Map? ?? const {},
      ),
    );
  }
}

class Business {
  const Business({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.category,
    required this.address,
    required this.phone,
    this.registrationNumber = '',
    this.photoUrl,
    this.photoPublicId,
    this.active = true,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String ownerId;
  final String name;
  final String category;
  final String address;
  final String phone;
  final String registrationNumber;
  final String? photoUrl;
  final String? photoPublicId;
  final bool active;
  final double? latitude;
  final double? longitude;

  factory Business.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Business(
      id: doc.id,
      ownerId: data['ownerId'] as String? ?? '',
      name: data['name'] as String? ?? 'LocalQuest Business',
      category: data['category'] as String? ?? 'Other',
      address: data['address'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      registrationNumber: data['registrationNumber'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      photoPublicId: data['photoPublicId'] as String?,
      active: data['active'] as bool? ?? true,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
    );
  }
}

class Campaign {
  const Campaign({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.type,
    required this.startDate,
    required this.endDate,
    this.businessId = '',
    this.status = 'active',
    this.views = 0,
    this.claims = 0,
    this.imageUrl,
    this.terms = '',
    this.discountType = 'percentage',
    this.discountValue = 0,
    this.minimumSpend = 0,
    this.quantity = 0,
    this.perCustomerLimit = 1,
  });

  final String id;
  final String ownerId;
  final String name;
  final String description;
  final String type;
  final DateTime startDate;
  final DateTime endDate;
  final String businessId;
  final String status;
  final int views;
  final int claims;
  final String? imageUrl;
  final String terms;
  final String discountType;
  final double discountValue;
  final double minimumSpend;
  final int quantity;
  final int perCustomerLimit;

  factory Campaign.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Campaign(
      id: doc.id,
      ownerId: data['ownerId'] as String? ?? '',
      name: data['name'] as String? ?? 'Untitled campaign',
      description: data['description'] as String? ?? '',
      type: data['type'] as String? ?? 'ad',
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate:
          (data['endDate'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(days: 30)),
      businessId: data['businessId'] as String? ?? '',
      status: data['status'] as String? ?? 'active',
      views: (data['views'] as num?)?.toInt() ?? 0,
      claims: (data['claims'] as num?)?.toInt() ?? 0,
      imageUrl: data['imageUrl'] as String?,
      terms: data['terms'] as String? ?? '',
      discountType: data['discountType'] as String? ?? 'percentage',
      discountValue: (data['discountValue'] as num?)?.toDouble() ?? 0,
      minimumSpend: (data['minimumSpend'] as num?)?.toDouble() ?? 0,
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      perCustomerLimit: (data['perCustomerLimit'] as num?)?.toInt() ?? 1,
    );
  }
}
