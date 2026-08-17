import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/models/candidate_model.dart';
import '../utils/profile_completion_calculator.dart';

final candidateRepositoryProvider = Provider(
  (ref) => CandidateRepository(FirebaseFirestore.instance),
);

class CandidateRepository {
  final FirebaseFirestore _firestore;

  CandidateRepository(this._firestore);

  Future<CandidateModel?> getCandidate(String uid) async {
    try {
      final doc = await _firestore.collection('candidates').doc(uid).get();
      if (doc.exists) {
        return CandidateModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Stream<CandidateModel?> getCandidateStream(String uid) {
    return _firestore.collection('candidates').doc(uid).snapshots().map((
      snapshot,
    ) {
      if (snapshot.exists && snapshot.data() != null) {
        return CandidateModel.fromMap(snapshot.data()!);
      }
      return null;
    });
  }

  Future<void> updateCandidate(CandidateModel candidate) async {
    try {
      // Calculate profile completion percentage
      final completionPercentage = ProfileCompletionCalculator.calculate(
        candidate,
      );
      final updatedCandidate = candidate.copyWith(
        profileCompletionPercentage: completionPercentage,
        lastUpdated: DateTime.now(),
      );

      await _firestore
          .collection('candidates')
          .doc(updatedCandidate.uid)
          .update(updatedCandidate.toMap());
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addSavedJob(String uid, String jobId) async {
    try {
      await _firestore.collection('candidates').doc(uid).update({
        'savedJobIds': FieldValue.arrayUnion([jobId]),
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removeSavedJob(String uid, String jobId) async {
    try {
      await _firestore.collection('candidates').doc(uid).update({
        'savedJobIds': FieldValue.arrayRemove([jobId]),
      });
    } catch (e) {
      rethrow;
    }
  }
}
