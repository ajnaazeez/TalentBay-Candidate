import 'package:flutter/material.dart';

import '../../models/profile_sections.dart';
import '../../../../core/theme/app_colors.dart';

class EditSkillsDialog extends StatefulWidget {
  final List<Skill> initialSkills;
  final ValueChanged<List<Skill>> onSave;

  const EditSkillsDialog({
    super.key,
    required this.initialSkills,
    required this.onSave,
  });

  @override
  State<EditSkillsDialog> createState() => _EditSkillsDialogState();
}

class _EditSkillsDialogState extends State<EditSkillsDialog> {
  late List<Skill> _skills;
  final TextEditingController _skillController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _skills = List.from(widget.initialSkills);
  }

  @override
  void dispose() {
    _skillController.dispose();
    super.dispose();
  }

  void _addSkill() {
    final text = _skillController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _skills.add(
          Skill(name: text, type: 'Primary', level: 'Intermediate'),
        ); // Default/Simple for now
      });
      _skillController.clear();
    }
  }

  void _removeSkill(Skill skill) {
    setState(() {
      _skills.remove(skill);
    });
  }

  void _save() {
    widget.onSave(_skills);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      title: Text(
        'EDIT SKILLS',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
          color: isDark ? AppColors.textMainDark : AppColors.textMainLight,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _skillController,
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textMainDark
                          : AppColors.textMainLight,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Add Skill',
                      hintText: 'e.g. Flutter',
                      labelStyle: TextStyle(
                        color: isDark
                            ? AppColors.textSubDark
                            : AppColors.textSubLight,
                      ),
                      hintStyle: TextStyle(
                        color: isDark
                            ? AppColors.disabledDark
                            : AppColors.disabledLight,
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _addSkill(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addSkill,
                  icon: Icon(Icons.add_circle, color: AppColors.primaryBrand),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _skills.map((skill) {
                return Chip(
                  label: Text(
                    skill.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: isDark
                          ? AppColors.textMainDark
                          : AppColors.textMainLight,
                    ),
                  ),
                  backgroundColor: isDark
                      ? AppColors.cardDark
                      : AppColors.cardLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                    side: BorderSide(
                      color: isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight,
                    ),
                  ),
                  deleteIcon: Icon(
                    Icons.close,
                    size: 14,
                    color: isDark
                        ? AppColors.textMainDark
                        : AppColors.textMainLight,
                  ),
                  onDeleted: () => _removeSkill(skill),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: isDark
                ? AppColors.textSubDark
                : AppColors.textSubLight,
          ),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBrand,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
          ),
          child: const Text(
            'SAVE',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
          ),
        ),
      ],
    );
  }
}
