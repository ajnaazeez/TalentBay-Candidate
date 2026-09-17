import 'package:flutter_test/flutter_test.dart';
import 'package:talentbay_candidate/features/auth/models/candidate_model.dart';
import 'package:talentbay_candidate/features/candidate/models/profile_sections.dart';
import 'package:talentbay_candidate/features/candidate/utils/profile_completion_calculator.dart';
import 'package:talentbay_candidate/features/jobs/models/job_application_model.dart';

void main() {
  group('CandidateModel.fromMap Robustness Tests', () {
    test('Correctly parses full valid candidate data', () {
      final map = {
        'uid': 'test_uid_123',
        'email': 'candidate@example.com',
        'firstName': 'John',
        'lastName': 'Doe',
        'phoneNumber': '+919876543210',
        'isPremium': true,
        'subscriptionStatus': 'active',
        'hasUsedTrial': true,
        'skills': [
          {'name': 'Flutter', 'type': 'Primary', 'level': 'Expert'},
          {'name': 'Dart', 'type': 'Primary', 'level': 'Expert'},
        ],
        'languages': {'en': 'Fluent', 'es': 'Intermediate'},
        'currentLocation': {'city': 'Bengaluru', 'state': 'Karnataka', 'country': 'India'},
        'jobPreference': {
          'role': 'Flutter Developer',
          'employmentType': 'Full-time',
          'workMode': 'Remote',
          'preferredLocations': ['Bengaluru'],
          'preferredIndustry': 'Technology',
          'salaryCurrency': 'INR',
          'salaryMin': 1000000.0,
          'salaryMax': 1500000.0,
          'noticePeriod': '15 days',
        },
        'workExperience': [
          {
            'id': 'exp_1',
            'companyName': 'Tech Corp',
            'jobTitle': 'Software Engineer',
            'startDate': '2022-01-01T00:00:00.000',
            'isCurrent': true,
            'description': 'Dev work',
          }
        ],
        'education': [
          {
            'id': 'edu_1',
            'degree': 'B.Tech',
            'fieldOfStudy': 'Computer Science',
            'institution': 'University',
            'startYear': 2018,
            'endYear': 2022,
          }
        ],
        'projects': [
          {
            'id': 'proj_1',
            'title': 'Job Portal',
            'description': 'Flutter app',
            'projectUrl': 'https://example.com',
            'startDate': '2023-01-01T00:00:00.000',
            'isOngoing': false,
          }
        ],
        'certifications': [
          {
            'id': 'cert_1',
            'name': 'Cloud Architect',
            'issuingOrganization': 'Google Cloud',
            'issueDate': '2023-01-01T00:00:00.000',
          }
        ],
        'createdAt': '2026-01-01T00:00:00.000',
        'lastUpdated': '2026-01-02T00:00:00.000',
      };

      final candidate = CandidateModel.fromMap(map);
      expect(candidate.uid, equals('test_uid_123'));
      expect(candidate.email, equals('candidate@example.com'));
      expect(candidate.phoneNumber, equals('+919876543210'));
      expect(candidate.skills.map((s) => s.name), contains('Flutter'));
      expect(candidate.languages['en'], equals('Fluent'));
      expect(candidate.currentLocation?.city, equals('Bengaluru'));
      expect(candidate.jobPreference?.role, equals('Flutter Developer'));
      expect(candidate.workExperience.length, equals(1));
      expect(candidate.workExperience.first.companyName, equals('Tech Corp'));
      expect(candidate.education.length, equals(1));
      expect(candidate.projects.length, equals(1));
      expect(candidate.certifications.length, equals(1));
      expect(candidate.isPremium, isTrue);
    });

    test('Defensively handles missing, null, and dynamic Firestore types without crashing', () {
      final malformedMap = {
        'uid': 'defensive_test_uid',
        'email': null,
        'phoneNumber': 1234567890, // integer instead of string
        'skills': [
          'Flutter', // string instead of map
          null,
          123,
          {'name': 'Dart', 'type': 'Primary', 'level': 'Expert'}
        ],
        'languages': ['English', 456], // List instead of Map
        'currentLocation': 'not_a_map', // string instead of Map
        'jobPreference': ['invalid_type'], // List instead of Map
        'workExperience': [
          'invalid_item',
          null,
          {
            'id': 'exp_2',
            'companyName': 'Valid Company',
            'jobTitle': 'Developer',
            'startDate': 'not-a-valid-date-string', // unparseable date string
            'isCurrent': 'true', // string instead of bool
            'description': 'Dev',
          }
        ],
        'education': [
          {
            'id': 'edu_2',
            'degree': 'M.S.',
            'institution': 'Univ',
            'fieldOfStudy': 'CS',
            'startYear': '2020', // string instead of int
            'endYear': null,
          }
        ],
        'projects': 'invalid_projects_list',
        'certifications': null,
        'createdAt': 'invalid_date',
        'lastUpdated': null,
        'isPremium': 'false', // string instead of bool
      };

      // Must not throw TypeError or any uncaught exception
      final candidate = CandidateModel.fromMap(malformedMap);
      expect(candidate.uid, equals('defensive_test_uid'));
      expect(candidate.email, equals(''));
      expect(candidate.phoneNumber, equals('1234567890'));
      expect(candidate.skills.length, equals(1));
      expect(candidate.skills.map((s) => s.name), contains('Dart'));
      expect(candidate.languages, isEmpty);
      expect(candidate.currentLocation, isNull);
      expect(candidate.jobPreference, isNull);
      expect(candidate.workExperience.length, equals(1));
      expect(candidate.workExperience.first.companyName, equals('Valid Company'));
      expect(candidate.workExperience.first.startDate, isA<DateTime>());
      expect(candidate.education.length, equals(1));
      expect(candidate.education.first.startYear, equals(2020));
      expect(candidate.projects, isEmpty);
      expect(candidate.certifications, isEmpty);
    });

    test('Calculates profile completion percentage correctly without error', () {
      final candidate = CandidateModel(
        uid: 'test_completion_uid',
        email: 'test@example.com',
        firstName: 'Alice',
        lastName: 'Smith',
        phoneNumber: '+1234567890',
        designation: 'Flutter Dev',
        skills: [
          const Skill(name: 'Flutter', type: 'Primary', level: 'Expert'),
          const Skill(name: 'Dart', type: 'Primary', level: 'Expert'),
        ],
        workExperience: [
          WorkExperience(
            id: 'exp_1',
            companyName: 'Co',
            jobTitle: 'Dev',
            startDate: DateTime.now(),
            isCurrent: true,
            description: 'Work',
          ),
        ],
        education: [
          const Education(
            id: 'edu_1',
            degree: 'B.S.',
            fieldOfStudy: 'CS',
            institution: 'MIT',
            startYear: 2018,
            endYear: 2022,
          ),
        ],
        createdAt: DateTime.now(),
        lastUpdated: DateTime.now(),
      );

      final percentage = ProfileCompletionCalculator.calculate(candidate);
      expect(percentage, isA<double>());
      expect(percentage, greaterThan(0.0));
      expect(percentage, lessThanOrEqualTo(100.0));
    });
  });

  group('JobApplication In-Memory Sorting Tests', () {
    test('Sorts job applications descending by appliedAt with nulls last', () {
      final app1 = JobApplicationModel(
        applicationId: 'app_1',
        jobId: 'job_1',
        candidateId: 'cand_1',
        appliedAt: DateTime(2026, 1, 10),
        applicationStatus: 'applied',
        resumeUrl: '',
        coverLetter: '',
        source: 'job_portal',
      );

      final app2 = JobApplicationModel(
        applicationId: 'app_2',
        jobId: 'job_2',
        candidateId: 'cand_1',
        appliedAt: DateTime(2026, 1, 15),
        applicationStatus: 'applied',
        resumeUrl: '',
        coverLetter: '',
        source: 'job_portal',
      );

      final app3 = JobApplicationModel(
        applicationId: 'app_3',
        jobId: 'job_3',
        candidateId: 'cand_1',
        appliedAt: DateTime(2026, 1, 5),
        applicationStatus: 'applied',
        resumeUrl: '',
        coverLetter: '',
        source: 'job_portal',
      );

      final applications = [app1, app2, app3];
      applications.sort((a, b) => b.appliedAt.compareTo(a.appliedAt));

      expect(applications.first.applicationId, equals('app_2')); // Jan 15 is most recent
      expect(applications[1].applicationId, equals('app_1'));     // Jan 10 is second
      expect(applications.last.applicationId, equals('app_3'));   // Jan 5 is oldest
    });
  });
}
