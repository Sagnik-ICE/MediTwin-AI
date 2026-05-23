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

  // Keep the daily log blank by default. Users should enter today's actual data,
  // not accidentally save placeholder values.
  final _sleepController = TextEditingController();
  final _waterController = TextEditingController();
  final _stressController = TextEditingController();
  final _exerciseController = TextEditingController();
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();

  String? _mood;
  String? _foodQuality;
  final Set<String> _symptoms = <String>{};
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
      final selectedSymptoms = _symptoms.isEmpty
          ? const ['No symptoms']
          : _symptoms.toList(growable: false);

      await appState.addHealthLog(
        sleepHours: double.parse(_sleepController.text.trim()),
        waterGlasses: int.parse(_waterController.text.trim()),
        stressLevel: int.parse(_stressController.text.trim()),
        mood: _mood!,
        exerciseMinutes: int.parse(_exerciseController.text.trim()),
        symptoms: selectedSymptoms,
        foodQuality: _foodQuality!,
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
        } else {
          _symptoms.remove('No symptoms');
        }
        return;
      }

      _symptoms.remove('No symptoms');

      if (selected) {
        _symptoms.add(symptom);
      } else {
        _symptoms.remove(symptom);
      }
    });
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _sleepController.clear();
    _waterController.clear();
    _stressController.clear();
    _exerciseController.clear();
    _weightController.clear();
    _notesController.clear();

    setState(() {
      _mood = null;
      _foodQuality = null;
      _symptoms.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Health Log')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Enter today\'s actual health details. The form starts empty to avoid saving default values by mistake.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
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
                            'Sleep hours',
                            hint: 'e.g. 7.5',
                            min: 0,
                            max: 24,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _numberField(
                            _waterController,
                            'Water glasses',
                            hint: 'e.g. 8',
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
                            'Stress level',
                            hint: '1-10',
                            min: 1,
                            max: 10,
                            integer: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _numberField(
                            _exerciseController,
                            'Exercise minutes',
                            hint: 'e.g. 20',
                            min: 0,
                            max: 1440,
                            integer: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _numberField(
                      _weightController,
                      'Weight (kg)',
                      hint: 'e.g. 70',
                      min: 1,
                      max: 500,
                    ),
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
                      onChanged: _saving ? null : (v) => setState(() => _mood = v),
                      decoration: const InputDecoration(
                        labelText: 'Mood',
                        hintText: 'Select mood',
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _foodQuality,
                      items: const [
                        DropdownMenuItem(value: 'good', child: Text('Good')),
                        DropdownMenuItem(value: 'average', child: Text('Average')),
                        DropdownMenuItem(value: 'poor', child: Text('Poor')),
                      ],
                      onChanged: _saving ? null : (v) => setState(() => _foodQuality = v),
                      decoration: const InputDecoration(
                        labelText: 'Food quality',
                        hintText: 'Select food quality',
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    _sectionTitle(context, 'Symptoms'),
                    Text(
                      'Select only what applies today. Leave empty if there are no symptoms.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final symptom in _availableSymptoms)
                          FilterChip(
                            label: Text(symptom),
                            selected: _symptoms.contains(symptom),
                            onSelected: _saving ? null : (value) => _toggleSymptom(symptom, value),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _notesController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        hintText: 'Optional notes about today',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _clearForm,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Clear'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
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
    String? hint,
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
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
        ),
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
          if (min != null && asDouble < min) return 'Must be >= ${_formatLimit(min)}';
          if (max != null && asDouble > max) return 'Must be <= ${_formatLimit(max)}';
          return null;
        },
      ),
    );
  }

  String _formatLimit(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
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
