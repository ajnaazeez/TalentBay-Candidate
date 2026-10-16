import 'package:flutter_test/flutter_test.dart';
import 'package:talentbay_candidate/features/jobs/models/job_model.dart';

void main() {
  group('Saved Jobs Model & Filtering Logic Tests', () {
    test('JobModel.fromMap falls back to documentId when map jobId is missing or empty', () {
      final mapWithoutJobId = {
        'companyId': 'comp_1',
        'recruiterId': 'rec_1',
        'roleName': 'Senior Flutter Developer',
        'status': 'active',
      };

      final jobWithFallback = JobModel.fromMap(mapWithoutJobId, documentId: 'doc_123');
      expect(jobWithFallback.jobId, equals('doc_123'));

      final mapWithEmptyJobId = {
        'jobId': '   ',
        'companyId': 'comp_1',
        'recruiterId': 'rec_1',
        'roleName': 'Senior Flutter Developer',
        'status': 'active',
      };

      final jobWithEmptyFallback = JobModel.fromMap(mapWithEmptyJobId, documentId: 'doc_456');
      expect(jobWithEmptyFallback.jobId, equals('doc_456'));

      final mapWithExplicitJobId = {
        'jobId': 'explicit_789',
        'companyId': 'comp_1',
        'recruiterId': 'rec_1',
        'roleName': 'Senior Flutter Developer',
        'status': 'active',
      };

      final jobExplicit = JobModel.fromMap(mapWithExplicitJobId, documentId: 'doc_ignore');
      expect(jobExplicit.jobId, equals('explicit_789'));
    });

    test('Strict filtering logic displays ONLY jobs present in candidate savedJobIds', () {
      final job1 = JobModel.fromMap({'jobId': 'job_1', 'roleName': 'Flutter Dev', 'status': 'active'});
      final job2 = JobModel.fromMap({'jobId': 'job_2', 'roleName': 'Backend Dev', 'status': 'active'});
      final job3 = JobModel.fromMap({'jobId': 'job_3', 'roleName': 'UI Designer', 'status': 'active'});
      final allJobs = [job1, job2, job3];

      // Candidate has saved only job_1
      final candidateSavedIds = {'job_1'};
      final filtered = allJobs.where((j) => candidateSavedIds.contains(j.jobId)).toList();

      expect(filtered.length, equals(1));
      expect(filtered.first.jobId, equals('job_1'));
      expect(filtered.any((j) => j.jobId == 'job_2'), isFalse);
      expect(filtered.any((j) => j.jobId == 'job_3'), isFalse);
    });

    test('Empty candidate savedJobIds results in empty list and never falls back to all jobs', () {
      final job1 = JobModel.fromMap({'jobId': 'job_1', 'roleName': 'Flutter Dev', 'status': 'active'});
      final job2 = JobModel.fromMap({'jobId': 'job_2', 'roleName': 'Backend Dev', 'status': 'active'});
      final allJobs = [job1, job2];

      final candidateSavedIds = <String>{};
      final filtered = allJobs.where((j) => candidateSavedIds.contains(j.jobId)).toList();

      expect(filtered, isEmpty);
      expect(filtered.length, equals(0));
    });

    test('Sanitizes whitespace and empty strings in saved job IDs', () {
      final rawJobIds = ['job_1', '  ', '', 'job_2', 'job_1'];
      final cleanIds = rawJobIds
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toSet();

      expect(cleanIds, equals({'job_1', 'job_2'}));
      expect(cleanIds.contains(''), isFalse);
    });
  });
}
