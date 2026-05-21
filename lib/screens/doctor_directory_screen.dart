import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/firestore_service.dart';
import '../utils/debug_logger.dart';

class DoctorDirectoryScreen extends StatefulWidget {
  const DoctorDirectoryScreen({super.key});

  @override
  State<DoctorDirectoryScreen> createState() => _DoctorDirectoryScreenState();
}

class _DoctorDirectoryScreenState extends State<DoctorDirectoryScreen> {
  static const List<String> _divisions = [
    'Barishal',
    'Chattogram',
    'Dhaka',
    'Khulna',
    'Mymensingh',
    'Rajshahi',
    'Rangpur',
    'Sylhet',
  ];

  static const List<String> _districts = [
    'Bagerhat', 'Bandarban', 'Barguna', 'Barishal', 'Bhola', 'Bogura', 'Brahmanbaria', 'Chandpur', 'Chapainawabganj', 'Chattogram', 'Chuadanga', 'Coxs Bazar', 'Cumilla', 'Dhaka', 'Dinajpur', 'Faridpur', 'Feni', 'Gaibandha', 'Gazipur', 'Gopalganj', 'Habiganj', 'Jamalpur', 'Jashore', 'Jhalokati', 'Jhenaidah', 'Joypurhat', 'Khagrachhari', 'Khulna', 'Kishoreganj', 'Kurigram', 'Kushtia', 'Lakshmipur', 'Lalmonirhat', 'Madaripur', 'Magura', 'Manikganj', 'Meherpur', 'Moulvibazar', 'Munshiganj', 'Mymensingh', 'Naogaon', 'Narail', 'Narayanganj', 'Narsingdi', 'Natore', 'Netrokona', 'Nilphamari', 'Noakhali', 'Pabna', 'Panchagarh', 'Patuakhali', 'Pirojpur', 'Rajbari', 'Rajshahi', 'Rangamati', 'Rangpur', 'Satkhira', 'Shariatpur', 'Sherpur', 'Sirajganj', 'Sunamganj', 'Sylhet', 'Tangail',
  ];

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
  bool _loading = true;
  String _query = '';
  String _division = 'All';
  String _district = 'All';
  String _category = 'All';

  @override
  void initState() {
    super.initState();
    _reload();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load doctors')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Doctor Directory'),
            actions: [
              IconButton(onPressed: _reload, icon: const Icon(Icons.refresh_rounded)),
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
                    _dropdown('Category', _category, _categories, (value) => setState(() => _category = value ?? 'All')),
                    const SizedBox(height: 16),
                    ..._results.map((doctor) {
                      final id = doctor['id']?.toString() ?? '';
                      return Card(
                        child: ListTile(
                          title: Text((doctor['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${doctor['category'] ?? ''} • ${doctor['division'] ?? ''} • ${doctor['district'] ?? ''}'),
                          trailing: appState.isAdmin
                              ? Wrap(
                                  spacing: 6,
                                  children: [
                                    IconButton(
                                      onPressed: () => _openDoctorForm(existing: doctor),
                                      icon: const Icon(Icons.edit_rounded),
                                    ),
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
                                  ],
                                )
                              : const Icon(Icons.chevron_right_rounded),
                          onTap: () => _openDoctorDetails(doctor),
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
      value: value,
      items: ['All', ...items.where((item) => item != 'All').toSet().toList()]
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
    );
  }

  Future<void> _openDoctorDetails(Map<String, dynamic> doctor) async {
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
              Text((doctor['name'] ?? '').toString(), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Category: ${doctor['category'] ?? ''}'),
              Text('Division: ${doctor['division'] ?? ''}'),
              Text('District: ${doctor['district'] ?? ''}'),
              Text('Qualification: ${doctor['qualification'] ?? ''}'),
              Text('Rating: ${((doctor['rating'] ?? 0) as num).toStringAsFixed(1)} / 5'),
              const SizedBox(height: 8),
              Text('Chamber: ${doctor['chamber'] ?? ''}'),
              Text('Contact: ${doctor['contact'] ?? ''}'),
              const SizedBox(height: 8),
              Text('Details: ${doctor['details'] ?? ''}'),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDoctorForm({Map<String, dynamic>? existing, bool admin = false}) async {
    final nameController = TextEditingController(text: existing?['name']?.toString() ?? '');
    final qualificationController = TextEditingController(text: existing?['qualification']?.toString() ?? '');
    final chamberController = TextEditingController(text: existing?['chamber']?.toString() ?? '');
    final contactController = TextEditingController(text: existing?['contact']?.toString() ?? '');
    final detailsController = TextEditingController(text: existing?['details']?.toString() ?? '');
    final ratingController = TextEditingController(text: (existing?['rating'] ?? 0).toString());
    String selectedCategory = _categories.contains(existing?['category']?.toString() ?? '')
        ? existing!['category'].toString()
        : _categories.first;
    String selectedDivision = _divisions.contains(existing?['division']?.toString() ?? '')
        ? existing!['division'].toString()
        : _divisions.first;
    String selectedDistrict = _districts.contains(existing?['district']?.toString() ?? '')
        ? existing!['district'].toString()
        : _districts.first;

    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add doctor' : 'Edit doctor'),
          content: SingleChildScrollView(
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
                  _dropdownField(
                    label: 'Category',
                    value: selectedCategory,
                    items: _categories,
                    onChanged: (value) => setDialogState(() => selectedCategory = value ?? _categories.first),
                  ),
                  _dropdownField(
                    label: 'Division',
                    value: selectedDivision,
                    items: _divisions,
                    onChanged: (value) => setDialogState(() => selectedDivision = value ?? _divisions.first),
                  ),
                  _dropdownField(
                    label: 'District',
                    value: selectedDistrict,
                    items: _districts,
                    onChanged: (value) => setDialogState(() => selectedDistrict = value ?? _districts.first),
                  ),
                  TextFormField(controller: qualificationController, decoration: const InputDecoration(labelText: 'Qualification')),
                  TextFormField(controller: chamberController, decoration: const InputDecoration(labelText: 'Chamber')),
                  TextFormField(controller: contactController, decoration: const InputDecoration(labelText: 'Contact')),
                  TextFormField(
                    controller: ratingController,
                    decoration: const InputDecoration(labelText: 'Rating'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      return double.tryParse(v.trim()) == null ? 'Enter a number' : null;
                    },
                  ),
                  TextFormField(controller: detailsController, decoration: const InputDecoration(labelText: 'Details'), maxLines: 3),
                ],
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
    final payload = <String, dynamic>{
      if (existing?['id'] != null) 'id': existing!['id'],
      'name': nameController.text.trim(),
      'category': selectedCategory,
      'division': selectedDivision,
      'district': selectedDistrict,
      'qualification': qualificationController.text.trim(),
      'chamber': chamberController.text.trim(),
      'contact': contactController.text.trim(),
      'details': detailsController.text.trim(),
      'rating': double.tryParse(ratingController.text.trim()) ?? 0,
    };

    await _fs.saveDoctor(payload);
    if (mounted) await _reload();
  }



  Widget _dropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: items.contains(value) ? value : items.first,
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
