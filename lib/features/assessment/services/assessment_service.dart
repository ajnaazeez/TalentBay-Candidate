import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/assessment_model.dart';
import '../../../core/constants/app_constants.dart';

/// Service to generate AI-powered skill assessment questions
class AssessmentService {
  // TODO: Move this to a secure storage or environment variable
  static const String _apiKey = AppConstants.googleApiKey;

  static GenerativeModel? _model;

  static void _initModel() {
    if (_model == null) {
      if (_apiKey.isEmpty || _apiKey == 'YOUR_API_KEY') {
        throw Exception(
          'API Key is not configured. Please set a valid Gemini API Key.',
        );
      }
      _model = GenerativeModel(
        model: AppConstants.geminiModel,
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          responseMimeType: 'application/json',
        ),
      );
    }
  }

  /// Generate assessment questions for a specific skill using AI
  /// Returns a list of [AssessmentQuestion]
  static Future<List<AssessmentQuestion>> generateQuestionsWithAI(
    String skill, {
    int count = 15,
    String difficulty = 'Medium',
  }) async {
    try {
      _initModel();

      final prompt =
          '''
        Generate $count multiple-choice questions for a "$skill" assessment.
        Difficulty level: $difficulty.
        
        The output must be a valid JSON array of objects.
        Each object must have the following structure:
        {
          "question": "The question text",
          "options": ["Option A", "Option B", "Option C", "Option D"],
          "correctAnswerIndex": 0 (integer from 0 to 3 indicating the correct option)
        }
        
        Ensure the questions are relevant to $skill and match the $difficulty difficulty.
        Do not include any markdown formatting like ```json ... ```, just the raw JSON array.
      ''';

      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);

      if (response.text == null) {
        throw Exception('Empty response from AI');
      }

      final cleanJson = _cleanJsonString(response.text!);
      final List<dynamic> jsonList = jsonDecode(cleanJson);

      final questions = <AssessmentQuestion>[];

      for (var i = 0; i < jsonList.length; i++) {
        final item = jsonList[i];
        questions.add(
          AssessmentQuestion(
            id: '${skill.toLowerCase()}_ai_${DateTime.now().millisecondsSinceEpoch}_$i',
            question: item['question'],
            options: List<String>.from(item['options']),
            correctAnswerIndex: item['correctAnswerIndex'],
            skill: skill,
            difficulty: difficulty,
          ),
        );
      }

      // Check if we got enough questions
      if (questions.length < count) {
        // In a real scenario, we might request more, but for now we'll just throw if it's too few
        // or return what we have if it's "enough" (e.g. > 80%)
        if (questions.isEmpty) {
          throw Exception('AI failed to generate any valid questions.');
        }
      }

      return questions.take(count).toList();
    } catch (e) {
      print('AI Generation failed: $e');
      rethrow; // Propagate error to UI
    }
  }

  /// Suggest related skills based on current skills using AI
  static Future<List<String>> getRelatedSkills(
    List<String> currentSkills,
  ) async {
    if (currentSkills.isEmpty) return [];

    try {
      _initModel();

      final prompt =
          '''
        Given the following list of technical skills: ${currentSkills.join(', ')}.
        Suggest 5 related technical skills that this candidate would benefit from learning or might already know.
        
        The output must be a valid JSON array of strings.
        Example: ["Skill A", "Skill B", "Skill C"]
        
        Do not include any markdown formatting.
      ''';

      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);

      if (response.text == null) {
        return [];
      }

      final cleanJson = _cleanJsonString(response.text!);
      final List<dynamic> jsonList = jsonDecode(cleanJson);

      // Filter out skills the user already has
      final related = jsonList
          .cast<String>()
          .where((s) => !currentSkills.contains(s))
          .toList();

      return related.take(5).toList();
    } catch (e) {
      print('Related/Recommended skills generation failed: $e');
      return []; // Return empty list on failure gracefully
    }
  }

  /// Helper to clean JSON string if it contains markdown
  static String _cleanJsonString(String jsonStr) {
    var clean = jsonStr.trim();
    if (clean.startsWith('```json')) {
      clean = clean.substring(7);
    }
    if (clean.startsWith('```')) {
      clean = clean.substring(3);
    }
    if (clean.endsWith('```')) {
      clean = clean.substring(0, clean.length - 3);
    }
    return clean.trim();
  }

  /// Calculate proficiency level based on score
  static String calculateProficiencyLevel(int score, int totalQuestions) {
    if (totalQuestions == 0) return 'Beginner';
    final percentage = (score / totalQuestions) * 100;

    if (percentage >= 90) return 'Expert';
    if (percentage >= 75) return 'Advanced';
    if (percentage >= 60) return 'Intermediate';
    return 'Beginner';
  }
}
