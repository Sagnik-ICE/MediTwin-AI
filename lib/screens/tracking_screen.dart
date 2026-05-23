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
  bool _saving = false;

  static const List<String> _availableSymptoms = [
    'No symptoms',
    'Headache',
    'Fatigue',
    'Dizziness',
    'Nausea',
    'Fever',
    'Chest pain',
    'Trouble breathing',
    'Severe bleeding',
    'Seizure',
  ];

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
    if (_saving) return;

    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() => _saving = true);

    try {
      final appState = context.read<AppState>();

      await appState.addHealthLog(
        sleepHours: double.parse(_sleepController.text.trim()),
        waterGlasses: int.parse(_waterController.text.trim()),
        stressLevel: int.parse(_stressController.text.trim()),
        mood: _mood,
        exerciseMinutes: int.parse(_exerciseController.text.trim()),
        symptoms: _symptoms.toList(growable: false),
        foodQuality: _foodQuality,
        weight: double.parse(_weightController.text.trim()),
        notes: _notesController.text.trim(),
      );

      if (!mounted) return;

      final logs = context.read<AppState>().logs;
      final latest = logs.isNotEmpty ? logs.first : null;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            latest == null
                ? 'Health log saved.'
                : 'Saved. Score: ${latest.healthScore}. ${latest.insight}',
          ),
        ),
      );

      widget.onSaved?.call();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save the health log. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _toggleSymptom(String symptom, bool selected) {
    setState(() {
      if (symptom == 'No symptoms') {
        if (selected) {
          _symptoms
            ..clear()
            ..add('No symptoms');
        }
        return;
      }

      _symptoms.remove('No symptoms');

      if (selected) {
        _symptoms.add(symptom);
      } else {
        _symptoms.remove(symptom);
      }

      if (_symptoms.isEmpty) {
        _symptoms.add('No symptoms');
      }
    });
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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
                        Expanded(
                          child: _numberField(
                            _sleepController,
                            'Sleep h',
                            min: 0,
                            max: 24,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _numberField(
                            _waterController,
                            'Water',
                            min: 0,
                            max: 50,
                            integer: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _numberField(
                            _stressController,
                            'Stress',
                            min: 1,
                            max: 10,
                            integer: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _numberField(
                            _exerciseController,
                            'Exercise min',
                            min: 0,
                            max: 1440,
                            integer: true,
                          ),
                        ),
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
                      onChanged: _saving ? null : (v) => setState(() => _mood = v ?? 'neutral'),
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
                      onChanged: _saving ? null : (v) => setState(() => _foodQuality = v ?? 'average'),
                      decoration: const InputDecoration(labelText: 'Food quality'),
                    ),
                    const SizedBox(height: 10),
                    _sectionTitle(context, 'Symptoms'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final symptom in _availableSymptoms)
                          FilterChip(
                            label: Text(symptom),
                            selected: _symptoms.contains(symptom),
                            onSelected: _saving
                                ? null
                                : (value) => _toggleSymptom(symptom, value),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _notesController,
                      enabled: !_saving,
                      decoration: const InputDecoration(labelText: 'Notes'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _submit,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check_rounded),
                        label: Text(_saving ? 'Saving...' : 'Save Log'),
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

  Widget _numberField(
    TextEditingController controller,
    String label, {
    double? min,
    double? max,
    bool integer = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: controller,
        enabled: !_saving,
        keyboardType: TextInputType.numberWithOptions(decimal: !integer),
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (text.isEmpty) {
            return 'Required';
          }

          final parsed = integer ? int.tryParse(text) : double.tryParse(text);
          if (parsed == null) {
            return 'Enter a valid number';
          }

          final asDouble = parsed.toDouble();
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
