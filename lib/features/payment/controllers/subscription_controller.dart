import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:talentbay_candidate/features/candidate/controllers/candidate_controller.dart';
import 'package:talentbay_candidate/features/payment/services/payment_service.dart';

final subscriptionControllerProvider =
    NotifierProvider<SubscriptionController, bool>(SubscriptionController.new);

/// Shown when money was taken but the subscription could not be confirmed.
final paymentNoticeProvider =
    NotifierProvider<PaymentNotice, String?>(PaymentNotice.new);

class PaymentNotice extends Notifier<String?> {
  @override
  String? build() => null;

  void setNotice(String? value) {
    state = value;
  }
}

final appleProductsProvider = FutureProvider<List<ProductDetails>>((ref) async {
  if (!Platform.isIOS) return [];
  try {
    final bool available = await InAppPurchase.instance.isAvailable();
    if (!available) return [];
    
    const Set<String> ids = {
      'com.talentbay.candidate.subscription.monthly',
      'com.talentbay.candidate.subscription.quarterly',
      'com.talentbay.candidate.subscription.halfyearly',
    };
    final response = await InAppPurchase.instance.queryProductDetails(ids);
    return response.productDetails;
  } catch (e) {
    debugPrint('Error fetching products from App Store: $e');
    return [];
  }
});

class SubscriptionController extends Notifier<bool> {
  late PaymentService _paymentService;
  StreamSubscription<List<PurchaseDetails>>? _iapSubscription;
  WeakReference<BuildContext>? _contextRef;
  int? _selectedPlanDurationDays;
  String? _currentOrderId;
  String? _currentPlanId;
  bool _didRecoverPayments = false;

  @override
  bool build() {
    _paymentService = PaymentService();
    
    final purchaseUpdated = InAppPurchase.instance.purchaseStream;
    _iapSubscription = purchaseUpdated.listen(
      (purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      },
      onDone: () {
        _iapSubscription?.cancel();
      },
      onError: (error) {
        debugPrint('IAP purchaseStream error: $error');
      },
    );

    // Dispose payment service and IAP subscription when provider is disposed
    ref.onDispose(() {
      _paymentService.dispose();
      _iapSubscription?.cancel();
    });

    if (!_didRecoverPayments) {
      _didRecoverPayments = true;
      Future.microtask(recoverPendingPayments);
    }
    return false;
  }

  void initializePayment(BuildContext context) {
    _paymentService.initialize(
      onSuccess: (response) => _handlePaymentSuccess(response, context),
      onFailure: (response) => _handlePaymentFailure(response, context),
      onExternalWallet: _handleExternalWallet,
    );
  }

