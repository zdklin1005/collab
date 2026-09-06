enum LocationQuality {
  unavailable,
  stale,
  unknownAccuracy,
  inaccurate,
  recent,
}

LocationQuality assessLocationQuality({
  required double? accuracy,
  required DateTime? recordedAt,
  required DateTime now,
  double warningAccuracyMetres = 25,
  Duration maximumAge = const Duration(seconds: 30),
}) {
  if (recordedAt == null) {
    return LocationQuality.unavailable;
  }

  final age = now.difference(recordedAt);

  // Also reject timestamps implausibly ahead of the phone's clock.
  if (age > maximumAge || age < const Duration(seconds: -5)) {
    return LocationQuality.stale;
  }

  if (accuracy == null || !accuracy.isFinite || accuracy <= 0) {
    return LocationQuality.unknownAccuracy;
  }

  if (accuracy > warningAccuracyMetres) {
    return LocationQuality.inaccurate;
  }

  return LocationQuality.recent;
}