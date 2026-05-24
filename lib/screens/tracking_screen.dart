import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_theme.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Health Log')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _LogHero(),
            const SizedBox(height: 14),
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionTitle(context, 'Vitals', Icons.monitor_heart_rounded),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final twoColumns = constraints.maxWidth >= 520;
                        return Column(
                          children: [
                            _fieldPair(
                              twoColumns: twoColumns,
                              first: _numberField(
                                _sleepController,
                                'Sleep hours',
                                hint: 'e.g. 7.5',
                                min: 0,
                                max: 24,
                              ),
                              second: _numberField(
                                _waterController,
                                'Water glasses',
                                hint: 'e.g. 8',
                                min: 0,
                                max: 50,
                                integer: true,
                              ),
                            ),
                            _fieldPair(
                              twoColumns: twoColumns,
                              first: _numberField(
                                _stressController,
                                'Stress level',
                                hint: '1-10',
                                min: 1,
                                max: 10,
                                integer: true,
                              ),
                              second: _numberField(
                                _exerciseController,
                                'Exercise minutes',
                                hint: 'e.g. 20',
                                min: 0,
                                max: 1440,
                                integer: true,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    _numberField(
                      _weightController,
                      'Weight (kg)',
                      hint: 'e.g. 70',
                      min: 1,
                      max: 500,
                    ),
                    const SizedBox(height: 8),
                    _sectionTitle(context, 'Wellness', Icons.spa_rounded),
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
                        prefixIcon: Icon(Icons.mood_rounded),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
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
                        prefixIcon: Icon(Icons.restaurant_rounded),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    _sectionTitle(context, 'Symptoms', Icons.fact_check_rounded),
                    Text(
                      'Select only what applies today. Leave empty if there are no symptoms.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMuted,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final symptom in _availableSymptoms)
                          FilterChip(
                            label: Text(symptom),
                            selected: _symptoms.contains(symptom),
                            onSelected: _saving ? null : (value) => _toggleSymptom(symptom, value),
                            visualDensity: VisualDensity.compact,
                            side: const BorderSide(color: AppTheme.border),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _notesController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        hintText: 'Optional notes about today',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 420;
                        final clearButton = OutlinedButton.icon(
                          onPressed: _saving ? null : _clearForm,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Clear'),
                        );
                        final saveButton = FilledButton.icon(
                          onPressed: _saving ? null : _submit,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.check_rounded),
                          label: Text(_saving ? 'Saving...' : 'Save log'),
                        );

                        if (wide) {
                          return Row(
                            children: [
                              Expanded(child: clearButton),
                              const SizedBox(width: 12),
                              Expanded(flex: 2, child: saveButton),
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            saveButton,
                            const SizedBox(height: 10),
                            clearButton,
                          ],
                        );
                      },
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

  Widget _fieldPair({
    required bool twoColumns,
    required Widget first,
    required Widget second,
  }) {
    if (twoColumns) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: first),
          const SizedBox(width: 10),
          Expanded(child: second),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [first, second],
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
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        enabled: !_saving,
        keyboardType: TextInputType.numberWithOptions(decimal: !integer),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: _iconForField(label),
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

  Widget? _iconForField(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('sleep')) return const Icon(Icons.bedtime_rounded);
    if (lower.contains('water')) return const Icon(Icons.water_drop_rounded);
    if (lower.contains('stress')) return const Icon(Icons.psychology_rounded);
    if (lower.contains('exercise')) return const Icon(Icons.directions_run_rounded);
    if (lower.contains('weight')) return const Icon(Icons.monitor_weight_rounded);
    return null;
  }

  String _formatLimit(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  Widget _sectionTitle(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 2),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.surfaceTint,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Icon(icon, size: 17, color: AppTheme.primaryTeal),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                ),
          ),
        ],
      ),
    );
  }
}

class _LogHero extends StatelessWidget {
  const _LogHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: AppTheme.softShadow(opacity: 0.10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: const Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily health log',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter today\'s real health details. The form stays blank to prevent accidental default saves.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
