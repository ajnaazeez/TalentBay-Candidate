import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(() {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const String _themeKey = 'theme_mode';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  ThemeMode build() {
    _loadTheme();
    return ThemeMode.system;
  }

  Future<void> _loadTheme() async {
    try {
      // First try to load from local cache
      final prefs = await SharedPreferences.getInstance();
      final cachedTheme = prefs.getString(_themeKey);

      if (cachedTheme != null) {
        state = _themeModeFromString(cachedTheme);
      }

      // Then load from Firebase if user is authenticated
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _firestore
            .collection('candidates')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null && data.containsKey('themeMode')) {
            final themeMode = _themeModeFromString(data['themeMode']);
            state = themeMode;
            // Update local cache
            await prefs.setString(_themeKey, data['themeMode']);
          }
        }
      }
    } catch (e) {
      // If loading fails, keep the default theme
      debugPrint('Error loading theme: $e');
    }
  }

  Future<void> _saveTheme(ThemeMode mode) async {
    try {
      final themeString = _themeStringFromMode(mode);

      // Save to local cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, themeString);

      // Save to Firebase if user is authenticated
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('candidates').doc(user.uid).update({
          'themeMode': themeString,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error saving theme: $e');
    }
  }

  void setLight() {
    state = ThemeMode.light;
    _saveTheme(ThemeMode.light);
  }

  void setDark() {
    state = ThemeMode.dark;
    _saveTheme(ThemeMode.dark);
  }

  void setSystem() {
    state = ThemeMode.system;
    _saveTheme(ThemeMode.system);
  }

  void toggle() {
    final newMode = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    state = newMode;
    _saveTheme(newMode);
  }

  ThemeMode _themeModeFromString(String theme) {
    switch (theme) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _themeStringFromMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      default:
        return 'system';
    }
  }
}
