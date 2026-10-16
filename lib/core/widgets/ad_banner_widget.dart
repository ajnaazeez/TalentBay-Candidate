import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  static const String _androidProdAdUnitId = 'ca-app-pub-8248852961173383/8631059168';
  static const String _iosProdAdUnitId = 'ca-app-pub-8248852961173383/4473949042';

  static const String _androidTestAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String _iosTestAdUnitId = 'ca-app-pub-3940256099942544/2934735716';

  static String get adUnitId {
    if (kDebugMode) {
      return defaultTargetPlatform == TargetPlatform.iOS
          ? _iosTestAdUnitId
          : _androidTestAdUnitId;
    }
    return defaultTargetPlatform == TargetPlatform.iOS
        ? _iosProdAdUnitId
        : _androidProdAdUnitId;
  }

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  Timer? _retryTimer;
  int _retryAttempts = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _retryTimer?.cancel();
    _bannerAd?.dispose();
    _bannerAd = null;

    final currentAdUnitId = AdBannerWidget.adUnitId;
    debugPrint('[AdBannerWidget] Requesting banner ad with unit ID: $currentAdUnitId');

    _bannerAd = BannerAd(
      adUnitId: currentAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('[AdBannerWidget] Ad loaded successfully. ResponseInfo: ${ad.responseInfo}');
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
              _retryAttempts = 0;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint(
            '[AdBannerWidget] Ad failed to load: '
            'code=${error.code}, domain=${error.domain}, message="${error.message}", '
            'responseInfo=${error.responseInfo}',
          );
          ad.dispose();
          if (mounted) {
            setState(() {
              _isAdLoaded = false;
              _bannerAd = null;
            });

            if (_retryAttempts < _maxRetries) {
              _retryAttempts++;
              final delaySeconds = 15 * _retryAttempts;
              debugPrint('[AdBannerWidget] Scheduling retry #$_retryAttempts in ${delaySeconds}s');
              _retryTimer?.cancel();
              _retryTimer = Timer(Duration(seconds: delaySeconds), () {
                if (mounted) {
                  _loadBannerAd();
                }
              });
            }
          }
        },
      ),
    );

    _bannerAd?.load();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
