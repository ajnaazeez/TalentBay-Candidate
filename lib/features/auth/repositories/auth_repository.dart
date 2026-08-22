import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/candidate_model.dart';

final authRepositoryProvider = Provider(
  (ref) => AuthRepository(FirebaseAuth.instance, FirebaseFirestore.instance),
);

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepository(this._auth, this._firestore);

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check user role
      final user = userCredential.user;
      if (user != null) {
        await verifyUserRole(user);
      }

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> verifyUserRole(User user) async {
    final userDoc = await _firestore.collection('users').doc(user.uid).get();

    if (userDoc.exists) {
      final role = userDoc.data()?['role'];
      if (role != 'candidate') {
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'wrong-role',
          message: 'User is invalid in this application',
        );
      }

      // If candidate user exists, ensure /candidates/{uid} document is also initialized
      final candidateDoc = await _firestore.collection('candidates').doc(user.uid).get();
      if (!candidateDoc.exists) {
        final candidate = CandidateModel(
          uid: user.uid,
          email: user.email ?? '',
          createdAt: DateTime.now(),
          lastUpdated: DateTime.now(),
          isPremium: false,
          subscriptionStatus: 'none',
          hasUsedTrial: false,
        );
        await _firestore
            .collection('candidates')
            .doc(user.uid)
            .set(candidate.toMap());
      }
    } else {
      // Fallback: Check if it's a recruiter (since we are in candidate app)
      final recruiterDoc = await _firestore
          .collection('recruiters')
          .doc(user.uid)
          .get();
      if (recruiterDoc.exists) {
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'wrong-role',
          message: 'User is invalid in this application',
        );
      }

      // If neither user nor recruiter document exists, auto-initialize candidate profile
      final candidate = CandidateModel(
        uid: user.uid,
        email: user.email ?? '',
        createdAt: DateTime.now(),
        lastUpdated: DateTime.now(),
        isPremium: false,
        subscriptionStatus: 'none',
        hasUsedTrial: false,
      );

      await _firestore
          .collection('candidates')
          .doc(user.uid)
          .set(candidate.toMap());

      await _firestore.collection('users').doc(user.uid).set({
        'role': 'candidate',
        'email': user.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    final userCredential = await _auth.signInWithCredential(credential);
    if (userCredential.user != null) {
      await verifyUserRole(userCredential.user!);
    }
    return userCredential;
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? phoneNumber,
  }) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      final candidate = CandidateModel(
        uid: userCredential.user!.uid,
        email: email,
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        createdAt: DateTime.now(),
        lastUpdated: DateTime.now(),
        isPremium: false,
        subscriptionStatus: 'none',
        hasUsedTrial: false,
      );

      await _firestore
          .collection('candidates')
          .doc(userCredential.user!.uid)
          .set(candidate.toMap());

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'role': 'candidate',
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updatePhoneNumber(PhoneAuthCredential credential) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }
      await user.updatePhoneNumber(credential);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String, int?) codeSent,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String) codeAutoRetrievalTimeout,
    Function(PhoneAuthCredential)? verificationCompleted,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        if (verificationCompleted != null) {
          verificationCompleted(credential);
        } else {
          await _auth.signInWithCredential(credential);
        }
      },
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }

      // Delete user data from Firestore
      final batch = _firestore.batch();
      batch.delete(_firestore.collection('candidates').doc(user.uid));
      batch.delete(_firestore.collection('users').doc(user.uid));
      await batch.commit();

      // Delete the user account
      await user.delete();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }
}
