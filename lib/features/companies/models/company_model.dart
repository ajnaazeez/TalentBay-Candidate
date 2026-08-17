import 'package:cloud_firestore/cloud_firestore.dart';

class CompanyModel {
  final String? id;
  // Core Sections
  final CompanyProfile profile;
  final CompanyContact contact;
  final CompanyBusiness business;
  final CompanyVerification verification;
  final CompanySocial social;
  final CompanyStats stats;
  final CompanySettings settings;
  final CompanyMeta meta;

  CompanyModel({
    this.id,
    required this.profile,
    required this.contact,
    required this.business,
    required this.verification,
    required this.social,
    required this.stats,
    required this.settings,
    required this.meta,
  });

  Map<String, dynamic> toMap() {
    return {
      'profile': profile.toMap(),
      'contact': contact.toMap(),
      'business': business.toMap(),
      'verification': verification.toMap(),
      'social': social.toMap(),
      'stats': stats.toMap(),
      'settings': settings.toMap(),
      'meta': meta.toMap(),
    };
  }

  factory CompanyModel.fromMap(Map<String, dynamic> map, String id) {
    return CompanyModel(
      id: id,
      profile: CompanyProfile.fromMap(map['profile'] ?? {}),
      contact: CompanyContact.fromMap(map['contact'] ?? {}),
      business: CompanyBusiness.fromMap(map['business'] ?? {}),
      verification: CompanyVerification.fromMap(map['verification'] ?? {}),
      social: CompanySocial.fromMap(map['social'] ?? {}),
      stats: CompanyStats.fromMap(map['stats'] ?? {}),
      settings: CompanySettings.fromMap(map['settings'] ?? {}),
      meta: CompanyMeta.fromMap(map['meta'] ?? {}),
    );
  }

  CompanyModel copyWith({
    String? id,
    CompanyProfile? profile,
    CompanyContact? contact,
    CompanyBusiness? business,
    CompanyVerification? verification,
    CompanySocial? social,
    CompanyStats? stats,
    CompanySettings? settings,
    CompanyMeta? meta,
  }) {
    return CompanyModel(
      id: id ?? this.id,
      profile: profile ?? this.profile,
      contact: contact ?? this.contact,
      business: business ?? this.business,
      verification: verification ?? this.verification,
      social: social ?? this.social,
      stats: stats ?? this.stats,
      settings: settings ?? this.settings,
      meta: meta ?? this.meta,
    );
  }
}

class CompanyProfile {
  final String companyName;
  final String logoUrl;
  final String coverImageUrl;
  final String tagline;
  final String about;
  final String industry;
  final String companyType;
  final int? foundedYear;
  final String companySize;
  final String website;

  CompanyProfile({
    required this.companyName,
    required this.logoUrl,
    required this.coverImageUrl,
    required this.tagline,
    required this.about,
    required this.industry,
    required this.companyType,
    this.foundedYear,
    required this.companySize,
    required this.website,
  });

  Map<String, dynamic> toMap() {
    return {
      'companyName': companyName,
      'logoUrl': logoUrl,
      'coverImageUrl': coverImageUrl,
      'tagline': tagline,
      'about': about,
      'industry': industry,
      'companyType': companyType,
      'foundedYear': foundedYear,
      'companySize': companySize,
      'website': website,
    };
  }

  factory CompanyProfile.fromMap(Map<String, dynamic> map) {
    return CompanyProfile(
      companyName: map['companyName'] ?? '',
      logoUrl: map['logoUrl'] ?? '',
      coverImageUrl: map['coverImageUrl'] ?? '',
      tagline: map['tagline'] ?? '',
      about: map['about'] ?? '',
      industry: map['industry'] ?? '',
      companyType: map['companyType'] ?? '',
      foundedYear: map['foundedYear'],
      companySize: map['companySize'] ?? '',
      website: map['website'] ?? '',
    );
  }

  CompanyProfile copyWith({
    String? companyName,
    String? logoUrl,
    String? coverImageUrl,
    String? tagline,
    String? about,
    String? industry,
    String? companyType,
    int? foundedYear,
    String? companySize,
    String? website,
  }) {
    return CompanyProfile(
      companyName: companyName ?? this.companyName,
      logoUrl: logoUrl ?? this.logoUrl,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      tagline: tagline ?? this.tagline,
      about: about ?? this.about,
      industry: industry ?? this.industry,
      companyType: companyType ?? this.companyType,
      foundedYear: foundedYear ?? this.foundedYear,
      companySize: companySize ?? this.companySize,
      website: website ?? this.website,
    );
  }
}

