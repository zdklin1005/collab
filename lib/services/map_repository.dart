import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:collab/models/localquest_models.dart';

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
  MapRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<Business>> watchActiveBusinesses() {
    return _firestore
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
}
