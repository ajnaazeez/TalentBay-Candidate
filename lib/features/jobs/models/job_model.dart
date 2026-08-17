import 'package:cloud_firestore/cloud_firestore.dart';

class JobLocation {
  final String city;
  final String state;
  final String country;

  JobLocation({required this.city, required this.state, required this.country});

  Map<String, dynamic> toMap() {
    return {'city': city, 'state': state, 'country': country};
  }

  factory JobLocation.fromMap(Map<String, dynamic> map) {
    return JobLocation(
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      country: map['country'] ?? '',
    );
  }
}

class JobExperienceRequired {
  final int minYears;
  final int maxYears;

  JobExperienceRequired({required this.minYears, required this.maxYears});

  Map<String, dynamic> toMap() {
    return {'minYears': minYears, 'maxYears': maxYears};
  }

  factory JobExperienceRequired.fromMap(Map<String, dynamic> map) {
    return JobExperienceRequired(
      minYears: map['minYears'] ?? 0,
      maxYears: map['maxYears'] ?? 0,
    );
  }
}

class JobSalary {
  final double min;
  final double max;
  final String currency;
  final String type; // CTC, Monthly, Hourly

  JobSalary({
    required this.min,
    required this.max,
    required this.currency,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {'min': min, 'max': max, 'currency': currency, 'type': type};
  }

  factory JobSalary.fromMap(Map<String, dynamic> map) {
    return JobSalary(
      min: (map['min'] ?? 0).toDouble(),
      max: (map['max'] ?? 0).toDouble(),
      currency: map['currency'] ?? 'INR',
      type: map['type'] ?? 'CTC',
    );
  }
}

class JobModel {
  final String jobId;
  final String companyId;
  final String recruiterId;

  final String roleId;
  final String roleName;

  final String designationId;
  final String designationName;

  final String experienceLevel; // Mid-Level, Senior, etc.

  final String employmentType; // Full-Time, Part-Time, Contract
  final String workMode; // Hybrid, Remote, Onsite

  final JobLocation jobLocation;

  final int vacancies;
  final int officeCount;

  final JobExperienceRequired experienceRequired;

  final JobSalary salary;

  final List<String> skillsRequired;
  final List<String> mustHaveSkills;
  final List<String> niceToHaveSkills;

  final String jobDescription;

  final List<String> responsibilities;
  final List<String> requirements;
  final List<String> interviewProcess;

  // Extra questions requested by user context (Optional)
  final List<String> extraQuestions;

  final String status; // active, closed, draft
  final String visibility; // public, private

  final DateTime postedAt;
  final DateTime expiresAt;

  // Enriched fields (fetched separately)
  final String? companyName;
  final String? companyLogoUrl;

  JobModel({
    required this.jobId,
    required this.companyId,
    required this.recruiterId,
    required this.roleId,
    required this.roleName,
    required this.designationId,
    required this.designationName,
    required this.experienceLevel,
    required this.employmentType,
    required this.workMode,
    required this.jobLocation,
    required this.vacancies,
    this.officeCount = 0,
    required this.experienceRequired,
    required this.salary,
    required this.skillsRequired,
    required this.mustHaveSkills,
    required this.niceToHaveSkills,
    required this.jobDescription,
    required this.responsibilities,
    required this.requirements,
    required this.interviewProcess,
    this.extraQuestions = const [],
    required this.status,
    required this.visibility,
    required this.postedAt,
    required this.expiresAt,
    this.companyName,
    this.companyLogoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'jobId': jobId,
      'companyId': companyId,
      'recruiterId': recruiterId,
      'roleId': roleId,
      'roleName': roleName,
      'designationId': designationId,
      'designationName': designationName,
      'experienceLevel': experienceLevel,
      'employmentType': employmentType,
      'workMode': workMode,
      'jobLocation': jobLocation.toMap(),
      'vacancies': vacancies,
      'officeCount': officeCount,
      'experienceRequired': experienceRequired.toMap(),
      'salary': salary.toMap(),
      'skillsRequired': skillsRequired,
      'mustHaveSkills': mustHaveSkills,
      'niceToHaveSkills': niceToHaveSkills,
      'jobDescription': jobDescription,
      'responsibilities': responsibilities,
      'requirements': requirements,
      'interviewProcess': interviewProcess,
      'extraQuestions': extraQuestions,
      'status': status,
      'visibility': visibility,
      'postedAt': Timestamp.fromDate(postedAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }

  factory JobModel.fromMap(
    Map<String, dynamic> map, {
    String? companyName,
    String? companyLogoUrl,
  }) {
    return JobModel(
      jobId: map['jobId'] ?? '',
      companyId: map['companyId'] ?? '',
      recruiterId: map['recruiterId'] ?? '',
      roleId: map['roleId'] ?? '',
      roleName: map['roleName'] ?? '',
      designationId: map['designationId'] ?? '',
      designationName: map['designationName'] ?? '',
      experienceLevel: map['experienceLevel'] ?? '',
      employmentType: map['employmentType'] ?? '',
      workMode: map['workMode'] ?? '',
      jobLocation: JobLocation.fromMap(map['jobLocation'] ?? {}),
      vacancies: map['vacancies'] ?? 1,
      officeCount: map['officeCount'] ?? 0,
      experienceRequired: JobExperienceRequired.fromMap(
        map['experienceRequired'] ?? {},
      ),
      salary: JobSalary.fromMap(map['salary'] ?? {}),
      skillsRequired: List<String>.from(map['skillsRequired'] ?? []),
      mustHaveSkills: List<String>.from(map['mustHaveSkills'] ?? []),
      niceToHaveSkills: List<String>.from(map['niceToHaveSkills'] ?? []),
      jobDescription: map['jobDescription'] ?? '',
      responsibilities: List<String>.from(map['responsibilities'] ?? []),
      requirements: List<String>.from(map['requirements'] ?? []),
      interviewProcess: List<String>.from(map['interviewProcess'] ?? []),
      extraQuestions: List<String>.from(map['extraQuestions'] ?? []),
      status: map['status'] ?? 'draft',
      visibility: map['visibility'] ?? 'public',
      postedAt: (map['postedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt:
          (map['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(days: 30)),
      companyName: companyName,
      companyLogoUrl: companyLogoUrl,
    );
  }

  JobModel copyWith({String? companyName, String? companyLogoUrl}) {
    return JobModel(
      jobId: jobId,
      companyId: companyId,
      recruiterId: recruiterId,
      roleId: roleId,
      roleName: roleName,
      designationId: designationId,
      designationName: designationName,
      experienceLevel: experienceLevel,
      employmentType: employmentType,
      workMode: workMode,
      jobLocation: jobLocation,
      vacancies: vacancies,
      officeCount: officeCount,
      experienceRequired: experienceRequired,
      salary: salary,
      skillsRequired: skillsRequired,
      mustHaveSkills: mustHaveSkills,
      niceToHaveSkills: niceToHaveSkills,
      jobDescription: jobDescription,
      responsibilities: responsibilities,
      requirements: requirements,
      interviewProcess: interviewProcess,
      extraQuestions: extraQuestions,
      status: status,
      visibility: visibility,
      postedAt: postedAt,
      expiresAt: expiresAt,
      companyName: companyName ?? this.companyName,
      companyLogoUrl: companyLogoUrl ?? this.companyLogoUrl,
    );
  }

  // Getters for compatibility or convenience
  String get title => roleName;
  String get location => '${jobLocation.city}, ${jobLocation.country}';
}
