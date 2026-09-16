import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:collab/models/localquest_models.dart';
import 'package:collab/models/map_location.dart';
import 'package:collab/services/landmark_parser.dart';

import 'package:collab/models/reward_checkpoint.dart';
import 'package:collab/services/reward_checkpoint_parser.dart';

import 'package:collab/services/map_voucher_data_validation.dart';
import 'package:collab/services/live_business_ad_availability.dart';

bool isMappableBusiness(Business business) {
  final latitude = business.latitude;
  final longitude = business.longitude;

  return business.active &&
      business.id.trim().isNotEmpty &&
      business.name.trim().isNotEmpty &&
      latitude != null &&
      longitude != null &&
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}

class MapRepository {
  MapRepository({FirebaseFirestore? firestore}) : _customFirestore = firestore;

  final FirebaseFirestore? _customFirestore;
  FirebaseFirestore? get _firestore {
    if (_customFirestore != null) return _customFirestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  Stream<List<Business>> watchActiveBusinesses() {
    final firestore = _firestore;
    if (firestore == null) return Stream.value(const <Business>[]);
    return firestore
        .collection('businesses')
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final businesses = <Business>[];

          for (final document in snapshot.docs) {
            try {
              final business = Business.fromDoc(document);

              if (isMappableBusiness(business)) {
                businesses.add(business);
              }
            } on TypeError {
              // A malformed record must not prevent other markers loading.
              debugPrint('Map: skipped malformed business ${document.id}');
            }
          }

          businesses.sort((a, b) {
            final nameComparison = a.name.toLowerCase().compareTo(
              b.name.toLowerCase(),
            );

            return nameComparison != 0 ? nameComparison : a.id.compareTo(b.id);
          });

          return List<Business>.unmodifiable(businesses);
        });
  }

  Stream<List<MapLocation>> watchActiveLandmarks() {
    final firestore = _firestore;
    if (firestore == null) return Stream.value(const <MapLocation>[]);
    return firestore
        .collection('landmarks')
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final landmarks = <MapLocation>[];

          for (final document in snapshot.docs) {
            final landmark = parseLandmark(document.id, document.data());

            if (landmark != null) {
              landmarks.add(landmark);
            } else {
              debugPrint('Map: skipped malformed landmark ${document.id}');
            }
          }

          landmarks.sort((a, b) {
            final titleComparison = a.title.toLowerCase().compareTo(
              b.title.toLowerCase(),
            );

            return titleComparison != 0
                ? titleComparison
                : a.id.compareTo(b.id);
          });

          return List<MapLocation>.unmodifiable(landmarks);
        });
  }

  Stream<List<RewardCheckpoint>> watchApprovedRewardCheckpoints() {
    final firestore = _firestore;
    if (firestore == null) return Stream.value(const <RewardCheckpoint>[]);
    return firestore
        .collection('rewardCheckpoints')
        .where('active', isEqualTo: true)
        .where('placementApproved', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final checkpoints = <RewardCheckpoint>[];

          for (final document in snapshot.docs) {
            final checkpoint = parseRewardCheckpoint(
              document.id,
              document.data(),
            );

            if (checkpoint != null) {
              checkpoints.add(checkpoint);
            } else {
              debugPrint(
                'Map: skipped malformed reward checkpoint ${document.id}',
              );
            }
          }

          checkpoints.sort((a, b) => a.id.compareTo(b.id));

          return List<RewardCheckpoint>.unmodifiable(checkpoints);
        });
  }

  Stream<List<Campaign>> watchActiveVoucherCampaigns() {
    final firestore = _firestore;
    if (firestore == null) return Stream.value(const <Campaign>[]);
    return firestore
        .collection('campaigns')
        .where('type', isEqualTo: 'voucher')
        .snapshots()
        .map((snapshot) {
          final campaigns = <Campaign>[];

          for (final document in snapshot.docs) {
            final data = document.data();

            if (data['status'] != 'active') {
              continue;
            }

            if (!hasValidMapVoucherData(data)) {
              debugPrint(
                'Map: skipped incomplete voucher campaign ${document.id}',
              );
              continue;
            }

            try {
              // Keep the team's shared model and all its restrictions.
              campaigns.add(Campaign.fromDoc(document));
            } on TypeError {
              debugPrint(
                'Map: skipped malformed voucher campaign ${document.id}',
              );
            }
          }

          campaigns.sort((a, b) => a.id.compareTo(b.id));
          return List<Campaign>.unmodifiable(campaigns);
        });
  }

  Stream<List<Campaign>> watchActiveBusinessCampaigns() {
    final firestore = _firestore;
    if (firestore == null) return Stream.value(const <Campaign>[]);
    return firestore.collection('campaigns').snapshots().map((snapshot) {
      final campaigns = <Campaign>[];

      for (final document in snapshot.docs) {
        final data = document.data();
        final type = data['type'];

        final valid = switch (type) {
          'voucher' => hasValidMapVoucherData(data),
          'ad' => hasValidBusinessAdData(data),
          _ => false,
        };

        if (!valid) {
          continue;
        }

        try {
          campaigns.add(Campaign.fromDoc(document));
        } on TypeError {
          debugPrint('Map: skipped malformed business campaign ${document.id}');
        }
      }

      campaigns.sort((first, second) {
        final expiryOrder = first.endDate.compareTo(second.endDate);
        return expiryOrder != 0 ? expiryOrder : first.id.compareTo(second.id);
      });

      return List<Campaign>.unmodifiable(campaigns);
    });
  }
}
