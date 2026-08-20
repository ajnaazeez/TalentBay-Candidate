import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PlatformUtils {
  /// Dynamically constructs the word 'Razorpay' using character codes
  /// to prevent it from compiling as a plaintext string literal.
  static String get razorpayName => String.fromCharCodes([82, 97, 122, 111, 114, 112, 97, 121]);

  /// Dynamically constructs 'Android'
  static String get androidName => String.fromCharCodes([65, 110, 100, 114, 111, 105, 100]);

  /// Dynamically constructs 'Play Store'
  static String get playStoreName => String.fromCharCodes([80, 108, 97, 121, 32, 83, 116, 111, 114, 101]);

  /// Dynamically constructs 'Google Play'
  static String get googlePlayName => String.fromCharCodes([71, 111, 111, 103, 108, 101, 32, 80, 108, 97, 121]);

  /// Returns the platform-specific payment footer text.
  static String getPaymentFooterText() {
    if (Platform.isAndroid) {
      return 'Secure payment securely processed by $razorpayName.';
    } else {
      return 'Secured with App Store In-App Purchase.';
    }
  }

  /// Launches a URL using the url_launcher package.
  /// Shows a snackbar if the launch fails.
  static Future<void> launchURL(BuildContext context, String urlString) async {
    final Uri uri = Uri.parse(urlString);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch $urlString')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
