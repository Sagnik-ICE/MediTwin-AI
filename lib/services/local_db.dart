import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/health_log.dart';
import '../utils/debug_logger.dart';

class LocalDb {
  static Directory? _appDocDir;
  static File? _healthFile;

  static Future<void> init() async {
    try {
      _appDocDir = await getApplicationDocumentsDirectory();
      _healthFile = File('${_appDocDir!.path}${Platform.pathSeparator}health_logs.json');
      if (!await _healthFile!.exists()) {
        await _healthFile!.writeAsString(jsonEncode([]));
      }
    } catch (e, st) {
      DebugLogger.warning('LocalDb.init failed', e);
      DebugLogger.debug(st.toString());
    }
  }

  static Future<List<HealthLog>> loadHealthLogs() async {
    try {
      if (_healthFile == null) await init();
      final content = await _healthFile!.readAsString();
      final list = jsonDecode(content) as List<dynamic>;
      return list.map((e) => HealthLog.fromMap(Map<String, dynamic>.from(e))).toList();
    } catch (e, st) {
      DebugLogger.warning('LocalDb.loadHealthLogs failed', e);
      DebugLogger.debug(st.toString());
      return [];
    }
  }

  static Future<void> saveHealthLogs(List<HealthLog> logs) async {
    try {
      if (_healthFile == null) await init();
      final list = logs.map((e) => e.toMap()).toList();
      await _healthFile!.writeAsString(jsonEncode(list));
    } catch (e, st) {
      DebugLogger.warning('LocalDb.saveHealthLogs failed', e);
      DebugLogger.debug(st.toString());
    }
  }

  static Future<void> appendHealthLog(HealthLog log) async {
    final current = await loadHealthLogs();
    final updated = [log, ...current];
    await saveHealthLogs(updated);
  }
}
