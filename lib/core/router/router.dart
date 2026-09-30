import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/controllers/auth_controller.dart';
import '../../features/auth/views/login_screen.dart';
import '../../features/auth/views/register_screen.dart';
import '../../features/auth/views/terms_and_conditions_screen.dart';
import '../../features/auth/views/otp_verification_screen.dart';
import '../../features/home/views/home_screen.dart';
import '../../features/candidate/views/profile_screen.dart';
import '../../features/candidate/views/edit_profile_basic_screen.dart';
import '../../features/settings/views/settings_screen.dart';
import '../../features/jobs/views/job_details_screen.dart';
import '../../features/home/views/invitations_screen.dart';
import '../../features/notifications/views/notification_screen.dart';

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    _authSub = ref.listen(authStateChangesProvider, (_, _) {
      notifyListeners();
    });
    _holdSub = ref.listen(authNavigationHoldProvider, (_, _) {
      notifyListeners();
    });
  }

  late final ProviderSubscription<AsyncValue<User?>> _authSub;
  late final ProviderSubscription<bool> _holdSub;

  @override
  void dispose() {
    _authSub.close();
    _holdSub.close();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) {
      if (ref.read(authNavigationHoldProvider)) {
        return null;
      }

      final authState = ref.read(authStateChangesProvider);
      final isLoading = authState.isLoading;
      final hasError = authState.hasError;
      final currentUser = FirebaseAuth.instance.currentUser;
      final isAuthenticated =
          authState.value != null || (currentUser != null && !hasError);

      final isOtpVerification = state.uri.path == '/otp-verification';
      final isLoggingIn = state.uri.path == '/login';
      final isRegistering = state.uri.path == '/register';
      final isTermsAndConditions = state.uri.path == '/terms-and-conditions';

      if (isLoading && currentUser == null) return null;

      if (isAuthenticated) {
        if (isLoggingIn ||
            isRegistering ||
            isOtpVerification ||
            isTermsAndConditions) {
          return '/home';
        }
      } else {
        if (!isLoggingIn &&
            !isRegistering &&
            !isOtpVerification &&
            !isTermsAndConditions) {
          return '/login';
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/terms-and-conditions',
        builder: (context, state) => const TermsAndConditionsScreen(),
      ),
      GoRoute(
        path: '/otp-verification',
        builder: (context, state) {
          final extraRaw = state.extra;
          if (extraRaw is! Map) {
            return const LoginScreen();
          }
          final extra = Map<String, dynamic>.from(extraRaw);
          return OtpVerificationScreen(
            verificationId: extra['verificationId'],
            phoneNumber: extra['phoneNumber'],
            verificationType: extra['verificationType'] ?? 'login',
            registrationData:
                extra['registrationData'] as Map<String, dynamic>?,
          );
        },
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
        routes: [
          GoRoute(
            path: 'edit-basic',
            builder: (context, state) => const EditProfileBasicScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/invitations',
        builder: (context, state) => const InvitationsScreen(),
      ),
      GoRoute(
        path: '/job/:jobId',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId'] ?? '';
          return JobDetailsScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
