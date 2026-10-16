import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:talentbay_candidate/core/router/router.dart';
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
  bool _isProcessingPaymentResult = false;
  VoidCallback? _onPaymentCancelled;

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

  BuildContext? _getValidContext([BuildContext? passedContext]) {
    if (passedContext != null && passedContext.mounted) {
      return passedContext;
    }
    final target = _contextRef?.target;
    if (target != null && target.mounted) {
      return target;
    }
    try {
      final router = ref.read(routerProvider);
      final navContext = router.routerDelegate.navigatorKey.currentContext;
      if (navContext != null && navContext.mounted) {
        return navContext;
      }
    } catch (_) {}
    return null;
  }

  void initializePayment(BuildContext context) {
    _paymentService.initialize(
      onSuccess: (response) => _handlePaymentSuccess(response, context),
      onFailure: (response) => _handlePaymentFailure(response, context),
      onExternalWallet: _handleExternalWallet,
    );
  }

  Future<void> startSubscription(
    BuildContext context,
    Map<String, dynamic> plan, {
    VoidCallback? onPaymentCancelled,
  }) async {
    final user = ref.read(candidateControllerProvider).value;
    if (user == null) return;

    _contextRef = WeakReference(context);
    _onPaymentCancelled = onPaymentCancelled;
    _isProcessingPaymentResult = false;

    if (Platform.isAndroid) {
      // Initialize if not already (safeguard)
      initializePayment(context);
      state = true;

      String orderId = '';
      try {
        final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
            .httpsCallable(
              'createRazorpayOrder',
              options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
            );

        HttpsCallableResult response;
        try {
          response = await callable.call({'planId': plan['id']});
        } on FirebaseFunctionsException catch (fe) {
          // If cold start or transient unavailability occurred, retry once after a short delay
          if (fe.code == 'unavailable' || fe.code == 'deadline-exceeded') {
            debugPrint('[SubscriptionController] First attempt failed with ${fe.code}. Retrying createRazorpayOrder once...');
            await Future.delayed(const Duration(milliseconds: 1500));
            response = await callable.call({'planId': plan['id']});
          } else {
            rethrow;
          }
        }

        final data = response.data;
        if (data != null && data is Map) {
          orderId = (data['orderId'] ?? data['id'] ?? '').toString();
        }
      } catch (e) {
        state = false;
        String errorMessage;
        if (e is FirebaseFunctionsException) {
          debugPrint('[SubscriptionController] createRazorpayOrder failed: code=${e.code}, message=${e.message}, details=${e.details}');
          switch (e.code) {
            case 'unavailable':
              errorMessage = 'Payment service is temporarily busy. Please check your internet connection and try again in a few moments.';
              break;
            case 'deadline-exceeded':
              errorMessage = 'Payment request timed out. Please check your internet connection and try again.';
              break;
            case 'unauthenticated':
              errorMessage = 'Your session has expired. Please log in again to subscribe.';
              break;
            case 'failed-precondition':
              errorMessage = (e.message != null && e.message!.isNotEmpty && e.message != 'failed-precondition')
                  ? e.message!
                  : 'This subscription plan is not eligible for your account.';
              break;
            default:
              errorMessage = (e.message != null && e.message!.isNotEmpty && e.message != e.code.toUpperCase())
                  ? e.message!
                  : 'Unable to start payment. Please try again.';
              break;
          }
        } else {
          debugPrint('[SubscriptionController] createRazorpayOrder unexpected error: $e');
          errorMessage = 'Unable to start payment. Please check your connection and try again.';
        }

        _showPaymentMessage(errorMessage, context: context, isError: true);
        return;
      }

      if (orderId.trim().isEmpty) {
        state = false;
        debugPrint('[SubscriptionController] Order creation failed or returned empty orderId. Aborting Razorpay checkout.');
        _showPaymentMessage('Unable to start payment. Please try again.', context: context, isError: true);
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
    if (_isProcessingPaymentResult) {
      debugPrint('[SubscriptionController] Ignoring duplicate payment success callback.');
      return;
    }
    _isProcessingPaymentResult = true;

    try {
      final orderId = (response.orderId != null && response.orderId!.isNotEmpty)
          ? response.orderId!
          : (_currentOrderId ?? '');
      await _confirmWithBackend(
        orderId: orderId,
        paymentId: response.paymentId,
        signature: response.signature,
        checkoutFailed: false,
      );
    } finally {
      _isProcessingPaymentResult = false;
    }
  }

  Future<void> _handlePaymentFailure(
    PaymentFailureResponse response,
    BuildContext context,
  ) async {
    if (_isProcessingPaymentResult) {
      debugPrint('[SubscriptionController] Ignoring duplicate payment failure callback.');
      return;
    }
    _isProcessingPaymentResult = true;

    try {
      final isCancelled = response.code == Razorpay.PAYMENT_CANCELLED ||
          (response.message != null &&
              (response.message!.contains('payment_cancelled') ||
                  response.message!.toLowerCase().contains('cancel')));

      final orderId = _currentOrderId ?? '';
      final message = _readableCheckoutError(response.message);

      if (isCancelled) {
        // Reset loading state immediately on cancellation
        state = false;
        _showPaymentMessage(message, isError: false);
        _onPaymentCancelled?.call();

        // Preserve backend reconciliation in the background for uncertain payment outcomes
        if (orderId.isNotEmpty) {
          unawaited(
            _confirmWithBackend(
              orderId: orderId,
              checkoutFailed: true,
              checkoutMessage: message,
              isCancellation: true,
            ),
          );
        }
        return;
      }

      if (orderId.isEmpty) {
        state = false;
        _showPaymentMessage(
          message,
          isError: true,
        );
        return;
      }

      // The checkout can report failure after the bank has already captured the money.
      await _confirmWithBackend(
        orderId: orderId,
        checkoutFailed: true,
        checkoutMessage: message,
        isCancellation: false,
      );
    } finally {
      _isProcessingPaymentResult = false;
    }
  }

  String _readableCheckoutError(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) {
      return 'Payment was not completed. If any amount was deducted, the bank reverses it automatically within 5–7 working days.';
    }
    try {
      final decoded = text.startsWith('{') ? text : '';
      if (decoded.isNotEmpty) {
        final description = RegExp(
          r'"description"\s*:\s*"([^"]+)"',
        ).firstMatch(text);
        final reason = RegExp(r'"reason"\s*:\s*"([^"]+)"').firstMatch(text);
        if (reason?.group(1) == 'payment_cancelled') {
          return 'Payment cancelled. If any amount was deducted, the bank reverses it automatically within 5–7 working days.';
        }
        if (description != null) {
          return 'Payment was not completed: ${description.group(1)}. If any amount was deducted, the bank reverses it automatically within 5–7 working days.';
        }
      }
    } catch (_) {}
    if (text.toLowerCase().contains('cancel')) {
      return 'Payment cancelled. If any amount was deducted, the bank reverses it automatically within 5–7 working days.';
    }
    return 'Payment was not completed. If any amount was deducted, the bank reverses it automatically within 5–7 working days.';
  }

  Future<void> _confirmWithBackend({
    required String orderId,
    String? paymentId,
    String? signature,
    required bool checkoutFailed,
    String? checkoutMessage,
    bool isCancellation = false,
  }) async {
    if (orderId.trim().isEmpty) {
      _showPaymentMessage(
        checkoutMessage ??
            'We could not find this payment. Please try again. If money was deducted, contact support.',
        isError: true,
      );
      return;
    }

    if (!isCancellation) {
      state = true;
    }
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
      final validContext = _getValidContext();
      if (validContext != null && validContext.mounted) {
        _applyPaymentDecision(
          validContext,
          data,
          checkoutMessage: checkoutMessage,
          isCancellation: isCancellation,
        );
      }
    } catch (e) {
      debugPrint('[SubscriptionController] confirmRazorpayPayment error: $e');
      if (!isCancellation) {
        final fallback = checkoutFailed
            ? (checkoutMessage ??
                'Payment could not be confirmed. If money was deducted, a refund will be issued within 5–7 working days.')
            : 'We could not confirm this payment with our server. If money was deducted, your subscription will be activated automatically, or a refund will be issued within 5–7 working days. Transaction: $orderId';
        ref.read(paymentNoticeProvider.notifier).setNotice(fallback);
        _showPaymentMessage(fallback, isError: true);
      }
    } finally {
      state = false;
    }
  }

  void _applyPaymentDecision(
    BuildContext context,
    Map<String, dynamic> data, {
    String? checkoutMessage,
    bool isCancellation = false,
  }) {
    final outcome = data['outcome']?.toString() ?? '';
    final message = data['message']?.toString() ?? '';
    final active = data['subscriptionActive'] == true ||
        outcome == 'subscribed' ||
        outcome == 'already_subscribed';

    if (active) {
      ref.read(paymentNoticeProvider.notifier).setNotice(null);
      _showPaymentMessage(
        message.isNotEmpty
            ? message
            : 'Payment confirmed. Your subscription is active.',
        context: context,
        isError: false,
      );
      return;
    }

    if (isCancellation) {
      if (outcome == 'refund_pending' || outcome == 'pending') {
        final notice = message.isNotEmpty
            ? message
            : 'Payment reversal is pending. If money was deducted, a refund will be issued within 5–7 working days.';
        ref.read(paymentNoticeProvider.notifier).setNotice(notice);
        _showPaymentMessage(notice, context: context, isError: false);
      }
      return;
    }

    final notice = message.isNotEmpty
        ? message
        : (checkoutMessage ??
            'Payment could not be confirmed. If money was deducted, a refund will be issued within 5–7 working days.');
    if (outcome == 'refund_pending' || outcome == 'pending') {
      ref.read(paymentNoticeProvider.notifier).setNotice(notice);
    }
    _showPaymentMessage(notice, context: context, isError: outcome != 'pending');
  }

  void _showPaymentMessage(
    String message, {
    BuildContext? context,
    required bool isError,
  }) {
    final validContext = _getValidContext(context);
    if (validContext == null || !validContext.mounted) {
      debugPrint('[SubscriptionController] Payment message: $message');
      return;
    }
    ScaffoldMessenger.of(validContext).showSnackBar(
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
