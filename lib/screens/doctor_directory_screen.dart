// ignore_for_file: use_build_context_synchronously

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../constants/bd_locations.dart';
import '../providers/app_state.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/debug_logger.dart';
import '../widgets/doctor_photo.dart';
import 'doctor_profile_screen.dart';

class DoctorDirectoryScreen extends StatefulWidget {
  const DoctorDirectoryScreen({super.key});

  @override
  State<DoctorDirectoryScreen> createState() => _DoctorDirectoryScreenState();
}

class _DoctorDirectoryScreenState extends State<DoctorDirectoryScreen> {
  static const List<String> _divisions = BdLocations.divisions;
  static const List<String> _districts = BdLocations.districts;

  static const List<String> _defaultCategories = [
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

  static const List<String> _weekDays = ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

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
      // Default categories remain available if Firestore category loading fails.
    }
  }

  List<String> get _categories {
    final set = <String>{..._defaultCategories, ..._dynamicCategories};
    final values = set.toList()..sort();
    return ['All', ...values];
  }

  List<String> get _districtFilterItems {
    if (_division == 'All') return ['All', ..._districts];
    return ['All', ...BdLocations.districtsFor(_division)];
  }

  Future<void> _reload() async {
    if (mounted) setState(() => _loading = true);
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load doctors. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _visibleDoctors {
    final q = _query.trim().toLowerCase();
    return _doctors.where((doctor) {
      if (q.isEmpty) return true;
      return _searchBlob(doctor).contains(q);
    }).toList();
  }

  String _searchBlob(Map<String, dynamic> doctor) {
    final values = <String>[
      doctor['name']?.toString() ?? '',
      doctor['displayName']?.toString() ?? '',
      doctor['category']?.toString() ?? '',
      doctor['qualification']?.toString() ?? '',
      doctor['specialtySummary']?.toString() ?? '',
      doctor['details']?.toString() ?? '',
      doctor['division']?.toString() ?? '',
      doctor['district']?.toString() ?? '',
      doctor['contact']?.toString() ?? '',
      doctor['doctorEmail']?.toString() ?? '',
    ];
    for (final chamber in _normalizeChambers(doctor)) {
      values.add(chamber['name']?.toString() ?? '');
      values.add(chamber['address']?.toString() ?? '');
      values.addAll(_days(chamber));
      for (final slot in _slots(chamber)) {
        values.add(_slotLabel(slot));
      }
    }
    return values.join(' ').toLowerCase();
  }

  bool _isDedicatedDoctor(Map<String, dynamic> doctor) {
    final doctorUserId = (doctor['doctorUserId'] ?? '').toString().trim();
    final hasDedicatedProfile = doctor['hasDedicatedProfile'] == true;
    final acceptsAppointments = doctor['acceptsAppointments'] != false;
    return hasDedicatedProfile && doctorUserId.isNotEmpty && acceptsAppointments;
  }

  Future<void> _confirmDeleteDoctor(Map<String, dynamic> doctor) async {
    final id = doctor['id']?.toString() ?? '';
    final name = (doctor['name'] ?? 'this doctor').toString();
    if (id.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete doctor?'),
        content: Text('Delete $name and remove the linked database profile, appointments, ratings, and schedule data? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete permanently'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await _fs.deleteDoctorCompletely(doctor);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor database profile deleted.')),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete doctor profile: $e')),
      );
    }
  }

  Future<void> _openDoctorForm({Map<String, dynamic>? existing}) async {
    var nameValue = existing?['name']?.toString() ?? '';
    var qualificationValue = existing?['qualification']?.toString() ?? '';
    var contactValue = existing?['contact']?.toString() ?? '';
    var detailsValue = existing?['details']?.toString() ?? '';
    var emailValue = existing?['doctorEmail']?.toString() ?? '';
    var passwordValue = '';

    var selectedImageUrl = existing?['profileImageUrl']?.toString() ?? '';
    var imageError = '';
    final existingDoctorUserId = (existing?['doctorUserId'] ?? '').toString().trim();
    final hasDedicatedUser = existingDoctorUserId.isNotEmpty;
    var createDedicatedAccount = hasDedicatedUser || ((existing?['hasDedicatedProfile'] as bool?) ?? false);
    var saving = false;

    String? selectedCategory = _categories.contains(existing?['category']?.toString() ?? '')
        ? existing!['category'].toString()
        : null;
    String? selectedDivision = _divisions.contains(existing?['division']?.toString() ?? '')
        ? existing!['division'].toString()
        : null;
    String? selectedDistrict = _districts.contains(existing?['district']?.toString() ?? '')
        ? existing!['district'].toString()
        : null;

    var chamberDrafts = _normalizeChambers(existing).isEmpty
        ? [_newChamberDraft()]
        : _normalizeChambers(existing).map((item) => _copyChamberDraft(item)).toList();

    List<String> dialogDistrictItems() {
      if (selectedDivision == null || selectedDivision!.isEmpty) return _districts;
      return BdLocations.districtsFor(selectedDivision!);
    }

    String? validateSchedule() {
      if (chamberDrafts.isEmpty) return 'Add at least one chamber.';
      for (var i = 0; i < chamberDrafts.length; i++) {
        final chamber = chamberDrafts[i];
        final name = (chamber['name'] ?? '').toString().trim();
        final days = _days(chamber);
        final slots = _slots(chamber);
        if (name.isEmpty) return 'Enter chamber ${i + 1} name.';
        if (days.isEmpty) return 'Select available days for $name.';
        if (slots.isEmpty) return 'Add at least one patient time for $name.';
      }
      return null;
    }

    final formKey = GlobalKey<FormState>();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickDoctorImage() async {
              if (saving) return;
              setDialogState(() => imageError = '');
              try {
                final picker = ImagePicker();
                final image = await picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 512,
                  maxHeight: 512,
                  imageQuality: 76,
                );
                if (!mounted || !dialogContext.mounted || image == null) return;

                final bytes = await image.readAsBytes();
                if (!mounted || !dialogContext.mounted) return;

                const maxBytes = 350 * 1024;
                if (bytes.length > maxBytes) {
                  setDialogState(() => imageError = 'Image is too large. Choose a smaller portrait photo.');
                  return;
                }

                final lowerName = image.name.toLowerCase();
                final mime = lowerName.endsWith('.png') ? 'image/png' : 'image/jpeg';
                setDialogState(() {
                  selectedImageUrl = 'data:$mime;base64,${base64Encode(bytes)}';
                  imageError = '';
                });
              } catch (e, st) {
                DebugLogger.warning('Failed to select doctor image', e, st);
                if (!mounted || !dialogContext.mounted) return;
                setDialogState(() => imageError = 'Could not select the image. Try another smaller photo.');
              }
            }

            Future<void> pickSlotTime({required int chamberIndex, required int slotIndex, required String field}) async {
              final chamber = chamberDrafts[chamberIndex];
              final slots = _slots(chamber);
              final current = slots[slotIndex][field]?.toString() ?? (field == 'start' ? '17:00' : '19:00');
              final parsed = _parseTimeOfDay(current) ?? const TimeOfDay(hour: 17, minute: 0);
              final picked = await showTimePicker(context: dialogContext, initialTime: parsed);
              if (picked == null) return;
              setDialogState(() {
                slots[slotIndex][field] = _formatTimeValue(picked);
                slots[slotIndex]['label'] = _slotLabel(slots[slotIndex]);
                chamberDrafts[chamberIndex]['timeSlots'] = slots;
              });
            }

            Future<void> submit() async {
              if (saving) return;
              if (!(formKey.currentState?.validate() ?? false)) return;
              if (selectedCategory == null || selectedDivision == null || selectedDistrict == null) return;

              final scheduleError = validateSchedule();
              if (scheduleError != null) {
                ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(scheduleError)));
                return;
              }

              setDialogState(() => saving = true);
              final chambers = chamberDrafts.map(_cleanChamberForSave).toList();
              final aggregateDays = <String>{};
              for (final chamber in chambers) {
                aggregateDays.addAll(_days(chamber));
              }
              final willHaveDedicatedProfile = createDedicatedAccount || hasDedicatedUser;

              final payload = <String, dynamic>{
                if (existing?['id'] != null) 'id': existing!['id'],
                'name': nameValue.trim(),
                'category': selectedCategory,
                'division': selectedDivision,
                'district': selectedDistrict,
                'qualification': qualificationValue.trim(),
                'chamber': chambers.isNotEmpty ? chambers.first['name'] : '',
                'chambers': chambers,
                'availableDays': aggregateDays.toList(),
                'contact': contactValue.trim(),
                'contactInfo': contactValue.trim(),
                'profileImageUrl': selectedImageUrl.trim(),
                'details': detailsValue.trim(),
                'specialtySummary': qualificationValue.trim().isNotEmpty
                    ? qualificationValue.trim()
                    : detailsValue.trim(),
                'rating': existing?['rating'] ?? 0,
                'ratingCount': existing?['ratingCount'] ?? 0,
                'acceptsAppointments': willHaveDedicatedProfile,
                'hasDedicatedProfile': willHaveDedicatedProfile,
              };

              String? error;
              if (createDedicatedAccount && !hasDedicatedUser) {
                final appState = this.context.read<AppState>();
                error = await appState.addDoctorAccount(
                  email: emailValue.trim(),
                  password: passwordValue.trim(),
                  displayName: nameValue.trim(),
                  doctorData: payload,
                );
              } else {
                try {
                  await _fs.saveDoctor(payload);
                } catch (_) {
                  error = 'Failed to save doctor. Please check the information and try again.';
                }
              }

              if (!dialogContext.mounted) return;
              setDialogState(() => saving = false);
              if (error != null) {
                ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(error)));
                return;
              }
              Navigator.pop(dialogContext, true);
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                  child: SafeArea(
                    top: false,
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Center(
                            child: Container(
                              width: 48,
                              height: 5,
                              decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(99)),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      existing == null ? 'Add doctor' : 'Edit doctor',
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Set profile, chamber days, and patient visiting times professionally.',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(onPressed: saving ? null : () => Navigator.pop(dialogContext, false), icon: const Icon(Icons.close_rounded)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _FormSection(
                            title: 'Doctor photo',
                            icon: Icons.photo_camera_rounded,
                            children: [
                              Row(
                                children: [
                                  DoctorPhoto(name: nameValue.trim(), imageUrl: selectedImageUrl, size: 78, radius: 24),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Profile portrait', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 4),
                                        Text('Use a clear square portrait. The app stores a compressed free image inside Firestore.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                                        if (imageError.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(imageError, style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w700)),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: saving ? null : pickDoctorImage,
                                      icon: const Icon(Icons.upload_rounded),
                                      label: const Text('Upload photo'),
                                    ),
                                  ),
                                  if (selectedImageUrl.isNotEmpty) ...[
                                    const SizedBox(width: 10),
                                    OutlinedButton.icon(
                                      onPressed: saving ? null : () => setDialogState(() => selectedImageUrl = ''),
                                      icon: const Icon(Icons.close_rounded),
                                      label: const Text('Remove'),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _FormSection(
                            title: 'Professional information',
                            icon: Icons.badge_rounded,
                            children: [
                              TextFormField(
                                initialValue: nameValue,
                                enabled: !saving,
                                decoration: const InputDecoration(labelText: 'Doctor name'),
                                onChanged: (value) => setDialogState(() => nameValue = value),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Doctor name is required' : null,
                              ),
                              const SizedBox(height: 12),
                              _dropdownField(
                                label: 'Specialty category',
                                value: selectedCategory,
                                items: _categories.where((item) => item != 'All').toList(),
                                enabled: !saving,
                                onChanged: (value) => setDialogState(() => selectedCategory = value),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                initialValue: qualificationValue,
                                enabled: !saving,
                                decoration: const InputDecoration(labelText: 'Qualification / specialty summary'),
                                onChanged: (value) => qualificationValue = value,
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Qualification is required' : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                initialValue: detailsValue,
                                enabled: !saving,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  labelText: 'Profile details',
                                  hintText: 'Example: Experienced cardiologist focused on hypertension and preventive care.',
                                ),
                                onChanged: (value) => detailsValue = value,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _FormSection(
                            title: 'Location and contact',
                            icon: Icons.place_rounded,
                            children: [
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final wide = constraints.maxWidth >= 620;
                                  final fields = [
                                    _dropdownField(
                                      label: 'Division',
                                      value: selectedDivision,
                                      items: _divisions,
                                      enabled: !saving,
                                      onChanged: (value) {
                                        setDialogState(() {
                                          selectedDivision = value;
                                          if (value == null || !BdLocations.districtsFor(value).contains(selectedDistrict)) {
                                            selectedDistrict = null;
                                          }
                                        });
                                      },
                                    ),
                                    _dropdownField(
                                      label: 'District',
                                      value: selectedDistrict,
                                      items: dialogDistrictItems(),
                                      enabled: !saving,
                                      onChanged: (value) => setDialogState(() => selectedDistrict = value),
                                    ),
                                  ];
                                  if (!wide) return Column(children: [fields[0], const SizedBox(height: 12), fields[1]]);
                                  return Row(children: [Expanded(child: fields[0]), const SizedBox(width: 12), Expanded(child: fields[1])]);
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                initialValue: contactValue,
                                enabled: !saving,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(labelText: 'Contact number'),
                                onChanged: (value) => contactValue = value,
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Contact number is required' : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _FormSection(
                            title: 'Chambers and patient schedule',
                            icon: Icons.apartment_rounded,
                            children: [
                              Text(
                                'Each chamber has its own available days and one or more patient visiting time blocks.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                              ),
                              const SizedBox(height: 12),
                              ...List.generate(chamberDrafts.length, (index) {
                                final chamber = chamberDrafts[index];
                                return _ChamberScheduleEditor(
                                  key: ValueKey(chamber['id']),
                                  chamber: chamber,
                                  index: index,
                                  canRemove: chamberDrafts.length > 1,
                                  saving: saving,
                                  days: _weekDays,
                                  onChanged: (updated) => setDialogState(() => chamberDrafts[index] = updated),
                                  onRemove: () => setDialogState(() => chamberDrafts.removeAt(index)),
                                  onAddSlot: () {
                                    setDialogState(() {
                                      final slots = _slots(chamber);
                                      slots.add(_newSlotDraft());
                                      chamber['timeSlots'] = slots;
                                    });
                                  },
                                  onPickSlotTime: pickSlotTime,
                                );
                              }),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: saving
                                    ? null
                                    : () => setDialogState(() => chamberDrafts.add(_newChamberDraft())),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Add another chamber'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _FormSection(
                            title: 'Dedicated doctor login',
                            icon: Icons.verified_user_rounded,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceSoft,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Material(
                                  type: MaterialType.transparency,
                                  child: SwitchListTile(
                                    value: createDedicatedAccount,
                                    onChanged: hasDedicatedUser || saving
                                        ? null
                                        : (value) => setDialogState(() => createDedicatedAccount = value),
                                    title: Text(
                                      hasDedicatedUser ? 'Dedicated account linked' : 'Create dedicated account',
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                    subtitle: Text(
                                      hasDedicatedUser
                                          ? 'This doctor can log in and manage chambers, appointments, and serials.'
                                          : 'Only dedicated doctors can receive appointment requests.',
                                    ),
                                  ),
                                ),
                              ),
                              if (createDedicatedAccount && !hasDedicatedUser) ...[
                                const SizedBox(height: 12),
                                TextFormField(
                                  initialValue: emailValue,
                                  enabled: !saving,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(labelText: 'Doctor login email'),
                                  onChanged: (value) => emailValue = value,
                                  validator: (value) {
                                    if (!createDedicatedAccount || hasDedicatedUser) return null;
                                    final text = value?.trim() ?? '';
                                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) return 'Enter a valid email';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  initialValue: passwordValue,
                                  enabled: !saving,
                                  obscureText: true,
                                  decoration: const InputDecoration(labelText: 'Temporary password'),
                                  onChanged: (value) => passwordValue = value,
                                  validator: (value) {
                                    if (!createDedicatedAccount || hasDedicatedUser) return null;
                                    if ((value ?? '').trim().length < 6) return 'Password must be at least 6 characters';
                                    return null;
                                  },
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: saving ? null : () => Navigator.pop(dialogContext, false),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: saving ? null : submit,
                                  icon: saving
                                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.check_rounded),
                                  label: Text(saving ? 'Saving...' : 'Save doctor'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (saved == true && mounted) await _reload();
  }

  Widget _dropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool enabled = true,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((item) => DropdownMenuItem<String>(value: item, child: Text(item)))
          .toList(),
      onChanged: enabled ? onChanged : null,
      validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
    );
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _division = 'All';
      _district = 'All';
      _category = 'All';
    });
    _reload();
  }

  void _openDoctor(Map<String, dynamic> doctor) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DoctorProfileScreen(doctor: doctor)),
    );
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isAdmin = appState.isAdmin;
    final doctors = _visibleDoctors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctors'),
        actions: [
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: () => _openDoctorForm(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add doctor'),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            _DirectoryHero(isAdmin: isAdmin),
            const SizedBox(height: 16),
            _FilterCard(
              searchController: _searchController,
              query: _query,
              division: _division,
              district: _district,
              category: _category,
              categories: _categories,
              divisions: ['All', ..._divisions],
              districts: _districtFilterItems,
              onQueryChanged: (value) => setState(() => _query = value),
              onDivisionChanged: (value) {
                setState(() {
                  _division = value ?? 'All';
                  if (!_districtFilterItems.contains(_district)) _district = 'All';
                });
                _reload();
              },
              onDistrictChanged: (value) {
                setState(() => _district = value ?? 'All');
                _reload();
              },
              onCategoryChanged: (value) {
                setState(() => _category = value ?? 'All');
                _reload();
              },
              onClear: _clearFilters,
            ),
            const SizedBox(height: 16),
            if (_loading)
              const _LoadingDoctors()
            else if (doctors.isEmpty)
              _EmptyDoctors(hasQuery: _query.trim().isNotEmpty || _division != 'All' || _district != 'All' || _category != 'All', onClear: _clearFilters)
            else
              ...doctors.map(
                (doctor) => _DoctorCard(
                  doctor: doctor,
                  isDedicated: _isDedicatedDoctor(doctor),
                  isAdmin: isAdmin,
                  onView: () => _openDoctor(doctor),
                  onEdit: () => _openDoctorForm(existing: doctor),
                  onDelete: () => _confirmDeleteDoctor(doctor),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _newChamberDraft() {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    return {
      'id': id,
      'name': '',
      'address': '',
      'days': <String>[],
      'availableDays': <String>[],
      'timeSlots': [_newSlotDraft()],
    };
  }

  Map<String, dynamic> _newSlotDraft() {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    return {'id': id, 'start': '17:00', 'end': '19:00', 'label': '5:00 PM - 7:00 PM'};
  }

  Map<String, dynamic> _copyChamberDraft(Map<String, dynamic> chamber) {
    final days = _days(chamber);
    final slots = _slots(chamber);
    return {
      'id': (chamber['id'] ?? DateTime.now().microsecondsSinceEpoch.toString()).toString(),
      'name': (chamber['name'] ?? '').toString(),
      'address': (chamber['address'] ?? chamber['contact'] ?? '').toString(),
      'days': days,
      'availableDays': days,
      'timeSlots': slots.isEmpty ? [_newSlotDraft()] : slots,
    };
  }

  Map<String, dynamic> _cleanChamberForSave(Map<String, dynamic> chamber) {
    final days = _days(chamber);
    final slots = _slots(chamber)
        .map((slot) => {
              'id': (slot['id'] ?? DateTime.now().microsecondsSinceEpoch.toString()).toString(),
              'start': (slot['start'] ?? '').toString(),
              'end': (slot['end'] ?? '').toString(),
              'label': _slotLabel(slot),
            })
        .toList();
    return {
      'id': (chamber['id'] ?? DateTime.now().microsecondsSinceEpoch.toString()).toString(),
      'name': (chamber['name'] ?? '').toString().trim(),
      'address': (chamber['address'] ?? '').toString().trim(),
      'days': days,
      'availableDays': days,
      'timeSlots': slots,
    };
  }

  List<Map<String, dynamic>> _normalizeChambers(Map<String, dynamic>? doctor) {
    if (doctor == null) return const [];
    final raw = doctor['chambers'];
    if (raw is List) {
      final result = <Map<String, dynamic>>[];
      for (final item in raw) {
        if (item is Map) result.add(Map<String, dynamic>.from(item));
      }
      if (result.isNotEmpty) return result;
    }
    final chamber = (doctor['chamber'] ?? '').toString().trim();
    if (chamber.isEmpty) return const [];
    return [
      {
        'id': 'legacy_0',
        'name': chamber,
        'address': (doctor['chamberAddress'] ?? doctor['contact'] ?? '').toString(),
        'days': _stringList(doctor['availableDays']),
        'availableDays': _stringList(doctor['availableDays']),
        'timeSlots': <Map<String, dynamic>>[],
      }
    ];
  }

  List<String> _days(Map<String, dynamic> chamber) {
    final values = _stringList(chamber['days']).isNotEmpty ? _stringList(chamber['days']) : _stringList(chamber['availableDays']);
    return values.where((day) => _weekDays.contains(day)).toList();
  }

  List<Map<String, dynamic>> _slots(Map<String, dynamic> chamber) {
    final raw = chamber['timeSlots'];
    if (raw is List) {
      return raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    }
    return <Map<String, dynamic>>[];
  }

  List<String> _stringList(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    if (raw is String && raw.trim().isNotEmpty) return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return const [];
  }

  TimeOfDay? _parseTimeOfDay(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTimeValue(TimeOfDay value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  String _slotLabel(Map<String, dynamic> slot) {
    final start = _parseTimeOfDay((slot['start'] ?? '').toString());
    final end = _parseTimeOfDay((slot['end'] ?? '').toString());
    if (start == null || end == null) return (slot['label'] ?? 'Patient time').toString();
    return '${_displayTime(start)} - ${_displayTime(end)}';
  }

  String _displayTime(TimeOfDay time) {
    final hour12 = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:${time.minute.toString().padLeft(2, '0')} $period';
  }
}

class _DirectoryHero extends StatelessWidget {
  const _DirectoryHero({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: AppTheme.softShadow(),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.medical_services_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Find the right doctor', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  isAdmin ? 'Manage professional doctor profiles and chamber schedules.' : 'Search doctors by specialty, district, chamber, or availability.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.88)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.searchController,
    required this.query,
    required this.division,
    required this.district,
    required this.category,
    required this.categories,
    required this.divisions,
    required this.districts,
    required this.onQueryChanged,
    required this.onDivisionChanged,
    required this.onDistrictChanged,
    required this.onCategoryChanged,
    required this.onClear,
  });

  final TextEditingController searchController;
  final String query;
  final String division;
  final String district;
  final String category;
  final List<String> categories;
  final List<String> divisions;
  final List<String> districts;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onDivisionChanged;
  final ValueChanged<String?> onDistrictChanged;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), border: Border.all(color: AppTheme.border), boxShadow: AppTheme.softShadow()),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            onChanged: onQueryChanged,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              labelText: 'Search doctors',
              hintText: 'Name, specialty, chamber, district, schedule...',
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              final fields = [
                _SimpleDropdown(label: 'Category', value: category, items: categories, onChanged: onCategoryChanged),
                _SimpleDropdown(label: 'Division', value: division, items: divisions, onChanged: onDivisionChanged),
                _SimpleDropdown(label: 'District', value: district, items: districts, onChanged: onDistrictChanged),
              ];
              if (!wide) {
                return Column(children: [fields[0], const SizedBox(height: 10), fields[1], const SizedBox(height: 10), fields[2]]);
              }
              return Row(children: [Expanded(child: fields[0]), const SizedBox(width: 10), Expanded(child: fields[1]), const SizedBox(width: 10), Expanded(child: fields[2])]);
            },
          ),
          if (query.isNotEmpty || division != 'All' || district != 'All' || category != 'All') ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(onPressed: onClear, icon: const Icon(Icons.clear_rounded), label: const Text('Clear filters')),
            ),
          ],
        ],
      ),
    );
  }
}

class _SimpleDropdown extends StatelessWidget {
  const _SimpleDropdown({required this.label, required this.value, required this.items, required this.onChanged});

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: items.contains(value) ? value : items.first,
      decoration: InputDecoration(labelText: label),
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
    );
  }
}

