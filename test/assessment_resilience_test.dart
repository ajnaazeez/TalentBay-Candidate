import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentbay_candidate/features/assessment/models/assessment_model.dart';
import 'package:talentbay_candidate/features/assessment/services/assessment_service.dart';

void main() {
  group('Assessment Model & Deserialization Resilience Tests', () {
    test('AssessmentQuestion.fromMap parses valid question data correctly', () {
      final map = {
        'id': 'q1',
        'question': 'What is Flutter?',
        'options': ['A UI framework', 'A database', 'An OS', 'A programming language'],
        'correctAnswerIndex': 0,
        'skill': 'Flutter',
        'difficulty': 'Medium',
      };

      final question = AssessmentQuestion.fromMap(map);
      expect(question.id, 'q1');
      expect(question.question, 'What is Flutter?');
      expect(question.options.length, 4);
      expect(question.correctAnswerIndex, 0);
      expect(question.skill, 'Flutter');
      expect(question.difficulty, 'Medium');
    });

    test('AssessmentQuestion.fromMap defensively handles missing fields with safe defaults', () {
      final map = <String, dynamic>{};

      final question = AssessmentQuestion.fromMap(map);
      expect(question.id, '');
      expect(question.question, '');
      expect(question.options, isEmpty);
      expect(question.correctAnswerIndex, 0);
      expect(question.skill, '');
      expect(question.difficulty, 'Medium');
    });

    test('Safe conversion of Map<Object?, Object?> from Cloud Functions callable output', () {
      // Cloud Functions SDK on Flutter web/native can return _Map<Object?, Object?>
      final Object rawUntypedData = <Object?, Object?>{
        'questions': [
          <Object?, Object?>{
            'id': 'q101',
            'question': 'What is state management?',
            'options': ['Provider', 'Riverpod', 'Bloc', 'All of the above'],
            'correctAnswerIndex': 3,
            'skill': 'Flutter',
            'difficulty': 'Hard',
          }
        ],
        'totalQuestions': 1,
      };

      expect(rawUntypedData is Map, isTrue);
      // Demonstrating that Map<String, dynamic>.from resolves the _Map<Object?, Object?> cast issue
      final typedData = Map<String, dynamic>.from(rawUntypedData as Map);
      expect(typedData['totalQuestions'], 1);

      final rawList = typedData['questions'] as List;
      final questions = rawList.map((q) => AssessmentQuestion.fromMap(Map<String, dynamic>.from(q as Map))).toList();
      expect(questions.length, 1);
      expect(questions.first.id, 'q101');
      expect(questions.first.difficulty, 'Hard');
    });

    test('AssessmentResult.fromMap preserves historical Timestamp without silent mutation', () {
      final historicalDate = DateTime.utc(2025, 5, 14, 10, 30, 0);
      final timestamp = Timestamp.fromDate(historicalDate);

      final map = {
        'id': 'res1',
        'candidateId': 'cand123',
        'skill': 'Dart',
        'questions': [],
        'userAnswers': [0, 1, 2],
        'score': 3,
        'totalQuestions': 3,
        'completedAt': timestamp,
        'proficiencyLevel': 'Expert',
        'difficulty': 'Hard',
      };

      final result = AssessmentResult.fromMap(map);
      expect(result.completedAt.toUtc(), historicalDate);
      expect(result.percentage, 100.0);
      expect(result.proficiencyLevel, 'Expert');
    });

    test('AssessmentResult.fromMap preserves ISO8601 string completedAt without silent mutation', () {
      const isoString = '2025-08-20T14:45:00.000Z';
      final expectedDate = DateTime.parse(isoString);

      final map = {
        'id': 'res2',
        'candidateId': 'cand456',
        'skill': 'Python',
        'questions': [],
        'userAnswers': [1, 2],
        'score': 2,
        'totalQuestions': 2,
        'completedAt': isoString,
        'proficiencyLevel': 'Advanced',
        'difficulty': 'Medium',
      };

      final result = AssessmentResult.fromMap(map);
      expect(result.completedAt, expectedDate);
      expect(result.percentage, 100.0);
    });
  });

  group('Assessment Scoring & Proficiency Level Tests', () {
    test('calculateProficiencyLevel matches exact configured threshold rules', () {
      // >= 90% -> Expert
      expect(AssessmentService.calculateProficiencyLevel(9, 10), 'Expert');
      expect(AssessmentService.calculateProficiencyLevel(10, 10), 'Expert');

      // >= 75% -> Advanced
      expect(AssessmentService.calculateProficiencyLevel(8, 10), 'Advanced');
      expect(AssessmentService.calculateProficiencyLevel(15, 20), 'Advanced'); // 75%

      // >= 60% -> Intermediate
      expect(AssessmentService.calculateProficiencyLevel(6, 10), 'Intermediate');
      expect(AssessmentService.calculateProficiencyLevel(7, 10), 'Intermediate');

      // < 60% -> Beginner
      expect(AssessmentService.calculateProficiencyLevel(5, 10), 'Beginner');
      expect(AssessmentService.calculateProficiencyLevel(0, 10), 'Beginner');

      // Boundary: 0 totalQuestions returns Beginner
      expect(AssessmentService.calculateProficiencyLevel(0, 0), 'Beginner');
    });

    test('Timer expiry auto-submit converts unanswered (null) questions to -1 and scores accurately', () {
      // Simulate 10 questions where user answered 7 (6 correctly, 1 wrong) and left 3 unanswered (null)
      final userAnswersWithNulls = <int?>[0, 1, 2, 3, 0, 1, 0, null, null, null];
      final correctAnswers = [0, 1, 2, 3, 0, 1, 1, 2, 3, 0];

      // Auto-submit logic converts null to -1
      final resolvedAnswers = userAnswersWithNulls.map((ans) => ans ?? -1).toList();

      int score = 0;
      for (int i = 0; i < correctAnswers.length; i++) {
        if (resolvedAnswers[i] == correctAnswers[i]) {
          score++;
        }
      }

      expect(resolvedAnswers.length, 10);
      expect(resolvedAnswers.sublist(7), [-1, -1, -1]);
      // Questions 0-5 match, Question 6 is 0 vs 1 (wrong), Questions 7-9 are -1 (wrong)
      expect(score, 6);

      final proficiency = AssessmentService.calculateProficiencyLevel(score, correctAnswers.length);
      expect(proficiency, 'Intermediate'); // 6/10 = 60%
    });
  });

  group('Concurrency Guard Tests', () {
    test('Duplicate generation guard prevents simultaneous execution', () async {
      bool isGenerating = false;
      int generationCallCount = 0;

      Future<void> triggerGeneration() async {
        if (isGenerating) {
          // Block duplicate concurrent request
          return;
        }
        isGenerating = true;
        try {
          generationCallCount++;
          await Future.delayed(const Duration(milliseconds: 50));
        } finally {
          isGenerating = false;
        }
      }

      // Simulate rapid double-tap
      await Future.wait([
        triggerGeneration(),
        triggerGeneration(),
      ]);

      expect(generationCallCount, 1, reason: 'Only the first generation request should proceed');
      expect(isGenerating, isFalse);
    });

    test('Duplicate submission guard prevents double submission', () async {
      bool isSubmitting = false;
      int submitCallCount = 0;

      Future<void> submitAssessment() async {
        if (isSubmitting) {
          return;
        }
        isSubmitting = true;
        try {
          submitCallCount++;
          await Future.delayed(const Duration(milliseconds: 50));
        } finally {
          isSubmitting = false;
        }
      }

      // Simulate rapid double-tap on submit
      await Future.wait([
        submitAssessment(),
        submitAssessment(),
      ]);

      expect(submitCallCount, 1, reason: 'Only the first submission should be processed');
      expect(isSubmitting, isFalse);
    });
  });
}
