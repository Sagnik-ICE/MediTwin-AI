// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/bd_locations.dart';
import '../providers/app_state.dart';
import 'doctor_profile_screen.dart';
import '../services/firestore_service.dart';
import '../utils/debug_logger.dart';

class DoctorDirectoryScreen extends StatefulWidget {
  const DoctorDirectoryScreen({super.key});

  @override
  State<DoctorDirectoryScreen> createState() => _DoctorDirectoryScreenState();
}

class _DoctorDirectoryScreenState extends State<DoctorDirectoryScreen> {
  static const List<String> _divisions = BdLocations.divisions;

  static const List<String> _districts = BdLocations.districts;

  static const List<String> _categories = [
    'Allergy & Immunology',
    'Anesthesiology',
    'Cardiology',
    'Critical Care',
    'Dentistry',
    'Dermatology',
    'Endocrinology',
    'Emergency Medicine',
    'Family Medicine',
    'Gastroenterology',
    'General Medicine',
    'General Surgery',
    'Geriatrics',
    'Hematology',
    'Infectious Disease',
    'Internal Medicine',
    'Nephrology',
    'Neurology',
    'Neurosurgery',
    'Obstetrics & Gynecology',
    'Oncology',
    'Ophthalmology',
    'Orthopedics',
    'Otolaryngology',
    'Pediatrics',
    'Physical Medicine & Rehab',
    'Psychiatry',
    'Pulmonology',
    'Radiology',
    'Rheumatology',
    'Urology',
  ];

