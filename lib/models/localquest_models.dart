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
    this.area = '',
    this.postcode = '',
    this.state = '',
    this.registrationNumber = '',
    this.verificationStatus = 'unverified',
    this.photoUrl,
    this.photoPublicId,
    this.active = true,
    this.latitude,
    this.longitude,
    this.operatingHours,
    this.dietaryStatus,
    this.website,
    this.description,
  });

  final String id;
  final String ownerId;
  final String name;
  final String category;
  final String address;
  final String phone;
  final String area;
  final String postcode;
  final String state;
  final String registrationNumber;
  final String verificationStatus; // 'unverified', 'pending_review', 'verified'
  final String? photoUrl;
  final String? photoPublicId;
  final bool active;
  final double? latitude;
  final double? longitude;
  final String? operatingHours;
  final String? dietaryStatus;
  final String? website;
  final String? description;

  bool get isSsmVerified => verificationStatus == 'verified';

  factory Business.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Business(
      id: doc.id,
      ownerId: data['ownerId'] as String? ?? '',
      name: data['name'] as String? ?? 'LocalQuest Business',
      category: data['category'] as String? ?? 'Other',
      address: data['address'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      area: data['area'] as String? ?? data['city'] as String? ?? '',
      postcode: data['postcode'] as String? ?? '',
      state: data['state'] as String? ?? '',
      registrationNumber: data['registrationNumber'] as String? ?? '',
      verificationStatus: data['verificationStatus'] as String? ?? 'unverified',
      photoUrl: data['photoUrl'] as String?,
      photoPublicId: data['photoPublicId'] as String?,
      active: data['active'] as bool? ?? true,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      operatingHours: data['operatingHours'] as String?,
      dietaryStatus: data['dietaryStatus'] as String?,
      website: data['website'] as String?,
      description: data['description'] as String?,
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
    this.voucherType = 'promotional',
    this.collectionMethod = 'both',
    this.seasonName,
    this.linkedAdId,
    this.validDays,
    this.validHours,
    this.redemptionHours,
    this.dailyQuota,
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
  final String voucherType; // 'welcome', 'promotional', 'seasonal'
  final String collectionMethod; // 'discovery_claim', 'walk_up_collect', 'both'
  final String? seasonName;
  final String? linkedAdId;
  final String? validDays;
  final String? validHours;
  final String? redemptionHours;
  final int? dailyQuota;

  String? get effectiveHours => validHours ?? redemptionHours;

  bool get isWelcomeVoucher => type == 'voucher' && voucherType == 'welcome';
  bool get isSeasonalVoucher =>
      type == 'voucher' &&
      (voucherType == 'seasonal' ||
          (voucherType == 'promotional' &&
              seasonName != null &&
              seasonName!.trim().isNotEmpty));
  bool get isPromotionalVoucher =>
      type == 'voucher' && voucherType == 'promotional' && !isSeasonalVoucher;

  factory Campaign.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final validHrs = data['validHours'] as String? ?? data['redemptionHours'] as String?;
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
      voucherType: data['voucherType'] as String? ?? 'promotional',
      collectionMethod: data['collectionMethod'] as String? ?? 'both',
      seasonName: data['seasonName'] as String?,
      linkedAdId: data['linkedAdId'] as String?,
      validDays: data['validDays'] as String?,
      validHours: validHrs,
      redemptionHours: validHrs,
      dailyQuota: (data['dailyQuota'] as num?)?.toInt(),
    );
  }
}

class Friend {
  const Friend({
    required this.id,
    required this.friendUserId,
    required this.displayName,
    required this.username,
    this.photoUrl,
    this.level = 1,
    this.note,
    required this.createdAt,
  });

  final String id;
  final String friendUserId;
  final String displayName;
  final String username;
  final String? photoUrl;
  final int level;
  final String? note;
  final DateTime createdAt;

  factory Friend.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Friend(
      id: doc.id,
      friendUserId: data['friendUserId'] as String? ?? doc.id,
      displayName: data['displayName'] as String? ?? 'Tourist Explorer',
      username: data['username'] as String? ?? '@explorer',
      photoUrl: data['photoUrl'] as String?,
      level: (data['level'] as num?)?.toInt() ?? 1,
      note: data['note'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.fromDisplayName,
    required this.fromUsername,
    this.fromPhotoUrl,
    this.fromLevel = 1,
    this.status = 'pending',
    required this.createdAt,
  });

  final String id;
  final String fromUserId;
  final String toUserId;
  final String fromDisplayName;
  final String fromUsername;
  final String? fromPhotoUrl;
  final int fromLevel;
  final String status;
  final DateTime createdAt;

