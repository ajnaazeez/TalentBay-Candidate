import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      if (uid.isEmpty) return null;
      final doc = await _firestore.collection('candidates').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return CandidateModel.fromMap(doc.data()!, uid: doc.id);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Stream<CandidateModel?> getCandidateStream(String uid) {
    if (uid.isEmpty) return Stream.value(null);

    return _firestore.collection('candidates').doc(uid).snapshots().asyncMap((
      snapshot,
    ) async {
      if (snapshot.exists && snapshot.data() != null) {
        return CandidateModel.fromMap(snapshot.data()!, uid: snapshot.id);
      }

      // If document does not exist yet for the authenticated user, ensure default candidate creation
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.uid == uid) {
        final fallback = CandidateModel(
          uid: uid,
          email: user.email ?? '',
          phoneNumber: user.phoneNumber,
          createdAt: DateTime.now(),
          lastUpdated: DateTime.now(),
          isPremium: false,
          subscriptionStatus: 'none',
          hasUsedTrial: false,
        );
        try {
          await _firestore
              .collection('candidates')
              .doc(uid)
              .set(fallback.toMap(), SetOptions(merge: true));
        } catch (_) {}
        return fallback;
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
