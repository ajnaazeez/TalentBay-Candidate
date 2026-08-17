import 'package:flutter/material.dart';

class AppColors {
  // LinkedIn-Inspired Royal Blue Theme
  static const Color primaryBrand = Color(0xFF009CA6); // Pantone 320C

  // Light Mode - Primary LinkedIn Blue
  static const Color primary = primaryLight; // Alias for primaryLight
  static const Color primaryLight = Color(0xFF0A66C2); // LinkedIn Blue
  static const Color secondaryLight = Color(0xFF004182); // Darker Navy
  static const Color accentLight = Color(0xFF378FE9); // Lighter Azure
  static const Color backgroundLight = Color(0xFFFFFFFF); // Pure White
  static const Color surfaceLight = Color(0xFFF3F6F8); // Soft Blue-Grey
  static const Color textMainLight = Color(0xFF000000); // Pure Black
  static const Color textSubLight = Color(0xFF666666); // Medium Grey
  static const Color borderLight = Color(0xFFDCE6F1); // Light Blue-Grey
  static const Color disabledLight = Color(0xFFB0BEC5); // Muted Blue-Grey
  static const Color successLight = Color(0xFF057642); // LinkedIn Green

  // Additional LinkedIn Colors for Light Mode
  static const Color orangeAccent = Color(0xFFF5AD51); // LinkedIn Orange
  static const Color purpleAccent = Color(0xFF7D55C7); // LinkedIn Purple
  static const Color cardLight = Color(0xFFFFFFFF); // Card background
  static const Color hoverLight = Color(0xFFE8F4FC); // Hover state

  // Dark Mode - Professional Dark Theme
  static const Color primaryDark = Color(0xFF378FE9); // Brighter Blue for dark
  static const Color secondaryDark = Color(0xFF0A66C2); // LinkedIn Blue
  static const Color accentDark = Color(0xFF70B5F9); // Light Blue
  static const Color backgroundDark = Color(0xFF000000); // True Black
  static const Color surfaceDark = Color(0xFF1B1F23); // Dark Blue-Grey
  static const Color textMainDark = Color(0xFFFFFFFF); // Pure White
  static const Color textSubDark = Color(0xFFB0B7BC); // Light Grey
  static const Color borderDark = Color(0xFF2D3339); // Dark Border
  static const Color disabledDark = Color(0xFF3A4149); // Disabled Dark
  static const Color successDark = Color(0xFF57B889); // Light Green

  // Additional LinkedIn Colors for Dark Mode
  static const Color orangeAccentDark = Color(0xFFFFB84D); // Bright Orange
  static const Color purpleAccentDark = Color(0xFF9B7DD4); // Light Purple
  static const Color cardDark = Color(0xFF1B1F23); // Card background
  static const Color hoverDark = Color(0xFF2D3339); // Hover state

  // Seasonal Colors - Spring
  static const Color springPrimary = Color(0xFFFF69B4); // Hot pink
  static const Color springSecondary = Color(0xFF90EE90); // Light green
  static const Color springAccent = Color(0xFFFFC0CB); // Pink

  // Seasonal Colors - Summer
  static const Color summerPrimary = Color(0xFFFFA500); // Orange
  static const Color summerSecondary = Color(0xFF87CEEB); // Sky blue
  static const Color summerAccent = Color(0xFFFFD700); // Gold

  // Seasonal Colors - Autumn
  static const Color autumnPrimary = Color(0xFFD2691E); // Chocolate
  static const Color autumnSecondary = Color(0xFFFF8C00); // Dark orange
  static const Color autumnAccent = Color(0xFF8B4513); // Saddle brown

  // Seasonal Colors - Winter
  static const Color winterPrimary = Color(0xFF4682B4); // Steel blue
  static const Color winterSecondary = Color(0xFFB0E0E6); // Powder blue
  static const Color winterAccent = Color(0xFFADD8E6); // Light blue

  // Status Colors (Universal)
  static const Color error = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFF57C00);
  static const Color info = Color(0xFF1976D2);

  // Application Status Colors
  static const Color statusApplied = Color(0xFF0A66C2); // Blue
  static const Color statusReject = Color(0xFFD32F2F); // Red
  static const Color statusShortlist = Color(
    0xFFFFB84D,
  ); // Yellow (using orange-yellow for better visibility on white)
  static const Color statusAccept = Color(0xFF057642); // Green

  // AI Score Colors (for candidate matching)
  static const Color scoreExcellent = Color(0xFF057642); // 80-100
  static const Color scoreGood = Color(0xFF0A66C2); // 60-79
  static const Color scoreFair = Color(0xFFF5AD51); // 40-59
  static const Color scorePoor = Color(0xFFD32F2F); // 0-39
}
