import '../models/health_log.dart';

class SimulationService {
  SimulationService._();

  @Deprecated('Future Simulation has been removed from MediTwin AI.')
  static Map<String, dynamic> simulate({
    required String scenario,
    required List<HealthLog> history,
  }) {
    return const {
      'summary': 'Future Simulation has been removed from MediTwin AI.',
      'sevenDay': 'Unavailable',
      'thirtyDay': 'Unavailable',
      'ninetyDay': 'Unavailable',
      'risks': <String>[],
      'suggestions': <String>[],
    };
  }
}
