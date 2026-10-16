import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/company_model.dart';

final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  return CompanyRepository(FirebaseFirestore.instance);
});

class CompanyRepository {
  final FirebaseFirestore _firestore;

  CompanyRepository(this._firestore);

  Stream<List<CompanyModel>> getCompanies() {
    return _firestore.collection('companies').snapshots().map((snapshot) {
      final companies = <CompanyModel>[];
      for (final doc in snapshot.docs) {
        try {
          companies.add(CompanyModel.fromMap(doc.data(), doc.id));
        } catch (e, stack) {
          debugPrint('Error parsing company doc ${doc.id}: $e\n$stack');
        }
      }
      return companies;
    });
  }

  Future<CompanyModel?> getCompany(String id) async {
    try {
      final doc = await _firestore.collection('companies').doc(id).get();
      if (doc.exists && doc.data() != null) {
        return CompanyModel.fromMap(doc.data()!, doc.id);
      }
    } catch (e, stack) {
      debugPrint('Error getting company doc $id: $e\n$stack');
    }
    return null;
  }
}
