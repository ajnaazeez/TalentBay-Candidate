import 'package:cloud_firestore/cloud_firestore.dart';

class AssessmentQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final String skill;
  final String difficulty; // Easy, Medium, Hard

  AssessmentQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    required this.skill,
    required this.difficulty,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'correctAnswerIndex': correctAnswerIndex,
      'skill': skill,
      'difficulty': difficulty,
    };
  }

  factory AssessmentQuestion.fromMap(Map<String, dynamic> map) {
    return AssessmentQuestion(
      id: map['id'] ?? '',
      question: map['question'] ?? '',
      options: List<String>.from(map['options'] ?? []),
      correctAnswerIndex: map['correctAnswerIndex'] ?? 0,
      skill: map['skill'] ?? '',
      difficulty: map['difficulty'] ?? 'Medium',
    );
  }
}

class AssessmentResult {
  final String id;
  final String candidateId;
  final String skill;
  final List<AssessmentQuestion> questions;
  final List<int> userAnswers;
  final int score;
  final int totalQuestions;
  final DateTime completedAt;
  final String proficiencyLevel; // Beginner, Intermediate, Advanced, Expert
  final String difficulty; // Easy, Medium, Hard

  AssessmentResult({
    required this.id,
    required this.candidateId,
    required this.skill,
    required this.questions,
    required this.userAnswers,
    required this.score,
    required this.totalQuestions,
    required this.completedAt,
    required this.proficiencyLevel,
    required this.difficulty,
  });

  double get percentage => (score / totalQuestions) * 100;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'candidateId': candidateId,
      'skill': skill,
      'questions': questions.map((x) => x.toMap()).toList(),
      'userAnswers': userAnswers,
      'score': score,
      'totalQuestions': totalQuestions,
      'completedAt': completedAt.toIso8601String(),
      'proficiencyLevel': proficiencyLevel,
      'difficulty': difficulty,
    };
  }

  factory AssessmentResult.fromMap(Map<String, dynamic> map) {
    return AssessmentResult(
      id: map['id'] ?? '',
      candidateId: map['candidateId'] ?? '',
      skill: map['skill'] ?? '',
      questions: List<AssessmentQuestion>.from(
        (map['questions'] as List? ?? []).map(
          (x) => AssessmentQuestion.fromMap(x),
        ),
      ),
      userAnswers: List<int>.from(map['userAnswers'] ?? []),
      score: map['score'] ?? 0,
      totalQuestions: map['totalQuestions'] ?? 0,
      completedAt: (map['completedAt'] is Timestamp)
          ? (map['completedAt'] as Timestamp).toDate()
          : DateTime.parse(map['completedAt']),
      proficiencyLevel: map['proficiencyLevel'] ?? 'Beginner',
      difficulty: map['difficulty'] ?? 'Medium',
    );
  }
}
