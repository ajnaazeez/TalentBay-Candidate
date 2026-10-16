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
    Map<String, dynamic> safeMap(dynamic val) {
      if (val is Map<String, dynamic>) return val;
      if (val is Map) return Map<String, dynamic>.from(val);
      return <String, dynamic>{};
    }

    final profileMap = safeMap(map['profile']);
    final contactMap = safeMap(map['contact']);
    final businessMap = safeMap(map['business']);
    final verificationMap = safeMap(map['verification']);
    final socialMap = safeMap(map['social']);
    final statsMap = safeMap(map['stats']);
    final settingsMap = safeMap(map['settings']);
    final metaMap = safeMap(map['meta']);

    // Fallbacks if document is flat or mixed:
    if (profileMap.isEmpty && map.containsKey('companyName')) {
      profileMap['companyName'] = map['companyName'];
      profileMap['logoUrl'] = map['logoUrl'] ?? map['companyLogoUrl'];
      profileMap['coverImageUrl'] = map['coverImageUrl'];
      profileMap['tagline'] = map['tagline'];
      profileMap['about'] = map['about'] ?? map['description'];
      profileMap['industry'] = map['industry'];
      profileMap['companyType'] = map['companyType'];
      profileMap['foundedYear'] = map['foundedYear'];
      profileMap['companySize'] = map['companySize'];
      profileMap['website'] = map['website'] ?? map['websiteUrl'];
    }

    if (contactMap.isEmpty) {
      if (map.containsKey('city')) contactMap['city'] = map['city'];
      if (map.containsKey('state')) contactMap['state'] = map['state'];
      if (map.containsKey('country')) contactMap['country'] = map['country'];
      if (map.containsKey('addressLine')) contactMap['addressLine'] = map['addressLine'] ?? map['address'];
      if (map.containsKey('email')) contactMap['email'] = map['email'];
      if (map.containsKey('phone')) contactMap['phone'] = map['phone'] ?? map['phoneNumber'];
      if (map.containsKey('location')) contactMap['location'] = map['location'];
    }

    if (verificationMap.isEmpty && map.containsKey('isVerified')) {
      verificationMap['isVerified'] = map['isVerified'];
      verificationMap['status'] = map['verificationStatus'] ?? (map['isVerified'] == true ? 'verified' : 'unverified');
    }

    if (statsMap.isEmpty) {
      if (map.containsKey('totalJobs')) statsMap['totalJobs'] = map['totalJobs'];
      if (map.containsKey('activeJobs')) statsMap['activeJobs'] = map['activeJobs'];
      if (map.containsKey('totalApplicants')) statsMap['totalApplicants'] = map['totalApplicants'];
    }

    if (metaMap.isEmpty) {
      if (map.containsKey('createdAt')) metaMap['createdAt'] = map['createdAt'];
      if (map.containsKey('updatedAt')) metaMap['updatedAt'] = map['updatedAt'];
      if (map.containsKey('isActive')) metaMap['isActive'] = map['isActive'];
      if (map.containsKey('createdBy')) metaMap['createdBy'] = map['createdBy'];
    }

    return CompanyModel(
      id: id,
      profile: CompanyProfile.fromMap(profileMap),
      contact: CompanyContact.fromMap(contactMap),
      business: CompanyBusiness.fromMap(businessMap),
      verification: CompanyVerification.fromMap(verificationMap),
      social: CompanySocial.fromMap(socialMap),
      stats: CompanyStats.fromMap(statsMap),
      settings: CompanySettings.fromMap(settingsMap),
      meta: CompanyMeta.fromMap(metaMap),
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
    int? parseFoundedYear(dynamic val) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val);
      return null;
    }

    return CompanyProfile(
      companyName: map['companyName']?.toString() ?? '',
      logoUrl: map['logoUrl']?.toString() ?? '',
      coverImageUrl: map['coverImageUrl']?.toString() ?? '',
      tagline: map['tagline']?.toString() ?? '',
      about: map['about']?.toString() ?? '',
      industry: map['industry']?.toString() ?? '',
      companyType: map['companyType']?.toString() ?? '',
      foundedYear: parseFoundedYear(map['foundedYear']),
      companySize: map['companySize']?.toString() ?? '',
      website: map['website']?.toString() ?? '',
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
    List<CompanyAddress> parseOffices(dynamic val) {
      if (val is! List) return const [];
      final offices = <CompanyAddress>[];
      for (final item in val) {
        if (item is Map) {
          try {
            offices.add(CompanyAddress.fromMap(Map<String, dynamic>.from(item)));
          } catch (_) {}
        }
      }
      return offices;
    }

    return CompanyContact(
      email: map['email']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      addressLine: map['addressLine']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      state: map['state']?.toString() ?? '',
      country: map['country']?.toString() ?? '',
      postalCode: map['postalCode']?.toString() ?? '',
      location: map['location'] is GeoPoint ? map['location'] as GeoPoint : null,
      additionalOffices: parseOffices(map['additionalOffices']),
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
    List<String> parseStrings(dynamic val) {
      if (val is! List) return const [];
      return val
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }

    return CompanyBusiness(
      registrationNumber: map['registrationNumber']?.toString() ?? '',
      gstOrTaxId: map['gstOrTaxId']?.toString() ?? '',
      ownershipType: map['ownershipType']?.toString() ?? '',
      operatingHours: map['operatingHours']?.toString() ?? '',
      remoteFriendly: map['remoteFriendly'] == true ||
          map['remoteFriendly']?.toString().toLowerCase() == 'true',
      hiringRegions: parseStrings(map['hiringRegions']),
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
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return null;
    }

    List<String> parseStrings(dynamic val) {
      if (val is! List) return const [];
      return val
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }

    return CompanyVerification(
      isVerified: map['isVerified'] == true ||
          map['isVerified']?.toString().toLowerCase() == 'true',
      verifiedBy: map['verifiedBy']?.toString() ?? '',
      verifiedAt: parseDate(map['verifiedAt']),
      documents: parseStrings(map['documents']),
      status: map['status']?.toString() ?? 'pending',
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
      linkedin: map['linkedin']?.toString() ?? '',
      twitter: map['twitter']?.toString() ?? '',
      facebook: map['facebook']?.toString() ?? '',
      instagram: map['instagram']?.toString() ?? '',
      github: map['github']?.toString() ?? '',
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
    int parseInt(dynamic val) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    return CompanyStats(
      totalJobs: parseInt(map['totalJobs']),
      activeJobs: parseInt(map['activeJobs']),
      totalApplicants: parseInt(map['totalApplicants']),
      profileViews: parseInt(map['profileViews']),
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
    bool parseBool(dynamic val, bool fallback) {
      if (val is bool) return val;
      if (val is String) {
        if (val.toLowerCase() == 'true') return true;
        if (val.toLowerCase() == 'false') return false;
      }
      return fallback;
    }

    return CompanySettings(
      allowPublicView: parseBool(map['allowPublicView'], true),
      allowMessages: parseBool(map['allowMessages'], true),
      showContactInfo: parseBool(map['showContactInfo'], true),
      autoApproveJobs: parseBool(map['autoApproveJobs'], false),
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
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    bool parseBool(dynamic val, bool fallback) {
      if (val is bool) return val;
      if (val is String) {
        if (val.toLowerCase() == 'true') return true;
        if (val.toLowerCase() == 'false') return false;
      }
      return fallback;
    }

    return CompanyMeta(
      createdBy: map['createdBy']?.toString() ?? '',
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      isActive: parseBool(map['isActive'], true),
      isBlocked: parseBool(map['isBlocked'], false),
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
