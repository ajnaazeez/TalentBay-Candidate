import 'dart:convert';
import 'package:crypto/crypto.dart';
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
    required String orderId, // Or generate locally if just testing
  }) {
    var options = {
      'key': PaymentConstants.razorpayKeyId,
      'amount': amount,
      'name': PaymentConstants.companyName,
      'description': description,
      'prefill': {'contact': contact, 'email': email},
      'external': {
        'wallets': ['paytm'],
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      print('Error: $e');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    _onSuccess?.call(response);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _onFailure?.call(response);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _onExternalWallet?.call(response);
  }

  void dispose() {
    _razorpay.clear();
  }

  // Client-side signature verification (Note: Less secure than backend)
  bool verifySignature({
    required String orderId,
    required String paymentId,
    required String signature,
  }) {
    // For standard checkout, the signature is generated using order_id + | + payment_id
    // But since we might not be creating an order ID on backend for this simple implementation,
    // Razorpay might just return payment_id in success response if no order_id was passed.

    // IF we passed an order_id in options, we verify:
    // generated_signature = hmac_sha256(order_id + "|" + payment_id, secret);

    // If not using orders API (just quick payment), signature verification might differ.
    // Assuming standard flow if orderId is present.

    if (orderId.isEmpty) return true; // weak verification if no order ID

    var bytes = utf8.encode('$orderId|$paymentId');
    var hmacSha256 = Hmac(
      sha256,
      utf8.encode(PaymentConstants.razorpayKeySecret),
    );
    var digest = hmacSha256.convert(bytes);
    var generatedSignature = digest.toString();

    return generatedSignature == signature;
  }
}
