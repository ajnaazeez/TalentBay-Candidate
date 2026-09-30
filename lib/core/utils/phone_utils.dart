class PhoneUtils {
  /// Normalizes a phone string to standard E.164 format.
  /// If [countryCode] is provided (e.g. '+91'), it prepends it if missing.
  /// Returns empty string if the input has no digits.
  static String normalizeE164(String phone, {String defaultCountryCode = '+91'}) {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return '';

    // Remove any whitespace, hyphens, parentheses
    String cleaned = trimmed.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.isEmpty) return '';

    // If it already starts with '+', keep '+' and keep only following digits
    if (cleaned.startsWith('+')) {
      final digits = cleaned.substring(1).replaceAll(RegExp(r'\D'), '');
      return digits.isEmpty ? '' : '+$digits';
    }

    // Strip non-digits
    cleaned = cleaned.replaceAll(RegExp(r'\D'), '');
    if (cleaned.isEmpty) return '';

    // Handle Indian number formats
    if (cleaned.length == 10) {
      final prefix = defaultCountryCode.startsWith('+') ? defaultCountryCode : '+$defaultCountryCode';
      return '$prefix$cleaned';
    } else if (cleaned.length == 12 && cleaned.startsWith('91')) {
      return '+$cleaned';
    } else if (cleaned.length == 11 && cleaned.startsWith('0')) {
      final prefix = defaultCountryCode.startsWith('+') ? defaultCountryCode : '+$defaultCountryCode';
      return '$prefix${cleaned.substring(1)}';
    }

    // Default fallback: prepend '+' if missing
    return '+$cleaned';
  }

  /// Checks if the normalized E.164 phone string has a valid subscriber length.
  static bool isValidE164(String phone) {
    if (!phone.startsWith('+')) return false;
    final digitsOnly = phone.substring(1).replaceAll(RegExp(r'\D'), '');
    return digitsOnly.length >= 8 && digitsOnly.length <= 15;
  }
}
