import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/theme/app_colors.dart';

class ResumeSection extends StatefulWidget {
  final Function(PlatformFile)? onUpload;
  final String? resumeUrl;

  const ResumeSection({super.key, this.onUpload, this.resumeUrl});

  @override
  State<ResumeSection> createState() => _ResumeSectionState();
}

class _ResumeSectionState extends State<ResumeSection> {
  String? _fileName;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.resumeUrl != null) {
      _fileName = 'Attached Resume';
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );

    if (result != null) {
      setState(() {
        _fileName = result.files.single.name;
      });
      widget.onUpload?.call(result.files.single);
    }
  }

  Future<void> _viewResume() async {
    if (widget.resumeUrl == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final Uri uri = Uri.parse(widget.resumeUrl!);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        // Try to get extension from url or content-type, default to pdf for now if unknown
        // A better approach would be to parse the content-disposition header if available
        String extension = 'pdf';
        if (widget.resumeUrl!.toLowerCase().contains('.doc')) {
          extension = 'doc';
        } else if (widget.resumeUrl!.toLowerCase().contains('.docx')) {
          extension = 'docx';
        }

        final filePath = '${directory.path}/resume.$extension';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        final result = await OpenFilex.open(filePath);

        if (result.type != ResultType.done) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not open file: ${result.message}')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to download resume')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
          ),
          child: Row(
            children: [
              _isLoading
                  ? const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.description,
                      color: isDark
                          ? AppColors.primaryDark
                          : AppColors.primaryLight,
                      size: 32,
                    ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: (widget.resumeUrl != null && !_isLoading)
                      ? _viewResume
                      : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fileName ?? 'No resume uploaded',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.textMainDark
                              : AppColors.textMainLight,
                          decoration: widget.resumeUrl != null
                              ? TextDecoration.underline
                              : null,
                        ),
                      ),
                      if (_fileName == null)
                        Text(
                          'Upload your CV/Resume to apply for jobs',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSubDark
                                : AppColors.textSubLight,
                          ),
                        ),
                      if (widget.resumeUrl != null)
                        Text(
                          'Tap to view',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.primaryDark
                                : AppColors.primaryLight,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: _pickFile,
                style: TextButton.styleFrom(
                  foregroundColor: isDark
                      ? AppColors.primaryDark
                      : AppColors.primaryLight,
                ),
                child: const Text('Upload'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
