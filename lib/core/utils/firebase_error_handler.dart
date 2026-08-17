import 'package:firebase_auth/firebase_auth.dart';

class FirebaseErrorHandler {
  static String getMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No user found with this email.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'email-already-in-use':
          return 'An account already exists with this email.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'user-disabled':
          return 'This user account has been disabled.';
        case 'operation-not-allowed':
          return 'This operation is not allowed.';
        case 'too-many-requests':
          return 'Too many requests. Please try again later.';
        case 'credential-already-in-use':
          return 'This credential is already associated with a different user account.';
        case 'invalid-credential':
          return 'Invalid credential. Please try again.';
        case 'invalid-verification-code':
          return 'Invalid verification code. Please check and try again.';
        case 'invalid-verification-id':
          return 'Invalid verification ID. Please request a new code.';
        case 'network-request-failed':
          return 'Network error. Please check your connection.';
        case 'weak-password':
          return 'The password provided is too weak.';
        default:
          return 'Authentication error: ${error.message ?? "Unknown error"}';
      }
    } else if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'You do not have permission to perform this action.';
        case 'unavailable':
          return 'Service is currently unavailable. Please try again later.';
        case 'too-many-attempts':
          return 'Too many attempts. Please try again later.';
        case 'app-not-authorized':
          return 'App Check failed. If you are a developer, please ensure your debug token is registered in the Firebase Console.';
        default:
          if (error.message?.contains('App attestation failed') ?? false) {
            return 'App Check attestation failed. Please check your configuration.';
          }
          return 'Firebase error: ${error.message ?? "Unknown error"}';
      }
    }

    return error.toString().replaceAll('Exception:', '').trim();
  }
}
