import '../constants/app_constants.dart';

class EmergencyService {
  static bool hasEmergencyKeywords(String input) {
    final text = _normalize(input);
    if (text.isEmpty) return false;

    return AppConstants.emergencyKeywords.any((keyword) {
      final normalizedKeyword = _normalize(keyword);
      if (normalizedKeyword.isEmpty) return false;
      return text.contains(normalizedKeyword);
    });
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[`’‘´]'), "'")
        .replaceAll(RegExp(r"[^\p{L}\p{N}\s']+", unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static const String emergencyWarning =
      'This may require urgent medical attention. Please contact local emergency services or visit the nearest hospital immediately. MediTwin AI cannot provide emergency diagnosis.';
}
