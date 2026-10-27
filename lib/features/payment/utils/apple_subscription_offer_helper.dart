import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

/// Helper model encapsulating iOS introductory offer details retrieved from StoreKit
/// with safe fallbacks according to App Store Connect configuration.
class AppleIntroductoryOfferInfo {
  /// The introductory price string (e.g. "₹29" or from StoreKit "$0.29").
  final String introPriceText;

  /// The regular renewal price string (e.g. "₹399" or from StoreKit "$3.99").
  final String renewalPriceText;

  /// Clear renewal disclosure required by App Store Review guidelines
  /// (e.g. "Renews at ₹399/month after first month").
  final String renewalDisclosureText;

  /// Card title (e.g. "₹29 for 1 Month").
  final String cardTitleText;

  /// Offer badge label (e.g. "OFFER").
  final String offerBadgeText;

  const AppleIntroductoryOfferInfo({
    required this.introPriceText,
    required this.renewalPriceText,
    required this.renewalDisclosureText,
    required this.cardTitleText,
    this.offerBadgeText = 'OFFER',
  });

  /// Resolves the introductory offer details from the monthly [ProductDetails]
  /// using StoreKit 1 (AppStoreProductDetails) or StoreKit 2 (AppStoreProduct2Details),
  /// falling back to the configured introductory offer (₹29 for 1 month, renews at ₹399/month).
  factory AppleIntroductoryOfferInfo.fromProductDetails(ProductDetails? product) {
    const String fallbackIntro = '₹29';
    const String fallbackRenewal = '₹399';

    if (product == null) {
      return const AppleIntroductoryOfferInfo(
        introPriceText: fallbackIntro,
        renewalPriceText: fallbackRenewal,
        renewalDisclosureText: 'Renews at $fallbackRenewal/month after first month',
        cardTitleText: '$fallbackIntro for 1 Month',
      );
    }

    // 1. Regular renewal price from monthly product
    final renewalPrice = product.price.trim().isNotEmpty ? product.price.trim() : fallbackRenewal;

    // 2. Fetch introductory pricing from StoreKit
    String? introPrice;

    try {
      if (product is AppStoreProductDetails) {
        final SKProductDiscountWrapper? introWrapper = product.skProduct.introductoryPrice;
        if (introWrapper != null) {
          final symbol = introWrapper.priceLocale.currencySymbol.isNotEmpty
              ? introWrapper.priceLocale.currencySymbol
              : (product.currencySymbol.isNotEmpty ? product.currencySymbol : '₹');
          final rawPrice = introWrapper.price.trim();
          if (rawPrice.isNotEmpty) {
            introPrice = rawPrice.startsWith(symbol) ? rawPrice : '$symbol$rawPrice';
          }
        }
      } else if (product is AppStoreProduct2Details) {
        final offers = product.sk2Product.subscription?.promotionalOffers ?? [];
        for (final offer in offers) {
          if (offer.type == SK2SubscriptionOfferType.introductory) {
            final symbol = product.currencySymbol.isNotEmpty ? product.currencySymbol : '₹';
            final p = offer.price;
            final formattedNum = p.truncateToDouble() == p ? p.toInt().toString() : p.toStringAsFixed(2);
            introPrice = '$symbol$formattedNum';
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('[AppleSubscriptionOfferHelper] Error parsing StoreKit intro offer: $e');
    }

    final resolvedIntro = introPrice ?? fallbackIntro;

    return AppleIntroductoryOfferInfo(
      introPriceText: resolvedIntro,
      renewalPriceText: renewalPrice,
      renewalDisclosureText: 'Renews at $renewalPrice/month after first month',
      cardTitleText: '$resolvedIntro for 1 Month',
      offerBadgeText: 'OFFER',
    );
  }
}
