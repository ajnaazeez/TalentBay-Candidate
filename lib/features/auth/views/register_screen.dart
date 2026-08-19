import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';

import '../controllers/auth_controller.dart';
import '../../../../core/utils/firebase_error_handler.dart';
import '../../../../core/theme/app_colors.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _agreedToTerms = false;
  String _fullPhoneNumber = '';

  Future<void> _signUp() async {
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please agree to the Terms and Conditions to continue.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final phoneNumber = _fullPhoneNumber.isNotEmpty
        ? _fullPhoneNumber
        : _phoneController.text.trim();
    final hasPhoneNumber = phoneNumber.isNotEmpty;

    if (hasPhoneNumber) {
      // Send OTP first
      ref
          .read(authControllerProvider.notifier)
          .sendOtp(
            context: context,
            phoneNumber: phoneNumber.startsWith('+')
                ? phoneNumber
                : '+91$phoneNumber',
            onCodeSent: (verificationId) {
              context.push(
                '/otp-verification',
                extra: {
                  'verificationId': verificationId,
                  'phoneNumber': phoneNumber,
                  'verificationType': 'register',
                  'registrationData': {
                    'email': _emailController.text.trim(),
                    'password': _passwordController.text.trim(),
                    'firstName': _firstNameController.text.trim(),
                    'lastName': _lastNameController.text.trim(),
                    'phoneNumber': phoneNumber,
                  },
                },
              );
            },
            verificationCompleted: (credential) {
              ref.read(authControllerProvider.notifier).completeRegistration(
                context,
                email: _emailController.text.trim(),
                password: _passwordController.text.trim(),
                firstName: _firstNameController.text.trim(),
                lastName: _lastNameController.text.trim(),
                phoneNumber: phoneNumber,
                credential: credential,
              );
            },
          );
      return;
    }

    // If no phone number, proceed with normal sign up
    await ref
        .read(authControllerProvider.notifier)
        .signUpWithEmail(
          context,
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          phoneNumber: null,
          shouldNavigate: true,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    // H&M Aesthetic
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
              // Splash Header
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.30,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/images/splash.png',
                      fit: BoxFit.cover,
                      color: textColor,
                    ),
                  ],
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
                      'REGISTER',
                      style: TextStyle(
                        fontFamily: 'Futura',
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your new account',
                      style: TextStyle(
                        fontSize: 14,
                        color: subTextColor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Fields
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _firstNameController,
                            label: 'First Name',
                            textColor: textColor,
                            subTextColor: subTextColor,
                            borderColor: borderColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _lastNameController,
                            label: 'Last Name',
                            textColor: textColor,
                            subTextColor: subTextColor,
                            borderColor: borderColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      textColor: textColor,
                      subTextColor: subTextColor,
                      borderColor: borderColor,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 24),

                    _buildTextField(
                      controller: _passwordController,
                      label: 'Password',
                      textColor: textColor,
                      subTextColor: subTextColor,
                      borderColor: borderColor,
                      obscureText: !_isPasswordVisible,
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
                    const SizedBox(height: 24),

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
                        labelText: 'Mobile Number (Optional)',
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

                    const SizedBox(height: 32),

                    // T&C Checkbox
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: _agreedToTerms,
                            activeColor: textColor,
                            checkColor: backgroundColor,
                            side: BorderSide(
                              color: subTextColor ?? Colors.grey,
                              width: 1.5,
                            ),
                            onChanged: (value) {
                              setState(() {
                                _agreedToTerms = value ?? false;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _agreedToTerms = !_agreedToTerms;
                              });
                            },
                            child: RichText(
                              text: TextSpan(
                                text: 'I agree to the ',
                                style: TextStyle(
                                  color: subTextColor,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Terms & Conditions',
                                    style: TextStyle(
                                      color: AppColors.primaryBrand,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        context.push('/terms-and-conditions');
                                      },
                                  ),
                                  TextSpan(text: ' and '),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: TextStyle(
                                      color: AppColors.primaryBrand,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () async {
                                        final url = Uri.parse(
                                          'https://www.waqtixllp.com/privacy-and-policy',
                                        );
                                        if (await canLaunchUrl(url)) {
                                          await launchUrl(
                                            url,
                                            mode:
                                                LaunchMode.externalApplication,
                                          );
                                        }
                                      },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: authState.isLoading ? null : _signUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBrand,
                          foregroundColor: backgroundColor,
                          elevation: 0,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
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
                                'BECOME A MEMBER',
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
                          'Error: ${FirebaseErrorHandler.getMessage(authState.error!)}',
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),

                    Center(
                      child: GestureDetector(
                        onTap: () {
                          context.go('/login');
                        },
                        child: RichText(
                          text: TextSpan(
                            text: 'Already a member? ',
                            style: TextStyle(color: subTextColor, fontSize: 13),
                            children: [
                              TextSpan(
                                text: 'Sign in',
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
                    const SizedBox(height: 32),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required Color textColor,
    required Color? subTextColor,
    required Color borderColor,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? prefixText,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
      cursorColor: textColor,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: subTextColor),
        prefixText: prefixText,
        prefixStyle: TextStyle(color: textColor, fontWeight: FontWeight.w500),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.primaryBrand, width: 1.5),
        ),
        contentPadding: const EdgeInsets.only(bottom: 8),
        suffixIcon: suffixIcon,
        isDense: true,
      ),
    );
  }
}
