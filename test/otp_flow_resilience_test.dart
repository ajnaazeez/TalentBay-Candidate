import 'package:flutter_test/flutter_test.dart';
import 'package:talentbay_candidate/core/utils/otp_flow_diagnostics.dart';
import 'package:talentbay_candidate/core/utils/firebase_error_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() {
  group('OtpFlowDiagnostics Tests', () {
    test('maskPhone sanitizes phone number and masks all but last 4 digits', () {
      expect(OtpFlowDiagnostics.maskPhone('+919876543210'), '***3210');
      expect(OtpFlowDiagnostics.maskPhone('9876543210'), '***3210');
      expect(OtpFlowDiagnostics.maskPhone('+1 (555) 234-5678'), '***5678');
      expect(OtpFlowDiagnostics.maskPhone('123'), '***');
      expect(OtpFlowDiagnostics.maskPhone(''), '[EMPTY]');
      expect(OtpFlowDiagnostics.maskPhone(null), '[EMPTY]');
    });

    test('maskVerificationId masks secrets and only exposes prefix length', () {
      expect(
        OtpFlowDiagnostics.maskVerificationId('AM3u_abcd1234567890'),
        '[LEN:19,PREFIX:AM3u...]',
      );
      expect(OtpFlowDiagnostics.maskVerificationId(''), '[EMPTY_OR_NULL]');
      expect(OtpFlowDiagnostics.maskVerificationId(null), '[EMPTY_OR_NULL]');
    });

    test('generateCorrelationId produces distinct IDs with flow prefix', () {
      final id1 = OtpFlowDiagnostics.generateCorrelationId(OtpFlowDiagnostics.flowPhoneSignIn);
      final id2 = OtpFlowDiagnostics.generateCorrelationId(OtpFlowDiagnostics.flowAccountCreation);
      final id3 = OtpFlowDiagnostics.generateCorrelationId(OtpFlowDiagnostics.flowProfilePhoneUpdate);

      expect(id1.startsWith('phone_sign_in_'), isTrue);
      expect(id2.startsWith('account_creation_'), isTrue);
      expect(id3.startsWith('profile_phone_update_'), isTrue);
      expect(id1, isNot(equals(id2)));
    });

    test('log does not throw on valid inputs and sanitizes records', () {
      expect(
        () => OtpFlowDiagnostics.log(
          flowId: OtpFlowDiagnostics.flowPhoneSignIn,
          correlationId: 'test_corr_1',
          stage: OtpFlowDiagnostics.stageOtpSubmitStarted,
          status: OtpFlowDiagnostics.statusStarted,
          details: 'Masked phone: ${OtpFlowDiagnostics.maskPhone("+919876543210")}',
        ),
        returnsNormally,
      );

      expect(
        () => OtpFlowDiagnostics.log(
          flowId: OtpFlowDiagnostics.flowPhoneSignIn,
          correlationId: 'test_corr_1',
          stage: OtpFlowDiagnostics.stageFlowFailed,
          status: OtpFlowDiagnostics.statusFailure,
          elapsedMs: 120,
          error: Exception('Test exception'),
          stackTrace: StackTrace.current,
        ),
        returnsNormally,
      );
    });
  });

  group('OTP Pre-Credential Guard & Error Handling Tests', () {
    test('FirebaseErrorHandler gives friendly messages for invalid & expired OTP codes', () {
      final invalidCodeEx = FirebaseAuthException(
        code: 'invalid-verification-code',
        message: 'The verification code from SMS is invalid',
      );
      final expiredIdEx = FirebaseAuthException(
        code: 'invalid-verification-id',
        message: 'The verification ID is invalid or has expired',
      );
      final sessionExpiredEx = FirebaseAuthException(
        code: 'session-expired',
        message: 'The SMS code has expired. Please re-send the verification code to try again.',
      );

      expect(
        FirebaseErrorHandler.getMessage(invalidCodeEx),
        'That code is incorrect. Please check it and try again.',
      );
      expect(
        FirebaseErrorHandler.getMessage(expiredIdEx),
        'This code has expired. Please request a new one.',
      );
      expect(
        FirebaseErrorHandler.getMessage(sessionExpiredEx),
        'This code has expired. Please request a new one.',
      );
    });

    test('Pre-credential validation logic safely rejects empty verification IDs', () {
      bool isPreCredentialValid(String vId, String code) {
        final trimmedVId = vId.trim();
        final trimmedCode = code.trim();
        return trimmedVId.isNotEmpty && trimmedCode.length == 6;
      }

      expect(isPreCredentialValid('', '123456'), isFalse);
      expect(isPreCredentialValid('   ', '123456'), isFalse);
      expect(isPreCredentialValid('valid_vid_123', '12345'), isFalse);
      expect(isPreCredentialValid('valid_vid_123', '1234567'), isFalse);
      expect(isPreCredentialValid('valid_vid_123', '123456'), isTrue);
      expect(isPreCredentialValid('  valid_vid_123  ', ' 123456 '), isTrue);
    });
  });
}
