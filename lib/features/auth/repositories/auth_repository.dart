import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/candidate_model.dart';

final authRepositoryProvider = Provider(
  (ref) => AuthRepository(FirebaseAuth.instance, FirebaseFirestore.instance),
);

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

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

    String? fName;
    String? lName;
    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      final parts = user.displayName!.trim().split(' ');
      fName = parts.first;
      if (parts.length > 1) {
        lName = parts.skip(1).join(' ');
      }
    }

    if (userDoc.exists) {
      final role = userDoc.data()?['role'];
      if (role != 'candidate') {
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'wrong-role',
          message: 'User is invalid in this application',
        );
      }

      final uFName = userDoc.data()?['firstName'] ?? fName;
      final uLName = userDoc.data()?['lastName'] ?? lName;

      // If candidate user exists, ensure /candidates/{uid} document is also initialized
      final candidateDoc = await _firestore.collection('candidates').doc(user.uid).get();
      if (!candidateDoc.exists) {
        final candidate = CandidateModel(
          uid: user.uid,
          email: user.email ?? '',
          phoneNumber: user.phoneNumber,
          firstName: uFName,
          lastName: uLName,
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
      } else {
        // If candidate doc exists but has missing phone number or names, update them safely
        final data = candidateDoc.data()!;
        final updates = <String, dynamic>{};
        
        final existingPhone = data['phoneNumber'];
        if ((existingPhone == null || (existingPhone is String && existingPhone.isEmpty)) &&
            user.phoneNumber != null &&
            user.phoneNumber!.isNotEmpty) {
          updates['phoneNumber'] = user.phoneNumber;
        }

        if ((data['firstName'] == null || data['firstName'].toString().isEmpty) && uFName != null) {
          updates['firstName'] = uFName;
        }
        if ((data['lastName'] == null || data['lastName'].toString().isEmpty) && uLName != null) {
          updates['lastName'] = uLName;
        }

        if (updates.isNotEmpty) {
          updates['lastUpdated'] = DateTime.now().toIso8601String();
          await _firestore.collection('candidates').doc(user.uid).update(updates);
        }
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
        phoneNumber: user.phoneNumber,
        firstName: fName,
        lastName: lName,
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

      final userData = <String, dynamic>{
        'role': 'candidate',
        'email': user.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (fName != null) userData['firstName'] = fName;
      if (lName != null) userData['lastName'] = lName;
      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
        userData['phoneNumber'] = user.phoneNumber;
      }

      await _firestore.collection('users').doc(user.uid).set(
        userData,
        SetOptions(merge: true),
      );
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

      final full = '${firstName ?? ''} ${lastName ?? ''}'.trim();
      if (full.isNotEmpty && userCredential.user != null) {
        await userCredential.user!.updateDisplayName(full);
      }

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
        'firstName': firstName,
        'lastName': lastName,
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

  Future<void> sendEmailOtp(String email) async {
    try {
      final callable = _functions.httpsCallable('sendEmailOtp');
      await callable.call({'email': email});
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Failed to send OTP code');
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> verifyEmailOtp(String email, String otp) async {
    try {
      final callable = _functions.httpsCallable('verifyEmailOtp');
      final res = await callable.call({'email': email, 'otp': otp});
      final data = res.data;
      return data['verified'] == true;
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Invalid OTP code');
    } catch (e) {
      rethrow;
    }
  }
}
