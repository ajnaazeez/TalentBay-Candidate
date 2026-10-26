import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/assessment_model.dart';

/// Service to generate AI-powered skill assessment questions via Cloud Functions
class AssessmentService {
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Generate assessment questions for a specific skill using AI via Cloud Function
  /// Returns a list of [AssessmentQuestion]
  static Future<List<AssessmentQuestion>> generateQuestionsWithAI(
    String skill, {
    int count = 15,
    String difficulty = 'Medium',
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'generateAssessmentQuestions',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 90)),
      );
      final response = await callable.call({
        'skill': skill,
        'difficulty': difficulty,
        'count': count,
      });

      final rawData = response.data;
      if (rawData == null || rawData is! Map) {
        throw Exception('AI failed to generate valid assessment questions.');
      }
      final data = Map<String, dynamic>.from(rawData);
      final rawQuestions = data['questions'] as List<dynamic>? ?? [];

      final questions = <AssessmentQuestion>[];
      for (var item in rawQuestions) {
        if (item is Map) {
          questions.add(
            AssessmentQuestion(
              id: item['id']?.toString() ?? '',
              question: item['question']?.toString() ?? '',
              options: List<String>.from(
                (item['options'] as List<dynamic>? ?? []).map((o) => o.toString()),
              ),
              correctAnswerIndex: (item['correctAnswerIndex'] is num)
                  ? (item['correctAnswerIndex'] as num).toInt()
                  : 0,
              skill: item['skill']?.toString() ?? skill,
              difficulty: item['difficulty']?.toString() ?? difficulty,
            ),
          );
        }
      }

      if (questions.isEmpty) {
        throw Exception('AI failed to generate any valid questions.');
      }

      return questions.take(count).toList();
    } on FirebaseFunctionsException catch (e) {
      debugPrint('AI Assessment Generation Cloud Function error [${e.code}]: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('AI Assessment Generation failed: $e');
      rethrow;
    }
  }

  /// Suggest related skills based on current skills using AI via Cloud Function
  static Future<List<String>> getRelatedSkills(
    List<String> currentSkills,
  ) async {
    if (currentSkills.isEmpty) return [];

    try {
      final callable = _functions.httpsCallable('getRelatedSkills');
      final response = await callable.call({
        'currentSkills': currentSkills,
      });

      final rawData = response.data;
      if (rawData == null || rawData is! Map) {
        return [];
      }
      final data = Map<String, dynamic>.from(rawData);
      final rawRelated = data['relatedSkills'] as List<dynamic>? ?? [];

      final related = rawRelated
          .map((s) => s.toString().trim())
          .where((s) => s.isNotEmpty && !currentSkills.contains(s))
          .toList();

      return related.take(5).toList();
    } catch (e) {
      debugPrint('Related/Recommended skills generation failed: $e');
      return []; // Return empty list on failure gracefully
    }
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

  /// Generate career readiness & skill improvement guidance via Cloud Functions
  static Future<Map<String, dynamic>> getCareerReadinessGuidance({
    required Map<String, double> skillScores,
    String? targetJobTitle,
    List<String>? targetJobSkills,
  }) async {
    try {
      final callable = _functions.httpsCallable('getCareerReadinessGuidance');
      final response = await callable.call({
        'skillScores': skillScores,
        if (targetJobTitle != null && targetJobTitle.isNotEmpty)
          'targetJobTitle': targetJobTitle,
        if (targetJobSkills != null && targetJobSkills.isNotEmpty)
          'targetJobSkills': targetJobSkills,
      });

      final data = response.data;
      if (data == null || data is! Map) {
        throw Exception('Invalid or empty response from AI guidance service.');
      }

      return Map<String, dynamic>.from(data);
    } catch (e) {
      debugPrint('Career Readiness Guidance generation failed: $e');
      rethrow;
    }
  }
}


