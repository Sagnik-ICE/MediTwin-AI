import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/bd_locations.dart';
import '../providers/app_state.dart';
import '../services/firestore_service.dart';
import '../utils/debug_logger.dart';
import '../widgets/glass_card.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  final _searchController = TextEditingController();
  final _divisionController = TextEditingController();
  final _districtController = TextEditingController();

  final _fs = FirestoreService();
  String? _selectedType;
  String _query = '';
  String _division = 'All';
  String _district = 'All';
  String _bloodGroup = 'All';
  bool _loading = false;
  List<Map<String, dynamic>> _items = [];

  static const List<String> _divisions = BdLocations.divisions;

  static const List<String> _districts = BdLocations.districts;

  @override
  void dispose() {
    _searchController.dispose();
    _divisionController.dispose();
    _districtController.dispose();
    super.dispose();
  }

  Future<void> _openType(String type) async {
    setState(() {
      _selectedType = type;
      _query = '';
      _division = 'All';
      _district = 'All';
      _bloodGroup = 'All';
    });
    await _reload();
  }

  Future<void> _reload() async {
    if (_selectedType == null) return;
    setState(() => _loading = true);
    try {
      if (_selectedType == 'donor') {
        _items = await _fs.queryDonors(
          bloodGroup: _bloodGroup == 'All' ? null : _bloodGroup,
          division: _division == 'All' ? null : _division,
          district: _district == 'All' ? null : _district,
          limit: 2000,
        );
      } else {
        _items = await _fs.queryEmergencyResources(
          type: _selectedType,
          division: _division == 'All' ? null : _division,
          district: _district == 'All' ? null : _district,
          limit: 2000,
        );
      }
    } catch (e, st) {
      DebugLogger.error('Failed to load emergency entries', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load entries')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredItems {
    final q = _query.trim().toLowerCase();
    return _items.where((item) {
      if (q.isEmpty) return true;
      final name = (item['name'] ?? '').toString().toLowerCase();
      return name.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_selectedType == null ? 'Emergency Resources' : _typeTitle(_selectedType!)),
            leading: _selectedType == null
                ? null
                : IconButton(
                    onPressed: () => setState(() {
                      _selectedType = null;
                      _items = [];
                    }),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
            actions: [
              if (_selectedType != null)
                IconButton(onPressed: _reload, icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
          floatingActionButton: appState.isAdmin && _selectedType != null
              ? FloatingActionButton.extended(
                  onPressed: () => _openEntryForm(type: _selectedType!),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add entry'),
                )
              : null,
          body: _selectedType == null ? _landing(context) : _panel(context, appState.isAdmin),
        );
      },
    );
  }

  Widget _landing(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Choose a category to browse live emergency contacts and donor records.', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width >= 700 ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.05,
          children: [
            _tile(context, Icons.local_taxi_rounded, 'Ambulance', 'Road rescue and transfer', () => _openType('ambulance')),
            _tile(context, Icons.local_hospital_rounded, 'Hospital', 'Emergency hospital contacts', () => _openType('hospital')),
            _tile(context, Icons.bloodtype_rounded, 'Blood bank', 'Blood inventory and support', () => _openType('blood_bank')),
            _tile(context, Icons.volunteer_activism_rounded, 'Donor', 'Search registered donors', () => _openType('donor')),
          ],
        ),
      ],
    );
  }

  Widget _panel(BuildContext context, bool isAdmin) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Filters', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value.trim()),
                      decoration: const InputDecoration(labelText: 'Search by name', prefixIcon: Icon(Icons.search_rounded)),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _dropdown('Division', _division, _divisions, (value) async { setState(() => _division = value ?? 'All'); await _reload(); })),
                        const SizedBox(width: 10),
                        Expanded(child: _dropdown('District', _district, _districts, (value) async { setState(() => _district = value ?? 'All'); await _reload(); })),
                      ],
                    ),
                    if (_selectedType == 'donor') ...[
                      const SizedBox(height: 10),
                      _dropdown(
                        'Blood group',
                        _bloodGroup,
                        const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
                        (value) async {
                          setState(() => _bloodGroup = value ?? 'All');
                          await _reload();
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ..._filteredItems.map((item) {
                final id = item['id']?.toString() ?? '';
                return Card(
                  child: ListTile(
                    title: Text((item['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${item['division'] ?? ''} • ${item['district'] ?? ''}'),
                    trailing: isAdmin
                        ? Wrap(
                            spacing: 6,
                            children: [
                              IconButton(onPressed: () => _openEntryForm(type: _selectedType!, existing: item), icon: const Icon(Icons.edit_rounded)),
                              IconButton(
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete entry?'),
                                      content: const Text('This will remove the record from Firestore.'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                                      ],
                                    ),
                                  );
                                  if (!(confirm ?? false) || id.isEmpty) return;
                                  if (_selectedType == 'donor') {
                                    await _fs.deleteDonor(id);
                                  } else {
                                    await _fs.deleteEmergencyResource(id);
                                  }
                                  if (mounted) await _reload();
                                },
                                icon: const Icon(Icons.delete_rounded),
                              ),
                            ],
                          )
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: () => _openDetails(item),
                  ),
                );
              }),
              if (_filteredItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(child: Text('No records found.')),
                ),
            ],
          );
  }

  Widget _tile(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: GlassCard(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 34, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: ['All', ...items]
          .map((item) => DropdownMenuItem<String>(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
    );
  }

  Future<void> _openDetails(Map<String, dynamic> item) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text((item['name'] ?? '').toString(), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Type: ${_typeTitle((item['type'] ?? _selectedType ?? '').toString())}'),
              Text('Division: ${item['division'] ?? ''}'),
              Text('District: ${item['district'] ?? ''}'),
              if ((item['bloodGroup'] ?? '').toString().isNotEmpty) Text('Blood group: ${item['bloodGroup']}'),
              const SizedBox(height: 8),
              Text('Contact: ${item['contact'] ?? item['phone'] ?? ''}'),
              Text('Note: ${item['note'] ?? item['details'] ?? ''}'),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEntryForm({required String type, Map<String, dynamic>? existing}) async {
    final nameController = TextEditingController(text: existing?['name']?.toString() ?? '');
    final contactController = TextEditingController(text: (existing?['contact'] ?? existing?['phone'] ?? '').toString());
    final noteController = TextEditingController(text: (existing?['note'] ?? existing?['details'] ?? '').toString());
    String? selectedDivision = _divisions.contains(existing?['division']?.toString() ?? '')
      ? existing!['division'].toString()
      : null;
    String? selectedDistrict = _districts.contains(existing?['district']?.toString() ?? '')
      ? existing!['district'].toString()
      : null;
    String? selectedBloodGroup = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].contains(existing?['bloodGroup']?.toString() ?? '')
      ? existing!['bloodGroup'].toString()
      : null;

    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          title: Text(existing == null ? 'Add ${_typeTitle(type)}' : 'Edit ${_typeTitle(type)}'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 520,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  TextFormField(controller: nameController, decoration: const InputDecoration(labelText: 'Name'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                  const SizedBox(height: 12),
                  _dropdownField(
                    label: 'Division',
                    value: selectedDivision,
                    items: _divisions,
                    onChanged: (value) => setDialogState(() => selectedDivision = value),
                  ),
                  const SizedBox(height: 12),
                  _dropdownField(
                    label: 'District',
                    value: selectedDistrict,
                    items: _districts,
                    onChanged: (value) => setDialogState(() => selectedDistrict = value),
                  ),
                  const SizedBox(height: 12),
                  if (type == 'donor')
                    _dropdownField(
                      label: 'Blood group',
                      value: selectedBloodGroup,
                      items: const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
                      onChanged: (value) => setDialogState(() => selectedBloodGroup = value),
                    ),
                  if (type == 'donor') const SizedBox(height: 12),
                  TextFormField(controller: contactController, decoration: const InputDecoration(labelText: 'Contact'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                  const SizedBox(height: 12),
                  TextFormField(controller: noteController, decoration: const InputDecoration(labelText: 'Note / details'), maxLines: 3),
                ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (!(saved ?? false)) return;
    if (selectedDivision == null || selectedDivision!.isEmpty || selectedDistrict == null || selectedDistrict!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Division and district are required.')));
      }
      return;
    }
    if (type == 'donor' && (selectedBloodGroup == null || selectedBloodGroup!.isEmpty)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Blood group is required for donors.')));
      }
      return;
    }
    final payload = <String, dynamic>{
      if (existing?['id'] != null) 'id': existing!['id'],
      'type': type,
      'name': nameController.text.trim(),
      'division': selectedDivision,
      'district': selectedDistrict,
      'contact': contactController.text.trim(),
      'phone': contactController.text.trim(),
      'note': noteController.text.trim(),
      'details': noteController.text.trim(),
      if (type == 'donor') 'bloodGroup': selectedBloodGroup,
    };

    if (type == 'donor') {
      try {
        await _fs.saveDonor(payload);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save donor: $e')));
        }
        return;
      }
    } else {
      try {
        await _fs.saveEmergencyResource(payload);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save entry: $e')));
        }
        return;
      }
    }
    if (mounted) await _reload();
  }

  // _input removed; dialogs use inline TextFormField instances with validation.

  Widget _dropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.zero,
      child: DropdownButtonFormField<String>(
        initialValue: (value != null && items.contains(value)) ? value : null,
        hint: Text(label),
        items: items.map((item) => DropdownMenuItem<String>(value: item, child: Text(item))).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label),
        validator: (selected) => (selected == null || selected.isEmpty) ? 'Required' : null,
      ),
    );
  }

  String _typeTitle(String type) {
    switch (type) {
      case 'ambulance':
        return 'Ambulance';
      case 'hospital':
        return 'Hospital';
      case 'blood_bank':
        return 'Blood bank';
      case 'donor':
        return 'Donor';
      default:
        return type;
    }
  }
}
