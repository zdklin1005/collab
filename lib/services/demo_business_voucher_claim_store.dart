import '../models/localquest_models.dart';
import 'business_voucher_availability.dart';
import 'daily_reward_generator.dart';

import 'dart:convert';

enum DemoBusinessVoucherClaimStatus { recorded, alreadyClaimed, unavailable }

class DemoBusinessVoucherClaim {
  const DemoBusinessVoucherClaim({
    required this.touristId,
    required this.offer,
    required this.claimedAt,
  });

  final String touristId;
  final MapVoucherOffer offer;
  final DateTime claimedAt;
}

/// Demo claim history—not a received-voucher wallet.
///
/// The caller must run fresh location and eligibility checks first.
/// No Firebase writes, real voucher issuance, or stock changes.
///
/// A new store starts empty until persistence is connected.
class DemoBusinessVoucherClaimStore {
  final Map<String, Map<String, DemoBusinessVoucherClaim>> _claimsByTourist =
      {};

  bool hasClaimed({required String touristId, required String offerId}) {
    _validateId(touristId);
    _validateId(offerId);

    return _claimsByTourist[touristId]?.containsKey(offerId) ?? false;
  }

  List<DemoBusinessVoucherClaim> claimsFor(String touristId) {
    _validateId(touristId);

    return List<DemoBusinessVoucherClaim>.unmodifiable(
      _claimsByTourist[touristId]?.values ?? <DemoBusinessVoucherClaim>[],
    );
  }

  DemoBusinessVoucherClaimStatus recordDemoClaim({
    required String touristId,
    required Business business,
    required MapVoucherOffer offer,
    required DateTime now,
  }) {
    _validateId(touristId);
    _validateId(offer.id);

    // No date-based reset. The same offer stays claimed even if
    // its dates, title, or quantity are subsequently changed.
    if (hasClaimed(touristId: touristId, offerId: offer.id)) {
      return DemoBusinessVoucherClaimStatus.alreadyClaimed;
    }

    if (availableBusinessVouchers(
      business: business,
      offers: [offer],
      now: now,
    ).isEmpty) {
      return DemoBusinessVoucherClaimStatus.unavailable;
    }

    final claims = _claimsByTourist.putIfAbsent(
      touristId,
      () => <String, DemoBusinessVoucherClaim>{},
    );

    // No await between duplicate checking and insertion.
    claims[offer.id] = DemoBusinessVoucherClaim(
      touristId: touristId,
      offer: offer,
      claimedAt: now.toUtc(),
    );

    return DemoBusinessVoucherClaimStatus.recorded;
  }

  String exportSnapshot() {
    final claims = _claimsByTourist.values.expand(
      (touristClaims) => touristClaims.values,
    );

    return jsonEncode({
      'version': 1,
      'claims': claims.map((claim) {
        final offer = claim.offer;

        return {
          'touristId': claim.touristId,
          'claimedAt': claim.claimedAt.toUtc().toIso8601String(),
          'offer': {
            'id': offer.id,
            'businessId': offer.businessId,
            'title': offer.title,
            'validFrom': offer.validFrom.toUtc().toIso8601String(),
            'expiresAt': offer.expiresAt.toUtc().toIso8601String(),
            'remainingStock': offer.remainingStock,
            'active': offer.active,
            'mapEligible': offer.mapEligible,
          },
        };
      }).toList(),
    });
  }

  static DemoBusinessVoucherClaimStore fromSnapshot(String source) {
    try {
      final data = jsonDecode(source) as Map<String, dynamic>;

      if (data['version'] != 1) {
        throw const FormatException(
          'Unsupported business-voucher claim version.',
        );
      }

      final restored = DemoBusinessVoucherClaimStore();
      final records = data['claims'] as List<dynamic>;

      for (final entry in records) {
        final record = entry as Map<String, dynamic>;
        final savedOffer = record['offer'] as Map<String, dynamic>;

        final touristId = record['touristId'] as String;
        final claimedAt = DateTime.parse(record['claimedAt'] as String).toUtc();

        final offer = MapVoucherOffer(
          id: savedOffer['id'] as String,
          businessId: savedOffer['businessId'] as String,
          title: savedOffer['title'] as String,
          validFrom: DateTime.parse(savedOffer['validFrom'] as String).toUtc(),
          expiresAt: DateTime.parse(savedOffer['expiresAt'] as String).toUtc(),
          remainingStock: savedOffer['remainingStock'] as int,
          active: savedOffer['active'] as bool,
          mapEligible: savedOffer['mapEligible'] as bool,
        );

        _validateId(touristId);
        _validateId(offer.id);
        _validateId(offer.businessId);

        // Validate the historical snapshot at its original claim time.
        // Do not reject history merely because the offer has expired now.
        if (offer.title.trim().isEmpty ||
            !offer.active ||
            offer.remainingStock <= 0 ||
            !offer.expiresAt.isAfter(offer.validFrom) ||
            claimedAt.isBefore(offer.validFrom) ||
            !claimedAt.isBefore(offer.expiresAt)) {
          throw const FormatException(
            'Invalid historical business-voucher claim.',
          );
        }

        final claims = restored._claimsByTourist.putIfAbsent(
          touristId,
          () => <String, DemoBusinessVoucherClaim>{},
        );

        if (claims.containsKey(offer.id)) {
          throw const FormatException(
            'Duplicate business-voucher claim in snapshot.',
          );
        }

        claims[offer.id] = DemoBusinessVoucherClaim(
          touristId: touristId,
          offer: offer,
          claimedAt: claimedAt,
        );
      }

      return restored;
    } on FormatException {
      rethrow;
    } on TypeError {
      throw const FormatException(
        'Invalid business-voucher snapshot data types.',
      );
    } on ArgumentError {
      throw const FormatException('Invalid business-voucher snapshot values.');
    }
  }

  static void _validateId(String value) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, 'id', 'Must not be empty.');
    }
  }
}
