import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class AiSetupScreen extends StatefulWidget {
  const AiSetupScreen({super.key});

  @override
  State<AiSetupScreen> createState() => _AiSetupScreenState();
}

class _AiSetupScreenState extends State<AiSetupScreen> {
  bool _testing = false;
  bool? _lastResult;

  Future<void> _testLocalOllama() async {
    if (_testing) return;
    setState(() {
      _testing = true;
      _lastResult = null;
    });

    final ok = await context.read<AppState>().testBackendConnection();
    if (!mounted) return;

    setState(() {
      _testing = false;
      _lastResult = ok;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Local Ollama is reachable.' : 'Could not reach local Ollama.'),
        backgroundColor: ok ? Colors.green : Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final endpoint = context.watch<AppState>().apiUrl.trim().isEmpty
        ? StorageService.defaultApiUrl
        : context.watch<AppState>().apiUrl.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Local Ollama Status')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Automatic local AI connection',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'MediTwin connects automatically to Ollama running on this laptop.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Endpoint',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(endpoint),
                    const SizedBox(height: 12),
                    Text(
                      'Expected model: qwen3:8b-q4_K_M',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'For Flutter Web on this laptop, 127.0.0.1 connects to Ollama on the same laptop. Keep Ollama running before using Chat.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _testing ? null : _testLocalOllama,
              icon: _testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.wifi_tethering_rounded),
              label: Text(_testing ? 'Testing...' : 'Test local Ollama'),
            ),
            if (_lastResult != null) ...[
              const SizedBox(height: 12),
              Text(
                _lastResult == true
                    ? 'Status: connected.'
                    : 'Status: not connected. Start Ollama and confirm it is listening on port 11434.',
                style: TextStyle(
                  color: _lastResult == true ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
