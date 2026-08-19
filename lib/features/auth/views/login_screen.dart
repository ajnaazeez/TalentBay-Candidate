import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/auth_controller.dart';
import '../../../../core/utils/firebase_error_handler.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isPhoneLogin = false;
  String _fullPhoneNumber = '';

  void _login() {
    if (_isPhoneLogin) {
      // Trigger OTP flow
      final phoneNumber = _phoneController.text.trim();
      final formattedPhoneNumber = _fullPhoneNumber.isNotEmpty
          ? _fullPhoneNumber
          : (phoneNumber.startsWith('+') ? phoneNumber : '+91$phoneNumber');

      ref
          .read(authControllerProvider.notifier)
          .sendOtp(
            context: context,
            phoneNumber: formattedPhoneNumber,
            onCodeSent: (verificationId) {
              context.push(
                '/otp-verification',
                extra: {
                  'verificationId': verificationId,
                  'phoneNumber': formattedPhoneNumber,
                },
              );
            },
          );
    } else {
      ref
          .read(authControllerProvider.notifier)
          .signInWithEmail(
            context,
            _emailController.text.trim(),
            _passwordController.text.trim(),
          );
    }
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final backgroundColor = isDark ? Colors.grey[900] : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black;

        return AlertDialog(
          backgroundColor: backgroundColor,
          title: Text(
            'Forgot Password',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter your email address to receive a password reset link.',
                style: TextStyle(color: textColor.withOpacity(0.7)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: textColor.withOpacity(0.6)),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: textColor.withOpacity(0.3)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: textColor),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: textColor.withOpacity(0.6)),
              ),
            ),
            TextButton(
              onPressed: () {
                final email = emailController.text.trim();
                if (email.isNotEmpty) {
                  ref
                      .read(authControllerProvider.notifier)
                      .sendPasswordResetEmail(context, email);
                  Navigator.pop(context);
                }
              },
              child: Text(
                'Send',
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    // H&M Aesthetic: Clean White/Black
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Splash Image Header
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.35,
                width: double.infinity,
                child: Image.asset(
                  'assets/images/splash.png',
                  fit: BoxFit.cover,
                  color: textColor,
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 32.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SIGN IN',
                      style: GoogleFonts.jost(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Welcome back to TalentBay',
                      style: TextStyle(
                        fontSize: 14,
                        color: subTextColor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 48),

                    if (!_isPhoneLogin) ...[
                      // Email Field
                      TextField(
                        controller: _emailController,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                        cursorColor: textColor,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: TextStyle(color: subTextColor),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.primaryBrand,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.only(bottom: 8),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 32),
                      // Password Field
                      TextField(
                        controller: _passwordController,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                        cursorColor: textColor,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(color: subTextColor),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.primaryBrand,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.only(bottom: 8),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: subTextColor,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                        ),
                        obscureText: !_isPasswordVisible,
                      ),
                    ] else ...[
                      IntlPhoneField(
                        controller: _phoneController,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                        cursorColor: textColor,
                        initialCountryCode: 'IN',
                        dropdownTextStyle: TextStyle(color: textColor),
                        dropdownIcon: Icon(
                          Icons.arrow_drop_down,
                          color: subTextColor,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Mobile Number',
                          labelStyle: TextStyle(color: subTextColor),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.primaryBrand,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.only(bottom: 8),
                          counterText: '',
                        ),
                        languageCode: "en",
                        onChanged: (phone) {
                          _fullPhoneNumber = phone.completeNumber;
                        },
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isPhoneLogin = !_isPhoneLogin;
                            });
                          },
                          child: Text(
                            _isPhoneLogin ? 'Use Password' : 'Use OTP',
                            style: TextStyle(
                              color: AppColors.primaryBrand,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            _showForgotPasswordDialog(context);
                          },
                          child: Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: subTextColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // Sign In Button (Sharp rectangular, black)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: authState.isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              AppColors.primaryBrand, // Pantone 320C
                          foregroundColor: backgroundColor, // White text
                          elevation: 0,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ), // Sharp edges
                        ),
                        child: authState.isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: backgroundColor,
                                ),
                              )
                            : const Text(
                                'SIGN IN',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    if (authState.hasError && !authState.isLoading)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          '${FirebaseErrorHandler.getMessage(authState.error!)}',
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),

                    // Social Login Placeholder
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          context.push('/register');
                        },
                        child: RichText(
                          text: TextSpan(
                            text: 'First time here? ',
                            style: TextStyle(color: subTextColor, fontSize: 13),
                            children: [
                              TextSpan(
                                text: 'Create account',
                                style: TextStyle(
                                  color: AppColors.primaryBrand,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
      ),
    );
  }
}
