import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meditwin_ai/services/ai_service.dart';

void main() {
  test('AiService.askAssistant works with mock server', () async {
    // Start a simple HTTP server
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;

    server.listen((HttpRequest req) async {
      if (req.method == 'POST' && req.uri.path.endsWith('/api/generate')) {
        final body = await utf8.decoder.bind(req).join();
        expect(body, contains('Hello'));
        // respond with a JSON structure containing 'response'
        final resp = {'response': 'Mock reply to your prompt'};
        req.response.statusCode = 200;
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode(resp));
        await req.response.close();
      } else {
        req.response.statusCode = 404;
        await req.response.close();
      }
    });

    final service = AiService();
    final apiUrl = '127.0.0.1:$port';
    final reply = await service.askAssistant(prompt: 'Hello', apiUrl: apiUrl, memoryHints: [], chatMode: 'general');

    expect(reply.toLowerCase(), contains('mock reply'));

    await server.close(force: true);
  });
}
