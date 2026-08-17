class PaymentConstants {
  static const String razorpayKeyId = 'rzp_live_TIywUmGVFfdXXf';
  // static const String razorpayKeyId = 'rzp_test_SEJUG8l7U0jbue';
  static const String razorpayKeySecret = 'WWjcLIcItrw39bakd5v1aRAX';
  // static const String razorpayKeySecret =
  //     'UMr8ZEf4Iy0mY775vQVtv8Sm'; // Note: In production, do not store this on client
  static const String currency = 'INR';
  static const String companyName = 'Talent Bay';

  // Trial Plan
  static const Map<String, dynamic> trialPlan = {
    'id': '7_days_trial',
    'title': '7 Days Trial',
    'amount': '100', // 1.00
    'displayAmount': '1',
    'durationDays': 7,
    'description': '7 Days Premium Trial',
    'linkId': 'plink_TIz8oHaumAgxDk',
    'offer': 'TRIAL',
    'appleProductId': 'com.talentbay.candidate.subscription.monthly',
  };

  // Subscription Plans
  static const List<Map<String, dynamic>> subscriptionPlans = [
    {
      'id': '1_month',
      'title': '1 Month',
      'amount': '39900', // 399.00
      'displayAmount': '399',
      'durationDays': 30,
      'description': 'Monthly Premium Subscription (30 Days)',
      'linkId': 'plink_TJQRrEidk1jb0c', // 149 -> 199
      'offer': null,
      'appleProductId': 'com.talentbay.candidate.subscription.monthly',
    },
    {
      'id': '3_months',
      'title': '3 Months',
      'amount': '56900', // 569.00
      'displayAmount': '569',
      'durationDays': 90,
      'description': 'Quarterly Premium Subscription (90 Days)',
      'linkId': 'plink_TJQSujCLADJB1O', // with 5% offer
      'offer': '5% OFF',
      'appleProductId': 'com.talentbay.candidate.subscription.quarterly',
    },
    {
      'id': '6_months',
      'title': '6 Months',
      'amount': '107900', // 1079.00
      'displayAmount': '1079',
      'durationDays': 180,
      'description': 'Half-Yearly Premium Subscription (180 Days)',
      'linkId': 'plink_TJQTRnkjPsKld5', // with 10% offer
      'offer': '10% OFF',
      'appleProductId': 'com.talentbay.candidate.subscription.halfyearly',
    },
  ];
}
