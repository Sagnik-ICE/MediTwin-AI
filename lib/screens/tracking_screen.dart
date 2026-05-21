import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../widgets/glass_card.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key, this.onSaved});

  final VoidCallback? onSaved;

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sleepController = TextEditingController(text: '7');
  final _waterController = TextEditingController(text: '8');
  final _stressController = TextEditingController(text: '5');
  final _exerciseController = TextEditingController(text: '20');
  final _weightController = TextEditingController(text: '70');
  final _notesController = TextEditingController();

  String _mood = 'neutral';
  String _foodQuality = 'average';
  final Set<String> _symptoms = {'No symptoms'};

  @override
  void dispose() {
    _sleepController.dispose();
    _waterController.dispose();
    _stressController.dispose();
    _exerciseController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final appState = context.read<AppState>();

    await appState.addHealthLog(
      sleepHours: double.parse(_sleepController.text),
      waterGlasses: int.parse(_waterController.text),
      stressLevel: int.parse(_stressController.text),
      mood: _mood,
      exerciseMinutes: int.parse(_exerciseController.text),
      symptoms: _symptoms.toList(),
      foodQuality: _foodQuality,
      weight: double.parse(_weightController.text),
      notes: _notesController.text,
    );

    if (!mounted) {
      return;
    }

    final latest = context.read<AppState>().logs.first;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved. Score: ${latest.healthScore}. ${latest.insight}'),
      ),
    );
    widget.onSaved?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Health Log')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Enter today\'s key health details in a single quick pass.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionTitle(context, 'Vitals'),
                    Row(
                      children: [
                        Expanded(child: _numberField(_sleepController, 'Sleep h', min: 0, max: 24)),
                        const SizedBox(width: 10),
                        Expanded(child: _numberField(_waterController, 'Water', min: 0, max: 50, integer: true)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _numberField(_stressController, 'Stress', min: 1, max: 10, integer: true)),
                        const SizedBox(width: 10),
                        Expanded(child: _numberField(_exerciseController, 'Exercise min', min: 0, max: 1440, integer: true)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _numberField(_weightController, 'Weight (kg)', min: 1, max: 500),
                    const SizedBox(height: 10),
                    _sectionTitle(context, 'Wellness'),
                    DropdownButtonFormField<String>(
                      initialValue: _mood,
                      items: const [
                        DropdownMenuItem(value: 'very good', child: Text('Very good')),
                        DropdownMenuItem(value: 'good', child: Text('Good')),
                        DropdownMenuItem(value: 'neutral', child: Text('Neutral')),
                        DropdownMenuItem(value: 'bad', child: Text('Bad')),
                        DropdownMenuItem(value: 'very bad', child: Text('Very bad')),
                      ],
                      onChanged: (v) => setState(() => _mood = v ?? 'neutral'),
                      decoration: const InputDecoration(labelText: 'Mood'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _foodQuality,
                      items: const [
                        DropdownMenuItem(value: 'good', child: Text('Good')),
                        DropdownMenuItem(value: 'average', child: Text('Average')),
                        DropdownMenuItem(value: 'poor', child: Text('Poor')),
                      ],
                      onChanged: (v) => setState(() => _foodQuality = v ?? 'average'),
                      decoration: const InputDecoration(labelText: 'Food quality'),
                    ),
                    const SizedBox(height: 10),
                    _sectionTitle(context, 'Symptoms'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final symptom in const ['No symptoms', 'Headache', 'Fatigue', 'Dizziness', 'Nausea', 'Fever'])
                          FilterChip(
                            label: Text(symptom),
                            selected: _symptoms.contains(symptom),
                            onSelected: (value) {
                              setState(() {
                                if (symptom == 'No symptoms' && value) {
                                  _symptoms
                                    ..clear()
                                    ..add('No symptoms');
                                } else {
                                  _symptoms.remove('No symptoms');
                                  if (value) {
                                    _symptoms.add(symptom);
                                  } else {
                                    _symptoms.remove(symptom);
                                  }
                                  if (_symptoms.isEmpty) {
                                    _symptoms.add('No symptoms');
                                  }
                                }
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(labelText: 'Notes'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _submit,
                        child: const Text('Save Log'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String label, {double? min, double? max, bool integer = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Required';
          }
          final parsed = integer ? int.tryParse(value) : double.tryParse(value);
          if (parsed == null) {
            return 'Enter a valid number';
          }
          final asDouble = (parsed is int) ? parsed.toDouble() : (parsed as double);
          if (min != null && asDouble < min) return 'Must be >= $min';
          if (max != null && asDouble > max) return 'Must be <= $max';
          return null;
        },
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
