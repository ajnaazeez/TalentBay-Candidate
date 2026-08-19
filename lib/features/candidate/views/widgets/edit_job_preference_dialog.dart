import 'package:flutter/material.dart';
import '../../models/profile_sections.dart';
import '../../../../core/theme/app_colors.dart';

class EditJobPreferenceDialog extends StatefulWidget {
  final JobPreference? initialPreference;
  final ValueChanged<JobPreference> onSave;

  const EditJobPreferenceDialog({
    super.key,
    this.initialPreference,
    required this.onSave,
  });

  @override
  State<EditJobPreferenceDialog> createState() =>
      _EditJobPreferenceDialogState();
}

class _EditJobPreferenceDialogState extends State<EditJobPreferenceDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _roleController;
  late TextEditingController _industryController;
  late TextEditingController _minSalaryController;
  late TextEditingController _maxSalaryController;
  late TextEditingController _locationController;
  String _workMode = 'Remote';
  String _employmentType = 'Full-Time';
  List<String> _preferredLocations = [];

  final List<String> _workModes = ['Remote', 'Hybrid', 'On-Site'];
  final List<String> _employmentTypes = [
    'Full-Time',
    'Part-Time',
    'Contract',
    'Freelance',
    'Internship',
  ];

  @override
  void initState() {
    super.initState();
    _roleController = TextEditingController(
      text: widget.initialPreference?.role ?? '',
    );
    _industryController = TextEditingController(
      text: widget.initialPreference?.preferredIndustry ?? '',
    );
    _minSalaryController = TextEditingController(
      text: widget.initialPreference?.salaryMin.toString() ?? '',
    );
    _maxSalaryController = TextEditingController(
      text: widget.initialPreference?.salaryMax.toString() ?? '',
    );
    _locationController = TextEditingController();

    if (widget.initialPreference?.workMode != null) {
      if (_workModes.contains(widget.initialPreference!.workMode)) {
        _workMode = widget.initialPreference!.workMode;
      }
    }
    if (widget.initialPreference?.employmentType != null) {
      if (_employmentTypes.contains(widget.initialPreference!.employmentType)) {
        _employmentType = widget.initialPreference!.employmentType;
      }
    }
    if (widget.initialPreference?.preferredLocations != null) {
      _preferredLocations = List.from(
        widget.initialPreference!.preferredLocations,
      );
    }
  }

  @override
  void dispose() {
    _roleController.dispose();
    _industryController.dispose();
    _minSalaryController.dispose();
    _maxSalaryController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _addLocation() {
    final location = _locationController.text.trim();
    if (location.isNotEmpty) {
      if (_preferredLocations.length >= 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You can add up to 5 locations only.')),
        );
        return;
      }
      if (!_preferredLocations.contains(location)) {
        setState(() {
          _preferredLocations.add(location);
          _locationController.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location already added.')),
        );
      }
    }
  }

  void _removeLocation(String location) {
    setState(() {
      _preferredLocations.remove(location);
    });
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      if (_preferredLocations.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least one preferred location.'),
          ),
        );
        return;
      }
      final preference = JobPreference(
        role: _roleController.text.trim(),
        preferredIndustry: _industryController.text.trim(),
        workMode: _workMode,
        employmentType: _employmentType,
        preferredLocations: _preferredLocations,
        salaryMin: double.tryParse(_minSalaryController.text.trim()) ?? 0,
        salaryMax: double.tryParse(_maxSalaryController.text.trim()) ?? 0,
        salaryCurrency: widget.initialPreference?.salaryCurrency ?? 'USD',
        noticePeriod: widget.initialPreference?.noticePeriod ?? '',
      );
      widget.onSave(preference);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
      child: Container(
        width: MediaQuery.of(context).size.shortestSide >= 600
            ? 500
            : MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'EDIT JOB PREFERENCES',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _roleController,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Preferred Role',
                        hintText: 'e.g. Flutter Developer',
                        labelStyle: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(0),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.grey[700]!
                                : Colors.grey[300]!,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(0),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.grey[700]!
                                : Colors.grey[300]!,
                          ),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(
                            color: AppColors.primaryBrand,
                            width: 1.5,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          v?.isNotEmpty == true ? null : 'Required',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _industryController,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Preferred Industry',
                        hintText: 'e.g. IT - Software Services',
                        labelStyle: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(0),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.grey[700]!
                                : Colors.grey[300]!,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(0),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.grey[700]!
                                : Colors.grey[300]!,
                          ),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(
                            color: AppColors.primaryBrand,
                            width: 1.5,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          v?.isNotEmpty == true ? null : 'Required',
                    ),
                    const SizedBox(height: 16),
                    // Location Section
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _locationController,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Add Location',
                              hintText: 'e.g. New York',
                              labelStyle: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(0),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.grey[700]!
                                      : Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(0),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.grey[700]!
                                      : Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.zero,
                                borderSide: BorderSide(
                                  color: isDark ? Colors.white : Colors.black,
                                  width: 1,
                                ),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  Icons.add,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                                onPressed: _addLocation,
                              ),
                            ),
                            onFieldSubmitted: (_) => _addLocation(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_preferredLocations.isNotEmpty)
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: _preferredLocations
                            .map(
                              (location) => Chip(
                                label: Text(
                                  location,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                backgroundColor: AppColors.primaryBrand
                                    .withOpacity(0.1),
                                deleteIcon: const Icon(
                                  Icons.close,
                                  size: 18,
                                  color: Colors.black54,
                                ),
                                onDeleted: () => _removeLocation(location),
                                shape: const RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.zero, // Sharp corners
                                  side: BorderSide(
                                    color: AppColors.primaryBrand,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    if (_preferredLocations.length < 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          '${5 - _preferredLocations.length} locations remaining',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _workMode,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      dropdownColor: isDark ? Colors.grey[900] : Colors.white,
                      decoration: InputDecoration(
                        labelText: 'Work Mode',
                        labelStyle: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(0),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.grey[700]!
                                : Colors.grey[300]!,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(0),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.grey[700]!
                                : Colors.grey[300]!,
                          ),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(
                            color: AppColors.primaryBrand,
                            width: 1.5,
                          ),
                        ),
                      ),
                      items: _workModes
                          .map(
                            (m) => DropdownMenuItem(value: m, child: Text(m)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _workMode = v);
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _employmentType,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      dropdownColor: isDark ? Colors.grey[900] : Colors.white,
                      decoration: InputDecoration(
                        labelText: 'Employment Type',
                        labelStyle: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(0),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.grey[700]!
                                : Colors.grey[300]!,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(0),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.grey[700]!
                                : Colors.grey[300]!,
                          ),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(
                            color: AppColors.primaryBrand,
                            width: 1.5,
                          ),
                        ),
                      ),
                      items: _employmentTypes
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _employmentType = v);
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _minSalaryController,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Min Salary',
                              labelStyle: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(0),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.grey[700]!
                                      : Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(0),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.grey[700]!
                                      : Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.zero,
                                borderSide: BorderSide(
                                  color: isDark ? Colors.white : Colors.black,
                                  width: 1,
                                ),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _maxSalaryController,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Max Salary',
                              labelStyle: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(0),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.grey[700]!
                                      : Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(0),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.grey[700]!
                                      : Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.zero,
                                borderSide: BorderSide(
                                  color: isDark ? Colors.white : Colors.black,
                                  width: 1,
                                ),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
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
                        'SAVE PREFERENCES',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
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
    );
  }
}
