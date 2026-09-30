import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class FirebaseErrorHandler {
  static String getMessage(Object error) {
    if (error is FirebaseFunctionsException || error is FirebaseAuthException) {
      final code = error is FirebaseFunctionsException
          ? error.code
          : (error as FirebaseAuthException).code;
      final serverMessage = error is FirebaseFunctionsException
          ? error.message
          : (error as FirebaseAuthException).message;
      return _authStyleMessage(code, serverMessage);
    } else if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'You do not have permission to perform this action.';
        case 'unavailable':
          return 'Service is currently unavailable. Please try again later.';
        case 'not-found':
          return 'The record could not be found. Please try again.';
        case 'too-many-attempts':
          return 'Too many attempts. Please try again later.';
        case 'app-not-authorized':
          return 'App Check failed. If you are a developer, please ensure your debug token is registered in the Firebase Console.';
        default:
          if (error.message?.contains('App attestation failed') ?? false) {
            return 'App Check attestation failed. Please check your configuration.';
          }
          final message = error.message?.trim();
          if (message != null && message.isNotEmpty) return message;
          return 'Something went wrong. Please try again.';
      }
    }

    var message = error.toString().trim();
    if (message.startsWith('Exception:')) {
      message = message.replaceFirst('Exception:', '').trim();
    }
    if (message.startsWith('FirebaseFunctionsException') ||
        message.startsWith('FirebaseAuthException')) {
      return 'Something went wrong. Please try again.';
    }
    return message.isEmpty ? 'Something went wrong. Please try again.' : message;
  }

  static String _authStyleMessage(String code, String? serverMessage) {
    final friendlyServer = serverMessage?.trim();
    switch (code) {
      case 'user-not-found':
      case 'not-found':
        return friendlyServer?.isNotEmpty == true
            ? friendlyServer!
            : 'No account found for this email or mobile number.';
      case 'wrong-password':
      case 'invalid-credential':
        return friendlyServer?.isNotEmpty == true &&
                !friendlyServer!.toLowerCase().contains('credential')
            ? friendlyServer
            : 'Incorrect email or password. Please try again.';
      case 'email-already-in-use':
      case 'already-exists':
        return friendlyServer?.isNotEmpty == true
            ? friendlyServer!
            : 'An account already exists with this email or mobile number.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'invalid-argument':
        return friendlyServer?.isNotEmpty == true
            ? friendlyServer!
            : 'Please check the details and try again.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support if this is unexpected.';
      case 'operation-not-allowed':
        return 'This sign-in method is not available right now.';
      case 'too-many-requests':
      case 'resource-exhausted':
        return friendlyServer?.isNotEmpty == true
            ? friendlyServer!
            : 'Too many attempts. Please wait a few minutes and try again.';
      case 'credential-already-in-use':
      case 'phone-number-already-exists':
        return 'This mobile number is already registered to another account.';
      case 'invalid-phone-number':
        return 'Please enter a valid mobile number.';
      case 'invalid-verification-code':
        return 'That code is incorrect. Please check it and try again.';
      case 'invalid-verification-id':
      case 'session-expired':
        return 'This code has expired. Please request a new one.';
      case 'network-request-failed':
      case 'unavailable':
        return 'Network error. Check your connection and try again.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'wrong-role':
        return 'This account cannot be used in the candidate app.';
      case 'requires-recent-login':
        return 'For your security, sign out, sign in again, then update your mobile number.';
      case 'internal':
      case 'deadline-exceeded':
      case 'failed-precondition':
      case 'permission-denied':
      case 'unauthenticated':
        return friendlyServer?.isNotEmpty == true
            ? friendlyServer!
            : 'Something went wrong. Please try again.';
      default:
        if (friendlyServer != null && friendlyServer.isNotEmpty) {
          return friendlyServer;
        }
        return 'Something went wrong. Please try again.';
    }
  }
}