class CompanyContact {
  final String email;
  final String phone;
  final String addressLine; // Primary address line
  final String city;
  final String state;
  final String country;
  final String postalCode;
  final GeoPoint? location;
  final List<CompanyAddress> additionalOffices; // For multiple locations

  CompanyContact({
    required this.email,
    required this.phone,
    required this.addressLine,
    required this.city,
    required this.state,
    required this.country,
    required this.postalCode,
    this.location,
    this.additionalOffices = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'phone': phone,
      'addressLine': addressLine,
      'city': city,
      'state': state,
      'country': country,
      'postalCode': postalCode,
      'location': location,
      'additionalOffices': additionalOffices.map((e) => e.toMap()).toList(),
    };
  }

  factory CompanyContact.fromMap(Map<String, dynamic> map) {
    return CompanyContact(
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      addressLine: map['addressLine'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      country: map['country'] ?? '',
      postalCode: map['postalCode'] ?? '',
      location: map['location'],
      additionalOffices: List<CompanyAddress>.from(
        (map['additionalOffices'] ?? []).map((e) => CompanyAddress.fromMap(e)),
      ),
    );
  }

  CompanyContact copyWith({
    String? email,
    String? phone,
    String? addressLine,
    String? city,
    String? state,
    String? country,
    String? postalCode,
    GeoPoint? location,
    List<CompanyAddress>? additionalOffices,
  }) {
    return CompanyContact(
      email: email ?? this.email,
      phone: phone ?? this.phone,
      addressLine: addressLine ?? this.addressLine,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      postalCode: postalCode ?? this.postalCode,
      location: location ?? this.location,
      additionalOffices: additionalOffices ?? this.additionalOffices,
    );
  }
}

// Reusing/updating CompanyAddress for the list of additional offices
class CompanyAddress {
  final String street;
  final String city;
  final String state;
  final String country;
  final String pincode;

  CompanyAddress({
    required this.street,
    required this.city,
    required this.state,
    required this.country,
    required this.pincode,
  });

  Map<String, dynamic> toMap() {
    return {
      'street': street,
      'city': city,
      'state': state,
      'country': country,
      'pincode': pincode,
    };
  }

  factory CompanyAddress.fromMap(Map<String, dynamic> map) {
    return CompanyAddress(
      street: map['street'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      country: map['country'] ?? '',
      pincode: map['pincode'] ?? '',
    );
  }
}

class CompanyBusiness {
  final String registrationNumber;
  final String gstOrTaxId;
  final String ownershipType; // Private / Public / NGO
  final String operatingHours;
  final bool remoteFriendly;
  final List<String> hiringRegions;

  CompanyBusiness({
    required this.registrationNumber,
    required this.gstOrTaxId,
    required this.ownershipType,
    required this.operatingHours,
    required this.remoteFriendly,
    required this.hiringRegions,
  });

  Map<String, dynamic> toMap() {
    return {
      'registrationNumber': registrationNumber,
      'gstOrTaxId': gstOrTaxId,
      'ownershipType': ownershipType,
      'operatingHours': operatingHours,
      'remoteFriendly': remoteFriendly,
      'hiringRegions': hiringRegions,
    };
  }

  factory CompanyBusiness.fromMap(Map<String, dynamic> map) {
    return CompanyBusiness(
      registrationNumber: map['registrationNumber'] ?? '',
      gstOrTaxId: map['gstOrTaxId'] ?? '',
      ownershipType: map['ownershipType'] ?? '',
      operatingHours: map['operatingHours'] ?? '',
      remoteFriendly: map['remoteFriendly'] ?? false,
      hiringRegions: List<String>.from(map['hiringRegions'] ?? []),
    );
  }

  CompanyBusiness copyWith({
    String? registrationNumber,
    String? gstOrTaxId,
    String? ownershipType,
    String? operatingHours,
    bool? remoteFriendly,
    List<String>? hiringRegions,
  }) {
    return CompanyBusiness(
      registrationNumber: registrationNumber ?? this.registrationNumber,
      gstOrTaxId: gstOrTaxId ?? this.gstOrTaxId,
      ownershipType: ownershipType ?? this.ownershipType,
      operatingHours: operatingHours ?? this.operatingHours,
      remoteFriendly: remoteFriendly ?? this.remoteFriendly,
      hiringRegions: hiringRegions ?? this.hiringRegions,
    );
  }
}

class CompanyVerification {
  final bool isVerified;
  final String verifiedBy;
  final DateTime? verifiedAt;
  final List<String> documents;
  final String status; // pending / approved / rejected

  CompanyVerification({
    required this.isVerified,
    required this.verifiedBy,
    this.verifiedAt,
    required this.documents,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'isVerified': isVerified,
      'verifiedBy': verifiedBy,
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      'documents': documents,
      'status': status,
    };
  }

