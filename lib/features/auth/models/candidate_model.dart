import 'package:cloud_firestore/cloud_firestore.dart';
import '../../candidate/models/profile_sections.dart';

class CandidateModel {
  final String uid;
  final String email;
  final String? phoneNumber;
  final String? firstName;
  final String? lastName;
  final String? photoUrl;
  final String? designation;
  final DateTime createdAt;

  // Basic Personal Info
  final DateTime? dob;
  final String? gender;
  final Address? currentLocation;
  final String? nationality;
  final bool willingToRelocate;

  // Professional Summary
  final String? bio; // Headline
  final String? aboutMe;

  // JOb Preferences
  final JobPreference? jobPreference;

  // Skills
  final List<Skill> skills;

  // Experience
  final List<WorkExperience> workExperience;

  // Education
  final List<Education> education;

  // Projects
  final List<Project> projects;

  // Certifications
  final List<Certification> certifications;

  // Resume & Portfolio
  final String? resumeUrl;
  final String? portfolioUrl;
  final String? githubProfile;
  final String? linkedinProfile;
  final List<String> otherLinks;

  // Additional Info
  final Map<String, String> languages; // Language: Proficiency
  final String? achievements;
  final String? disabilityInfo;

  // Saved Jobs
  final List<String> savedJobIds;

  // System Fields
  final double profileCompletionPercentage;
  final bool isProfilePublic;
  final String accountStatus; // Active, Blocked
  final DateTime lastUpdated;

  // Subscription Fields
  final bool isPremium;
  final DateTime? subscriptionExpiryDate;
  final String? subscriptionStatus; // 'active', 'expired', 'none'
  final bool hasUsedTrial;
  final String? appleSubscriptionId;

  CandidateModel({
    required this.uid,
    required this.email,
    this.phoneNumber,
    this.firstName,
    this.lastName,
    this.photoUrl,
    this.designation,
    required this.createdAt,
    this.dob,
    this.gender,
    this.currentLocation,
    this.nationality,
    this.willingToRelocate = false,
    this.bio,
    this.aboutMe,
    this.jobPreference,
    this.skills = const [],
    this.workExperience = const [],
    this.education = const [],
    this.projects = const [],
    this.certifications = const [],
    this.resumeUrl,
    this.portfolioUrl,
    this.githubProfile,
    this.linkedinProfile,
    this.otherLinks = const [],
    this.languages = const {},
    this.achievements,
    this.disabilityInfo,
    this.savedJobIds = const [],
    this.profileCompletionPercentage = 0.0,
    this.isProfilePublic = true,
    this.accountStatus = 'Active',
    required this.lastUpdated,
    this.isPremium = false,
    this.subscriptionExpiryDate,
    this.subscriptionStatus = 'none',
    this.hasUsedTrial = false,
    this.appleSubscriptionId,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'phoneNumber': phoneNumber,
      'firstName': firstName,
      'lastName': lastName,
      'photoUrl': photoUrl,
      'designation': designation,
      'createdAt': createdAt.toIso8601String(),
      'dob': dob?.toIso8601String(),
      'gender': gender,
      'currentLocation': currentLocation?.toMap(),
      'nationality': nationality,
      'willingToRelocate': willingToRelocate,
      'bio': bio,
      'aboutMe': aboutMe,
      'jobPreference': jobPreference?.toMap(),
      'skills': skills.map((x) => x.toMap()).toList(),
      'workExperience': workExperience.map((x) => x.toMap()).toList(),
      'education': education.map((x) => x.toMap()).toList(),
      'projects': projects.map((x) => x.toMap()).toList(),
      'certifications': certifications.map((x) => x.toMap()).toList(),
      'resumeUrl': resumeUrl,
      'portfolioUrl': portfolioUrl,
      'githubProfile': githubProfile,
      'linkedinProfile': linkedinProfile,
      'otherLinks': otherLinks,
      'languages': languages,
      'achievements': achievements,
      'disabilityInfo': disabilityInfo,
      'savedJobIds': savedJobIds,
      'profileCompletionPercentage': profileCompletionPercentage,
      'isProfilePublic': isProfilePublic,
      'accountStatus': accountStatus,
      'lastUpdated': lastUpdated.toIso8601String(),
      'isPremium': isPremium,
      'subscriptionExpiryDate': subscriptionExpiryDate?.toIso8601String(),
      'subscriptionStatus': subscriptionStatus,
      'hasUsedTrial': hasUsedTrial,
      'appleSubscriptionId': appleSubscriptionId,
    };
  }

