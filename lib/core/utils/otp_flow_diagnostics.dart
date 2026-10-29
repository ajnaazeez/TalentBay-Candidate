import 'package:flutter/foundation.dart';

/// Structured, privacy-safe diagnostics for OTP verification flows.
/// Complies with Phase 2 requirements of the iOS OTP diagnostic protocol.
class OtpFlowDiagnostics {
  // Supported flow identifiers
  static const String flowPhoneSignIn = 'phone_sign_in';
  static const String flowAccountCreation = 'account_creation';
  static const String flowProfilePhoneUpdate = 'profile_phone_update';

  // Standardized Stage Identifiers
  static const String stagePhoneSubmitStarted = 'PHONE_SUBMIT_STARTED';
  static const String stagePhoneValidationCompleted = 'PHONE_VALIDATION_COMPLETED';
  static const String stageFirebasePhoneVerifyStarted = 'FIREBASE_PHONE_VERIFY_STARTED';
  static const String stageFirebaseCodeSent = 'FIREBASE_CODE_SENT';
  static const String stageFirebaseVerificationFailed = 'FIREBASE_VERIFICATION_FAILED';
  static const String stageFirebaseAutoVerified = 'FIREBASE_AUTO_VERIFIED';
  static const String stageFirebaseCodeTimeout = 'FIREBASE_CODE_TIMEOUT';
  static const String stageOtpScreenNavigationStarted = 'OTP_SCREEN_NAVIGATION_STARTED';
  static const String stageOtpSubmitStarted = 'OTP_SUBMIT_STARTED';
  static const String stageOtpValidationCompleted = 'OTP_VALIDATION_COMPLETED';
  static const String stageFirebaseCredentialCreated = 'FIREBASE_CREDENTIAL_CREATED';
  static const String stageFirebaseVerificationStarted = 'FIREBASE_VERIFICATION_STARTED';
  static const String stageFirebaseVerificationSucceeded = 'FIREBASE_VERIFICATION_SUCCEEDED';
  static const String stageAuthStateUpdated = 'AUTH_STATE_UPDATED';
  static const String stageAccountProcessingStarted = 'ACCOUNT_PROCESSING_STARTED';
  static const String stageProfileUpdateStarted = 'PROFILE_UPDATE_STARTED';
  static const String stageDatabaseOperationCompleted = 'DATABASE_OPERATION_COMPLETED';
  static const String stageNavigationStarted = 'NAVIGATION_STARTED';
  static const String stageFlowCompleted = 'FLOW_COMPLETED';
  static const String stageFlowFailed = 'FLOW_FAILED';

  // Status values
  static const String statusStarted = 'STARTED';
  static const String statusSuccess = 'SUCCESS';
  static const String statusFailure = 'FAILURE';
  static const String statusInfo = 'INFO';

  /// Generates a unique correlation ID for an OTP attempt.
  static String generateCorrelationId(String flowId) {
    return '${flowId}_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Sanitizes phone numbers to retain only the last 4 digits (e.g. '***1234').
  /// Never outputs the full phone number or country code.
  static String maskPhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return '[EMPTY]';
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return '***';
    return '***${digits.substring(digits.length - 4)}';
  }

  /// Sanitizes verification ID to avoid leaking sensitive secrets, only showing prefix length.
  static String maskVerificationId(String? vId) {
    if (vId == null || vId.trim().isEmpty) return '[EMPTY_OR_NULL]';
    return '[LEN:${vId.length},PREFIX:${vId.substring(0, vId.length > 4 ? 4 : vId.length)}...]';
  }

  /// Logs a structured diagnostic event.
  static void log({
    required String flowId,
    required String correlationId,
    required String stage,
    required String status,
    int? elapsedMs,
    String? details,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final elapsedStr = elapsedMs != null ? ' [elapsed: ${elapsedMs}ms]' : '';
    final detailsStr = details != null ? ' [details: $details]' : '';
    final errorStr = error != null
        ? ' [errorType: ${error.runtimeType}, error: $error]'
        : '';
    final stackStr =
        stackTrace != null ? '\n[stackTrace: $stackTrace]' : '';

    debugPrint(
      '[OTP_DIAGNOSTIC] [time: $timestamp] [flow: $flowId] [correlationId: $correlationId] '
      '[stage: $stage] [status: $status]$elapsedStr$detailsStr$errorStr$stackStr',
    );
  }
}
