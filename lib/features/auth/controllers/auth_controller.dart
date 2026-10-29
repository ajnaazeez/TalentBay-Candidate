import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../repositories/auth_repository.dart';
import '../../../../core/utils/firebase_error_handler.dart';
import '../../../../core/utils/otp_flow_diagnostics.dart';

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
    debugPrint('Firebase Phone Auth Exception: [${e.code}] ${e.message}');
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
    String? correlationId,
    String flowId = OtpFlowDiagnostics.flowPhoneSignIn,
  }) async {
    final corrId = correlationId ??
        OtpFlowDiagnostics.generateCorrelationId(flowId);
    final sw = Stopwatch()..start();

    OtpFlowDiagnostics.log(
      flowId: flowId,
      correlationId: corrId,
      stage: OtpFlowDiagnostics.stageFirebasePhoneVerifyStarted,
      status: OtpFlowDiagnostics.statusStarted,
      details:
          'Calling verifyPhoneNumber for ${OtpFlowDiagnostics.maskPhone(phoneNumber)}',
    );

    if (state.isLoading) {
      OtpFlowDiagnostics.log(
        flowId: flowId,
        correlationId: corrId,
        stage: OtpFlowDiagnostics.stageFirebasePhoneVerifyStarted,
        status: OtpFlowDiagnostics.statusInfo,
        details: 'sendOtp skipped because state.isLoading is true',
      );
      return;
    }
    state = const AsyncValue.loading();
    try {
      await _authRepository.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (credential) {
          OtpFlowDiagnostics.log(
            flowId: flowId,
            correlationId: corrId,
            stage: OtpFlowDiagnostics.stageFirebaseAutoVerified,
            status: OtpFlowDiagnostics.statusSuccess,
            elapsedMs: sw.elapsedMilliseconds,
            details: 'verificationCompleted callback triggered natively',
          );
          if (verificationCompleted != null) {
            verificationCompleted(credential);
          }
        },
        codeSent: (verificationId, forceResendingToken) {
          state = const AsyncValue.data(null);
          OtpFlowDiagnostics.log(
            flowId: flowId,
            correlationId: corrId,
            stage: OtpFlowDiagnostics.stageFirebaseCodeSent,
            status: OtpFlowDiagnostics.statusSuccess,
            elapsedMs: sw.elapsedMilliseconds,
            details:
                'vId=${OtpFlowDiagnostics.maskVerificationId(verificationId)}, resendToken=$forceResendingToken',
          );
          if (onCodeSent != null) {
            onCodeSent(verificationId);
          }
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('OTP Sent to $phoneNumber')));
          }
        },
        verificationFailed: (e) {
          OtpFlowDiagnostics.log(
            flowId: flowId,
            correlationId: corrId,
            stage: OtpFlowDiagnostics.stageFirebaseVerificationFailed,
            status: OtpFlowDiagnostics.statusFailure,
            elapsedMs: sw.elapsedMilliseconds,
            details: 'code=${e.code}, message=${e.message}',
            error: e,
          );
          state = AsyncValue.error(e, StackTrace.current);
          if (context.mounted) {
            final message = _getFriendlyPhoneAuthErrorMessage(e);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
          }
        },
        codeAutoRetrievalTimeout: (verificationId) {
          OtpFlowDiagnostics.log(
            flowId: flowId,
            correlationId: corrId,
            stage: OtpFlowDiagnostics.stageFirebaseCodeTimeout,
            status: OtpFlowDiagnostics.statusInfo,
            details:
                'vId=${OtpFlowDiagnostics.maskVerificationId(verificationId)}',
          );
        },
      );
    } catch (e, st) {
      debugPrint('[AuthController] sendOtp failed synchronously: $e\n$st');
      OtpFlowDiagnostics.log(
        flowId: flowId,
        correlationId: corrId,
        stage: OtpFlowDiagnostics.stageFlowFailed,
        status: OtpFlowDiagnostics.statusFailure,
        elapsedMs: sw.elapsedMilliseconds,
        details: 'sendOtp synchronous exception: $e',
        error: e,
        stackTrace: st,
      );
      state = AsyncValue.error(e, st);
      if (context.mounted) {
        final message = e is FirebaseAuthException
            ? _getFriendlyPhoneAuthErrorMessage(e)
            : 'Failed to initiate phone verification: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  Future<void> verifyOtp(
    BuildContext context,
    String verificationId,
    String smsCode, {
    String? correlationId,
  }) async {
    final corrId = correlationId ??
        OtpFlowDiagnostics.generateCorrelationId(
            OtpFlowDiagnostics.flowPhoneSignIn);
    debugPrint('[OTP_TRACE] AuthController.verifyOtp entered. correlationId=$corrId');

    final trimmedVId = verificationId.trim();
    final trimmedCode = smsCode.trim();

    if (trimmedVId.isEmpty || trimmedCode.length != 6) {
      OtpFlowDiagnostics.log(
        flowId: OtpFlowDiagnostics.flowPhoneSignIn,
        correlationId: corrId,
        stage: OtpFlowDiagnostics.stageFlowFailed,
        status: OtpFlowDiagnostics.statusFailure,
        details:
            'Pre-credential validation failed: vIdLength=${trimmedVId.length}, codeLength=${trimmedCode.length}',
      );
      _showError(
        context,
        FirebaseAuthException(
          code: 'invalid-verification-id',
          message: 'The verification code has expired. Please request a new one.',
        ),
      );
      return;
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: trimmedVId,
      smsCode: trimmedCode,
    );
    OtpFlowDiagnostics.log(
      flowId: OtpFlowDiagnostics.flowPhoneSignIn,
      correlationId: corrId,
      stage: OtpFlowDiagnostics.stageFirebaseCredentialCreated,
      status: OtpFlowDiagnostics.statusSuccess,
    );
    await completePhoneLogin(context, credential, correlationId: corrId);
  }

  /// Verifies the SMS code, then asks the backend which candidate owns that
  /// number. The app stays on this screen until that answer arrives.
  Future<void> completePhoneLogin(
    BuildContext context,
    PhoneAuthCredential credential, {
    String? correlationId,
  }) async {
    final corrId = correlationId ??
        OtpFlowDiagnostics.generateCorrelationId(
            OtpFlowDiagnostics.flowPhoneSignIn);
    debugPrint('[OTP_TRACE] completePhoneLogin entered. _phoneLoginInFlight=$_phoneLoginInFlight, corrId=$corrId');
    if (_phoneLoginInFlight) return;
    _phoneLoginInFlight = true;
    _holdNavigation(true);
    state = const AsyncValue.loading();

    final totalSw = Stopwatch()..start();
    final stepSw = Stopwatch()..start();

    try {
      debugPrint('[OTP_TRACE] Stage 1 START: signInWithPhoneCredential');
      OtpFlowDiagnostics.log(
        flowId: OtpFlowDiagnostics.flowPhoneSignIn,
        correlationId: corrId,
        stage: OtpFlowDiagnostics.stageFirebaseVerificationStarted,
        status: OtpFlowDiagnostics.statusStarted,
      );
      await _authRepository.signInWithPhoneCredential(credential);
      debugPrint('[OTP_TRACE] Stage 1 COMPLETE: signInWithPhoneCredential took ${stepSw.elapsedMilliseconds}ms');
      OtpFlowDiagnostics.log(
        flowId: OtpFlowDiagnostics.flowPhoneSignIn,
        correlationId: corrId,
        stage: OtpFlowDiagnostics.stageFirebaseVerificationSucceeded,
        status: OtpFlowDiagnostics.statusSuccess,
        elapsedMs: stepSw.elapsedMilliseconds,
      );
      stepSw.reset();

      debugPrint('[OTP_TRACE] Stage 2 START: getIdToken');
      final tempUser = FirebaseAuth.instance.currentUser;
      final idToken = await tempUser?.getIdToken();
      debugPrint('[OTP_TRACE] Stage 2 COMPLETE: getIdToken took ${stepSw.elapsedMilliseconds}ms, idTokenPresent=${idToken?.isNotEmpty == true}');
      stepSw.reset();

      if (idToken == null || idToken.isEmpty) {
        throw FirebaseAuthException(
          code: 'internal',
          message: 'Could not verify the code. Please request a new one.',
        );
      }

      debugPrint('[OTP_TRACE] Stage 3 START: loginWithPhoneOtp Cloud Function');
      OtpFlowDiagnostics.log(
        flowId: OtpFlowDiagnostics.flowPhoneSignIn,
        correlationId: corrId,
        stage: OtpFlowDiagnostics.stageAccountProcessingStarted,
        status: OtpFlowDiagnostics.statusStarted,
      );
      final result = await _authRepository.loginWithPhoneOtp(idToken);
      final customToken = result['customToken']?.toString() ?? '';
      debugPrint('[OTP_TRACE] Stage 3 COMPLETE: loginWithPhoneOtp took ${stepSw.elapsedMilliseconds}ms, customTokenPresent=${customToken.isNotEmpty}');
      stepSw.reset();

      if (customToken.isEmpty) {
        throw FirebaseAuthException(
          code: 'internal',
          message: 'Sign in did not finish. Please try again.',
        );
      }

      debugPrint('[OTP_TRACE] Stage 4 START: signInWithCustomToken');
      await FirebaseAuth.instance.signInWithCustomToken(customToken);
      final user = FirebaseAuth.instance.currentUser;
      debugPrint('[OTP_TRACE] Stage 4 COMPLETE: signInWithCustomToken took ${stepSw.elapsedMilliseconds}ms, userPresent=${user != null}');
      stepSw.reset();

      if (user == null) {
        throw FirebaseAuthException(
          code: 'internal',
          message: 'Sign in did not finish. Please try again.',
        );
      }

      debugPrint('[OTP_TRACE] Stage 5 START: verifyUserRole');
      await _authRepository.verifyUserRole(user);
      debugPrint('[OTP_TRACE] Stage 5 COMPLETE: verifyUserRole took ${stepSw.elapsedMilliseconds}ms');
      OtpFlowDiagnostics.log(
        flowId: OtpFlowDiagnostics.flowPhoneSignIn,
        correlationId: corrId,
        stage: OtpFlowDiagnostics.stageDatabaseOperationCompleted,
        status: OtpFlowDiagnostics.statusSuccess,
        elapsedMs: stepSw.elapsedMilliseconds,
      );
      debugPrint('[OTP_TRACE] Total auth pipeline duration before navigation: ${totalSw.elapsedMilliseconds}ms');

      state = const AsyncValue.data(null);
      debugPrint('[OTP_TRACE] Stage 6 START: Navigation to /home. contextMounted=${context.mounted}');
      OtpFlowDiagnostics.log(
        flowId: OtpFlowDiagnostics.flowPhoneSignIn,
        correlationId: corrId,
        stage: OtpFlowDiagnostics.stageNavigationStarted,
        status: OtpFlowDiagnostics.statusStarted,
        details: 'Destination: /home, contextMounted: ${context.mounted}',
      );
      if (context.mounted) {
        context.go('/home');
        debugPrint('[OTP_TRACE] Stage 6 COMPLETE: context.go(\'/home\') called successfully');
      } else {
        debugPrint('[OTP_TRACE] Stage 6 WARNING: context not mounted, cannot call context.go(\'/home\')');
      }
      OtpFlowDiagnostics.log(
        flowId: OtpFlowDiagnostics.flowPhoneSignIn,
        correlationId: corrId,
        stage: OtpFlowDiagnostics.stageFlowCompleted,
        status: OtpFlowDiagnostics.statusSuccess,
        elapsedMs: totalSw.elapsedMilliseconds,
      );
    } catch (e, stack) {
      debugPrint('[OTP_TRACE] completePhoneLogin FAILED after ${totalSw.elapsedMilliseconds}ms: type=${e.runtimeType}, error=$e\n$stack');
      OtpFlowDiagnostics.log(
        flowId: OtpFlowDiagnostics.flowPhoneSignIn,
        correlationId: corrId,
        stage: OtpFlowDiagnostics.stageFlowFailed,
        status: OtpFlowDiagnostics.statusFailure,
        elapsedMs: totalSw.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
      );
      try {
        await _authRepository.signOut();
      } catch (_) {}
      state = AsyncValue.error(e, stack);
      if (context.mounted) {
        _showError(context, e);
      }
    } finally {
      debugPrint('[OTP_TRACE] completePhoneLogin FINALLY: resetting flight and hold flags');
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
    String? correlationId,
  }) async {
    final corrId = correlationId ??
        OtpFlowDiagnostics.generateCorrelationId(
            OtpFlowDiagnostics.flowProfilePhoneUpdate);
    final sw = Stopwatch()..start();

    OtpFlowDiagnostics.log(
      flowId: OtpFlowDiagnostics.flowProfilePhoneUpdate,
      correlationId: corrId,
      stage: OtpFlowDiagnostics.stageFirebasePhoneVerifyStarted,
      status: OtpFlowDiagnostics.statusStarted,
      details:
          'Calling verifyPhoneNumber for ${OtpFlowDiagnostics.maskPhone(phoneNumber)}',
    );

    if (state.isLoading) return;
    state = const AsyncValue.loading();

    try {
      await _authRepository.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (credential) async {
          OtpFlowDiagnostics.log(
            flowId: OtpFlowDiagnostics.flowProfilePhoneUpdate,
            correlationId: corrId,
            stage: OtpFlowDiagnostics.stageFirebaseAutoVerified,
            status: OtpFlowDiagnostics.statusSuccess,
            elapsedMs: sw.elapsedMilliseconds,
          );
          await _authRepository.updatePhoneNumber(credential);
          state = const AsyncValue.data(null);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Phone number updated successfully!')),
            );
          }
        },
        codeSent: (verificationId, forceResendingToken) {
          state = const AsyncValue.data(null);
          OtpFlowDiagnostics.log(
            flowId: OtpFlowDiagnostics.flowProfilePhoneUpdate,
            correlationId: corrId,
            stage: OtpFlowDiagnostics.stageFirebaseCodeSent,
            status: OtpFlowDiagnostics.statusSuccess,
            elapsedMs: sw.elapsedMilliseconds,
            details:
                'vId=${OtpFlowDiagnostics.maskVerificationId(verificationId)}, resendToken=$forceResendingToken',
          );
          if (onCodeSent != null) {
            onCodeSent(verificationId);
          }
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('OTP Sent to $phoneNumber')));
          }
        },
        verificationFailed: (e) {
          OtpFlowDiagnostics.log(
            flowId: OtpFlowDiagnostics.flowProfilePhoneUpdate,
            correlationId: corrId,
            stage: OtpFlowDiagnostics.stageFirebaseVerificationFailed,
            status: OtpFlowDiagnostics.statusFailure,
            elapsedMs: sw.elapsedMilliseconds,
            details: 'code=${e.code}, message=${e.message}',
            error: e,
          );
          state = AsyncValue.error(e, StackTrace.current);
          if (context.mounted) {
            final message = _getFriendlyPhoneAuthErrorMessage(e);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
          }
        },
        codeAutoRetrievalTimeout: (verificationId) {
          OtpFlowDiagnostics.log(
            flowId: OtpFlowDiagnostics.flowProfilePhoneUpdate,
            correlationId: corrId,
            stage: OtpFlowDiagnostics.stageFirebaseCodeTimeout,
            status: OtpFlowDiagnostics.statusInfo,
            details:
                'vId=${OtpFlowDiagnostics.maskVerificationId(verificationId)}',
          );
        },
      );
    } catch (e, st) {
      debugPrint('[AuthController] sendUpdatePhoneOtp failed synchronously: $e\n$st');
      OtpFlowDiagnostics.log(
        flowId: OtpFlowDiagnostics.flowProfilePhoneUpdate,
        correlationId: corrId,
        stage: OtpFlowDiagnostics.stageFlowFailed,
        status: OtpFlowDiagnostics.statusFailure,
        elapsedMs: sw.elapsedMilliseconds,
        details: 'sendUpdatePhoneOtp synchronous exception: $e',
        error: e,
        stackTrace: st,
      );
      state = AsyncValue.error(e, st);
      if (context.mounted) {
        final message = e is FirebaseAuthException
            ? _getFriendlyPhoneAuthErrorMessage(e)
            : 'Failed to initiate phone verification: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  // Revised approach for sendUpdatePhoneOtp to make it usable in UI
  Future<void> sendUpdatePhoneOtpWithCallback({
    required BuildContext context,
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(PhoneAuthCredential) onAutoVerified,
    String? correlationId,
  }) async {
    final corrId = correlationId ??
        OtpFlowDiagnostics.generateCorrelationId(
            OtpFlowDiagnostics.flowProfilePhoneUpdate);
    final sw = Stopwatch()..start();

    OtpFlowDiagnostics.log(
      flowId: OtpFlowDiagnostics.flowProfilePhoneUpdate,
      correlationId: corrId,
      stage: OtpFlowDiagnostics.stageFirebasePhoneVerifyStarted,
      status: OtpFlowDiagnostics.statusStarted,
      details:
          'Calling verifyPhoneNumber for ${OtpFlowDiagnostics.maskPhone(phoneNumber)}',
    );

    if (state.isLoading) return;
    state = const AsyncValue.loading();
    try {
      await _authRepository.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (credential) {
          OtpFlowDiagnostics.log(
            flowId: OtpFlowDiagnostics.flowProfilePhoneUpdate,
            correlationId: corrId,
            stage: OtpFlowDiagnostics.stageFirebaseAutoVerified,
            status: OtpFlowDiagnostics.statusSuccess,
            elapsedMs: sw.elapsedMilliseconds,
          );
          onAutoVerified(credential);
        },
        codeSent: (verificationId, forceResendingToken) {
          state = const AsyncValue.data(null);
          OtpFlowDiagnostics.log(
            flowId: OtpFlowDiagnostics.flowProfilePhoneUpdate,
            correlationId: corrId,
            stage: OtpFlowDiagnostics.stageFirebaseCodeSent,
            status: OtpFlowDiagnostics.statusSuccess,
            elapsedMs: sw.elapsedMilliseconds,
            details:
                'vId=${OtpFlowDiagnostics.maskVerificationId(verificationId)}, resendToken=$forceResendingToken',
          );
          onCodeSent(verificationId);
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('OTP Sent to $phoneNumber')));
          }
        },
        verificationFailed: (e) {
          OtpFlowDiagnostics.log(
            flowId: OtpFlowDiagnostics.flowProfilePhoneUpdate,
            correlationId: corrId,
            stage: OtpFlowDiagnostics.stageFirebaseVerificationFailed,
            status: OtpFlowDiagnostics.statusFailure,
            elapsedMs: sw.elapsedMilliseconds,
            details: 'code=${e.code}, message=${e.message}',
            error: e,
          );
          state = AsyncValue.error(e, StackTrace.current);
          if (context.mounted) {
            final message = _getFriendlyPhoneAuthErrorMessage(e);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
          }
        },
        codeAutoRetrievalTimeout: (verificationId) {
          OtpFlowDiagnostics.log(
            flowId: OtpFlowDiagnostics.flowProfilePhoneUpdate,
            correlationId: corrId,
            stage: OtpFlowDiagnostics.stageFirebaseCodeTimeout,
            status: OtpFlowDiagnostics.statusInfo,
            details:
                'vId=${OtpFlowDiagnostics.maskVerificationId(verificationId)}',
          );
        },
      );
    } catch (e, st) {
      debugPrint('[AuthController] sendUpdatePhoneOtpWithCallback failed synchronously: $e\n$st');
      OtpFlowDiagnostics.log(
        flowId: OtpFlowDiagnostics.flowProfilePhoneUpdate,
        correlationId: corrId,
        stage: OtpFlowDiagnostics.stageFlowFailed,
        status: OtpFlowDiagnostics.statusFailure,
        elapsedMs: sw.elapsedMilliseconds,
        details: 'sendUpdatePhoneOtpWithCallback synchronous exception: $e',
        error: e,
        stackTrace: st,
      );
      state = AsyncValue.error(e, st);
      if (context.mounted) {
        final message = e is FirebaseAuthException
            ? _getFriendlyPhoneAuthErrorMessage(e)
            : 'Failed to initiate phone verification: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  Future<bool> verifyUpdatePhoneOtp(
    BuildContext context,
    String verificationId,
    String smsCode, {
    String? correlationId,
  }) async {
    final corrId = correlationId ??
        OtpFlowDiagnostics.generateCorrelationId(
            OtpFlowDiagnostics.flowProfilePhoneUpdate);
    state = const AsyncValue.loading();
    bool success = false;
    final sw = Stopwatch()..start();

    final trimmedVId = verificationId.trim();
    final trimmedCode = smsCode.trim();

    if (trimmedVId.isEmpty || trimmedCode.length != 6) {
      OtpFlowDiagnostics.log(
        flowId: OtpFlowDiagnostics.flowProfilePhoneUpdate,
        correlationId: corrId,
        stage: OtpFlowDiagnostics.stageFlowFailed,
        status: OtpFlowDiagnostics.statusFailure,
        details:
            'Pre-credential validation failed: vIdLength=${trimmedVId.length}, codeLength=${trimmedCode.length}',
      );
      if (context.mounted) {
        _showError(
          context,
          FirebaseAuthException(
            code: 'invalid-verification-id',
            message: 'The verification code has expired. Please request a new one.',
          ),
        );
      }
      return false;
    }

    state = await AsyncValue.guard(() async {
      OtpFlowDiagnostics.log(
        flowId: OtpFlowDiagnostics.flowProfilePhoneUpdate,
        correlationId: corrId,
        stage: OtpFlowDiagnostics.stageFirebaseCredentialCreated,
        status: OtpFlowDiagnostics.statusSuccess,
      );
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: trimmedVId,
        smsCode: trimmedCode,
      );
      OtpFlowDiagnostics.log(
        flowId: OtpFlowDiagnostics.flowProfilePhoneUpdate,
        correlationId: corrId,
        stage: OtpFlowDiagnostics.stageFirebaseVerificationStarted,
        status: OtpFlowDiagnostics.statusStarted,
      );
      await _authRepository.updatePhoneNumber(credential);
      OtpFlowDiagnostics.log(
        flowId: OtpFlowDiagnostics.flowProfilePhoneUpdate,
        correlationId: corrId,
        stage: OtpFlowDiagnostics.stageFirebaseVerificationSucceeded,
        status: OtpFlowDiagnostics.statusSuccess,
        elapsedMs: sw.elapsedMilliseconds,
      );
      success = true;
    });

    if (state.hasError) {
      OtpFlowDiagnostics.log(
        flowId: OtpFlowDiagnostics.flowProfilePhoneUpdate,
        correlationId: corrId,
        stage: OtpFlowDiagnostics.stageFlowFailed,
        status: OtpFlowDiagnostics.statusFailure,
        elapsedMs: sw.elapsedMilliseconds,
        error: state.error,
      );
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
    OtpFlowDiagnostics.log(
      flowId: OtpFlowDiagnostics.flowProfilePhoneUpdate,
      correlationId: corrId,
      stage: OtpFlowDiagnostics.stageFlowCompleted,
      status: OtpFlowDiagnostics.statusSuccess,
      elapsedMs: sw.elapsedMilliseconds,
    );
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
    String? correlationId,
  }) async {
    final corrId = correlationId ??
        OtpFlowDiagnostics.generateCorrelationId(
            OtpFlowDiagnostics.flowAccountCreation);
    _holdNavigation(true);
    state = const AsyncValue.loading();
    final sw = Stopwatch()..start();

    try {
      state = await AsyncValue.guard(() async {
        OtpFlowDiagnostics.log(
          flowId: OtpFlowDiagnostics.flowAccountCreation,
          correlationId: corrId,
          stage: OtpFlowDiagnostics.stageAccountProcessingStarted,
          status: OtpFlowDiagnostics.statusStarted,
          details: 'Creating user with email and linking phone credential',
        );
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

        OtpFlowDiagnostics.log(
          flowId: OtpFlowDiagnostics.flowAccountCreation,
          correlationId: corrId,
          stage: OtpFlowDiagnostics.stageFirebaseVerificationStarted,
          status: OtpFlowDiagnostics.statusStarted,
          details: 'Linking phone credential to active user',
        );

        // Link the phone number credential to the active account
        try {
          await _authRepository.updatePhoneNumber(credential);
          OtpFlowDiagnostics.log(
            flowId: OtpFlowDiagnostics.flowAccountCreation,
            correlationId: corrId,
            stage: OtpFlowDiagnostics.stageFirebaseVerificationSucceeded,
            status: OtpFlowDiagnostics.statusSuccess,
          );
        } catch (e, st) {
          debugPrint('Phone number linking notice: $e');
          OtpFlowDiagnostics.log(
            flowId: OtpFlowDiagnostics.flowAccountCreation,
            correlationId: corrId,
            stage: OtpFlowDiagnostics.stageFirebaseVerificationStarted,
            status: OtpFlowDiagnostics.statusFailure,
            error: e,
            stackTrace: st,
          );
          if (e is FirebaseAuthException) {
            if (e.code == 'credential-already-in-use' ||
                e.code == 'phone-number-already-exists') {
              throw Exception(
                  'This phone number is already registered to another user account.');
            } else if (e.code == 'provider-already-linked') {
              // Already linked to this user account, safe to proceed
              return;
            }
          }
          rethrow;
        }
      });

      if (!state.hasError) {
        OtpFlowDiagnostics.log(
          flowId: OtpFlowDiagnostics.flowAccountCreation,
          correlationId: corrId,
          stage: OtpFlowDiagnostics.stageNavigationStarted,
          status: OtpFlowDiagnostics.statusStarted,
          details: 'Navigating to /home, contextMounted: ${context.mounted}',
        );
        if (context.mounted) {
          context.go('/home');
        }
        OtpFlowDiagnostics.log(
          flowId: OtpFlowDiagnostics.flowAccountCreation,
          correlationId: corrId,
          stage: OtpFlowDiagnostics.stageFlowCompleted,
          status: OtpFlowDiagnostics.statusSuccess,
          elapsedMs: sw.elapsedMilliseconds,
        );
      } else {
        OtpFlowDiagnostics.log(
          flowId: OtpFlowDiagnostics.flowAccountCreation,
          correlationId: corrId,
          stage: OtpFlowDiagnostics.stageFlowFailed,
          status: OtpFlowDiagnostics.statusFailure,
          elapsedMs: sw.elapsedMilliseconds,
          error: state.error,
        );
        _showError(context, state.error ?? 'Could not finish registration.');
      }
    } finally {
      _holdNavigation(false);
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