  Future<void> startSubscription(BuildContext context, Map<String, dynamic> plan) async {
    final user = ref.read(candidateControllerProvider).value;
    if (user == null) return;

    if (Platform.isAndroid) {
      // Initialize if not already (safeguard)
      initializePayment(context);

      String orderId = '';
      try {
        final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
            .httpsCallable('createRazorpayOrder');
        final response = await callable.call({'planId': plan['id']});
        final data = response.data;
        if (data != null && data is Map) {
          orderId = (data['orderId'] ?? data['id'] ?? '').toString();
        }
      } catch (e) {
        debugPrint('[SubscriptionController] createRazorpayOrder error: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e is FirebaseFunctionsException
                    ? (e.message ?? 'Unable to start payment. Please try again.')
                    : 'Unable to start payment. Please check your connection and try again.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (orderId.trim().isEmpty) {
        debugPrint('[SubscriptionController] Order creation failed or returned empty orderId. Aborting Razorpay checkout.');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to start payment. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      debugPrint('[SubscriptionController] Valid orderId received: ${orderId.substring(0, orderId.length > 8 ? 8 : orderId.length)}***. Launching Razorpay checkout.');

      _currentOrderId = orderId;
      _currentPlanId = plan['id']?.toString();
      _selectedPlanDurationDays = plan['durationDays'];

      _paymentService.openCheckout(
        email: user.email,
        contact: user.phoneNumber ?? '',
        amount: plan['amount'],
        description: plan['description'],
        orderId: orderId,
      );
    } else if (Platform.isIOS) {
      _contextRef = WeakReference(context);
      state = true;
      try {
        final String productId = plan['appleProductId'];
        
        final bool available = await InAppPurchase.instance.isAvailable();
        if (!available) {
          throw Exception('App Store In-App Purchases are not available on this device.');
        }

        final ProductDetailsResponse response =
            await InAppPurchase.instance.queryProductDetails({productId});

        if (response.productDetails.isEmpty) {
          throw Exception('Product details not found on the App Store.');
        }

        final ProductDetails productDetails = response.productDetails.first;
        final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
        
        _selectedPlanDurationDays = plan['durationDays'];

        await InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);
      } catch (e) {
        state = false;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to start purchase: $e')),
          );
        }
      }
    }
  }

  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        state = true;
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          state = false;
          _handleIAPError(purchaseDetails.error);
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          await _handleIAPSuccess(purchaseDetails);
        } else if (purchaseDetails.status == PurchaseStatus.canceled) {
          state = false;
          final context = _contextRef?.target;
          if (context != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Purchase canceled.')),
            );
          }
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchaseDetails);
        }
      }
    }
  }

  void _handleIAPError(IAPError? error) {
    state = false;
    final context = _contextRef?.target;
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment Failed: ${error?.message ?? "Unknown error"}')),
      );
    }
  }

  Future<void> _handleIAPSuccess(PurchaseDetails purchaseDetails) async {
    state = true;
    try {
      final user = ref.read(candidateControllerProvider).value;
      if (user == null) return;

      // Update Firestore
      final days = _selectedPlanDurationDays ?? 30;
      final expiryDate = DateTime.now().add(Duration(days: days));

      final updateData = <String, dynamic>{
        'isPremium': true,
        'subscriptionExpiryDate': expiryDate.toIso8601String(),
        'subscriptionStatus': 'active',
        'appleSubscriptionId': purchaseDetails.purchaseID ?? purchaseDetails.transactionDate ?? 'apple_iap_active',
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      if (days == 7) {
        updateData['hasUsedTrial'] = true;
      }

      await FirebaseFirestore.instance
          .collection('candidates')
          .doc(user.uid)
          .update(updateData);

      final context = _contextRef?.target;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(days == 7
                ? 'Trial Activated! Welcome to Premium.'
                : 'Subscription Successful! Premium Renewed.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      final context = _contextRef?.target;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Subscription activation failed: $e')),
        );
      }
    } finally {
      state = false;
    }
  }

  Future<void> _handlePaymentSuccess(
    PaymentSuccessResponse response,
    BuildContext context,
  ) async {
    final orderId = (response.orderId != null && response.orderId!.isNotEmpty)
        ? response.orderId!
        : (_currentOrderId ?? '');
    await _confirmWithBackend(
      context,
      orderId: orderId,
      paymentId: response.paymentId,
      signature: response.signature,
      checkoutFailed: false,
    );
  }

  Future<void> _handlePaymentFailure(
    PaymentFailureResponse response,
    BuildContext context,
  ) async {
    final orderId = _currentOrderId ?? '';
    if (orderId.isEmpty) {
      _showPaymentMessage(
        context,
        _readableCheckoutError(response.message),
        isError: true,
      );
      return;
    }

    // The checkout can report failure after the bank has already captured the money.
    await _confirmWithBackend(
      context,
      orderId: orderId,
      checkoutFailed: true,
      checkoutMessage: _readableCheckoutError(response.message),
    );
  }

  String _readableCheckoutError(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) {
      return 'Payment was not completed. You have not been charged.';
    }
    try {
      final decoded = text.startsWith('{') ? text : '';
      if (decoded.isNotEmpty) {
        final description = RegExp(
          r'"description"\s*:\s*"([^"]+)"',
        ).firstMatch(text);
        final reason = RegExp(r'"reason"\s*:\s*"([^"]+)"').firstMatch(text);
        if (reason?.group(1) == 'payment_cancelled') {
          return 'Payment cancelled. You have not been charged.';
        }
        if (description != null) {
          return 'Payment was not completed: ${description.group(1)}. If any amount was deducted, the bank reverses it automatically.';
        }
      }
    } catch (_) {}
    if (text.toLowerCase().contains('cancel')) {
      return 'Payment cancelled. You have not been charged.';
    }
    return 'Payment was not completed. If any amount was deducted, the bank reverses it automatically.';
  }

  Future<void> _confirmWithBackend(
    BuildContext context, {
    required String orderId,
    String? paymentId,
    String? signature,
    required bool checkoutFailed,
    String? checkoutMessage,
  }) async {
    if (orderId.trim().isEmpty) {
      _showPaymentMessage(
        context,
        checkoutMessage ??
            'We could not find this payment. Please try again. If money was deducted, contact support.',
        isError: true,
      );
      return;
    }

    state = true;
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('confirmRazorpayPayment');
      final response = await callable.call({
        'orderId': orderId,
        if (paymentId != null && paymentId.isNotEmpty) 'paymentId': paymentId,
        if (signature != null && signature.isNotEmpty) 'signature': signature,
        if (_currentPlanId != null) 'planId': _currentPlanId,
      });
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      if (!context.mounted) return;
      _applyPaymentDecision(
        context,
        data,
        checkoutMessage: checkoutMessage,
      );
    } catch (e) {
      debugPrint('[SubscriptionController] confirmRazorpayPayment error: $e');
      final fallback = checkoutFailed
          ? (checkoutMessage ??
              'Payment could not be confirmed. If money was deducted, a refund will be issued within 5–7 working days.')
          : 'We could not confirm this payment with our server. If money was deducted, your subscription will be activated automatically, or a refund will be issued within 5–7 working days. Transaction: $orderId';
      ref.read(paymentNoticeProvider.notifier).setNotice(fallback);
      if (context.mounted) {
        _showPaymentMessage(context, fallback, isError: true);
      }
    } finally {
      state = false;
    }
  }

  void _applyPaymentDecision(
    BuildContext context,
    Map<String, dynamic> data, {
    String? checkoutMessage,
  }) {
    final outcome = data['outcome']?.toString() ?? '';
    final message = data['message']?.toString() ?? '';
    final active = data['subscriptionActive'] == true ||
        outcome == 'subscribed' ||
        outcome == 'already_subscribed';

    if (active) {
      ref.read(paymentNoticeProvider.notifier).setNotice(null);
      _showPaymentMessage(
        context,
        message.isNotEmpty
            ? message
            : 'Payment confirmed. Your subscription is active.',
        isError: false,
      );
      return;
    }

    final notice = message.isNotEmpty
        ? message
        : (checkoutMessage ??
            'Payment could not be confirmed. If money was deducted, a refund will be issued within 5–7 working days.');
    if (outcome == 'refund_pending' || outcome == 'pending') {
      ref.read(paymentNoticeProvider.notifier).setNotice(notice);
    }
    _showPaymentMessage(context, notice, isError: outcome != 'pending');
  }

  void _showPaymentMessage(
    BuildContext context,
    String message, {
    required bool isError,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[700] : Colors.green[700],
        duration: const Duration(seconds: 6),
      ),
    );
  }

  Future<void> recoverPendingPayments() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('reconcileMyPayments');
      final response = await callable.call();
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final message = data['message']?.toString() ?? '';
      if (data['needsAttention'] == true && message.isNotEmpty) {
        ref.read(paymentNoticeProvider.notifier).setNotice(message);
      } else if (data['subscriptionActivated'] == true) {
        ref.read(paymentNoticeProvider.notifier).setNotice(null);
      }
    } catch (e) {
      debugPrint('[SubscriptionController] recoverPendingPayments: $e');
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    // Handle external wallet
  }

  Future<void> restorePurchases(BuildContext context) async {
    state = true;
    try {
      final bool available = await InAppPurchase.instance.isAvailable();
      if (!available) {
        throw Exception('In-App Purchases not available on this device');
      }
      await InAppPurchase.instance.restorePurchases();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchases restored successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restore purchases: $e')),
        );
      }
    } finally {
      state = false;
    }
  }
}
