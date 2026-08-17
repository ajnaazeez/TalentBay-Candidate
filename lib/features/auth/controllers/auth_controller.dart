import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../repositories/auth_repository.dart';

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(() {
  return AuthController();
});

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

class AuthController extends AsyncNotifier<void> {
  late final AuthRepository _authRepository;

  @override
  Future<void> build() async {
    _authRepository = ref.watch(authRepositoryProvider);
  }

  Future<void> signInWithEmail(
    BuildContext context,
    String email,
    String password,
  ) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authRepository.signInWithEmail(email, password);
    });

    if (state.hasError) {
      if (context.mounted) {
        String message = 'Login Failed';
        final error = state.error;
        if (error is FirebaseAuthException) {
          if (error.code == 'wrong-role') {
            message = 'User is invalid in this application';
          } else {
            message = error.message ?? 'Login Failed';
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        );
      }
    } else {
      if (context.mounted) {
        context.go('/home');
      }
    }
  }

  Future<bool> signUpWithEmail(
    BuildContext context, {
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    bool shouldNavigate = true,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authRepository.signUpWithEmail(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
      );
    });

    if (!state.hasError) {
      if (shouldNavigate && context.mounted) {
        context.go('/home');
      }
      return true;
    }
    return false;
  }

  Future<void> sendOtp({
    required BuildContext context,
    required String phoneNumber,
    Function(String verificationId)? onCodeSent,
    Function(PhoneAuthCredential credential)? verificationCompleted,
  }) async {
    state = const AsyncValue.loading();
    await _authRepository.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      codeSent: (verificationId, forceResendingToken) {
        state = const AsyncValue.data(null);
        if (onCodeSent != null) {
          onCodeSent(verificationId);
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('OTP Sent to $phoneNumber')));
      },
      verificationFailed: (e) {
        state = AsyncValue.error(e, StackTrace.current);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification Failed: ${e.message}')),
        );
      },
      codeAutoRetrievalTimeout: (verificationId) {},
    );
  }

  Future<void> verifyOtp(
    BuildContext context,
    String verificationId,
    String smsCode,
  ) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      await _authRepository.signInWithCredential(credential);
    });

    if (state.hasError) {
      if (context.mounted) {
        String message = 'Verification Failed';
        final error = state.error;
        if (error is FirebaseAuthException) {
          if (error.code == 'wrong-role') {
            message = 'User is invalid in this application';
          } else {
            message = error.message ?? 'Verification Failed';
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        );
      }
    } else {
      if (context.mounted) {
        context.go('/home');
      }
    }
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
  }

  Future<void> sendUpdatePhoneOtp({
    required BuildContext context,
    required String phoneNumber,
    Function(String verificationId)? onCodeSent,
  }) async {
    // Determine the current state value to restore it if needed, or loading
    state = const AsyncValue.loading();
    // We don't want to reset the entire auth state (logout user) if this fails,
    // but AsyncNotifier state represents the *operation* state here mainly for UI feedback.

    await _authRepository.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) async {
        // Auto-resolution on Android devices or instant verification
        await _authRepository.updatePhoneNumber(credential);
        state = const AsyncValue.data(null);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Phone number updated successfully!')),
          );
          // Logic to close dialog can be handled in UI listener
        }
      },
      codeSent: (verificationId, forceResendingToken) {
        state = const AsyncValue.data(null);
        if (onCodeSent != null) {
          onCodeSent(verificationId);
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('OTP Sent to $phoneNumber')));
      },
      verificationFailed: (e) {
        state = AsyncValue.error(e, StackTrace.current);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification Failed: ${e.message}')),
        );
      },
      codeAutoRetrievalTimeout: (verificationId) {},
    );
  }

  // Revised approach for sendUpdatePhoneOtp to make it usable in UI
  Future<void> sendUpdatePhoneOtpWithCallback({
    required BuildContext context,
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(PhoneAuthCredential) onAutoVerified,
  }) async {
    state = const AsyncValue.loading();
    await _authRepository.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) {
        onAutoVerified(credential);
      },
      codeSent: (verificationId, forceResendingToken) {
        state = const AsyncValue.data(null);
        onCodeSent(verificationId);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('OTP Sent to $phoneNumber')));
      },
      verificationFailed: (e) {
        state = AsyncValue.error(e, StackTrace.current);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification Failed: ${e.message}')),
        );
      },
      codeAutoRetrievalTimeout: (verificationId) {},
    );
  }

  Future<void> verifyUpdatePhoneOtp(
    BuildContext context,
    String verificationId,
    String smsCode,
  ) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      await _authRepository.updatePhoneNumber(credential);
    });

    if (state.hasError) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification Failed: ${state.error}')),
        );
      }
    } else {
      // Success is handled by the caller awaiting this future
    }
  }

  Future<void> sendPasswordResetEmail(
    BuildContext context,
    String email,
  ) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authRepository.sendPasswordResetEmail(email);
    });

    if (state.hasError) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${state.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> completeRegistration(
    BuildContext context, {
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required PhoneAuthCredential credential,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      // 1. Create the account
      await _authRepository.signUpWithEmail(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
      );

      // 2. Link the phone number
      try {
        await _authRepository.updatePhoneNumber(credential);
      } catch (e) {
        // Rollback the newly created account if linking fails
        debugPrint('Failed to link phone number: $e');
        try {
          await _authRepository.deleteAccount();
        } catch (rollbackError) {
          debugPrint('Rollback failed: $rollbackError');
        }
        
        if (e is FirebaseAuthException && 
            (e.code == 'credential-already-in-use' || e.code == 'phone-number-already-exists' || e.code == 'invalid-credential')) {
          throw Exception('This phone number is already registered to an existing account.');
        }
        rethrow;
      }
    });

    if (!state.hasError) {
      if (context.mounted) {
        context.go('/home');
      }
    } else {
      if (context.mounted) {
        String errorMsg = state.error.toString();
        if (errorMsg.startsWith('Exception: ')) {
          errorMsg = errorMsg.replaceFirst('Exception: ', '');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
