import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../candidate/models/profile_sections.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/repositories/auth_repository.dart';
import '../controllers/candidate_controller.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:csc_picker_plus/csc_picker_plus.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart'; // Added for date masking
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/phone_utils.dart';
import '../../../../core/utils/firebase_error_handler.dart';

class EditProfileBasicScreen extends ConsumerStatefulWidget {
  const EditProfileBasicScreen({super.key});

  @override
  ConsumerState<EditProfileBasicScreen> createState() =>
      _EditProfileBasicScreenState();
}

class _EditProfileBasicScreenState
    extends ConsumerState<EditProfileBasicScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _countryController;
  late TextEditingController _nationalityController;
  late TextEditingController _designationController;
  late TextEditingController _linkedinController;

  // New fields
  late TextEditingController _dobController; // Controller for Date of Birth
  final _dobFormatter = MaskTextInputFormatter(
    mask: '##-##-####',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  String _completePhoneNumber = '';
  DateTime? _selectedDob;
  String? _selectedGender;
  Map<String, String> _languages = {}; // Language: Proficiency

  final List<String> _genderOptions = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  final List<String> _commonLanguages = [
    'English',
    'Hindi',
    'Spanish',
    'French',
    'German',
    'Chinese',
    'Japanese',
    'Arabic',
    'Portuguese',
    'Russian',
    'Italian',
    'Korean',
    'Tamil',
    'Telugu',
    'Bengali',
    'Marathi',
    'Gujarati',
    'Kannada',
    'Malayalam',
    'Punjabi',
  ];

  final List<String> _proficiencyLevels = [
    'Beginner',
    'Intermediate',
    'Advanced',
    'Native',
  ];

  @override
  void initState() {
    super.initState();
    final candidate = ref.read(candidateControllerProvider).value;
    _firstNameController = TextEditingController(
      text: candidate?.firstName ?? '',
    );
    _lastNameController = TextEditingController(
      text: candidate?.lastName ?? '',
    );
    _emailController = TextEditingController(text: candidate?.email ?? '');

    // Initialize Phone
    String initialPhone = candidate?.phoneNumber ?? '';
    // Basic Handling for +91 - Ideally use phone parsing logic
    if (initialPhone.startsWith('+91')) {
      _phoneController = TextEditingController(
        text: initialPhone.substring(3).trim(),
      );
    } else if (initialPhone.startsWith('91') && initialPhone.length > 10) {
      _phoneController = TextEditingController(
        text: initialPhone.substring(2).trim(),
      );
    } else if (initialPhone.startsWith('+')) {
      _phoneController = TextEditingController(text: initialPhone);
    } else {
      _phoneController = TextEditingController(text: initialPhone);
    }

    _cityController = TextEditingController(
      text: candidate?.currentLocation?.city ?? '',
    );
    _stateController = TextEditingController(
      text: candidate?.currentLocation?.state ?? '',
    );
    _countryController = TextEditingController(
      text: candidate?.currentLocation?.country ?? '',
    );
    _nationalityController = TextEditingController(
      text: candidate?.nationality ?? '',
    );
    _designationController = TextEditingController(
      text: candidate?.designation ?? '',
    );
    _linkedinController = TextEditingController(
      text: candidate?.linkedinProfile ?? '',
    );

    // Initialize new fields
    _selectedDob = candidate?.dob;
    _dobController = TextEditingController(
      text: _selectedDob != null
          ? DateFormat('dd-MM-yyyy').format(_selectedDob!)
          : '',
    );

    _selectedGender = candidate?.gender;
    _languages = Map<String, String>.from(candidate?.languages ?? {});
    _completePhoneNumber = candidate?.phoneNumber ?? '';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _nationalityController.dispose();
    _designationController.dispose();
    _linkedinController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  void _showAddLanguageDialog() {
    String? selectedLanguage;
    String selectedProficiency = 'Intermediate';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: Text(
            'Add Language',
            style: TextStyle(
              color: isDark ? AppColors.textMainDark : AppColors.textMainLight,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                dropdownColor: isDark
                    ? AppColors.cardDark
                    : AppColors.cardLight,
                style: TextStyle(
                  color: isDark
                      ? AppColors.textMainDark
                      : AppColors.textMainLight,
                ),
                decoration: InputDecoration(
                  labelText: 'Language',
                  labelStyle: TextStyle(
                    color: isDark
                        ? AppColors.textSubDark
                        : AppColors.textSubLight,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(
                      color: isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(
                      color: isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight,
                    ),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(
                      color: AppColors.primaryBrand,
                      width: 1,
                    ),
                  ),
                ),
                initialValue: selectedLanguage,
                items: _commonLanguages
                    .where((lang) => !_languages.containsKey(lang))
                    .map(
                      (lang) =>
                          DropdownMenuItem(value: lang, child: Text(lang)),
                    )
                    .toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedLanguage = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                dropdownColor: isDark
                    ? AppColors.cardDark
                    : AppColors.cardLight,
                style: TextStyle(
                  color: isDark
                      ? AppColors.textMainDark
                      : AppColors.textMainLight,
                ),
                decoration: InputDecoration(
                  labelText: 'Proficiency',
                  labelStyle: TextStyle(
                    color: isDark
                        ? AppColors.textSubDark
                        : AppColors.textSubLight,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(
                      color: isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(
                      color: isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight,
                    ),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(
                      color: AppColors.primaryBrand,
                      width: 1,
                    ),
                  ),
                ),
                initialValue: selectedProficiency,
                items: _proficiencyLevels
                    .map(
                      (level) =>
                          DropdownMenuItem(value: level, child: Text(level)),
                    )
                    .toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedProficiency = value!;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: isDark
                    ? AppColors.textSubDark
                    : AppColors.textSubLight,
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedLanguage != null) {
                  setState(() {
                    _languages[selectedLanguage!] = selectedProficiency;
                  });
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBrand,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
                elevation: 0,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  bool _isVerifyingOtp = false;

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final currentCandidate = ref.read(candidateControllerProvider).value;
      if (currentCandidate == null) return;

      final rawPhone = _phoneController.text.trim();
      if (rawPhone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone number is required.')),
        );
        return;
      }

      final normalizedInputPhone = PhoneUtils.normalizeE164(
        _completePhoneNumber.isNotEmpty ? _completePhoneNumber : rawPhone,
      );

      if (!PhoneUtils.isValidE164(normalizedInputPhone)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid phone number.')),
        );
        return;
      }

      final existingCandidatePhone = PhoneUtils.normalizeE164(currentCandidate.phoneNumber ?? '');

      if (normalizedInputPhone != existingCandidatePhone) {
        // Phone number changed or newly added: verify via OTP first
        await _handlePhoneUpdate(normalizedInputPhone);
      } else {
        // No change in phone number, update profile
        await _updateProfile(existingCandidatePhone);
      }
    }
  }

  Future<void> _handlePhoneUpdate(String formattedPhoneNumber) async {
    final rawPhone = _phoneController.text.trim();
    if (rawPhone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone number is required.')),
        );
      }
      return;
    }

    if (!PhoneUtils.isValidE164(formattedPhoneNumber)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid phone number.')),
        );
      }
      return;
    }

    final authController = ref.read(authControllerProvider.notifier);

    // Send OTP using callback
    await authController.sendUpdatePhoneOtpWithCallback(
      context: context,
      phoneNumber: formattedPhoneNumber,
      onCodeSent: (verificationId) {
        if (mounted) {
          _showOtpDialog(verificationId, formattedPhoneNumber);
        }
      },
      onAutoVerified: (credential) async {
        // Auto-resolution on Android SMS receiver
        if (_isVerifyingOtp) return;
        _isVerifyingOtp = true;
        try {
          await ref.read(authRepositoryProvider).updatePhoneNumber(credential);
          if (mounted) {
            _completePhoneNumber = formattedPhoneNumber;
            await _updateProfile(formattedPhoneNumber);
          }
        } catch (e) {
          if (mounted) {
            final msg = FirebaseErrorHandler.getMessage(e);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg), backgroundColor: Colors.red[700]),
            );
          }
        } finally {
          _isVerifyingOtp = false;
        }
      },
    );
  }

  void _showOtpDialog(String verificationId, String newPhoneNumber) {
    final otpController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text(
          'Verify Phone Number',
          style: TextStyle(
            color: isDark ? AppColors.textMainDark : AppColors.textMainLight,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter the OTP sent to $newPhoneNumber',
              style: TextStyle(
                color: isDark
                    ? AppColors.textMainDark
                    : AppColors.textMainLight,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: TextStyle(
                color: isDark
                    ? AppColors.textMainDark
                    : AppColors.textMainLight,
              ),
              decoration: InputDecoration(
                labelText: 'OTP',
                labelStyle: TextStyle(
                  color: isDark
                      ? AppColors.textSubDark
                      : AppColors.textSubLight,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                  ),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(
                    color: AppColors.primaryBrand,
                    width: 1,
                  ),
                ),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: isDark
                  ? AppColors.textSubDark
                  : AppColors.textSubLight,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_isVerifyingOtp) return;
              final smsCode = otpController.text.trim();
              if (smsCode.length == 6) {
                await _verifyOtp(verificationId, smsCode, newPhoneNumber);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBrand,
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyOtp(String verificationId, String smsCode, String newPhoneNumber) async {
    if (_isVerifyingOtp) return;
    _isVerifyingOtp = true;
    try {
      final success = await ref
          .read(authControllerProvider.notifier)
          .verifyUpdatePhoneOtp(context, verificationId, smsCode);

      if (success && mounted) {
        Navigator.pop(context); // Close OTP dialog
        _completePhoneNumber = newPhoneNumber;
        await _updateProfile(newPhoneNumber); // Proceed to update profile with verified canonical E.164 number
      }
    } finally {
      _isVerifyingOtp = false;
    }
  }

  Future<void> _updateProfile([String? verifiedPhoneNumber]) async {
    final currentCandidate = ref.read(candidateControllerProvider).value;
    if (currentCandidate == null) return;

    DateTime? parsedDob;
    if (_dobController.text.isNotEmpty) {
      try {
        final parts = _dobController.text.split('-');
        if (parts.length == 3) {
          parsedDob = DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      } catch (e) {
        debugPrint('Error parsing DOB: $e');
      }
    }

    final finalPhone = verifiedPhoneNumber ??
        (_completePhoneNumber.isNotEmpty
            ? PhoneUtils.normalizeE164(_completePhoneNumber)
            : PhoneUtils.normalizeE164(_phoneController.text.trim()));

    // Update the candidate object with new values from controllers
    final updatedCandidate = currentCandidate.copyWith(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      phoneNumber: finalPhone, // Canonical E.164 number
      currentLocation: Address(
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        country: _countryController.text.trim(),
      ),
      dob: parsedDob,
      gender: _selectedGender,
      nationality: _nationalityController.text.trim(),
      designation: _designationController.text.trim(),
      linkedinProfile: _linkedinController.text.trim(),
      languages: _languages,
      lastUpdated: DateTime.now(),
    );

    await ref
        .read(candidateControllerProvider.notifier)
        .updateProfile(updatedCandidate);

    if (mounted) {
      if (context.canPop()) {
        context.pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number verified successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.surfaceLight,
      body: SafeArea(
        child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection(
                      title: 'Personal Details',
                      icon: Icons.person_outline,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _firstNameController,
                                label: 'First Name',
                                icon: Icons.person,
                                validator: (v) =>
                                    v?.isEmpty == true ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: _lastNameController,
                                label: 'Last Name',
                                icon: Icons.person,
                                validator: (v) =>
                                    v?.isEmpty == true ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email',
                          icon: Icons.email_outlined,
                          readOnly: true,
                          enabled: false,
                        ),
                        const SizedBox(height: 16),
                        IntlPhoneField(
                          controller: _phoneController,
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            labelStyle: TextStyle(
                              color: isDark
                                  ? AppColors.textSubDark
                                  : AppColors.textSubLight,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: isDark
                                    ? AppColors.borderDark
                                    : AppColors.borderLight,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: isDark
                                    ? AppColors.borderDark
                                    : AppColors.borderLight,
                              ),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: AppColors.primaryBrand,
                                width: 1,
                              ),
                            ),
                            counterText: '',
                          ),
                          initialCountryCode:
                              'IN', // Default, logic handles prepopulation
                          style: TextStyle(
                            color: isDark
                                ? AppColors.textMainDark
                                : AppColors.textMainLight,
                          ),
                          dropdownTextStyle: TextStyle(
                            color: isDark
                                ? AppColors.textMainDark
                                : AppColors.textMainLight,
                          ),
                          dropdownIcon: Icon(
                            Icons.arrow_drop_down,
                            color: isDark
                                ? AppColors.textMainDark
                                : AppColors.textMainLight,
                          ),
                          validator: (phone) {
                            if (phone == null || phone.number.trim().isEmpty) {
                              return 'Mobile number is required';
                            }
                            if (!phone.isValidNumber()) {
                              return 'Please enter a valid mobile number';
                            }
                            return null;
                          },
                          onChanged: (phone) {
                            _completePhoneNumber = phone.completeNumber;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildDateField(),
                        const SizedBox(height: 16),
                        _buildGenderField(),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nationality',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.textSubDark
                                    : AppColors.textSubLight,
                              ),
                            ),
                            const SizedBox(height: 8),
                            CSCPickerPlus(
                              showStates: false,
                              showCities: false,
                              flagState: CountryFlag.SHOW_IN_DROP_DOWN_ONLY,
                              dropdownDecoration: BoxDecoration(
                                borderRadius: BorderRadius.zero,
                                color: isDark
                                    ? AppColors.cardDark
                                    : AppColors.cardLight,
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.borderDark
                                      : AppColors.borderLight,
                                ),
                              ),
                              disabledDropdownDecoration: BoxDecoration(
                                borderRadius: BorderRadius.zero,
                                color: isDark
                                    ? AppColors.backgroundDark
                                    : AppColors.surfaceLight,
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.disabledDark
                                      : AppColors.disabledLight,
                                ),
                              ),
                              selectedItemStyle: TextStyle(
                                color: isDark
                                    ? AppColors.textMainDark
                                    : AppColors.textMainLight,
                                fontSize: 14,
                              ),
                              dropdownHeadingStyle: TextStyle(
                                color: isDark
                                    ? AppColors.textMainDark
                                    : AppColors.textMainLight,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              dropdownItemStyle: TextStyle(
                                color: isDark
                                    ? AppColors.textMainDark
                                    : AppColors.textMainLight,
                                fontSize: 14,
                              ),
                              searchBarRadius: 0,
                              onCountryChanged: (value) {
                                setState(() {
                                  _nationalityController.text = value;
                                });
                              },
                              onStateChanged: (value) {},
                              onCityChanged: (value) {},
                              currentCountry:
                                  _nationalityController.text.isNotEmpty
                                  ? _nationalityController.text
                                  : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _designationController,
                          label: 'Designation',
                          icon: Icons.work_outline,
                          hintText: 'e.g. Software Developer',
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _linkedinController,
                          label: 'LinkedIn Profile',
                          icon: Icons
                              .link, // or Icons.business derived for LinkedIn
                          hintText: 'e.g. https://linkedin.com/in/yourprofile',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      title: 'Location',
                      icon: Icons.location_on_outlined,
                      children: [
                        _buildTextField(
                          controller: _cityController,
                          label: 'City',
                          icon: Icons.location_city,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _stateController,
                                label: 'State',
                                icon: Icons.map_outlined,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: _countryController,
                                label: 'Country',
                                icon: Icons.public,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      title: 'Languages',
                      icon: Icons.language,
                      children: [
                        if (_languages.isEmpty)
                          Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.translate,
                                  size: 48,
                                  color: isDark
                                      ? AppColors.disabledDark
                                      : AppColors.disabledLight,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No languages added yet',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? AppColors.textSubDark
                                        : AppColors.textSubLight,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _languages.entries.map((entry) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.cardDark
                                      : AppColors.cardLight,
                                  borderRadius: BorderRadius.zero,
                                  border: Border.all(
                                    color: isDark
                                        ? AppColors.borderDark
                                        : AppColors.borderLight,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      entry.key.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? AppColors.textMainDark
                                            : AppColors.textMainLight,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      entry.value,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? AppColors.textSubDark
                                            : AppColors.textSubLight,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _languages.remove(entry.key);
                                        });
                                      },
                                      child: Icon(
                                        Icons.close,
                                        size: 16,
                                        color: isDark
                                            ? AppColors.textMainDark
                                            : AppColors.textMainLight,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _showAddLanguageDialog,
                          icon: const Icon(Icons.add, size: 20),
                          label: const Text('Add Language'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark
                                ? AppColors.textMainDark
                                : AppColors.textMainLight,
                            side: BorderSide(
                              color: isDark
                                  ? AppColors.borderDark
                                  : AppColors.borderLight,
                              width: 1,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBrand,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'SAVE CHANGES',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isDark
                    ? AppColors.textMainDark
                    : AppColors.textMainLight,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: isDark
                      ? AppColors.textMainDark
                      : AppColors.textMainLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    bool readOnly = false,
    bool enabled = true,
    TextInputType? keyboardType,
    String? prefixText,
    String? hintText,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      style: TextStyle(
        color: isDark ? AppColors.textMainDark : AppColors.textMainLight,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        labelStyle: TextStyle(
          color: isDark ? AppColors.textSubDark : AppColors.textSubLight,
        ),
        hintStyle: TextStyle(
          color: isDark ? AppColors.disabledDark : AppColors.disabledLight,
        ),
        prefixIcon: Icon(
          icon,
          color: isDark ? AppColors.textSubDark : AppColors.textSubLight,
          size: 20,
        ),
        prefixText: prefixText,
        prefixStyle: TextStyle(
          color: isDark ? AppColors.textMainDark : AppColors.textMainLight,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.primaryBrand, width: 1),
        ),
        filled: !enabled,
        fillColor: enabled
            ? null
            : (isDark ? AppColors.backgroundDark : AppColors.surfaceLight),
      ),
      validator: validator,
      readOnly: readOnly,
      enabled: enabled,
      keyboardType: keyboardType,
    );
  }

  Widget _buildDateField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: _dobController,
      inputFormatters: [_dobFormatter],
      keyboardType: TextInputType.number,
      style: TextStyle(
        color: isDark ? AppColors.textMainDark : AppColors.textMainLight,
      ),
      decoration: InputDecoration(
        labelText: 'Date of Birth',
        hintText: 'DD-MM-YYYY',
        labelStyle: TextStyle(
          color: isDark ? AppColors.textSubDark : AppColors.textSubLight,
        ),
        hintStyle: TextStyle(
          color: isDark ? AppColors.disabledDark : AppColors.disabledLight,
        ),
        prefixIcon: Icon(
          Icons.calendar_today,
          color: isDark ? AppColors.textSubDark : AppColors.textSubLight,
          size: 20,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.primaryBrand, width: 1),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return null; // or 'Required' if mandatory
        }
        if (value.length != 10) {
          return 'Enter valid date (DD-MM-YYYY)';
        }
        try {
          final parts = value.split('-');
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);

          if (day < 1 || day > 31) return 'Day must be 1-31';
          if (month < 1 || month > 12) return 'Month must be 1-12';
          if (year < 1950) return 'Year must be 1950 or later';

          final date = DateTime(year, month, day);
          // DateTime corrects overflow (e.g. Feb 30 -> Mar 2), so we must verify
          if (date.year != year || date.month != month || date.day != day) {
            return 'Invalid Date';
          }
          if (date.isAfter(DateTime.now())) {
            return 'Date cannot be in future';
          }
        } catch (e) {
          return 'Invalid Date format';
        }
        return null;
      },
    );
  }

  Widget _buildGenderField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DropdownButtonFormField<String>(
      initialValue: _selectedGender,
      dropdownColor: isDark ? AppColors.cardDark : AppColors.cardLight,
      style: TextStyle(
        color: isDark ? AppColors.textMainDark : AppColors.textMainLight,
      ),
      decoration: InputDecoration(
        labelText: 'Gender',
        labelStyle: TextStyle(
          color: isDark ? AppColors.textSubDark : AppColors.textSubLight,
        ),
        prefixIcon: Icon(
          Icons.wc,
          color: isDark ? AppColors.textSubDark : AppColors.textSubLight,
          size: 20,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.primaryBrand, width: 1),
        ),
      ),
      items: _genderOptions
          .map((gender) => DropdownMenuItem(value: gender, child: Text(gender)))
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedGender = value;
        });
      },
    );
  }
}