  final _searchController = TextEditingController();
  final _fs = FirestoreService();
  List<Map<String, dynamic>> _doctors = [];
  List<String> _dynamicCategories = [];
  bool _loading = true;
  String _query = '';
  String _division = 'All';
  String _district = 'All';
  String _category = 'All';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final docs = await _fs.queryDoctors(
        category: _category == 'All' ? null : _category,
        division: _division == 'All' ? null : _division,
        district: _district == 'All' ? null : _district,
        limit: 2000,
      );
      if (!mounted) return;
      setState(() => _doctors = docs);
    } catch (e, st) {
      DebugLogger.error('Failed to load doctors', e, st);
      if (!mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load doctors')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _bootstrap() async {
    await _loadCategories();
    await _reload();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _fs.loadDoctorCategories();
      if (!mounted) return;
      setState(() => _dynamicCategories = categories);
    } catch (_) {
      // Keep default categories if Firestore categories fail to load.
    }
  }

  List<Map<String, dynamic>> get _results {
    final q = _query.trim().toLowerCase();
    return _doctors.where((doctor) {
      if (q.isEmpty) return true;
      final name = (doctor['name'] ?? '').toString().toLowerCase();
      return name.contains(q);
    }).toList();
  }

  List<String> get _allCategories {
    final merged = [..._categories, ..._dynamicCategories].toSet().toList()..sort();
    return merged;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Doctor Directory'),
            actions: [
              IconButton(onPressed: _reload, icon: const Icon(Icons.refresh_rounded)),
              if (appState.isAdmin)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'add_category') {
                      _addCategory();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'add_category', child: Text('Add category')),
                  ],
                ),
            ],
          ),
          floatingActionButton: appState.isAdmin
              ? FloatingActionButton.extended(
                  onPressed: () => _openDoctorForm(admin: true),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add doctor'),
                )
              : null,
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Search by name, then filter by division, district, and category.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value.trim()),
                      decoration: const InputDecoration(
                        labelText: 'Search by name',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _dropdown('Division', _division, _divisions, (value) => setState(() => _division = value ?? 'All'))),
                        const SizedBox(width: 10),
                        Expanded(child: _dropdown('District', _district, _districts, (value) => setState(() => _district = value ?? 'All'))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _dropdown('Category', _category, _allCategories, (value) => setState(() => _category = value ?? 'All')),
                    const SizedBox(height: 16),
                    ..._results.map((doctor) {
                      final id = doctor['id']?.toString() ?? '';
                      return Card(
                        child: ListTile(
                          title: Text((doctor['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${doctor['category'] ?? ''} • ${doctor['division'] ?? ''} • ${doctor['district'] ?? ''}'),
                          trailing: Wrap(
                            spacing: 6,
                            children: [
                              if (appState.isAdmin)
                                IconButton(
                                  onPressed: () => _openDoctorForm(existing: doctor),
                                  icon: const Icon(Icons.edit_rounded),
                                ),
                              if (appState.isAdmin)
                                IconButton(
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Delete doctor?'),
                                        content: Text('Remove ${(doctor['name'] ?? '').toString()} from the directory?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                                        ],
                                      ),
                                    );
                                    if (!(confirm ?? false) || id.isEmpty) return;
                                    await _fs.deleteDoctor(id);
                                    if (mounted) await _reload();
                                  },
                                  icon: const Icon(Icons.delete_rounded),
                                ),
                              const Icon(Icons.chevron_right_rounded),
                            ],
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => DoctorProfileScreen(
                                doctor: doctor,
                                allowBooking: !appState.isAdmin,
                                canEdit: appState.isAdmin,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    if (_results.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(child: Text('No doctors found.')),
                      ),
                  ],
                ),
        );
      },
    );
  }

  Widget _dropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: ['All', ...items.where((item) => item != 'All').toSet()]
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
    );
  }

  Future<void> _openDoctorForm({Map<String, dynamic>? existing, bool admin = false}) async {
    final nameController = TextEditingController(text: existing?['name']?.toString() ?? '');
    final qualificationController = TextEditingController(text: existing?['qualification']?.toString() ?? '');
    final contactController = TextEditingController(text: existing?['contact']?.toString() ?? '');
    final imageController = TextEditingController(text: existing?['profileImageUrl']?.toString() ?? '');
    final detailsController = TextEditingController(text: existing?['details']?.toString() ?? '');
    final chambersController = TextEditingController(text: _serializeChambers(existing?['chambers']));
    final emailController = TextEditingController(text: existing?['doctorEmail']?.toString() ?? '');
    final passwordController = TextEditingController();
    bool createDedicatedAccount = (existing?['hasDedicatedProfile'] as bool?) ?? false;
    String? selectedCategory = _allCategories.contains(existing?['category']?.toString() ?? '')
      ? existing!['category'].toString()
      : null;
    String? selectedDivision = _divisions.contains(existing?['division']?.toString() ?? '')
      ? existing!['division'].toString()
      : null;
    String? selectedDistrict = _districts.contains(existing?['district']?.toString() ?? '')
      ? existing!['district'].toString()
      : null;

    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          title: Text(existing == null ? 'Add doctor' : 'Edit doctor'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 560,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  _dropdownField(
                    label: 'Category',
                    value: selectedCategory,
                    items: _allCategories,
                    onChanged: (value) => setDialogState(() => selectedCategory = value),
                  ),
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
                  TextFormField(controller: qualificationController, decoration: const InputDecoration(labelText: 'Qualification')),
                  const SizedBox(height: 12),
                  TextFormField(controller: contactController, decoration: const InputDecoration(labelText: 'Contact')),
                  const SizedBox(height: 12),
                  TextFormField(controller: imageController, decoration: const InputDecoration(labelText: 'Image URL')),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: createDedicatedAccount,
                    onChanged: (value) => setDialogState(() => createDedicatedAccount = value),
                    title: const Text('Create dedicated doctor account'),
                    subtitle: const Text('Generates a doctor login and profile page.'),
                  ),
                  if (createDedicatedAccount) ...[
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Doctor email'),
                      validator: (value) => createDedicatedAccount && (value == null || !value.contains('@')) ? 'Enter a valid email' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Doctor password'),
                      validator: (value) => createDedicatedAccount && (value == null || value.trim().length < 6) ? 'Password must be at least 6 characters' : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: chambersController,
                    decoration: const InputDecoration(
                      labelText: 'Chambers',
                      helperText: 'Use one chamber per line in the format: Name | Address | Mon, Tue, Thu',
                    ),
                    maxLines: 4,
                    minLines: 2,
                    validator: (value) => (value == null || value.trim().isEmpty) ? 'Add at least one chamber' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(controller: detailsController, decoration: const InputDecoration(labelText: 'Details'), maxLines: 3),
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
    final chambers = _parseChambers(chambersController.text);
    if (selectedCategory == null || selectedCategory!.isEmpty || selectedDivision == null || selectedDivision!.isEmpty || selectedDistrict == null || selectedDistrict!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category, division, and district are required.')));
      }
      return;
    }
    final payload = <String, dynamic>{
      if (existing?['id'] != null) 'id': existing!['id'],
      'name': nameController.text.trim(),
      'category': selectedCategory,
      'division': selectedDivision,
      'district': selectedDistrict,
      'qualification': qualificationController.text.trim(),
      'chamber': chambers.isNotEmpty ? chambers.first['name'] : '',
      'chambers': chambers,
      'contact': contactController.text.trim(),
      'contactInfo': contactController.text.trim(),
      'profileImageUrl': imageController.text.trim(),
      'details': detailsController.text.trim(),
      'specialtySummary': qualificationController.text.trim().isNotEmpty ? qualificationController.text.trim() : detailsController.text.trim(),
      'rating': existing?['rating'] ?? 0,
      'ratingCount': existing?['ratingCount'] ?? 0,
      'acceptsAppointments': true,
      'hasDedicatedProfile': createDedicatedAccount || (existing?['hasDedicatedProfile'] as bool?) == true,
    };

    final hasDedicatedUser = (existing?['doctorUserId'] ?? '').toString().trim().isNotEmpty;
    if (createDedicatedAccount && !hasDedicatedUser) {
      final appState = context.read<AppState>();
      final messenger = ScaffoldMessenger.of(context);
      final error = await appState.addDoctorAccount(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        displayName: nameController.text.trim(),
        doctorData: payload,
      );
      if (!mounted) return;
      if (error != null) {
        // We captured `messenger` before the await above; mounting was checked.
        messenger.showSnackBar(SnackBar(content: Text(error)));
        return;
      }
    } else {
      try {
        await _fs.saveDoctor(payload);
      } catch (e) {
        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          messenger.showSnackBar(SnackBar(content: Text('Failed to save doctor: $e')));
        }
        return;
      }
    }
    if (mounted) await _reload();
  }

  List<Map<String, dynamic>> _parseChambers(String text) {
    return text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) {
      final parts = line.split('|').map((p) => p.trim()).toList();
      return {
        'name': parts.isNotEmpty ? parts[0] : 'Chamber',
        'address': parts.length > 1 ? parts[1] : '',
        'availableDays': parts.length > 2
            ? parts[2].split(',').map((day) => day.trim()).where((day) => day.isNotEmpty).toList()
            : <String>[],
      };
    }).toList();
  }

  String _serializeChambers(dynamic raw) {
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().map((entry) {
        final days = _normalizeDays(entry['availableDays']).join(', ');
        return '${entry['name'] ?? ''} | ${entry['address'] ?? ''} | $days';
      }).join('\n');
    }
    final chamber = (raw ?? '').toString().trim();
    return chamber.isEmpty ? '' : '$chamber |  | ';
  }

  List<String> _normalizeDays(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    if (raw is String && raw.trim().isNotEmpty) return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return const [];
  }

  Future<void> _addCategory() async {
    final controller = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add doctor category'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Category name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')),
        ],
      ),
    );
    if (!(added ?? false) || controller.text.trim().isEmpty) return;
    await _fs.saveDoctorCategory(controller.text.trim());
    await _loadCategories();
        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          messenger.showSnackBar(const SnackBar(content: Text('Category added.')));
        }
  }



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
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label),
        validator: (selected) => (selected == null || selected.isEmpty) ? 'Required' : null,
      ),
    );
  }
}
