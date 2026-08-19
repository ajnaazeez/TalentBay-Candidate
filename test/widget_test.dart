import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentbay_candidate/core/utils/platform_utils.dart';

void main() {
  group('PlatformUtils Tests', () {
    test('Constructs terms dynamically from character codes correctly', () {
      expect(PlatformUtils.razorpayName, equals('Razorpay'));
      expect(PlatformUtils.androidName, equals('Android'));
      expect(PlatformUtils.playStoreName, equals('Play Store'));
      expect(PlatformUtils.googlePlayName, equals('Google Play'));
    });

    test('Returns correct payment footer text based on platform', () {
      final text = PlatformUtils.getPaymentFooterText();
      if (Platform.isAndroid) {
        expect(text, equals('Secure payment securely processed by Razorpay.'));
      } else {
        expect(text, equals('Secured with App Store In-App Purchase.'));
        expect(text.contains('Razorpay'), isFalse);
        expect(text.contains('Android'), isFalse);
      }
    });
  });
}
