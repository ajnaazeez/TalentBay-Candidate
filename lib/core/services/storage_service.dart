import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

final storageServiceProvider = Provider((ref) => StorageService());

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadProfileImage(String userId, File file) async {
    try {
      final String extension = path.extension(file.path);
      final String fileName = 'profile_$userId$extension';
      final Reference ref = _storage.ref().child(
        'candidates/$userId/profile/$fileName',
      );

      print(
        'Attempting to upload to: candidates/$userId/profile/$fileName',
      ); // Debug log

      final UploadTask uploadTask = ref.putFile(file);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload profile image: $e');
    }
  }

  Future<void> deleteProfileImage(String userId) async {
    try {
      final ListResult result =
          await _storage.ref().child('candidates/$userId/profile').listAll();
      for (final Reference ref in result.items) {
        await ref.delete();
      }
    } catch (e) {
      print('Warning: Failed to delete old profile image from storage: $e');
    }
  }

  Future<String> uploadResume(String userId, File file) async {
    try {
      final String fileName = path.basename(file.path);
      // Use timestamp to avoid overwriting and caching issues if name is same
      final String uniqueName =
          '${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final Reference ref = _storage.ref().child(
        'candidates/$userId/resumes/$uniqueName',
      );

      final UploadTask uploadTask = ref.putFile(
        file,
        SettableMetadata(
          contentType: 'application/pdf',
        ), // Assuming most are PDFs
      );
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload resume: $e');
    }
  }
}