class _DoctorCard extends StatelessWidget {
  const _DoctorCard({required this.doctor, required this.isDedicated, required this.isAdmin, required this.onView, required this.onEdit, required this.onDelete});

  final Map<String, dynamic> doctor;
  final bool isDedicated;
  final bool isAdmin;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name = (doctor['name'] ?? 'Doctor').toString();
    final category = (doctor['category'] ?? '').toString();
    final qualification = (doctor['qualification'] ?? doctor['specialtySummary'] ?? '').toString();
    final location = [doctor['district'], doctor['division']].map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).join(', ');
    final image = (doctor['profileImageUrl'] ?? '').toString();
    final rating = (doctor['rating'] as num?)?.toDouble() ?? 0;
    final ratingCount = (doctor['ratingCount'] as num?)?.toInt() ?? 0;
    final chambers = _chambers(doctor);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: AppTheme.border), boxShadow: AppTheme.softShadow()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DoctorPhoto(name: name, imageUrl: image, size: 72, radius: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                        ),
                        if (isAdmin)
                          PopupMenuButton<String>(
                            tooltip: 'Doctor actions',
                            onSelected: (value) {
                              if (value == 'edit') onEdit();
                              if (value == 'delete') onDelete();
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit doctor')),
                              PopupMenuItem(value: 'delete', child: Text('Delete doctor')),
                            ],
                          ),
                      ],
                    ),
                    if (category.isNotEmpty) Text(category, style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.w800)),
                    if (qualification.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(qualification, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (location.isNotEmpty) _InfoChip(icon: Icons.place_rounded, label: location),
              _InfoChip(icon: Icons.star_rounded, label: ratingCount == 0 ? 'No rating' : '${rating.toStringAsFixed(1)} ($ratingCount)'),
              _InfoChip(icon: isDedicated ? Icons.verified_rounded : Icons.list_alt_rounded, label: isDedicated ? 'Appointment enabled' : 'Listed profile'),
              if (chambers.isNotEmpty) _InfoChip(icon: Icons.apartment_rounded, label: '${chambers.length} chamber${chambers.length == 1 ? '' : 's'}'),
            ],
          ),
          if (chambers.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_schedulePreview(chambers.first), maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
          ],
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(onPressed: onView, icon: const Icon(Icons.arrow_forward_rounded), label: const Text('View profile')),
          ),
        ],
      ),
    );
  }

  static List<Map<String, dynamic>> _chambers(Map<String, dynamic> doctor) {
    final raw = doctor['chambers'];
    if (raw is List) return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return const [];
  }

  static String _schedulePreview(Map<String, dynamic> chamber) {
    final name = (chamber['name'] ?? 'Chamber').toString();
    final days = (chamber['days'] is List ? chamber['days'] : chamber['availableDays'] is List ? chamber['availableDays'] : const []) as List;
    final slots = chamber['timeSlots'] is List ? chamber['timeSlots'] as List : const [];
    final dayText = days.map((e) => e.toString()).join(', ');
    final slotText = slots.whereType<Map>().map((slot) => (slot['label'] ?? '').toString()).where((e) => e.isNotEmpty).join(' • ');
    return '$name${dayText.isNotEmpty ? ' · $dayText' : ''}${slotText.isNotEmpty ? ' · $slotText' : ''}';
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: AppTheme.surfaceTint, borderRadius: BorderRadius.circular(999), border: Border.all(color: AppTheme.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16, color: AppTheme.primaryTeal), const SizedBox(width: 6), Text(label, style: const TextStyle(fontWeight: FontWeight.w700))]),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.icon, required this.children});

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surfaceSoft, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(width: 34, height: 34, decoration: BoxDecoration(color: AppTheme.accentMint, borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 18, color: AppTheme.primaryTeal)),
          const SizedBox(width: 10),
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 14),
        ...children,
      ]),
    );
  }
}

