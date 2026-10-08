import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/assessment_model.dart';

final assessmentRepositoryProvider = Provider<AssessmentRepository>((ref) {
  return AssessmentRepository(FirebaseFirestore.instance);
});

class AssessmentRepository {
  final FirebaseFirestore _firestore;

  AssessmentRepository(this._firestore);

  /// Save assessment result
  Future<void> saveAssessmentResult(AssessmentResult result) async {
    // Check if an assessment for this skill AND difficulty already exists
    final existingQuery = await _firestore
        .collection('assessmentResults')
        .where('candidateId', isEqualTo: result.candidateId)
        .where('skill', isEqualTo: result.skill)
        .where('difficulty', isEqualTo: result.difficulty)
        .get();

    final batch = _firestore.batch();

    // Delete existing result for this specific difficulty level
    for (var doc in existingQuery.docs) {
      batch.delete(doc.reference);
    }

    // Add the new result
    final newDoc = _firestore.collection('assessmentResults').doc(result.id);
    batch.set(newDoc, result.toMap());

    await batch.commit();
  }

  /// Get all assessment results for a candidate
  Stream<List<AssessmentResult>> getCandidateAssessments(String candidateId) {
    return _firestore
        .collection('assessmentResults')
        .where('candidateId', isEqualTo: candidateId)
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => AssessmentResult.fromMap(doc.data()))
              .toList();
        });
  }

  /// Get assessment result for a specific skill
  Future<AssessmentResult?> getSkillAssessment(
    String candidateId,
    String skill,
  ) async {
    final snapshot = await _firestore
        .collection('assessmentResults')
        .where('candidateId', isEqualTo: candidateId)
        .where('skill', isEqualTo: skill)
        .orderBy('completedAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    return AssessmentResult.fromMap(snapshot.docs.first.data());
  }

  /// Delete assessment result
  Future<void> deleteAssessment(String assessmentId) async {
    await _firestore.collection('assessmentResults').doc(assessmentId).delete();
  }

  /// Get assessment statistics
  Future<Map<String, dynamic>> getAssessmentStats(String candidateId) async {
    final assessments = await _firestore
        .collection('assessmentResults')
        .where('candidateId', isEqualTo: candidateId)
        .orderBy('completedAt', descending: true) // Ensure latest first
        .get();

    if (assessments.docs.isEmpty) {
      return {'totalAssessments': 0, 'averageScore': 0.0, 'skillsAssessed': 0};
    }

    final allResults = assessments.docs
        .map((doc) => AssessmentResult.fromMap(doc.data()))
        .toList();

    // Calculate unique skills
    final uniqueSkills = <String>{};
    double totalPercentage = 0;

    for (var result in allResults) {
      uniqueSkills.add(result.skill.toLowerCase());
      totalPercentage += result.percentage;
    }

    final averageScore = allResults.isNotEmpty
        ? totalPercentage / allResults.length
        : 0.0;

    return {
      'totalAssessments': allResults.length,
      'averageScore': averageScore,
      'skillsAssessed': uniqueSkills.length,
    };
  }

  /// Helper: Extract the latest score percentage per skill from a list of AssessmentResults
  static Map<String, double> extractLatestSkillScores(List<AssessmentResult> results) {
    final map = <String, double>{};
    // Sort descending by date so latest result for each skill is stored
    final sorted = List<AssessmentResult>.from(results)
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));

    for (var res in sorted) {
      final key = res.skill.trim();
      if (key.isNotEmpty && !map.containsKey(key)) {
        map[key] = res.percentage;
      }
    }
    return map;
  }

  /// Helper: Calculate overall cumulative skill readiness percentage
  static double calculateOverallPerformance(Map<String, double> skillScores) {
    if (skillScores.isEmpty) return 0.0;
    final total = skillScores.values.fold<double>(0.0, (sum, val) => sum + val);
    return total / skillScores.length;
  }

  /// Helper: Calculate Job Skill Match Percentage against required job skills
  static double calculateJobSkillMatch({
    required Map<String, double> candidateSkillScores,
    required List<String> requiredSkills,
  }) {
    if (requiredSkills.isEmpty) return 0.0;

    // Build a case-insensitive map of candidate skill scores
    final normalizedCandidateSkills = <String, double>{};
    candidateSkillScores.forEach((key, value) {
      normalizedCandidateSkills[key.trim().toLowerCase()] = value;
    });

    double totalMatchedScore = 0.0;
    for (var reqSkill in requiredSkills) {
      final key = reqSkill.trim().toLowerCase();
      if (normalizedCandidateSkills.containsKey(key)) {
        totalMatchedScore += normalizedCandidateSkills[key]!;
      } else {
        // Unassessed required skill counts as 0% for match calculation (as per product specification)
        totalMatchedScore += 0.0;
      }
    }

    return totalMatchedScore / requiredSkills.length;
  }
}

