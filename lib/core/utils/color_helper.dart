import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ColorHelper {
  /// Returns a color based on the percentage/score (0-100).
  ///
  /// Logic:
  /// - 0-39%: Red (Reject/Poor)
  /// - 40-69%: Yellow (Shortlist/Fair)
  /// - 70-100%: Green (Accept/Good)
  static Color getColorForScore(double percentage) {
    if (percentage < 40) {
      return AppColors.statusReject;
    } else if (percentage < 70) {
      return AppColors.statusShortlist;
    } else {
      return AppColors.statusAccept;
    }
  }

  /// Returns a color for a specific application status string.
  /// Case-insensitive.
  static Color getColorForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'applied':
        return AppColors.statusApplied;
      case 'rejected':
      case 'reject':
        return AppColors.statusReject;
      case 'shortlisted':
      case 'shortlist':
        return AppColors.statusShortlist;
      case 'accepted':
      case 'accept':
      case 'hired':
        return AppColors.statusAccept;
      default:
        return AppColors.textSubLight; // Default grey for unknown
    }
  }
}
