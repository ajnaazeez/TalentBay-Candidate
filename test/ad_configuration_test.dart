import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentbay_candidate/core/widgets/ad_banner_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ad Configuration & AdBannerWidget Tests', () {
    test('AdBannerWidget.adUnitId returns valid Google test ad unit in test/debug environment', () {
      final adUnitId = AdBannerWidget.adUnitId;
      // In flutter test/debug, kDebugMode is true.
      expect(adUnitId.startsWith('ca-app-pub-3940256099942544/'), isTrue);
    });

    test('AndroidManifest.xml contains valid AdMob App ID and AD_ID permission', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);

      final content = manifestFile.readAsStringSync();
      // Must contain AdMob App ID in meta-data
      expect(content.contains('com.google.android.gms.ads.APPLICATION_ID'), isTrue);
      // App ID must have ~ separator, not / separator
      expect(content.contains('ca-app-pub-8248852961173383~7693613527'), isTrue);
      // Must contain AD_ID permission
      expect(content.contains('com.google.android.gms.permission.AD_ID'), isTrue);
    });

    test('iOS Info.plist contains valid GADApplicationIdentifier and SKAdNetworkItems', () {
      final plistFile = File('ios/Runner/Info.plist');
      expect(plistFile.existsSync(), isTrue);

      final content = plistFile.readAsStringSync();
      expect(content.contains('<key>GADApplicationIdentifier</key>'), isTrue);
      expect(content.contains('ca-app-pub-8248852961173383~4638524015'), isTrue);
      expect(content.contains('<key>SKAdNetworkItems</key>'), isTrue);
    });
  });
}
