import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../widgets/disclaimer_banner.dart';
import '../widgets/glass_card.dart';

class SimulateScreen extends StatefulWidget {
  const SimulateScreen({super.key});

  @override
  State<SimulateScreen> createState() => _SimulateScreenState();
}

class _SimulateScreenState extends State<SimulateScreen> {
  final _controller = TextEditingController(text: 'What if I reduce stress and exercise more?');
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _simulate() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _result = context.read<AppState>().runSimulation(text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Future Simulation')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const DisclaimerBanner(),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Scenario',
              hintText: 'What happens if I continue this lifestyle?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _simulate,
            icon: const Icon(Icons.timeline_rounded),
            label: const Text('Run Simulation'),
          ),
          const SizedBox(height: 14),
          if (_result != null)
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('7-day projection: ${_result!['day7']}'),
                  Text('30-day projection: ${_result!['day30']}'),
                  Text('90-day projection: ${_result!['day90']}'),
                  const SizedBox(height: 8),
                  Text('Possible risks', style: Theme.of(context).textTheme.titleSmall),
                  ...(_result!['risks'] as List<dynamic>).map((r) => Text('- $r')),
                  const SizedBox(height: 8),
                  Text('Improvement suggestions', style: Theme.of(context).textTheme.titleSmall),
                  ...(_result!['suggestions'] as List<dynamic>).map((s) => Text('- $s')),
                  const SizedBox(height: 8),
                  const Text('This is only a wellness simulation, not a medical prediction.'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
