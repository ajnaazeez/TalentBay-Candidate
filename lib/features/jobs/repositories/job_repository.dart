import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job_model.dart';
import '../models/job_application_model.dart';

final jobRepositoryProvider = Provider<JobRepository>((ref) {
  return JobRepository(FirebaseFirestore.instance);
});

class JobRepository {
  final FirebaseFirestore _firestore;

  JobRepository(this._firestore);

  // Fetch all jobs and enrich with Company info
  Stream<List<JobModel>> getJobsStream() {
    return _firestore
        .collection('jobs')
        .where('status', isEqualTo: 'active') // Only show active jobs
        .orderBy('postedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final jobs = <JobModel>[];
          for (final doc in snapshot.docs) {
            var job = JobModel.fromMap(doc.data());

            // Enrich with Company Info
            try {
              if (job.companyId.isNotEmpty) {
                final companyDoc = await _firestore
                    .collection('companies')
                    .doc(job.companyId)
                    .get();
                if (companyDoc.exists) {
                  final companyData = companyDoc.data();
                  if (companyData != null && companyData['profile'] != null) {
                    final profile =
                        companyData['profile'] as Map<String, dynamic>;
                    job = job.copyWith(
                      companyName: profile['companyName'],
                      companyLogoUrl: profile['logoUrl'],
                    );
                  }
                }
              }
            } catch (e) {
              print('Error fetching company info for job ${job.jobId}: $e');
            }
            jobs.add(job);
          }
          return jobs;
        })
        .asBroadcastStream();
  }

  Future<void> applyToJob(JobApplicationModel application) async {
    // strict check to prevent double application
    final existingApps = await _firestore
        .collection('job_applications')
        .where('jobId', isEqualTo: application.jobId)
        .where('candidateId', isEqualTo: application.candidateId)
        .get();

    if (existingApps.docs.isNotEmpty) {
      throw Exception('You have already applied to this job.');
    }

    // Set doc ID same as applicationId
    await _firestore
        .collection('job_applications')
        .doc(application.applicationId)
        .set(application.toMap());
  }

  Stream<JobApplicationModel?> getApplicationStatus(
    String jobId,
    String candidateId,
  ) {
    final applicationId = '${jobId}_$candidateId';
    return _firestore
        .collection('job_applications')
        .doc(applicationId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return null;
          return JobApplicationModel.fromMap(snapshot.data()!, snapshot.id);
        });
  }

  Future<JobModel?> getJob(String jobId) async {
    final doc = await _firestore.collection('jobs').doc(jobId).get();
    if (!doc.exists) return null;

    var job = JobModel.fromMap(doc.data()!);

    // Fetch company info
    try {
      if (job.companyId.isNotEmpty) {
        final companyDoc = await _firestore
            .collection('companies')
            .doc(job.companyId)
            .get();
        if (companyDoc.exists) {
          final companyData = companyDoc.data();
          if (companyData != null && companyData['profile'] != null) {
            final profile = companyData['profile'] as Map<String, dynamic>;
            job = job.copyWith(
              companyName: profile['companyName'],
              companyLogoUrl: profile['logoUrl'],
            );
          }
        }
      }
    } catch (e) {
      // ignore error
    }

    return job;
  }

  // Fetch applications for a candidate
  Stream<List<JobApplicationModel>> getCandidateApplications(
    String candidateId,
  ) {
    return _firestore
        .collection('job_applications')
        .where('candidateId', isEqualTo: candidateId)
        .orderBy('appliedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => JobApplicationModel.fromMap(doc.data(), doc.id))
              .toList(),
        )
        .asBroadcastStream();
  }

  // Fetch invites for a candidate (Applications with status 'invited' or similar notification)
  // For now we check job_applications where status == 'invited'
  Stream<List<JobApplicationModel>> getInvites(String candidateId) {
    return _firestore
        .collection('job_applications')
        .where('candidateId', isEqualTo: candidateId)
        .where('applicationStatus', isEqualTo: 'invited')
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs
              .map((doc) => JobApplicationModel.fromMap(doc.data(), doc.id))
              .toList();
          // Sort in memory to avoid needing a composite index
          docs.sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
          return docs;
        })
        .asBroadcastStream();
  }

  // Fetch saved jobs by IDs
  Stream<List<JobModel>> getSavedJobs(List<String> jobIds) {
    if (jobIds.isEmpty) {
      return Stream.value(<JobModel>[]).asBroadcastStream();
    }

    // Firestore 'whereIn' is limited to 10 items.
    // For now, handling up to 10 items. In a real app, we'd need to batch this.
    // Or we could fetch one by one, but that's expensive.
    // A better approach for large lists is to fetch all active jobs and filter client side
    // if the total jobs count isn't huge, or pagination.
    // For this task, assuming < 10 saved jobs is a reasonable constraint or we take latest 10.
    final idsToFetch = jobIds.length > 10 ? jobIds.sublist(0, 10) : jobIds;

    return _firestore
        .collection('jobs')
        .where(FieldPath.documentId, whereIn: idsToFetch)
        .snapshots()
        .asyncMap((snapshot) async {
          final jobs = <JobModel>[];
          for (final doc in snapshot.docs) {
            var job = JobModel.fromMap(doc.data());

            // Filter out closed jobs
            if (job.status == 'closed') {
              continue;
            }

            // Enrich with company info (duplicate logic from below - could extract)
            try {
              if (job.companyId.isNotEmpty) {
                final companyDoc = await _firestore
                    .collection('companies')
                    .doc(job.companyId)
                    .get();
                if (companyDoc.exists) {
                  final companyData = companyDoc.data();
                  if (companyData != null && companyData['profile'] != null) {
                    final profile =
                        companyData['profile'] as Map<String, dynamic>;
                    job = job.copyWith(
                      companyName: profile['companyName'],
                      companyLogoUrl: profile['logoUrl'],
                    );
                  }
                }
              }
            } catch (e) {
              // ignore
            }
            jobs.add(job);
          }
          return jobs;
        })
        .asBroadcastStream();
  }

  // Accept an investigation (convert to applied)
  Future<void> acceptInvitation(String applicationId) async {
    await _firestore.collection('job_applications').doc(applicationId).update({
      'applicationStatus': 'applied',
      'appliedAt': FieldValue.serverTimestamp(), // Update applied time to now
    });
  }

  // Decline an invitation
  Future<void> declineInvitation(String applicationId) async {
    await _firestore.collection('job_applications').doc(applicationId).update({
      'applicationStatus': 'rejected', // Or 'declined'
    });
  }
}
