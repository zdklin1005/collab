import 'package:cloud_firestore/cloud_firestore.dart';

class SeedBusinessData {
  const SeedBusinessData({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.area,
    required this.postcode,
    required this.state,
    required this.phone,
    required this.registrationNumber,
    required this.latitude,
    required this.longitude,
    required this.vouchers,
    this.operatingHours,
    this.dietaryStatus,
    this.website,
    this.description,
  });

  final String id;
  final String name;
  final String category;
  final String address;
  final String area;
  final String postcode;
  final String state;
  final String phone;
  final String registrationNumber;
  final double latitude;
  final double longitude;
  final List<SeedVoucherData> vouchers;
  final String? operatingHours;
  final String? dietaryStatus;
  final String? website;
  final String? description;
}

class SeedVoucherData {
  const SeedVoucherData({
    required this.id,
    required this.name,
    required this.description,
    required this.voucherType,
    required this.collectionMethod,
    required this.discountType,
    required this.discountValue,
    required this.minimumSpend,
    required this.quantity,
    required this.perCustomerLimit,
    this.seasonName,
    this.linkedAdId,
    this.validDays,
    this.validHours,
    this.redemptionHours,
    this.dailyQuota,
    required this.terms,
  });

  final String id;
  final String name;
  final String description;
  final String voucherType; // 'welcome', 'promotional', 'seasonal'
  final String collectionMethod; // 'discovery_claim', 'walk_up_collect', 'both'
  final String discountType; // 'percentage', 'fixed'
  final double discountValue;
  final double minimumSpend;
  final int quantity;
  final int perCustomerLimit;
  final String? seasonName;
  final String? linkedAdId;
  final String? validDays;
  final String? validHours;
  final String? redemptionHours;
  final int? dailyQuota;
  final String terms;

  String? get effectiveHours => validHours ?? redemptionHours;
}

class DemoDatabaseSeeder {
  DemoDatabaseSeeder._();

