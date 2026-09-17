import 'package:cloud_firestore/cloud_firestore.dart';

DateTime _parseDate(dynamic val) {
  if (val is Timestamp) return val.toDate();
  if (val is String) {
    try {
      return DateTime.parse(val);
    } catch (_) {}
  }
  return DateTime.now();
}

DateTime? _parseNullableDate(dynamic val) {
  if (val == null) return null;
  if (val is Timestamp) return val.toDate();
  if (val is String) {
    try {
      return DateTime.parse(val);
    } catch (_) {}
  }
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
    double parseNum(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    return JobPreference(
      role: map['role']?.toString() ?? '',
      employmentType: map['employmentType']?.toString() ?? '',
      workMode: map['workMode']?.toString() ?? '',
      preferredLocations: (map['preferredLocations'] is List)
          ? (map['preferredLocations'] as List).where((e) => e != null).map((e) => e.toString()).toList()
          : <String>[],
      preferredIndustry: map['preferredIndustry']?.toString() ?? '',
      salaryCurrency: map['salaryCurrency']?.toString() ?? '',
      salaryMin: parseNum(map['salaryMin']),
      salaryMax: parseNum(map['salaryMax']),
      noticePeriod: map['noticePeriod']?.toString() ?? '',
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
      name: map['name']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      level: map['level']?.toString() ?? '',
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
      id: map['id']?.toString() ?? '',
      jobTitle: map['jobTitle']?.toString() ?? '',
      companyName: map['companyName']?.toString() ?? '',
      employmentType: map['employmentType']?.toString() ?? '',
      startDate: _parseDate(map['startDate']),
      endDate: _parseNullableDate(map['endDate']),
      isCurrent: map['isCurrent'] is bool ? map['isCurrent'] as bool : false,
      description: map['description']?.toString() ?? '',
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
    int parseInt(dynamic val) {
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    return Education(
      id: map['id']?.toString() ?? '',
      degree: map['degree']?.toString() ?? '',
      institution: map['institution']?.toString() ?? '',
      fieldOfStudy: map['fieldOfStudy']?.toString() ?? '',
      startYear: parseInt(map['startYear']),
      endYear: parseInt(map['endYear']),
      grade: map['grade']?.toString(),
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
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      technologies: (map['technologies'] is List)
          ? (map['technologies'] as List).where((e) => e != null).map((e) => e.toString()).toList()
          : <String>[],
      role: map['role']?.toString() ?? '',
      link: map['link']?.toString(),
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
      name: map['name']?.toString() ?? '',
      organization: map['organization']?.toString() ?? '',
      issueDate: _parseDate(map['issueDate']),
      expiryDate: _parseNullableDate(map['expiryDate']),
      credentialUrl: map['credentialUrl']?.toString(),
    );
  }
}