  factory CompanyVerification.fromMap(Map<String, dynamic> map) {
    return CompanyVerification(
      isVerified: map['isVerified'] ?? false,
      verifiedBy: map['verifiedBy'] ?? '',
      verifiedAt: (map['verifiedAt'] as Timestamp?)?.toDate(),
      documents: List<String>.from(map['documents'] ?? []),
      status: map['status'] ?? 'pending',
    );
  }

  CompanyVerification copyWith({
    bool? isVerified,
    String? verifiedBy,
    DateTime? verifiedAt,
    List<String>? documents,
    String? status,
  }) {
    return CompanyVerification(
      isVerified: isVerified ?? this.isVerified,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      documents: documents ?? this.documents,
      status: status ?? this.status,
    );
  }
}

class CompanySocial {
  final String linkedin;
  final String twitter;
  final String facebook;
  final String instagram;
  final String github;

  CompanySocial({
    this.linkedin = '',
    this.twitter = '',
    this.facebook = '',
    this.instagram = '',
    this.github = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'linkedin': linkedin,
      'twitter': twitter,
      'facebook': facebook,
      'instagram': instagram,
      'github': github,
    };
  }

  factory CompanySocial.fromMap(Map<String, dynamic> map) {
    return CompanySocial(
      linkedin: map['linkedin'] ?? '',
      twitter: map['twitter'] ?? '',
      facebook: map['facebook'] ?? '',
      instagram: map['instagram'] ?? '',
      github: map['github'] ?? '',
    );
  }

  CompanySocial copyWith({
    String? linkedin,
    String? twitter,
    String? facebook,
    String? instagram,
    String? github,
  }) {
    return CompanySocial(
      linkedin: linkedin ?? this.linkedin,
      twitter: twitter ?? this.twitter,
      facebook: facebook ?? this.facebook,
      instagram: instagram ?? this.instagram,
      github: github ?? this.github,
    );
  }
}

class CompanyStats {
  final int totalJobs;
  final int activeJobs;
  final int totalApplicants;
  final int profileViews;

  CompanyStats({
    this.totalJobs = 0,
    this.activeJobs = 0,
    this.totalApplicants = 0,
    this.profileViews = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'totalJobs': totalJobs,
      'activeJobs': activeJobs,
      'totalApplicants': totalApplicants,
      'profileViews': profileViews,
    };
  }

  factory CompanyStats.fromMap(Map<String, dynamic> map) {
    return CompanyStats(
      totalJobs: map['totalJobs'] ?? 0,
      activeJobs: map['activeJobs'] ?? 0,
      totalApplicants: map['totalApplicants'] ?? 0,
      profileViews: map['profileViews'] ?? 0,
    );
  }
}

class CompanySettings {
  final bool allowPublicView;
  final bool allowMessages;
  final bool showContactInfo;
  final bool autoApproveJobs;

  CompanySettings({
    this.allowPublicView = true,
    this.allowMessages = true,
    this.showContactInfo = true,
    this.autoApproveJobs = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'allowPublicView': allowPublicView,
      'allowMessages': allowMessages,
      'showContactInfo': showContactInfo,
      'autoApproveJobs': autoApproveJobs,
    };
  }

  factory CompanySettings.fromMap(Map<String, dynamic> map) {
    return CompanySettings(
      allowPublicView: map['allowPublicView'] ?? true,
      allowMessages: map['allowMessages'] ?? true,
      showContactInfo: map['showContactInfo'] ?? true,
      autoApproveJobs: map['autoApproveJobs'] ?? false,
    );
  }

  CompanySettings copyWith({
    bool? allowPublicView,
    bool? allowMessages,
    bool? showContactInfo,
    bool? autoApproveJobs,
  }) {
    return CompanySettings(
      allowPublicView: allowPublicView ?? this.allowPublicView,
      allowMessages: allowMessages ?? this.allowMessages,
      showContactInfo: showContactInfo ?? this.showContactInfo,
      autoApproveJobs: autoApproveJobs ?? this.autoApproveJobs,
    );
  }
}

class CompanyMeta {
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final bool isBlocked;

  CompanyMeta({
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.isBlocked = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
      'isBlocked': isBlocked,
    };
  }

  factory CompanyMeta.fromMap(Map<String, dynamic> map) {
    return CompanyMeta(
      createdBy: map['createdBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] ?? true,
      isBlocked: map['isBlocked'] ?? false,
    );
  }

  CompanyMeta copyWith({
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    bool? isBlocked,
  }) {
    return CompanyMeta(
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      isBlocked: isBlocked ?? this.isBlocked,
    );
  }
}