class _ChamberScheduleEditor extends StatelessWidget {
  const _ChamberScheduleEditor({
    super.key,
    required this.chamber,
    required this.index,
    required this.canRemove,
    required this.saving,
    required this.days,
    required this.onChanged,
    required this.onRemove,
    required this.onAddSlot,
    required this.onPickSlotTime,
  });

  final Map<String, dynamic> chamber;
  final int index;
  final bool canRemove;
  final bool saving;
  final List<String> days;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final VoidCallback onRemove;
  final VoidCallback onAddSlot;
  final Future<void> Function({required int chamberIndex, required int slotIndex, required String field}) onPickSlotTime;

  @override
  Widget build(BuildContext context) {
    final selectedDays = _stringList(chamber['days']).toSet();
    final slots = _slots(chamber);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Chamber ${index + 1}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
          if (canRemove) IconButton(onPressed: saving ? null : onRemove, icon: const Icon(Icons.delete_outline_rounded)),
        ]),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: (chamber['name'] ?? '').toString(),
          enabled: !saving,
          decoration: const InputDecoration(labelText: 'Chamber name'),
          onChanged: (value) => onChanged({...chamber, 'name': value}),
        ),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: (chamber['address'] ?? '').toString(),
          enabled: !saving,
          decoration: const InputDecoration(labelText: 'Address / room details'),
          onChanged: (value) => onChanged({...chamber, 'address': value}),
        ),
        const SizedBox(height: 14),
        Text('Available days', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: days.map((day) {
            final selected = selectedDays.contains(day);
            return FilterChip(
              label: Text(day),
              selected: selected,
              onSelected: saving
                  ? null
                  : (value) {
                      final next = {...selectedDays};
                      if (value) {
                        next.add(day);
                      } else {
                        next.remove(day);
                      }
                      onChanged({...chamber, 'days': next.toList(), 'availableDays': next.toList()});
                    },
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: Text('Patient visiting times', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900))),
          TextButton.icon(onPressed: saving ? null : onAddSlot, icon: const Icon(Icons.add_rounded), label: const Text('Add time')),
        ]),
        const SizedBox(height: 6),
        ...List.generate(slots.length, (slotIndex) {
          final slot = slots[slotIndex];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.surfaceTint, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppTheme.border)),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: saving ? null : () => onPickSlotTime(chamberIndex: index, slotIndex: slotIndex, field: 'start'),
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text('Start ${_timeLabel(slot['start'])}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: saving ? null : () => onPickSlotTime(chamberIndex: index, slotIndex: slotIndex, field: 'end'),
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text('End ${_timeLabel(slot['end'])}'),
                ),
              ),
              IconButton(
                tooltip: 'Remove time',
                onPressed: saving || slots.length == 1
                    ? null
                    : () {
                        final next = List<Map<String, dynamic>>.from(slots)..removeAt(slotIndex);
                        onChanged({...chamber, 'timeSlots': next});
                      },
                icon: const Icon(Icons.close_rounded),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    return const [];
  }

  static List<Map<String, dynamic>> _slots(Map<String, dynamic> chamber) {
    final raw = chamber['timeSlots'];
    if (raw is List) return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return const [];
  }

  static String _timeLabel(dynamic value) {
    final parts = value?.toString().split(':') ?? const [];
    if (parts.length != 2) return '--';
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return '--';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final period = hour >= 12 ? 'PM' : 'AM';
    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }
}

class _LoadingDoctors extends StatelessWidget {
  const _LoadingDoctors();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Loading doctor profiles...', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _EmptyDoctors extends StatelessWidget {
  const _EmptyDoctors({required this.hasQuery, required this.onClear});

  final bool hasQuery;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(34),
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(color: AppTheme.surfaceSoft, borderRadius: BorderRadius.circular(24)),
              child: const Icon(Icons.search_off_rounded, size: 34, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            Text(hasQuery ? 'No doctors match your search' : 'No doctors found', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              hasQuery ? 'Try a different specialty, location, chamber, or doctor name.' : 'Doctor profiles will appear here once they are added.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (hasQuery) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(onPressed: onClear, icon: const Icon(Icons.clear_rounded), label: const Text('Clear filters')),
            ],
          ],
        ),
      ),
    );
  }
}
