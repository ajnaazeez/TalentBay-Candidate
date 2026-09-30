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

  /// Last 10 digits, used to match the same mobile stored in different formats.
  static String? lastTenDigits(String? phone) {
    if (phone == null) return null;
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    if (digits.length <= 10) return digits;
    return digits.substring(digits.length - 10);
  }

  /// Formats a number may have been stored as, so login can find the same account.
  static List<String> lookupVariants(String phone) {
    final normalized = normalizeE164(phone);
    final digits = normalized.replaceAll(RegExp(r'\D'), '');
    final last10 = lastTenDigits(normalized);
    final variants = <String>{};
    if (phone.trim().isNotEmpty) variants.add(phone.trim());
    if (normalized.isNotEmpty) variants.add(normalized);
    if (digits.isNotEmpty) variants.add(digits);
    if (last10 != null && last10.isNotEmpty) {
      variants.add(last10);
      variants.add('+91$last10');
      variants.add('91$last10');
    }
    return variants.where((value) => value.isNotEmpty).take(10).toList();
  }
}
