import 'package:cloud_firestore/cloud_firestore.dart';

class JobApplicationModel {
  final String applicationId;
  final String jobId;
  final String candidateId;
  final String resumeUrl;
  final String coverLetter;
  final String
  applicationStatus; // applied, screening, interviewing, hired, rejected
  final DateTime appliedAt;
  final String source; // job_portal, referral, etc.

  JobApplicationModel({
    required this.applicationId,
    required this.jobId,
    required this.candidateId,
    required this.resumeUrl,
    required this.coverLetter,
    required this.applicationStatus,
    required this.appliedAt,
    required this.source,
  });

  Map<String, dynamic> toMap() {
    return {
      'applicationId': applicationId,
      'jobId': jobId,
      'candidateId': candidateId,
      'resumeUrl': resumeUrl,
      'coverLetter': coverLetter,
      'applicationStatus': applicationStatus,
      'appliedAt': Timestamp.fromDate(appliedAt),
      'source': source,
    };
  }

  factory JobApplicationModel.fromMap(Map<String, dynamic> map, String id) {
    return JobApplicationModel(
      applicationId: id, // Typically we use the doc ID
      jobId: map['jobId'] ?? '',
      candidateId: map['candidateId'] ?? '',
      resumeUrl: map['resumeUrl'] ?? '',
      coverLetter: map['coverLetter'] ?? '',
      applicationStatus: map['applicationStatus'] ?? 'applied',
      appliedAt: (map['appliedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      source: map['source'] ?? 'job_portal',
    );
  }
}
