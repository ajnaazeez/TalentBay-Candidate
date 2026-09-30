import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../repositories/auth_repository.dart';
import '../../../../core/utils/firebase_error_handler.dart';

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(() {
  return AuthController();
});

/// While true, routing must stay on the current screen. Phone OTP briefly
/// signs into a temporary user before the server returns the real account.
final authNavigationHoldProvider =
    NotifierProvider<AuthNavigationHold, bool>(AuthNavigationHold.new);

class AuthNavigationHold extends Notifier<bool> {
  @override
  bool build() => false;

  void setHold(bool value) {
    state = value;
  }
}

final authStateChangesProvider = StreamProvider<User?>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.authStateChanges.asyncMap((user) async {
    final holdNavigation = ref.read(authNavigationHoldProvider);
    if (user != null && !holdNavigation) {
      try {
        await authRepository.verifyUserRole(user);
      } catch (e) {
        // Only return null if wrong-role specifically was confirmed (e.g. recruiter logging into candidate app)
        if (e is FirebaseAuthException && e.code == 'wrong-role') {
          return null;
        }
        // If it was a network error (e.g. GaiException/DNS) or temporary issue, preserve the user session
        debugPrint('verifyUserRole note: $e');
      }
    }
    return user;
  });
});

class AuthController extends AsyncNotifier<void> {
  late final AuthRepository _authRepository;
  bool _phoneLoginInFlight = false;

  void _showError(BuildContext context, Object error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                FirebaseErrorHandler.getMessage(error),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _holdNavigation(bool hold) {
    ref.read(authNavigationHoldProvider.notifier).setHold(hold);
  }

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
      _showError(context, state.error ?? 'Login failed');
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
    _showError(context, state.error ?? 'Could not create your account.');
    return false;
  }

  String _getFriendlyPhoneAuthErrorMessage(FirebaseAuthException e) {
    if (e.code == 'invalid-phone-number' ||
        (e.message != null &&
            (e.message!.contains('E.164') ||
                e.message!.contains('invalid format') ||
                e.message!.contains('format of the phone number')))) {
      return 'Please enter a valid mobile number.';
    }
    return e.message ?? 'Verification Failed';
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
        if (context.mounted) {
          final message = _getFriendlyPhoneAuthErrorMessage(e);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      },
      codeAutoRetrievalTimeout: (verificationId) {},
    );
  }

  Future<void> verifyOtp(
    BuildContext context,
    String verificationId,
    String smsCode,
  ) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    await completePhoneLogin(context, credential);
  }

  /// Verifies the SMS code, then asks the backend which candidate owns that
  /// number. The app stays on this screen until that answer arrives.
  Future<void> completePhoneLogin(
    BuildContext context,
    PhoneAuthCredential credential,
  ) async {
    if (_phoneLoginInFlight) return;
    _phoneLoginInFlight = true;
    _holdNavigation(true);
    state = const AsyncValue.loading();

    try {
      await _authRepository.signInWithPhoneCredential(credential);
      final tempUser = FirebaseAuth.instance.currentUser;
      final idToken = await tempUser?.getIdToken(true);
      if (idToken == null || idToken.isEmpty) {
        throw FirebaseAuthException(
          code: 'internal',
          message: 'Could not verify the code. Please request a new one.',
        );
      }

      final result = await _authRepository.loginWithPhoneOtp(idToken);
      final customToken = result['customToken']?.toString() ?? '';
      if (customToken.isEmpty) {
        throw FirebaseAuthException(
          code: 'internal',
          message: 'Sign in did not finish. Please try again.',
        );
      }
      await FirebaseAuth.instance.signInWithCustomToken(customToken);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'internal',
          message: 'Sign in did not finish. Please try again.',
        );
      }
      await _authRepository.verifyUserRole(user);
      state = const AsyncValue.data(null);
      if (context.mounted) {
        context.go('/home');
      }
    } catch (e, stack) {
      debugPrint('completePhoneLogin failed: $e\n$stack');
      try {
        await _authRepository.signOut();
      } catch (_) {}
      state = AsyncValue.error(e, stack);
      if (context.mounted) {
        _showError(context, e);
      }
    } finally {
      _phoneLoginInFlight = false;
      _holdNavigation(false);
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
        if (context.mounted) {
          final message = _getFriendlyPhoneAuthErrorMessage(e);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
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
        if (context.mounted) {
          final message = _getFriendlyPhoneAuthErrorMessage(e);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      },
      codeAutoRetrievalTimeout: (verificationId) {},
    );
  }

  Future<bool> verifyUpdatePhoneOtp(
    BuildContext context,
    String verificationId,
    String smsCode,
  ) async {
    state = const AsyncValue.loading();
    bool success = false;
    state = await AsyncValue.guard(() async {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      await _authRepository.updatePhoneNumber(credential);
      success = true;
    });

    if (state.hasError) {
      if (context.mounted) {
        final message = FirebaseErrorHandler.getMessage(state.error!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red[700],
          ),
        );
      }
      return false;
    }
    return success;
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
      _showError(context, state.error ?? 'Could not send the reset email.');
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
      final existingUser = FirebaseAuth.instance.currentUser;
      if (existingUser == null) {
        // Create the account safely
        await _authRepository.signUpWithEmail(
          email: email,
          password: password,
          firstName: firstName,
          lastName: lastName,
          phoneNumber: phoneNumber,
        );
      }

      // Link the phone number credential to the active account
      try {
        await _authRepository.updatePhoneNumber(credential);
      } catch (e) {
        debugPrint('Phone number linking notice: $e');
        if (e is FirebaseAuthException) {
          if (e.code == 'credential-already-in-use' || e.code == 'phone-number-already-exists') {
            throw Exception('This phone number is already registered to another user account.');
          } else if (e.code == 'provider-already-linked') {
            // Already linked to this user account, safe to proceed
            return;
          }
        }
        rethrow;
      }
    });

    if (!state.hasError) {
      if (context.mounted) {
        context.go('/home');
      }
    } else {
      _showError(context, state.error ?? 'Could not finish registration.');
    }
  }

  Future<bool> sendEmailOtp(
    BuildContext context,
    String email,
  ) async {
    state = const AsyncValue.loading();
    bool success = false;
    state = await AsyncValue.guard(() async {
      await _authRepository.sendEmailOtp(email);
      success = true;
    });

    if (state.hasError) {
      _showError(context, state.error ?? 'Could not send the verification code.');
    }
    return success;
  }

  Future<bool> verifyEmailOtp(
    BuildContext context,
    String email,
    String otp,
  ) async {
    state = const AsyncValue.loading();
    bool verified = false;
    state = await AsyncValue.guard(() async {
      verified = await _authRepository.verifyEmailOtp(email, otp);
    });

    if (state.hasError) {
      _showError(context, state.error ?? 'Could not verify the code.');
    }
    return verified;
  }
}