  factory FriendRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return FriendRequest(
      id: doc.id,
      fromUserId: data['fromUserId'] as String? ?? '',
      toUserId: data['toUserId'] as String? ?? '',
      fromDisplayName: data['fromDisplayName'] as String? ?? 'Explorer',
      fromUsername: data['fromUsername'] as String? ?? '@explorer',
      fromPhotoUrl: data['fromPhotoUrl'] as String?,
      fromLevel: (data['fromLevel'] as num?)?.toInt() ?? 1,
      status: data['status'] as String? ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class UserNote {
  const UserNote({
    required this.userId,
    required this.text,
    required this.createdAt,
    this.songTitle,
    this.songArtist,
    this.albumArtUrl,
    this.spotifyUrl,
  });

  final String userId;
  final String text;
  final DateTime createdAt;
  final String? songTitle;
  final String? songArtist;
  final String? albumArtUrl;
  final String? spotifyUrl;

  bool get hasMusic => songTitle != null && songTitle!.trim().isNotEmpty;

  factory UserNote.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserNote(
      userId: doc.id,
      text: data['text'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      songTitle: data['songTitle'] as String?,
      songArtist: data['songArtist'] as String?,
      albumArtUrl: data['albumArtUrl'] as String?,
      spotifyUrl: data['spotifyUrl'] as String?,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.isRead = false,
    this.type = 'text',
    this.imageUrl,
    this.latitude,
    this.longitude,
    this.locationName,
  });

  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final bool isRead;
  final String type;
  final String? imageUrl;
  final double? latitude;
  final double? longitude;
  final String? locationName;

  bool get isImage => type == 'image';
  bool get isLocation => type == 'location';
  bool get isText => type == 'text';

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ChatMessage(
      id: doc.id,
      chatId: data['chatId'] as String? ?? '',
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] as bool? ?? false,
      type: data['type'] as String? ?? 'text',
      imageUrl: data['imageUrl'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      locationName: data['locationName'] as String?,
    );
  }
}

class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.participants,
    required this.otherUserId,
    required this.otherDisplayName,
    required this.otherUsername,
    this.otherPhotoUrl,
    this.lastMessage = '',
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.lastSenderId = '',
  });

  final String id;
  final List<String> participants;
  final String otherUserId;
  final String otherDisplayName;
  final String otherUsername;
  final String? otherPhotoUrl;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final String lastSenderId;

  factory ChatConversation.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String currentUserId,
  ) {
    final data = doc.data() ?? {};
    final participants = List<String>.from(data['participants'] as List? ?? []);
    final otherUserId = participants.firstWhere(
      (p) => p != currentUserId,
      orElse: () => '',
    );

    final userSummaries = Map<String, dynamic>.from(
      data['userSummaries'] as Map? ?? {},
    );
    final otherSummary = Map<String, dynamic>.from(
      userSummaries[otherUserId] as Map? ?? {},
    );

    return ChatConversation(
      id: doc.id,
      participants: participants,
      otherUserId: otherUserId,
      otherDisplayName: otherSummary['displayName'] as String? ?? 'Friend',
      otherUsername: otherSummary['username'] as String? ?? '@friend',
      otherPhotoUrl: otherSummary['photoUrl'] as String?,
      lastMessage: data['lastMessage'] as String? ?? '',
      lastMessageTime:
          (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCount:
          (data['unreadCount_$currentUserId'] as num?)?.toInt() ?? 0,
      lastSenderId: data['lastSenderId'] as String? ?? '',
    );
  }
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.username,
    this.photoUrl,
    required this.level,
    required this.exp,
    required this.rank,
    this.isCurrentUser = false,
  });

  final String userId;
  final String displayName;
  final String username;
  final String? photoUrl;
  final int level;
  final int exp;
  final int rank;
  final bool isCurrentUser;

  factory LeaderboardEntry.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    int rank = 1,
    String? currentUserId,
  }) {
    final data = doc.data() ?? {};
    return LeaderboardEntry(
      userId: doc.id,
      displayName: data['displayName'] as String? ?? 'Penang Explorer',
      username: data['username'] as String? ?? '@explorer',
      photoUrl: data['photoUrl'] as String?,
      level: (data['level'] as num?)?.toInt() ?? 1,
      exp: (data['exp'] as num?)?.toInt() ?? 0,
      rank: rank,
      isCurrentUser: currentUserId != null && currentUserId == doc.id,
    );
  }

  factory LeaderboardEntry.fromAppUser(
    AppUser user, {
    int rank = 1,
    String? currentUserId,
  }) {
    return LeaderboardEntry(
      userId: user.id,
      displayName: user.displayName,
      username: user.username,
      photoUrl: user.photoUrl,
      level: user.level,
      exp: user.exp,
      rank: rank,
      isCurrentUser: currentUserId != null && currentUserId == user.id,
    );
  }

  LeaderboardEntry copyWith({
    int? rank,
    bool? isCurrentUser,
  }) {
    return LeaderboardEntry(
      userId: userId,
      displayName: displayName,
      username: username,
      photoUrl: photoUrl,
      level: level,
      exp: exp,
      rank: rank ?? this.rank,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }
}
