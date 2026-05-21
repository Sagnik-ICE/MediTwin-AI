import '../constants/app_constants.dart';

class EmergencyService {
  static bool hasEmergencyKeywords(String input) {
    final text = input.toLowerCase();
    return AppConstants.emergencyKeywords.any(text.contains);
  }

  static const String emergencyWarning =
      'This may require urgent medical attention. Please contact local emergency services or visit the nearest hospital immediately. MediTwin AI cannot provide emergency diagnosis.';
}
