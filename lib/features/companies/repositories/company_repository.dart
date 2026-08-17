import 'package:cloud_firestore/cloud_firestore.dart';
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
      return snapshot.docs.map((doc) {
        return CompanyModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  Future<CompanyModel?> getCompany(String id) async {
    final doc = await _firestore.collection('companies').doc(id).get();
    if (doc.exists) {
      return CompanyModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }
}
