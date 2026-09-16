import 'dart:math';

/// Generates a short, human-typeable redemption code, stored directly on
/// the voucher document so a merchant can look it up by code — unlike a
/// code derived from the Firestore document ID, which isn't queryable.
/// Excludes visually ambiguous characters (0/O, 1/I/L) for readability
/// when read aloud or typed by hand.
///
/// Not collision-checked: at this app's scale, 32^6 (~1 billion)
/// combinations makes a collision astronomically unlikely. Worth adding
/// a retry-on-collision loop only if this ever needs to scale past a
/// prototype.
class VoucherCode {
  VoucherCode._();

  static const _chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static final _random = Random();

  static String generate({int length = 6}) {
    return List.generate(
      length,
      (_) => _chars[_random.nextInt(_chars.length)],
    ).join();
  }
}
