class PasswordPolicy {
  static const minimum = 6;
  static const maximum = 128;
  static bool isObvious(String value) {
    final compact = value.toLowerCase().replaceAll(RegExp(r'\s'), '');
    final simplified = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return compact.isEmpty ||
        RegExp(r'^(.)\1+$', unicode: true).hasMatch(compact) ||
        RegExp(
          r'^(password|qwerty|letmein|welcome|localquest|1234567890|123456789|123456|abc123)+[0-9]*$',
        ).hasMatch(simplified) ||
        RegExp(r'^(.{1,4})\1{2,}$', unicode: true).hasMatch(compact);
  }

  static String? validate(String? value) {
    final password = value ?? '';
    final length = password.runes.length;
    if (length < minimum) {
      return 'Use at least $minimum characters. A few unrelated words work well.';
    }
    if (length > maximum) return 'Use no more than $maximum characters.';
    if (isObvious(password)) {
      return 'Avoid common passwords and repeated or obvious patterns.';
    }
    return null;
  }

  /// Local heuristic only, not an entropy or breached-password check.
  static int score(String password) {
    if (password.isEmpty) return 0;
    if (validate(password) != null) return 1;
    if (password.runes.length >= 24 && password.runes.toSet().length >= 10) {
      return 4;
    }
    if (password.runes.length >= 20 && password.runes.toSet().length >= 8) {
      return 3;
    }
    return 2;
  }
}