  /// Curated authentic establishments exclusively located in Penang (Pulau Pinang), Malaysia.
  static final List<SeedBusinessData> sampleMalaysianBusinesses = [
    SeedBusinessData(
      id: 'demo_biz_chinahouse_penang',
      name: 'ChinaHouse Heritage Cafe & Bakery',
      category: 'Food & Beverage',
      address: '153, Beach St, Georgetown',
      area: 'George Town Heritage Core',
      postcode: '10300',
      state: 'Pulau Pinang',
      phone: '+6042637299',
      registrationNumber: '201101034567 (934567-T)',
      latitude: 5.4144,
      longitude: 100.3392,
      operatingHours: '9:00 AM – 12:00 AM (Daily)',
      dietaryStatus: 'Muslim-Friendly / Pork-Free',
      website: 'https://instagram.com/chinahousepenang',
      description:
          'Penang\'s longest heritage shophouse featuring an iconic 30-cake counter, live music, courtyard dining, and art gallery.',
      vouchers: [
        SeedVoucherData(
          id: 'demo_ch_welcome_cake',
          name: 'George Town Welcome - RM5 Off Cake Counter',
          description: 'Discover Penang\'s longest heritage shophouse! Enjoy RM5 off any slice from our famous 30-cake counter display.',
          voucherType: 'welcome',
          collectionMethod: 'discovery_claim',
          discountType: 'fixed',
          discountValue: 5.0,
          minimumSpend: 20.0,
          quantity: 250,
          perCustomerLimit: 1,
          terms: '1. Valid for first-time visitors upon discovery.\n2. 1 voucher per guest receipt.\n3. Applicable on all freshly baked counter cakes.',
        ),
        SeedVoucherData(
          id: 'demo_ch_promo_coffee',
          name: 'Heritage Cake & Coffee Set - 15% Off',
          description: 'Enjoy 15% off when ordering any artisanal dessert alongside a drip coffee or cold brew.',
          voucherType: 'promotional',
          collectionMethod: 'both',
          discountType: 'percentage',
          discountValue: 15.0,
          minimumSpend: 30.0,
          quantity: 180,
          perCustomerLimit: 2,
          linkedAdId: 'demo_ad_penang_heritage_fest',
          redemptionHours: '2:00 PM – 6:00 PM (Tea time)',
          dailyQuota: 30,
          terms: '1. Valid daily between 2:00 PM and 6:00 PM.\n2. Up to 2 redemptions per customer.\n3. Maximum 30 daily redemptions.',
        ),
        SeedVoucherData(
          id: 'demo_ch_seasonal_heritage',
          name: 'Penang Heritage Month - RM10 Off Courtyard Dining',
          description: 'Celebrate UNESCO World Heritage status with RM10 off our courtyard dining mains and fusion bowls.',
          voucherType: 'seasonal',
          seasonName: 'Penang Heritage Month',
          collectionMethod: 'both',
          discountType: 'fixed',
          discountValue: 10.0,
          minimumSpend: 50.0,
          quantity: 100,
          perCustomerLimit: 1,
          terms: '1. Valid during Penang Heritage Month.\n2. One claim per customer.\n3. Minimum spend RM50 on food and beverage.',
        ),
      ],
    ),
    SeedBusinessData(
      id: 'demo_biz_hameediyah_penang',
      name: 'Hameediyah Restaurant 1907',
      category: 'Food & Beverage',
      address: '164A, Lebuh Campbell, City Centre',
      area: 'George Town',
      postcode: '10100',
      state: 'Pulau Pinang',
      phone: '+6042611095',
      registrationNumber: '190701000001 (10001-A)',
      latitude: 5.4172,
      longitude: 100.3323,
      operatingHours: '10:00 AM – 10:00 PM (Daily)',
      dietaryStatus: 'Halal Certified',
      website: 'https://hameediyah.my',
      description:
          'Malaysia\'s oldest existing Nasi Kandar restaurant, established in 1907, renowned for spiced murtabak, duck biryani, and rich heritage gravies.',
      vouchers: [
        SeedVoucherData(
          id: 'demo_ham_welcome_murtabak',
          name: 'Hameediyah 1907 Welcome - RM3 Off Murtabak & Biryani',
          description: 'Welcome to Malaysia\'s oldest Nasi Kandar establishment, serving authentic spiced heritage cuisine since 1907.',
          voucherType: 'welcome',
          collectionMethod: 'discovery_claim',
          discountType: 'fixed',
          discountValue: 3.0,
          minimumSpend: 15.0,
          quantity: 300,
          perCustomerLimit: 1,
          terms: '1. Claimable once upon discovering Hameediyah.\n2. Valid for dine-in or takeaway at Campbell Street branch.\n3. One voucher per order.',
        ),
        SeedVoucherData(
          id: 'demo_ham_promo_feast',
          name: 'Nasi Kandar Heritage Feast - 10% Off Orders Above RM30',
          description: 'Enjoy 10% off our famous spiced mutton, crispy fried chicken, and signature mixed curries (kuah campur).',
          voucherType: 'promotional',
          collectionMethod: 'both',
          discountType: 'percentage',
          discountValue: 10.0,
          minimumSpend: 30.0,
          quantity: 200,
          perCustomerLimit: 2,
          redemptionHours: '3:00 PM – 7:00 PM (Off-peak)',
          dailyQuota: 40,
          terms: '1. Valid between 3:00 PM and 7:00 PM.\n2. Limit 2 vouchers per user account.\n3. Applicable on food and beverage combos.',
        ),
        SeedVoucherData(
          id: 'demo_ham_seasonal_feast',
          name: 'Raya Festive Heritage Feast - RM8 Off Spiced Lamb Biryani',
          description: 'Festive season savings on our signature claypot lamb biryani and rose syrup bandung.',
          voucherType: 'seasonal',
          seasonName: 'Hari Raya Festive',
          collectionMethod: 'both',
          discountType: 'fixed',
          discountValue: 8.0,
          minimumSpend: 35.0,
          quantity: 120,
          perCustomerLimit: 1,
          terms: '1. Valid during Hari Raya festive month.\n2. Available via discovery claim and geofenced walk-up.\n3. One voucher per customer.',
        ),
      ],
    ),
    SeedBusinessData(
      id: 'demo_biz_toh_soon_penang',
      name: 'Toh Soon Cafe',
      category: 'Food & Beverage',
      address: 'Campbell Street Alleyway, Lebuh Campbell',
      area: 'George Town',
      postcode: '10100',
      state: 'Pulau Pinang',
      phone: '+6042633000',
      registrationNumber: '201201015678 (985678-K)',
      latitude: 5.4189,
      longitude: 100.3322,
      operatingHours: '8:00 AM – 5:00 PM (Closed Sundays)',
      dietaryStatus: 'Muslim-Friendly / Pork-Free',
      website: 'https://facebook.com/tohsooncafe',
      description:
          'A historic Campbell Street back-alley kopitiam famous for charcoal-toasted Hainan bread, homemade kaya, half-boiled kampung eggs, and aromatic butter coffee.',
      vouchers: [
        SeedVoucherData(
          id: 'demo_ts_welcome_kopi',
          name: 'Toh Soon Welcome - Complimentary Hainanese Kopi',
          description: 'Experience Penang\'s iconic back-alley coffee spot! Get a free traditional hot Hainanese butter coffee with any toast order.',
          voucherType: 'welcome',
          collectionMethod: 'discovery_claim',
          discountType: 'fixed',
          discountValue: 3.5,
          minimumSpend: 8.0,
          quantity: 300,
          perCustomerLimit: 1,
          terms: '1. Valid for first-time visitors upon discovery.\n2. 1 claim per customer.\n3. Valid with any charcoal toast order.',
        ),
        SeedVoucherData(
          id: 'demo_ts_promo_toast',
          name: 'Traditional Kopitiam Set - 15% Off Toast Combo',
          description: 'Charcoal-toasted Hainan bread with homemade kaya and half-boiled kampung eggs combo discount.',
          voucherType: 'promotional',
          collectionMethod: 'walk_up_collect',
          discountType: 'percentage',
          discountValue: 15.0,
          minimumSpend: 12.0,
          quantity: 150,
          perCustomerLimit: 2,
          redemptionHours: '8:00 AM – 11:30 AM',
          dailyQuota: 50,
          terms: '1. Walk up to the Campbell Street alley to collect via GPS.\n2. Max 2 uses per tourist.\n3. Cashier verification required.',
        ),
      ],
    ),
    SeedBusinessData(
      id: 'demo_biz_ferringhi_batik',
      name: 'Batu Ferringhi Artisan Batik & Craft',
      category: 'Retail & Souvenirs',
      address: '88, Jalan Batu Ferringhi',
      area: 'Batu Ferringhi',
      postcode: '11100',
      state: 'Pulau Pinang',
      phone: '+6048812345',
      registrationNumber: '201601023456 (1123456-M)',
      latitude: 5.4745,
      longitude: 100.2482,
      operatingHours: '10:00 AM – 9:00 PM (Daily)',
      dietaryStatus: 'Not Applicable',
      website: 'https://penangbatikcraft.com.my',
      description:
          'Premier cultural craft boutique offering hand-painted Malaysian silk batik apparel, tropical resort wear, and locally made souvenirs.',
      vouchers: [
        SeedVoucherData(
          id: 'demo_bf_welcome_keepsake',
          name: 'Penang Artisan Welcome - RM15 Off Handcrafted Silk Batik',
          description: 'Discover certified Penang handcrafted batik apparel, beachwear, and handmade pewter souvenirs.',
          voucherType: 'welcome',
          collectionMethod: 'discovery_claim',
          discountType: 'fixed',
          discountValue: 15.0,
          minimumSpend: 60.0,
          quantity: 150,
          perCustomerLimit: 1,
          terms: '1. Valid once per tourist upon map discovery.\n2. Applicable on silk batik wraps and handmade shirts.\n3. Cannot be combined with other vouchers.',
        ),
        SeedVoucherData(
          id: 'demo_bf_seasonal_gtf',
          name: 'George Town Festival - 20% Off Artisan Apparel',
          description: 'Special annual festival celebration: 20% off authentic Malaysian hand-drawn batik apparel.',
          voucherType: 'seasonal',
          seasonName: 'George Town Festival',
          collectionMethod: 'both',
          discountType: 'percentage',
          discountValue: 20.0,
          minimumSpend: 80.0,
          quantity: 100,
          perCustomerLimit: 1,
          terms: '1. Valid during George Town Festival season.\n2. Available via discovery claim and geofenced walk-up.\n3. Minimum purchase RM80.',
        ),
        SeedVoucherData(
          id: 'demo_bf_promo_souvenirs',
          name: 'Island Souvenir Perk - 10% Off Small Accessories',
          description: '10% discount on handmade batik pouches, tote bags, and locally crafted wooden keychains.',
          voucherType: 'promotional',
          collectionMethod: 'walk_up_collect',
          discountType: 'percentage',
          discountValue: 10.0,
          minimumSpend: 25.0,
          quantity: 200,
          perCustomerLimit: 3,
          redemptionHours: 'All Day',
          dailyQuota: 50,
          terms: '1. Walk up to Batu Ferringhi showroom to collect via GPS.\n2. Up to 3 claims per tourist.\n3. Valid on souvenir items.',
        ),
      ],
    ),
    SeedBusinessData(
      id: 'demo_biz_air_itam_curry',
      name: 'Air Itam Sister Curry Mee',
      category: 'Food & Beverage',
      address: '612 T, Jalan Air Itam, Pekan Itam',
      area: 'Air Itam',
      postcode: '11500',
      state: 'Pulau Pinang',
      phone: '+60124108888',
      registrationNumber: '201801045678 (1245678-T)',
      latitude: 5.3995,
      longitude: 100.2783,
      operatingHours: '7:30 AM – 1:00 PM (Closed Tuesdays)',
      dietaryStatus: 'Non-Halal',
      website: 'https://penangfooddirectory.com/sister-curry-mee',
      description:
          'Legendary 70-year roadside stall run by two sisters cooking rich charcoal-fired curry mee with cuttlefish, coagulated blood, and aromatic chili paste.',
      vouchers: [
        SeedVoucherData(
          id: 'demo_ai_welcome_curry',
          name: 'Air Itam Welcome Treat - RM2 Off Charcoal Curry Mee',
          description: 'Visit the legendary 70-year charcoal curry mee stall near the foot of Kek Lok Si Temple! Get RM2 off your bowl.',
          voucherType: 'welcome',
          collectionMethod: 'discovery_claim',
          discountType: 'fixed',
          discountValue: 2.0,
          minimumSpend: 8.0,
          quantity: 300,
          perCustomerLimit: 1,
          terms: '1. One claim per customer.\n2. Valid for dine-in at Air Itam stall.\n3. Valid with purchase of any signature curry mee.',
        ),
        SeedVoucherData(
          id: 'demo_ai_promo_kek_lok_si',
          name: 'Kek Lok Si Explorer Combo - 10% Off Two Bowls & Drink',
          description: 'Special temple explorer combo: 10% off when enjoying two bowls of curry mee with homemade herbal tea.',
          voucherType: 'promotional',
          collectionMethod: 'both',
          discountType: 'percentage',
          discountValue: 10.0,
          minimumSpend: 15.0,
          quantity: 200,
          perCustomerLimit: 2,
          redemptionHours: '7:30 AM – 1:00 PM (Morning service)',
          dailyQuota: 30,
          terms: '1. Valid daily during morning stall hours until 1:00 PM.\n2. Limit 2 uses per user.\n3. Cannot be combined with other offers.',
        ),
      ],
    ),
  ];