  factory CandidateModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.parse(val);
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.parse(val);
      return null;
    }

    return CandidateModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'],
      firstName: map['firstName'],
      lastName: map['lastName'],
      photoUrl: map['photoUrl'],
      designation: map['designation'],
      createdAt: parseDate(map['createdAt']),
      dob: parseNullableDate(map['dob']),
      gender: map['gender'],
      currentLocation: map['currentLocation'] != null
          ? Address.fromMap(map['currentLocation'])
          : null,
      nationality: map['nationality'],
      willingToRelocate: map['willingToRelocate'] ?? false,
      bio: map['bio'],
      aboutMe: map['aboutMe'],
      jobPreference: map['jobPreference'] != null
          ? JobPreference.fromMap(map['jobPreference'])
          : null,
      skills: List<Skill>.from(
        (map['skills'] as List? ?? []).map((x) => Skill.fromMap(x)),
      ),
      workExperience: List<WorkExperience>.from(
        (map['workExperience'] as List? ?? []).map(
          (x) => WorkExperience.fromMap(x),
        ),
      ),
      education: List<Education>.from(
        (map['education'] as List? ?? []).map((x) => Education.fromMap(x)),
      ),
      projects: List<Project>.from(
        (map['projects'] as List? ?? []).map((x) => Project.fromMap(x)),
      ),
      certifications: List<Certification>.from(
        (map['certifications'] as List? ?? []).map(
          (x) => Certification.fromMap(x),
        ),
      ),
      resumeUrl: map['resumeUrl'],
      portfolioUrl: map['portfolioUrl'],
      githubProfile: map['githubProfile'],
      linkedinProfile: map['linkedinProfile'],
      otherLinks: List<String>.from(map['otherLinks'] ?? []),
      languages: Map<String, String>.from(map['languages'] ?? {}),
      achievements: map['achievements'],
      disabilityInfo: map['disabilityInfo'],
      savedJobIds: List<String>.from(map['savedJobIds'] ?? []),
      profileCompletionPercentage: (map['profileCompletionPercentage'] ?? 0.0)
          .toDouble(),
      isProfilePublic: map['isProfilePublic'] ?? true,
      accountStatus: map['accountStatus'] ?? 'Active',
      lastUpdated: parseDate(map['lastUpdated']),
      isPremium: map['isPremium'] ?? false,
      subscriptionExpiryDate: parseNullableDate(map['subscriptionExpiryDate']),
      subscriptionStatus: map['subscriptionStatus'] ?? 'none',
      hasUsedTrial: map['hasUsedTrial'] ?? false,
      appleSubscriptionId: map['appleSubscriptionId'],
    );
  }

  CandidateModel copyWith({
    String? uid,
    String? email,
    String? phoneNumber,
    String? firstName,
    String? lastName,
    String? photoUrl,
    String? designation,
    DateTime? createdAt,
    DateTime? dob,
    String? gender,
    Address? currentLocation,
    String? nationality,
    bool? willingToRelocate,
    String? bio,
    String? aboutMe,
    JobPreference? jobPreference,
    List<Skill>? skills,
    List<WorkExperience>? workExperience,
    List<Education>? education,
    List<Project>? projects,
    List<Certification>? certifications,
    String? resumeUrl,
    String? portfolioUrl,
    String? githubProfile,
    String? linkedinProfile,
    List<String>? otherLinks,
    Map<String, String>? languages,
    String? achievements,
    String? disabilityInfo,
    List<String>? savedJobIds,
    double? profileCompletionPercentage,
    bool? isProfilePublic,
    String? accountStatus,
    DateTime? lastUpdated,
    bool? isPremium,
    DateTime? subscriptionExpiryDate,
    String? subscriptionStatus,
    bool? hasUsedTrial,
    String? appleSubscriptionId,
  }) {
    return CandidateModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      photoUrl: photoUrl ?? this.photoUrl,
      designation: designation ?? this.designation,
      createdAt: createdAt ?? this.createdAt,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      currentLocation: currentLocation ?? this.currentLocation,
      nationality: nationality ?? this.nationality,
      willingToRelocate: willingToRelocate ?? this.willingToRelocate,
      bio: bio ?? this.bio,
      aboutMe: aboutMe ?? this.aboutMe,
      jobPreference: jobPreference ?? this.jobPreference,
      skills: skills ?? this.skills,
      workExperience: workExperience ?? this.workExperience,
      education: education ?? this.education,
      projects: projects ?? this.projects,
      certifications: certifications ?? this.certifications,
      resumeUrl: resumeUrl ?? this.resumeUrl,
      portfolioUrl: portfolioUrl ?? this.portfolioUrl,
      githubProfile: githubProfile ?? this.githubProfile,
      linkedinProfile: linkedinProfile ?? this.linkedinProfile,
      otherLinks: otherLinks ?? this.otherLinks,
      languages: languages ?? this.languages,
      achievements: achievements ?? this.achievements,
      disabilityInfo: disabilityInfo ?? this.disabilityInfo,
      savedJobIds: savedJobIds ?? this.savedJobIds,
      profileCompletionPercentage:
          profileCompletionPercentage ?? this.profileCompletionPercentage,
      isProfilePublic: isProfilePublic ?? this.isProfilePublic,
      accountStatus: accountStatus ?? this.accountStatus,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isPremium: isPremium ?? this.isPremium,
      subscriptionExpiryDate:
          subscriptionExpiryDate ?? this.subscriptionExpiryDate,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      hasUsedTrial: hasUsedTrial ?? this.hasUsedTrial,
      appleSubscriptionId: appleSubscriptionId ?? this.appleSubscriptionId,
    );
  }
}
