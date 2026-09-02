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
      final callable = _functions.httpsCallable('generateAssessmentQuestions');
      final response = await callable.call<Map<String, dynamic>>({
        'skill': skill,
        'difficulty': difficulty,
        'count': count,
      });

      final data = response.data;
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
      print('AI Assessment Generation Cloud Function error: ${e.message}');
      throw Exception(e.message ?? 'Failed to load assessment');
    } catch (e) {
      print('AI Assessment Generation failed: $e');
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
      final response = await callable.call<Map<String, dynamic>>({
        'currentSkills': currentSkills,
      });

      final data = response.data;
      final rawRelated = data['relatedSkills'] as List<dynamic>? ?? [];

      final related = rawRelated
          .map((s) => s.toString().trim())
          .where((s) => s.isNotEmpty && !currentSkills.contains(s))
          .toList();

      return related.take(5).toList();
    } catch (e) {
      print('Related/Recommended skills generation failed: $e');
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
}

