import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:talentbay_candidate/features/candidate/controllers/candidate_controller.dart';
import 'package:talentbay_candidate/features/payment/services/payment_service.dart';

final subscriptionControllerProvider =
    NotifierProvider<SubscriptionController, bool>(SubscriptionController.new);

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

  @override
  bool build() {
    _paymentService = PaymentService();
    
    if (Platform.isIOS) {
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
    }

    // Dispose payment service and IAP subscription when provider is disposed
    ref.onDispose(() {
      _paymentService.dispose();
      _iapSubscription?.cancel();
    });
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

      _paymentService.openCheckout(
        email: user.email,
        contact: user.phoneNumber ?? '',
        amount: plan['amount'],
        description: plan['description'],
        orderId: '', // Client-side only
      );

      _selectedPlanDurationDays = plan['durationDays'];
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
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      if (days == 7) {
        updateData['hasUsedTrial'] = true;
      }

      await FirebaseFirestore.instance
          .collection('candidates')
          .doc(user.uid)
          .update(updateData);

      if (context.mounted) {
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Subscription activation failed: $e')),
        );
      }
    } finally {
      state = false;
    }
  }

  void _handlePaymentFailure(
    PaymentFailureResponse response,
    BuildContext context,
  ) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment Failed: ${response.message}')),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    // Handle external wallet
  }
}
