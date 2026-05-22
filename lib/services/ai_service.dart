import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'emergency_service.dart';
import '../utils/debug_logger.dart';

class AiService {
  Future<String> askAssistant({
    required String prompt,
    required String apiUrl,
    required List<String> memoryHints,
    required String chatMode,
  }) async {
    if (EmergencyService.hasEmergencyKeywords(prompt)) {
      return EmergencyService.emergencyWarning;
    }
    final uri = _normalizeEndpoint(apiUrl);
    if (uri == null) {
      return fallbackConnectionMessage;
    }

    const maxAttempts = 3;
    int attempt = 0;
    while (attempt < maxAttempts) {
      try {
        DebugLogger.debug('Sending AI request to $uri (attempt ${attempt + 1})');
        final response = await http
            .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'model': 'qwen3:8b-q4_K_M',
            'stream': false,
            'temperature': 0.4,
            'top_p': 0.9,
            'prompt': _buildPrompt(
              userPrompt: prompt,
              chatMode: chatMode,
              memoryHints: memoryHints,
            ),
          }),
        )
            .timeout(const Duration(seconds: 20));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final text = _extractAssistantText(decoded);
          if (text.isNotEmpty) {
            return text;
          }
          DebugLogger.warning('AI response did not contain assistant text', response.body);
        } else {
          DebugLogger.warning('AI request failed with status ${response.statusCode}', response.body);
        }
      } catch (e, st) {
        DebugLogger.warning('AI request attempt ${attempt + 1} failed', e);
        DebugLogger.debug(st.toString());
      }

      attempt += 1;
      if (attempt < maxAttempts) {
        // exponential backoff: 500ms, 1000ms, ...
        final delayMs = 500 * (1 << (attempt - 1));
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    DebugLogger.warning('All AI request attempts failed; returning fallback message');
    return '$fallbackConnectionMessage\n\nTip: verify your endpoint and Ollama service.';
  }

  Future<bool> testConnection(String apiUrl) async {
    final uri = _normalizeEndpoint(apiUrl);
    if (uri == null) {
      return false;
    }

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'qwen3:8b-q4_K_M',
          'stream': false,
          'prompt': 'Reply with a single word: ok',
        }),
      ).timeout(const Duration(seconds: 10));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      DebugLogger.warning('AI connection test failed', e);
      return false;
    }
  }

  Uri? _normalizeEndpoint(String apiUrl) {
    final raw = apiUrl.trim();
    if (raw.isEmpty) {
      return null;
    }

    final withScheme = raw.startsWith('http://') || raw.startsWith('https://') ? raw : 'http://$raw';
    final parsed = Uri.tryParse(withScheme);
    if (parsed == null) {
      return null;
    }

    if (parsed.path.isEmpty || parsed.path == '/') {
      return parsed.replace(path: '/api/generate');
    }

    if (parsed.path.endsWith('/')) {
      return parsed.replace(path: '${parsed.path}api/generate');
    }

    return parsed;
  }

  String _buildPrompt({
    required String userPrompt,
    required String chatMode,
    required List<String> memoryHints,
  }) {
    final memory = memoryHints.where((e) => e.trim().isNotEmpty).join(' | ');
    return '''
You are a professional preventive healthcare assistant.
Mode: $chatMode

Rules:
- Prioritize accuracy over breadth. If uncertain, say what is uncertain.
- Never invent medical facts, doses, lab values, or diagnoses.
- Keep responses practical and personalized to the user's message and memory.
- Use simple language and short sections.
- Do not mention being an AI model.
- For emergencies (chest pain, stroke signs, severe breathing issues, self-harm risk), instruct immediate local emergency care.

Output format:
1) Brief assessment of likely concern
2) Action plan (3-6 specific steps)
3) Red flags: when to seek urgent care
4) One follow-up question if key details are missing

Memory: $memory
User message: $userPrompt
''';
  }

  String _extractAssistantText(Map<String, dynamic> decoded) {
    final raw = (decoded['response'] ?? decoded['message'] ?? '').toString();
    if (raw.isNotEmpty) {
      return raw;
    }

    if (decoded['content'] is String) {
      return decoded['content'] as String;
    }

    final choices = decoded['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map<String, dynamic>) {
        final message = first['message'];
        if (message is Map<String, dynamic>) {
          final content = message['content'];
          if (content is String) {
            return content;
          }
        }
        final text = first['text'];
        if (text is String) {
          return text;
        }
      }
    }

    return '';
  }

      /// Public fallback message used when the AI server cannot be reached.
      static const String fallbackConnectionMessage =
          'Unable to reach the AI assistant right now. Your health data is still saved.';
}
