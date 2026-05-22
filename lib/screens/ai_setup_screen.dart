import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../utils/debug_logger.dart';
import '../theme/app_theme.dart';

class AiSetupScreen extends StatefulWidget {
  const AiSetupScreen({super.key});

  @override
  State<AiSetupScreen> createState() => _AiSetupScreenState();
}

class _AiSetupScreenState extends State<AiSetupScreen> {
  final _controller = TextEditingController();
  bool _testing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final api = context.read<AppState>().apiUrl;
    _controller.text = api;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _testAndSave() async {
    final endpoint = _controller.text.trim();
    if (endpoint.isEmpty) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter the AI endpoint.')));
      return;
    }

    setState(() => _testing = true);
    final appState = context.read<AppState>();
    await appState.setApiUrl(endpoint);
    try {
      final ok = await appState.testBackendConnection();
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'AI server reachable.' : 'Could not reach the AI server. Check the laptop and network.'),
        backgroundColor: ok ? Colors.green : Colors.orange,
      ));
      if (ok) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      DebugLogger.error('AI setup test failed', e);
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connection test failed: $e')));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _saveOnly() async {
    final endpoint = _controller.text.trim();
    if (endpoint.isEmpty) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter the AI endpoint.')));
      return;
    }
    final appState = context.read<AppState>();
    await appState.setApiUrl(endpoint);
    if (!mounted) return;
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Endpoint saved. You can test it any time in Settings.')));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Endpoint Setup')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Connect to your laptop-hosted Qwen model',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the laptop IP and port (e.g. 192.168.1.5:11434) or the full URL. Use the Test button to verify connectivity.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'AI endpoint',
                  hintText: '192.168.1.12:11434 or http://192.168.1.12:11434/api/generate',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _testing ? null : _testAndSave,
                      icon: _testing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.wifi_tethering_rounded),
                      label: Text(_testing ? 'Testing...' : 'Test & Save'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _testing ? null : _saveOnly,
                    child: const Text('Save (skip test)'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('If you do not have Ollama running, please start the service on your laptop and ensure your phone and laptop are on the same Wi‑Fi network.'),
            ],
          ),
        ),
      ),
    );
  }
}
