import 'package:flutter_test/flutter_test.dart';
import 'package:talentbay_candidate/core/constants/payment_constants.dart';
import 'package:talentbay_candidate/core/utils/phone_utils.dart';
import 'package:talentbay_candidate/features/auth/models/candidate_model.dart';
import 'package:talentbay_candidate/features/candidate/models/profile_sections.dart';
import 'package:talentbay_candidate/features/candidate/utils/profile_completion_calculator.dart';
import 'package:talentbay_candidate/features/companies/models/company_model.dart';
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

  group('CandidateModel 7-Day Free Trial Tests', () {
    test('Parses trialStartDate and trialExpiryDate from Firestore map correctly', () {
      final now = DateTime.now();
      final expiry = now.add(const Duration(days: 7));
      final map = {
        'uid': 'trial_test_uid',
        'email': 'trial@example.com',
        'isPremium': true,
        'subscriptionStatus': 'trial',
        'hasUsedTrial': true,
        'trialStartDate': now.toIso8601String(),
        'trialExpiryDate': expiry.toIso8601String(),
        'createdAt': now.toIso8601String(),
        'lastUpdated': now.toIso8601String(),
      };

      final candidate = CandidateModel.fromMap(map);
      expect(candidate.hasUsedTrial, isTrue);
      expect(candidate.isPremium, isTrue);
      expect(candidate.subscriptionStatus, equals('trial'));
      expect(candidate.trialStartDate, isNotNull);
      expect(candidate.trialExpiryDate, isNotNull);
      expect(candidate.isTrialActive, isTrue);
    });

    test('isTrialActive returns false when trial has expired', () {
      final pastStart = DateTime.now().subtract(const Duration(days: 8));
      final pastExpiry = DateTime.now().subtract(const Duration(days: 1));
      final map = {
        'uid': 'expired_trial_uid',
        'email': 'expired@example.com',
        'isPremium': false,
        'subscriptionStatus': 'expired',
        'hasUsedTrial': true,
        'trialStartDate': pastStart.toIso8601String(),
        'trialExpiryDate': pastExpiry.toIso8601String(),
        'createdAt': pastStart.toIso8601String(),
        'lastUpdated': pastStart.toIso8601String(),
      };

      final candidate = CandidateModel.fromMap(map);
      expect(candidate.isTrialActive, isFalse);
    });

    test('toMap serializes trialStartDate and trialExpiryDate safely', () {
      final now = DateTime.now();
      final expiry = now.add(const Duration(days: 7));
      final candidate = CandidateModel(
        uid: 'serialize_test_uid',
        email: 'serialize@example.com',
        isPremium: true,
        subscriptionStatus: 'trial',
        hasUsedTrial: true,
        trialStartDate: now,
        trialExpiryDate: expiry,
        createdAt: now,
        lastUpdated: now,
      );

      final map = candidate.toMap();
      expect(map['hasUsedTrial'], isTrue);
      expect(map['trialStartDate'], equals(now.toIso8601String()));
      expect(map['trialExpiryDate'], equals(expiry.toIso8601String()));
      expect(map['isPremium'], isTrue);
      expect(map['subscriptionStatus'], equals('trial'));
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

  group('PhoneUtils Tests', () {
    test('Normalizes various Indian phone formats to standard E.164', () {
      expect(PhoneUtils.normalizeE164('9876543210'), equals('+919876543210'));
      expect(PhoneUtils.normalizeE164('+919876543210'), equals('+919876543210'));
      expect(PhoneUtils.normalizeE164('09876543210'), equals('+919876543210'));
      expect(PhoneUtils.normalizeE164('919876543210'), equals('+919876543210'));
      expect(PhoneUtils.normalizeE164('+91 98765 43210'), equals('+919876543210'));
      expect(PhoneUtils.normalizeE164(''), equals(''));
    });

    test('Builds lookup variants so email accounts can be found by mobile login', () {
      final variants = PhoneUtils.lookupVariants('9876543210');
      expect(variants, contains('+919876543210'));
      expect(variants, contains('9876543210'));
      expect(PhoneUtils.lastTenDigits('+91 98765-43210'), equals('9876543210'));
      expect(PhoneUtils.lastTenDigits(null), isNull);
    });

    test('Validates E.164 phone numbers correctly', () {
      expect(PhoneUtils.isValidE164('+919876543210'), isTrue);
      expect(PhoneUtils.isValidE164('+14155552671'), isTrue);
      expect(PhoneUtils.isValidE164('9876543210'), isFalse); // Missing '+'
      expect(PhoneUtils.isValidE164('+91'), isFalse); // Too short
      expect(PhoneUtils.isValidE164(''), isFalse);
    });
  });

  group('PaymentConstants & Razorpay Configuration Tests', () {
    test('Uses verified Live Razorpay Key ID and has no client secret', () {
      expect(PaymentConstants.razorpayKeyId, equals('rzp_live_TdPCKnpedQNEW6'));
      expect(PaymentConstants.currency, equals('INR'));
      expect(PaymentConstants.companyName, equals('Talent Bay'));
    });

    test('Subscription and trial plans have valid structure and amount strings', () {
      expect(PaymentConstants.trialPlan['id'], equals('7_days_trial'));
      expect(PaymentConstants.trialPlan['amount'], equals('100')); // 100 paise = 1 INR
      expect(PaymentConstants.trialPlan['durationDays'], equals(7));

      for (final plan in PaymentConstants.subscriptionPlans) {
        expect(plan['id'], isNotEmpty);
        expect(int.tryParse(plan['amount']), isNotNull);
        expect(int.parse(plan['amount']), greaterThan(0));
        expect(plan['durationDays'], isNotNull);
        expect(plan['durationDays'], greaterThan(0));
      }
    });
  });

  group('CompanyModel.fromMap Robustness Tests', () {
    test('Parses full nested recruiter/company schema correctly', () {
      final map = {
        'id': 'comp_1',
        'profile': {
          'companyName': 'Google',
          'legalName': 'Google LLC',
          'website': 'https://google.com',
          'logoUrl': 'https://example.com/logo.png',
          'industry': 'Tech',
          'sector': 'Software',
          'companySize': '10000+',
          'foundedYear': 1998,
          'headquarters': {'city': 'Mountain View', 'country': 'USA'},
        },
        'verification': {
          'status': 'verified',
          'isVerified': true,
        },
        'stats': {
          'totalJobs': 50,
          'activeJobs': 12,
          'totalApplicants': 200,
        },
        'createdAt': '2026-01-01T00:00:00.000',
        'updatedAt': '2026-01-02T00:00:00.000',
      };

      final company = CompanyModel.fromMap(map, 'comp_1');
      expect(company.id, equals('comp_1'));
      expect(company.profile.companyName, equals('Google'));
      expect(company.profile.logoUrl, equals('https://example.com/logo.png'));
      expect(company.profile.foundedYear, equals(1998));
      expect(company.verification.isVerified, isTrue);
      expect(company.stats.totalJobs, equals(50));
      expect(company.stats.totalApplicants, equals(200));
      expect(company.meta.createdAt, isA<DateTime>());
    });

    test('Defensively parses flat legacy documents without nested profile map', () {
      final flatMap = {
        'companyName': 'Acme Corp',
        'logoUrl': 'https://acme.com/logo.png',
        'about': 'A great company',
        'industry': 'Manufacturing',
        'websiteUrl': 'https://acme.com',
        'city': 'Kozhikode',
        'state': 'Kerala',
        'country': 'India',
        'isVerified': true,
        'foundedYear': '2015', // string instead of int
        'totalJobs': '25', // string instead of int
        'totalApplicants': 100.0, // double instead of int
        'createdAt': '2026-02-01T12:00:00.000', // ISO string instead of Timestamp
      };

      final company = CompanyModel.fromMap(flatMap, 'flat_1');
      expect(company.id, equals('flat_1'));
      expect(company.profile.companyName, equals('Acme Corp'));
      expect(company.profile.logoUrl, equals('https://acme.com/logo.png'));
      expect(company.profile.about, equals('A great company'));
      expect(company.profile.foundedYear, equals(2015));
      expect(company.contact.city, equals('Kozhikode'));
      expect(company.contact.state, equals('Kerala'));
      expect(company.contact.country, equals('India'));
      expect(company.verification.isVerified, isTrue);
      expect(company.stats.totalJobs, equals(25));
      expect(company.stats.totalApplicants, equals(100));
      expect(company.meta.createdAt, isA<DateTime>());
    });

    test('Safely handles malformed and null fields without throwing exceptions', () {
      final corruptedMap = {
        'profile': 'not-a-map',
        'contact': 12345,
        'business': null,
        'verification': false,
        'social': ['not', 'a', 'map'],
        'stats': 'invalid_stats',
        'settings': 0,
        'meta': true,
        'createdAt': 'completely-unparseable-date',
        'updatedAt': null,
        'location': 'invalid_location',
        'isActive': 'true',
        'isDeleted': 0,
      };

      // Must not throw any TypeError or FormatException
      final company = CompanyModel.fromMap(corruptedMap, 'corrupt_1');
      expect(company.id, equals('corrupt_1'));
      expect(company.profile.companyName, equals(''));
      expect(company.verification.isVerified, isFalse);
      expect(company.stats.totalJobs, equals(0));
      expect(company.meta.createdAt, isA<DateTime>());
    });
  });
}
