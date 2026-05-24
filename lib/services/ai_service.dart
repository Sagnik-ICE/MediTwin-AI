import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'emergency_service.dart';
import '../models/chat_message.dart';
import '../utils/debug_logger.dart';

class AiService {
  // Quality-first local model order. The quantized 8B model is the default
  // balance for natural health conversation on a laptop. Smaller 4B is only a
  // fallback if the preferred model is not installed.
  static const List<String> _preferredModels = [
    'qwen3:8b-q4_K_M',
    'qwen3:8b',
    'qwen3:4b',
  ];

  static const Duration _requestTimeout = Duration(seconds: 75);
  static const Duration _testTimeout = Duration(seconds: 10);

  Future<String> askAssistant({
    required String prompt,
    required String apiUrl,
    required List<String> memoryHints,
    required String chatMode,
    List<ChatMessage> conversationHistory = const [],
  }) async {
    if (EmergencyService.hasEmergencyKeywords(prompt)) {
      return EmergencyService.emergencyWarning;
    }

    final uri = _normalizeEndpoint(apiUrl);
    if (uri == null) {
      return fallbackConnectionMessage;
    }

    Object? lastError;

    for (final model in _preferredModels) {
      try {
        DebugLogger.debug('Sending natural AI chat request to $uri with $model');
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(_buildChatRequest(
                model: model,
                userPrompt: prompt,
                chatMode: chatMode,
                memoryHints: memoryHints,
                conversationHistory: conversationHistory,
              )),
            )
            .timeout(_requestTimeout);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final raw = _extractAssistantText(decoded);
          final formatted = _formatConversationalReply(raw);
          if (formatted.isNotEmpty) {
            return formatted;
          }
          DebugLogger.warning('AI response did not contain usable assistant text', response.body);
          continue;
        }

        final body = response.body.toLowerCase();
        if (response.statusCode == 404 || body.contains('model') && body.contains('not found')) {
          lastError = 'Ollama model $model was not available';
          DebugLogger.warning('Ollama model $model was not available. Trying fallback model.');
          continue;
        }

        DebugLogger.warning('AI request failed with status ${response.statusCode}', response.body);
        lastError = 'HTTP ${response.statusCode}';
        break;
      } on TimeoutException catch (e) {
        lastError = e;
        DebugLogger.warning('AI request timed out for model $model', e);
        break;
      } catch (e, st) {
        lastError = e;
        DebugLogger.warning('AI request failed for model $model', e);
        DebugLogger.debug(st.toString());
        break;
      }
    }

    final modelHint = _preferredModels.join(', ');
    return '$fallbackConnectionMessage\n\nIf you are using this app on a phone, open Settings > AI Connect and paste the Cloudflare Tunnel URL ending with /api/chat. Also make sure Ollama is running and at least one model is available: $modelHint.${lastError == null ? '' : '\n\nLast error: $lastError'}';
  }

  Future<bool> testConnection(String apiUrl) async {
    final uri = _normalizeEndpoint(apiUrl);
    if (uri == null) {
      return false;
    }

    // First verify the Ollama server itself. This is more reliable for
    // Cloudflare Tunnel because it proves the tunnel reaches Ollama even before
    // a specific model is loaded.
    final serverReachable = await _testOllamaServer(uri);
    if (serverReachable) {
      return true;
    }

    // Fallback: some proxies may block GET-style checks but still allow /api/chat.
    for (final model in _preferredModels) {
      try {
        final response = await http
            .post(
              uri,
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode({
                'model': model,
                'stream': false,
                'think': false,
                'keep_alive': '45m',
                'messages': [
                  {'role': 'user', 'content': 'Reply with exactly one word: ok'},
                ],
                'options': {
                  'num_predict': 8,
                  'num_ctx': 256,
                  'temperature': 0,
                },
              }),
            )
            .timeout(_testTimeout);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return true;
        }
      } catch (e) {
        DebugLogger.warning('AI connection test failed for model $model', e);
      }
    }

    return false;
  }

  Future<bool> _testOllamaServer(Uri chatUri) async {
    final rootUri = chatUri.replace(path: '/', query: null, fragment: null);
    final tagsUri = chatUri.replace(path: '/api/tags', query: null, fragment: null);

    try {
      final rootResponse = await http.get(rootUri).timeout(const Duration(seconds: 8));
      if (rootResponse.statusCode < 200 || rootResponse.statusCode >= 500) {
        DebugLogger.warning('Ollama root check failed with status ${rootResponse.statusCode}', rootResponse.body);
        return false;
      }

      final tagsResponse = await http.get(tagsUri).timeout(const Duration(seconds: 8));
      if (tagsResponse.statusCode >= 200 && tagsResponse.statusCode < 300) {
        return true;
      }

      DebugLogger.warning('Ollama tags check failed with status ${tagsResponse.statusCode}', tagsResponse.body);
      return false;
    } catch (e) {
      DebugLogger.warning('Ollama server reachability check failed', e);
      return false;
    }
  }

  Uri? _normalizeEndpoint(String apiUrl) {
    final rawInput = apiUrl.trim().isEmpty ? 'http://127.0.0.1:11434/api/chat' : apiUrl.trim();

    // Remove accidental spaces/newlines from copied tunnel URLs.
    final raw = rawInput.replaceAll(RegExp(r'\s+'), '');
    final lower = raw.toLowerCase();
    final hasScheme = lower.startsWith('http://') || lower.startsWith('https://');

    final withScheme = hasScheme
        ? raw
        : lower.contains('trycloudflare.com') || lower.contains('cfargotunnel.com')
            ? 'https://$raw'
            : 'http://$raw';

    final parsed = Uri.tryParse(withScheme);
    if (parsed == null || parsed.host.trim().isEmpty) {
      return null;
    }

    return parsed.replace(path: '/api/chat', query: null, fragment: null);
  }

  Map<String, dynamic> _buildChatRequest({
    required String model,
    required String userPrompt,
    required String chatMode,
    required List<String> memoryHints,
    required List<ChatMessage> conversationHistory,
  }) {
    final memory = memoryHints.where((e) => e.trim().isNotEmpty).take(12).join(' | ');
    final messages = _buildConversationMessages(
      userPrompt: userPrompt,
      chatMode: chatMode,
      memory: memory,
      conversationHistory: conversationHistory,
    );

    return {
      'model': model,
      'stream': false,
      'think': false,
      'keep_alive': '45m',
      'messages': messages,
      'options': {
        'num_predict': 260,
        'num_ctx': 4096,
        'temperature': 0.42,
        'top_p': 0.90,
        'top_k': 45,
        'repeat_penalty': 1.16,
      },
    };
  }

  List<Map<String, String>> _buildConversationMessages({
    required String userPrompt,
    required String chatMode,
    required String memory,
    required List<ChatMessage> conversationHistory,
  }) {
    final followUpContext = _shortFollowUpContext(userPrompt, conversationHistory);

    final messages = <Map<String, String>>[
      {
        'role': 'system',
        'content': '''
/no_think
You are MediTwin, a premium health and wellness assistant inside a health tracking app.
Chat like a skilled human health assistant: fluent, direct, context-aware, and calm.

Core behavior:
- Treat the chat as one continuous conversation. Do not answer each message as a new isolated question.
- If the user gives a short reply such as "yes", "no", "ok", "a little", "since yesterday", or "minimal nausea", interpret it as an answer to your previous question.
- When the user only acknowledges advice, reply briefly. Do not repeat the previous plan.
- When the user adds a detail, update the earlier guidance rather than starting over.
- Ask at most one follow-up question, and only when it would change the next advice.
- Use recent health tracking context and remembered chat details as background, but do not overstate certainty.
- If the user gives a short answer, connect it to the previous assistant question and the remembered context.
- Use English unless the user writes in another language.

Medical safety:
- Do not diagnose. Use careful phrases like "could be", "may be related to", or "one possibility is".
- Give practical next steps that are safe and realistic.
- Mention urgent-care warning signs only when they are relevant to the user's symptoms.
- Do not mention being an AI model.
- Do not expose hidden reasoning.

Style:
- Be conversational, not template-driven.
- Avoid fixed headings in normal replies.
- Avoid repeating the exact same bullets from the previous assistant message.
- Use bullets only if there are several clear actions.
- Keep most replies between 2 and 7 short sentences.
- Do not use markdown headings, bold markers, hashtags, tables, emojis, or numbered formats.
- Never output JSON.

Example of good follow-up handling:
User: I feel dizzy.
Assistant: Dizziness can come from dehydration, low food intake, poor sleep, stress, or inner-ear irritation. Sit or lie down for a bit, drink water slowly, and avoid standing up quickly. Are you also feeling nausea, chest pain, weakness, or blurred vision?
User: yes nausea.
Assistant: Since the dizziness is now paired with nausea, rest in a quiet place, take small sips of water, and avoid sudden head movement. If you start vomiting repeatedly, feel faint, develop chest pain, severe headache, weakness, or confusion, get urgent medical care. Did this start suddenly or gradually?
User: ok I understand.
Assistant: Good. Monitor it for now, and update me if it gets worse or a new symptom appears.
''',
      },
      {
        'role': 'system',
        'content': 'Mode: $chatMode. User context and remembered health details: ${memory.isEmpty ? 'No useful context available.' : memory}',
      },
    ];

    if (followUpContext.isNotEmpty) {
      messages.add({
        'role': 'system',
        'content': followUpContext,
      });
    }

    final recent = conversationHistory
        .where((message) => message.text.trim().isNotEmpty && !message.isError)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final tail = recent.length > 16 ? recent.sublist(recent.length - 16) : recent;
    for (final message in tail) {
      messages.add({
        'role': message.isUser ? 'user' : 'assistant',
        'content': _compactHistoryText(message.text),
      });
    }

    if (messages.last['role'] != 'user' || messages.last['content']?.trim() != userPrompt.trim()) {
      messages.add({'role': 'user', 'content': userPrompt.trim()});
    }

    return messages;
  }

  String _shortFollowUpContext(String userPrompt, List<ChatMessage> conversationHistory) {
    if (!_looksLikeShortFollowUp(userPrompt)) return '';

    final recent = conversationHistory
        .where((message) => message.text.trim().isNotEmpty && !message.isError)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    String? lastAssistantQuestion;
    String? previousUserIssue;

    for (var i = recent.length - 1; i >= 0; i--) {
      final message = recent[i];
      if (!message.isUser && lastAssistantQuestion == null) {
        lastAssistantQuestion = _lastQuestionFrom(message.text);
      }
      if (message.isUser && message.text.trim() != userPrompt.trim() && previousUserIssue == null) {
        previousUserIssue = message.text.trim();
      }
      if (lastAssistantQuestion != null && previousUserIssue != null) break;
    }

    if (lastAssistantQuestion == null && previousUserIssue == null) return '';

    return 'The current user message is probably a brief follow-up, not a new topic. '
        '${lastAssistantQuestion == null ? '' : 'It appears to answer your previous question: "$lastAssistantQuestion". '}'
        '${previousUserIssue == null ? '' : 'The earlier user concern was: "$previousUserIssue". '}'
        'Do not repeat the full previous response; continue naturally from this context.';
  }

  bool _looksLikeShortFollowUp(String value) {
    final normalized = value.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    final words = normalized.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (words.length <= 4) return true;

    const followUpPhrases = [
      'yes',
      'no',
      'ok',
      'okay',
      'understood',
      'i understand',
      'a little',
      'minimal',
      'mild',
      'since yesterday',
      'from yesterday',
      'today',
      'not much',
      'sometimes',
    ];

    return followUpPhrases.any((phrase) => normalized.contains(phrase));
  }

  String? _lastQuestionFrom(String value) {
    final clean = _sanitizeFreeText(value);
    final questionMatches = RegExp(r'([^.!?\n]*\?+)').allMatches(clean).toList();
    if (questionMatches.isEmpty) return null;
    final last = questionMatches.last.group(1)?.trim();
    if (last == null || last.isEmpty) return null;
    return last.length > 220 ? '${last.substring(0, 220).trim()}...' : last;
  }

  String _compactHistoryText(String raw) {
    var text = _stripThinking(raw);
    text = text.replaceAll(RegExp(r'^[ \t]*(Brief assessment|Assessment|Summary|What you can do now|Next steps|Seek care urgently if|Watch for|Red flags|Question)[ \t]*:?\s*', multiLine: true, caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'^[ \t]*[-*•][ \t]*', multiLine: true), '');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    if (text.length <= 1400) return text;
    return text.substring(text.length - 1400).trim();
  }

  String _extractAssistantText(Map<String, dynamic> decoded) {
    final message = decoded['message'];
    if (message is Map<String, dynamic>) {
      final content = message['content'];
      if (content is String && content.trim().isNotEmpty) {
        return content.trim();
      }
    }

    final response = decoded['response'];
    if (response is String && response.trim().isNotEmpty) {
      return response.trim();
    }

    final content = decoded['content'];
    if (content is String && content.trim().isNotEmpty) {
      return content.trim();
    }

    return '';
  }

  String _formatConversationalReply(String raw) {
    final withoutThinking = _stripThinking(raw);
    if (withoutThinking.isEmpty) return '';

    final parsed = _tryDecodeObject(withoutThinking);
    if (parsed != null) {
      return _formatReplyObject(parsed);
    }

    return _finalPolish(_sanitizeFreeText(withoutThinking));
  }

  Map<String, dynamic>? _tryDecodeObject(String value) {
    final candidates = <String>[value.trim()];

    final firstBrace = value.indexOf('{');
    final lastBrace = value.lastIndexOf('}');
    if (firstBrace >= 0 && lastBrace > firstBrace) {
      candidates.add(value.substring(firstBrace, lastBrace + 1));
    }

    for (final candidate in candidates) {
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (_) {
        // Try the next candidate.
      }
    }

    return null;
  }

  String _formatReplyObject(Map<String, dynamic> data) {
    final reply = _cleanParagraph(data['reply']?.toString() ?? data['summary']?.toString() ?? '');
    final suggestions = _stringList(data['suggestions'] ?? data['actions'])
        .map(_cleanOneLine)
        .where((e) => e.isNotEmpty)
        .take(4)
        .toList();
    final urgent = _stringList(data['urgent'])
        .map(_cleanOneLine)
        .where((e) => e.isNotEmpty)
        .take(3)
        .toList();
    final followUp = _cleanParagraph(data['follow_up']?.toString() ?? data['question']?.toString() ?? '');

    final buffer = StringBuffer();

    if (reply.isNotEmpty) {
      buffer.writeln(reply);
    }

    if (suggestions.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.writeln();
      for (final item in suggestions) {
        buffer.writeln('- $item');
      }
    }

    if (urgent.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.writeln();
      if (urgent.length == 1) {
        buffer.writeln('Get urgent medical help if ${_lowercaseFirst(urgent.first)}');
      } else {
        buffer.writeln('Get urgent medical help if you notice any of these:');
        for (final item in urgent) {
          buffer.writeln('- $item');
        }
      }
    }

    if (followUp.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln(followUp);
    }

    return _finalPolish(buffer.toString().trim());
  }

  List<String> _stringList(Object? value) {
    if (value is List) {
      return value.map((item) => item?.toString() ?? '').toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      return [value];
    }
    return const [];
  }

  String _stripThinking(String value) {
    return value
        .replaceAll(RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '')
        .replaceAll(RegExp(r'</?think>', caseSensitive: false), '')
        .trim();
  }

  String _sanitizeFreeText(String raw) {
    var text = _stripThinking(raw);
    text = text.replaceAll(RegExp(r'^[ \t]*#{1,6}[ \t]*', multiLine: true), '');
    text = text.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');
    text = text.replaceAll(RegExp(r'__([^_]+)__'), r'$1');
    text = text.replaceAll(RegExp(r'^[ \t]*(\d+)[.)][ \t]*', multiLine: true), '');
    text = text.replaceAll(RegExp(r'^[ \t]*(Brief assessment|Assessment|Summary|What you can do now|Next steps|Seek care urgently if|Watch for|Red flags|Question)[ \t]*:?\s*', multiLine: true, caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'^(Assistant|MediTwin)\s*:\s*', caseSensitive: false, multiLine: true), '');
    text = text.replaceAll(RegExp(r'[ \t]+\n'), '\n');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  String _finalPolish(String value) {
    var text = value.trim();
    if (text.isEmpty) return text;

    text = text.replaceAll(RegExp(r'Get urgent medical help if\s+get urgent medical help if\s+', caseSensitive: false), 'Get urgent medical help if ');
    text = text.replaceAll(RegExp(r'\bif if\b', caseSensitive: false), 'if');
    text = text.replaceAll(RegExp(r'\s+([,.!?])'), r'$1');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    final paragraphs = text.split('\n\n').map((block) {
      final lines = block.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
      if (lines.isEmpty) return '';
      if (lines.every((line) => line.startsWith('- '))) {
        return lines.join('\n');
      }
      return lines.join(' ');
    }).where((block) => block.trim().isNotEmpty).join('\n\n');

    return paragraphs.trim();
  }

  String _cleanParagraph(String raw) {
    return _cleanOneLine(raw)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _cleanOneLine(String raw) {
    return raw
        .replaceAll(RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '')
        .replaceAll(RegExp(r'</?think>', caseSensitive: false), '')
        .replaceAll(RegExp(r'^[ \t]*[-*•\d.)]+[ \t]*'), '')
        .replaceAll(RegExp(r'^[ \t]*(Brief assessment|Assessment|Summary|What you can do now|Next steps|Seek care urgently if|Watch for|Red flags|Question)[ \t]*:?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1')
        .replaceAll(RegExp(r'__([^_]+)__'), r'$1')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _lowercaseFirst(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed[0].toLowerCase() + trimmed.substring(1);
  }

  /// Public fallback message used when the AI server cannot be reached.
  static const String fallbackConnectionMessage =
      'Unable to reach the configured AI server right now. Your health data is still saved.';
}
