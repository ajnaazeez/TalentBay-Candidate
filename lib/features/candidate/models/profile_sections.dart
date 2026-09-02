import 'package:cloud_firestore/cloud_firestore.dart';

DateTime _parseDate(dynamic val) {
  if (val is Timestamp) return val.toDate();
  if (val is String) return DateTime.parse(val);
  return DateTime.now();
}

DateTime? _parseNullableDate(dynamic val) {
  if (val == null) return null;
  if (val is Timestamp) return val.toDate();
  if (val is String) return DateTime.parse(val);
  return null;
}

class Address {
  final String city;
  final String state;
  final String country;

  const Address({
    required this.city,
    required this.state,
    required this.country,
  });

  Map<String, dynamic> toMap() {
    return {'city': city, 'state': state, 'country': country};
  }

  factory Address.fromMap(Map<String, dynamic> map) {
    return Address(
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      country: map['country'] ?? '',
    );
  }
}

class JobPreference {
  final String role;
  final String employmentType; // Full-time, Part-time, Internship, Contract
  final String workMode; // On-site, Remote, Hybrid
  final List<String> preferredLocations;
  final String preferredIndustry;
  final String salaryCurrency;
  final double salaryMin;
  final double salaryMax;
  final String noticePeriod;

  const JobPreference({
    required this.role,
    required this.employmentType,
    required this.workMode,
    required this.preferredLocations,
    required this.preferredIndustry,
    required this.salaryCurrency,
    required this.salaryMin,
    required this.salaryMax,
    required this.noticePeriod,
  });

  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'employmentType': employmentType,
      'workMode': workMode,
      'preferredLocations': preferredLocations,
      'preferredIndustry': preferredIndustry,
      'salaryCurrency': salaryCurrency,
      'salaryMin': salaryMin,
      'salaryMax': salaryMax,
      'noticePeriod': noticePeriod,
    };
  }

  factory JobPreference.fromMap(Map<String, dynamic> map) {
    return JobPreference(
      role: map['role'] ?? '',
      employmentType: map['employmentType'] ?? '',
      workMode: map['workMode'] ?? '',
      preferredLocations: List<String>.from(map['preferredLocations'] ?? []),
      preferredIndustry: map['preferredIndustry'] ?? '',
      salaryCurrency: map['salaryCurrency'] ?? '',
      salaryMin: (map['salaryMin'] ?? 0).toDouble(),
      salaryMax: (map['salaryMax'] ?? 0).toDouble(),
      noticePeriod: map['noticePeriod'] ?? '',
    );
  }
}

class Skill {
  final String name;
  final String type; // Primary, Secondary, Tool
  final String level; // Beginner, Intermediate, Expert

  const Skill({required this.name, required this.type, required this.level});

  Map<String, dynamic> toMap() {
    return {'name': name, 'type': type, 'level': level};
  }

  factory Skill.fromMap(Map<String, dynamic> map) {
    return Skill(
      name: map['name'] ?? '',
      type: map['type'] ?? '',
      level: map['level'] ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Skill &&
          runtimeType == other.runtimeType &&
          name.toLowerCase() == other.name.toLowerCase();

  @override
  int get hashCode => name.toLowerCase().hashCode;
}

class WorkExperience {
  final String id;
  final String jobTitle;
  final String companyName;
  final String employmentType; // Can be empty if not collected in basic form
  final DateTime startDate;
  final DateTime? endDate;
  final bool isCurrent;
  final String description;

  const WorkExperience({
    required this.id,
    required this.jobTitle,
    required this.companyName,
    this.employmentType = '',
    required this.startDate,
    this.endDate,
    required this.isCurrent,
    required this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jobTitle': jobTitle,
      'companyName': companyName,
      'employmentType': employmentType,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'isCurrent': isCurrent,
      'description': description,
    };
  }

  factory WorkExperience.fromMap(Map<String, dynamic> map) {
    return WorkExperience(
      id: map['id'] ?? '',
      jobTitle: map['jobTitle'] ?? '',
      companyName: map['companyName'] ?? '',
      employmentType: map['employmentType'] ?? '',
      startDate: _parseDate(map['startDate']),
      endDate: _parseNullableDate(map['endDate']),
      isCurrent: map['isCurrent'] ?? false,
      description: map['description'] ?? '',
    );
  }
}

class Education {
  final String id;
  final String degree;
  final String institution;
  final String fieldOfStudy;
  final int startYear;
  final int endYear;
  final String? grade;

  const Education({
    required this.id,
    required this.degree,
    required this.institution,
    required this.fieldOfStudy,
    required this.startYear,
    required this.endYear,
    this.grade,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'degree': degree,
      'institution': institution,
      'fieldOfStudy': fieldOfStudy,
      'startYear': startYear,
      'endYear': endYear,
      'grade': grade,
    };
  }

  factory Education.fromMap(Map<String, dynamic> map) {
    return Education(
      id: map['id'] ?? '',
      degree: map['degree'] ?? '',
      institution: map['institution'] ?? '',
      fieldOfStudy: map['fieldOfStudy'] ?? '',
      startYear: map['startYear'] ?? 0,
      endYear: map['endYear'] ?? 0,
      grade: map['grade'],
    );
  }
}

class Project {
  final String id;
  final String title;
  final String description;
  final List<String> technologies;
  final String role;
  final String? link;

  const Project({
    required this.id,
    required this.title,
    required this.description,
    required this.technologies,
    required this.role,
    this.link,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'technologies': technologies,
      'role': role,
      'link': link,
    };
  }

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      technologies: List<String>.from(map['technologies'] ?? []),
      role: map['role'] ?? '',
      link: map['link'],
    );
  }
}

class Certification {
  final String name;
  final String organization;
  final DateTime issueDate;
  final DateTime? expiryDate;
  final String? credentialUrl;

  const Certification({
    required this.name,
    required this.organization,
    required this.issueDate,
    this.expiryDate,
    this.credentialUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'organization': organization,
      'issueDate': issueDate.toIso8601String(),
      'expiryDate': expiryDate?.toIso8601String(),
      'credentialUrl': credentialUrl,
    };
  }

  factory Certification.fromMap(Map<String, dynamic> map) {
    return Certification(
      name: map['name'] ?? '',
      organization: map['organization'] ?? '',
      issueDate: _parseDate(map['issueDate']),
      expiryDate: _parseNullableDate(map['expiryDate']),
      credentialUrl: map['credentialUrl'],
    );
  }
}