  /// Seeds authentic Penang sample businesses, promotional Ads, and categorized vouchers into Firestore.
  /// If [targetOwnerId] is supplied (e.g. the currently signed-in merchant),
  /// the businesses and vouchers will be associated with that owner so they appear in their dashboard.
  static Future<int> seed({String? targetOwnerId}) async {
    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    int count = 0;

    final now = DateTime.now();
    final oneMonthAhead = now.add(const Duration(days: 30));
    final twoMonthsAhead = now.add(const Duration(days: 60));

    final ownerId = (targetOwnerId != null && targetOwnerId.trim().isNotEmpty)
        ? targetOwnerId.trim()
        : 'demo_merchant_penang';

    // Seed a flagship Promotional Ad Campaign for ChinaHouse to showcase linking
    final adRef = db.collection('campaigns').doc('demo_ad_penang_heritage_fest');
    batch.set(adRef, {
      'ownerId': ownerId,
      'businessId': 'demo_biz_chinahouse_penang',
      'name': 'Penang Heritage Weekend Festival Ad',
      'description': 'Experience George Town living heritage, live courtyard acoustic performances, and artisanal pastry tastings at ChinaHouse.',
      'type': 'ad',
      'startDate': Timestamp.fromDate(now),
      'endDate': Timestamp.fromDate(oneMonthAhead),
      'status': 'active',
      'views': 420,
      'claims': 0,
      'terms': 'Ad banner featured across Penang interactive map and explorer discovery feeds.',
      'discountType': 'percentage',
      'discountValue': 0,
      'minimumSpend': 0,
      'quantity': 1000,
      'perCustomerLimit': 1,
      'voucherType': 'promotional',
      'collectionMethod': 'both',
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    count++;

    for (final biz in sampleMalaysianBusinesses) {
      final bizRef = db.collection('businesses').doc(biz.id);
      batch.set(bizRef, {
        'ownerId': ownerId,
        'name': biz.name,
        'category': biz.category,
        'address': biz.address,
        'area': biz.area,
        'postcode': biz.postcode,
        'state': biz.state,
        'phone': biz.phone,
        'registrationNumber': biz.registrationNumber,
        'verificationStatus': 'verified',
        'active': true,
        'latitude': biz.latitude,
        'longitude': biz.longitude,
        if (biz.operatingHours != null) 'operatingHours': biz.operatingHours,
        if (biz.dietaryStatus != null) 'dietaryStatus': biz.dietaryStatus,
        if (biz.website != null) 'website': biz.website,
        if (biz.description != null) 'description': biz.description,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      count++;

      for (final v in biz.vouchers) {
        final vRef = db.collection('campaigns').doc(v.id);
        batch.set(vRef, {
          'ownerId': ownerId,
          'businessId': biz.id,
          'name': v.name,
          'description': v.description,
          'type': 'voucher',
          'startDate': Timestamp.fromDate(now),
          'endDate': Timestamp.fromDate(
            v.voucherType == 'seasonal' ? twoMonthsAhead : oneMonthAhead,
          ),
          'status': 'active',
          'views': 0,
          'claims': 0,
          'terms': v.terms,
          'discountType': v.discountType,
          'discountValue': v.discountValue,
          'minimumSpend': v.minimumSpend,
          'quantity': v.quantity,
          'perCustomerLimit': v.voucherType == 'welcome' ? 1 : v.perCustomerLimit,
          'voucherType': v.voucherType,
          'collectionMethod': v.collectionMethod,
          if (v.seasonName != null) 'seasonName': v.seasonName,
          if (v.linkedAdId != null) 'linkedAdId': v.linkedAdId,
          if (v.validDays != null) 'validDays': v.validDays,
          if (v.effectiveHours != null) 'validHours': v.effectiveHours,
          if (v.effectiveHours != null) 'redemptionHours': v.effectiveHours,
          if (v.dailyQuota != null) 'dailyQuota': v.dailyQuota,
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        count++;
      }
    }

    await batch.commit();
    return count;
  }

  /// Seeds sample friends, 24-hr vibe notes, and a pending request for immediate testing.
  static Future<void> seedTouristSocial(String touristUid) async {
    if (touristUid.isEmpty) return;
    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    // Friend 1: Sarah Tan
    final friend1Ref = db
        .collection('users')
        .doc(touristUid)
        .collection('friends')
        .doc('demo_tourist_sarah');
    batch.set(friend1Ref, {
      'friendUserId': 'demo_tourist_sarah',
      'displayName': 'Sarah Tan',
      'username': '@sarahexplores',
      'level': 3,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Sarah's 24-hr note with Spotify music
    final sarahNoteRef = db
        .collection('users')
        .doc('demo_tourist_sarah')
        .collection('notes')
        .doc('status');
    batch.set(sarahNoteRef, {
      'text': 'Eating Cendol at Penang Road! 🍧',
      'songTitle': 'Golden Hour',
      'songArtist': 'JVKE',
      'albumArtUrl':
          'https://is1-ssl.mzstatic.com/image/thumb/Music112/v4/bf/16/be/bf16be0c-54be-9cfc-084e-397394c8e718/196925184852_Cover.jpg/300x300bb.jpg',
      'spotifyUrl': 'https://open.spotify.com/search/JVKE%20Golden%20Hour',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Friend 2: Marcus Wong
    final friend2Ref = db
        .collection('users')
        .doc(touristUid)
        .collection('friends')
        .doc('demo_tourist_marcus');
    batch.set(friend2Ref, {
      'friendUserId': 'demo_tourist_marcus',
      'displayName': 'Marcus Wong',
      'username': '@marcus_penang',
      'level': 2,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Marcus's 24-hr note with Spotify music
    final marcusNoteRef = db
        .collection('users')
        .doc('demo_tourist_marcus')
        .collection('notes')
        .doc('status');
    batch.set(marcusNoteRef, {
      'text': 'Hunting street art at Armenian St 🎨',
      'songTitle': 'Sunflower',
      'songArtist': 'Post Malone & Swae Lee',
      'albumArtUrl':
          'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/05/85/74/0585743c-6238-d621-396a-a8c6fb20e980/18UMGIM72688.rgb.jpg/300x300bb.jpg',
      'spotifyUrl': 'https://open.spotify.com/search/Post%20Malone%20Sunflower',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Pending friend request from Aiman
    final reqRef = db
        .collection('users')
        .doc(touristUid)
        .collection('friendRequests')
        .doc('demo_tourist_aiman');
    batch.set(reqRef, {
      'fromUserId': 'demo_tourist_aiman',
      'toUserId': touristUid,
      'fromDisplayName': 'Aiman Hakim',
      'fromUsername': '@aiman_travels',
      'fromLevel': 4,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}
