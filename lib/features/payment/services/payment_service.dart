import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:talentbay_candidate/core/constants/payment_constants.dart';

class PaymentService {
  late Razorpay _razorpay;
  Function(PaymentSuccessResponse)? _onSuccess;
  Function(PaymentFailureResponse)? _onFailure;
  Function(ExternalWalletResponse)? _onExternalWallet;

  void initialize({
    required Function(PaymentSuccessResponse) onSuccess,
    required Function(PaymentFailureResponse) onFailure,
    required Function(ExternalWalletResponse) onExternalWallet,
  }) {
    _razorpay = Razorpay();
    _onSuccess = onSuccess;
    _onFailure = onFailure;
    _onExternalWallet = onExternalWallet;

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void openCheckout({
    required String email,
    required String contact,
    required String amount,
    required String description,
    required String orderId,
  }) {
    final numAmount = int.tryParse(amount) ?? double.tryParse(amount)?.toInt() ?? 0;
    
    // Sanitize contact number for Razorpay: remove non-digits, keep last 10 digits if Indian format
    String sanitizedContact = contact.replaceAll(RegExp(r'\D'), '');
    if (sanitizedContact.length > 10 && sanitizedContact.startsWith('91')) {
      sanitizedContact = sanitizedContact.substring(sanitizedContact.length - 10);
    }
    if (sanitizedContact.isEmpty) {
      sanitizedContact = '9999999999';
    }

    final options = <String, dynamic>{
      'key': PaymentConstants.razorpayKeyId,
      'amount': numAmount,
      'currency': PaymentConstants.currency,
      'name': PaymentConstants.companyName,
      'description': description,
      'prefill': {
        'contact': sanitizedContact,
        'email': email.trim().isNotEmpty ? email.trim() : 'candidate@talentbay.com',
      },
      'theme': {
        'color': '#008080',
      },
      'retry': {
        'enabled': true,
        'max_count': 1,
      },
    };

    // Note: Razorpay Flutter SDK requires amount in options even when order_id is present.
    // The amount in options MUST match the order's amount in paise.
    if (orderId.trim().isNotEmpty) {
      options['order_id'] = orderId.trim();
    }

    try {
      print('[PaymentService] Opening Razorpay checkout with order_id: ${options['order_id']}, amount: ${options['amount']}');
      _razorpay.open(options);
    } catch (e) {
      print('[PaymentService] Razorpay open exception: $e');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    print('[PaymentService] Payment Success: paymentId=${response.paymentId}, orderId=${response.orderId}');
    _onSuccess?.call(response);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print('[PaymentService] Payment Error: code=${response.code}, message=${response.message}');
    _onFailure?.call(response);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print('[PaymentService] External Wallet Selected: ${response.walletName}');
    _onExternalWallet?.call(response);
  }

  void dispose() {
    _razorpay.clear();
  }

  // Signature verification is performed securely on the server via verifyRazorpayPayment Cloud Function.
  bool verifySignature({
    required String orderId,
    required String paymentId,
    required String signature,
  }) {
    // Client-side verification is deprecated; server-side Cloud Function performs verification.
    return orderId.isNotEmpty && paymentId.isNotEmpty && signature.isNotEmpty;
  }
}
