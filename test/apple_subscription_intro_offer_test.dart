import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'package:talentbay_candidate/core/constants/payment_constants.dart';
import 'package:talentbay_candidate/features/payment/utils/apple_subscription_offer_helper.dart';

void main() {
  group('AppleIntroductoryOfferInfo & PaymentConstants Tests', () {
    test('PaymentConstants maintains unchanged monthly subscription product ID', () {
      final monthlyPlan = PaymentConstants.subscriptionPlans.firstWhere(
        (plan) => plan['id'] == '1_month',
      );
      expect(monthlyPlan['appleProductId'], equals('com.talentbay.candidate.subscription.monthly'));
      expect(PaymentConstants.trialPlan['appleProductId'], equals('com.talentbay.candidate.subscription.monthly'));
    });

    test('PaymentConstants Android trial and subscription plans remain untouched', () {
      expect(PaymentConstants.trialPlan['amount'], equals('100'));
      expect(PaymentConstants.trialPlan['displayAmount'], equals('1'));
      expect(PaymentConstants.trialPlan['durationDays'], equals(7));
      expect(PaymentConstants.trialPlan['offer'], equals('TRIAL'));

      final monthlyPlan = PaymentConstants.subscriptionPlans.firstWhere(
        (plan) => plan['id'] == '1_month',
      );
      expect(monthlyPlan['amount'], equals('39900'));
      expect(monthlyPlan['displayAmount'], equals('399'));
      expect(monthlyPlan['durationDays'], equals(30));
    });

    test('AppleIntroductoryOfferInfo fallback values when store products are loading or null', () {
      final offer = AppleIntroductoryOfferInfo.fromProductDetails(null);
      expect(offer.introPriceText, equals('₹29'));
      expect(offer.renewalPriceText, equals('₹399'));
      expect(offer.cardTitleText, equals('₹29 for 1 Month'));
      expect(offer.renewalDisclosureText, equals('Renews at ₹399/month after first month'));
      expect(offer.offerBadgeText, equals('OFFER'));
    });

    test('AppleIntroductoryOfferInfo uses store regular price for renewal disclosure', () {
      final product = ProductDetails(
        id: 'com.talentbay.candidate.subscription.monthly',
        title: 'Monthly Subscription',
        description: 'Monthly Premium Access',
        price: '₹399',
        rawPrice: 399.0,
        currencyCode: 'INR',
        currencySymbol: '₹',
      );

      final offer = AppleIntroductoryOfferInfo.fromProductDetails(product);
      expect(offer.introPriceText, equals('₹29'));
      expect(offer.renewalPriceText, equals('₹399'));
      expect(offer.renewalDisclosureText, equals('Renews at ₹399/month after first month'));
      expect(offer.cardTitleText, equals('₹29 for 1 Month'));
    });

    test('AppleIntroductoryOfferInfo parses StoreKit 1 introductory price from AppStoreProductDetails', () {
      final skProduct = SKProductWrapper(
        productIdentifier: 'com.talentbay.candidate.subscription.monthly',
        localizedTitle: 'Monthly Subscription',
        localizedDescription: 'Monthly Premium Access',
        priceLocale: SKPriceLocaleWrapper(
          currencySymbol: '₹',
          currencyCode: 'INR',
          countryCode: 'IN',
        ),
        price: '399.00',
        subscriptionGroupIdentifier: 'group_candidate_sub',
        introductoryPrice: SKProductDiscountWrapper(
          price: '29.00',
          priceLocale: SKPriceLocaleWrapper(
            currencySymbol: '₹',
            currencyCode: 'INR',
            countryCode: 'IN',
          ),
          numberOfPeriods: 1,
          paymentMode: SKProductDiscountPaymentMode.payUpFront,
          subscriptionPeriod: SKProductSubscriptionPeriodWrapper(
            numberOfUnits: 1,
            unit: SKSubscriptionPeriodUnit.month,
          ),
          identifier: 'intro_monthly_offer',
          type: SKProductDiscountType.introductory,
        ),
      );

      final product = AppStoreProductDetails.fromSKProduct(skProduct);

      final offer = AppleIntroductoryOfferInfo.fromProductDetails(product);
      expect(offer.introPriceText, equals('₹29.00'));
      expect(offer.cardTitleText, equals('₹29.00 for 1 Month'));
      expect(offer.renewalPriceText, equals('₹399.00'));
      expect(offer.renewalDisclosureText, equals('Renews at ₹399.00/month after first month'));
    });
  });
}
