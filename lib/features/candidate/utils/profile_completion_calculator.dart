import '../../auth/models/candidate_model.dart';

class ProfileCompletionCalculator {
  /// Calculates the profile completion percentage based on filled fields
  /// Returns a value between 0.0 and 1.0
  static double calculate(CandidateModel candidate) {
    int totalFields = 0;
    int filledFields = 0;

    // Basic Info (Weight: 30%)
    totalFields += 6;
    if (candidate.firstName != null && candidate.firstName!.isNotEmpty) {
      filledFields++;
    }
    if (candidate.lastName != null && candidate.lastName!.isNotEmpty) {
      filledFields++;
    }
    if (candidate.phoneNumber != null && candidate.phoneNumber!.isNotEmpty) {
      filledFields++;
    }
    if (candidate.photoUrl != null && candidate.photoUrl!.isNotEmpty) {
      filledFields++;
    }
    if (candidate.dob != null) filledFields++;
    if (candidate.gender != null && candidate.gender!.isNotEmpty) {
      filledFields++;
    }

    // Location & Nationality (Weight: 10%)
    totalFields += 2;
    if (candidate.currentLocation != null) filledFields++;
    if (candidate.nationality != null && candidate.nationality!.isNotEmpty) {
      filledFields++;
    }

    // Professional Summary (Weight: 15%)
    totalFields += 2;
    if (candidate.bio != null && candidate.bio!.isNotEmpty) filledFields++;
    if (candidate.aboutMe != null && candidate.aboutMe!.isNotEmpty) {
      filledFields++;
    }

    // Skills (Weight: 10%)
    totalFields += 1;
    if (candidate.skills.isNotEmpty) filledFields++;

    // Experience (Weight: 15%)
    totalFields += 1;
    if (candidate.workExperience.isNotEmpty) filledFields++;

    // Education (Weight: 10%)
    totalFields += 1;
    if (candidate.education.isNotEmpty) filledFields++;

    // Job Preferences (Weight: 5%)
    totalFields += 1;
    if (candidate.jobPreference != null) filledFields++;

    // Resume & Links (Weight: 5%)
    totalFields += 1;
    if (candidate.resumeUrl != null && candidate.resumeUrl!.isNotEmpty) {
      filledFields++;
    }

    // Calculate percentage
    if (totalFields == 0) return 0.0;
    return filledFields / totalFields;
  }

  /// Returns a list of missing fields for profile completion
  static List<String> getMissingFields(CandidateModel candidate) {
    List<String> missing = [];

    if (candidate.firstName == null || candidate.firstName!.isEmpty) {
      missing.add('First Name');
    }
    if (candidate.lastName == null || candidate.lastName!.isEmpty) {
      missing.add('Last Name');
    }
    if (candidate.phoneNumber == null || candidate.phoneNumber!.isEmpty) {
      missing.add('Phone Number');
    }
    if (candidate.photoUrl == null || candidate.photoUrl!.isEmpty) {
      missing.add('Profile Photo');
    }
    if (candidate.dob == null) {
      missing.add('Date of Birth');
    }
    if (candidate.gender == null || candidate.gender!.isEmpty) {
      missing.add('Gender');
    }
    if (candidate.currentLocation == null) {
      missing.add('Current Location');
    }
    if (candidate.nationality == null || candidate.nationality!.isEmpty) {
      missing.add('Nationality');
    }
    if (candidate.bio == null || candidate.bio!.isEmpty) {
      missing.add('CV Headline');
    }
    if (candidate.aboutMe == null || candidate.aboutMe!.isEmpty) {
      missing.add('About Me');
    }
    if (candidate.skills.isEmpty) {
      missing.add('Skills');
    }
    if (candidate.workExperience.isEmpty) {
      missing.add('Work Experience');
    }
    if (candidate.education.isEmpty) {
      missing.add('Education');
    }
    if (candidate.jobPreference == null) {
      missing.add('Job Preferences');
    }
    if (candidate.resumeUrl == null || candidate.resumeUrl!.isEmpty) {
      missing.add('Resume');
    }

    return missing;
  }
}
