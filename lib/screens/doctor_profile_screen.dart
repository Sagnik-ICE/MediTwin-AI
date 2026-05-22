import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/firestore_service.dart';
import 'settings_screen.dart';
import '../widgets/glass_card.dart';

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({
    super.key,
    this.doctor,
    this.doctorId,
    this.allowBooking = true,
    this.canEdit = false,
  });

  final Map<String, dynamic>? doctor;
  final String? doctorId;
  final bool allowBooking;
  final bool canEdit;

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  final _fs = FirestoreService();
  Map<String, dynamic>? _doctor;
  List<Map<String, dynamic>> _appointments = [];
  bool _loading = true;
  bool _saving = false;
  String? _selectedChamber;

  @override
  void initState() {
    super.initState();
    _doctor = widget.doctor;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final appState = context.read<AppState>();
      final cachedUserId = appState.currentUserId;
      final cachedUserEmail = appState.currentUserEmail;
      final cachedIsDoctor = appState.isDoctor;
      final cachedIsAdmin = appState.isAdmin;

      if (_doctor == null) {
        if (widget.doctorId != null && widget.doctorId!.isNotEmpty) {
          _doctor = await _fs.getDoctorById(widget.doctorId!);
        } else if (cachedUserEmail != null) {
          _doctor = await _fs.getDoctorByUserId(cachedUserId ?? '');
        }
      }

      if (_doctor != null) {
        final doctorUserId = (_doctor!['doctorUserId'] ?? '').toString();
        final canSeeAll = cachedIsDoctor || cachedIsAdmin;
        _appointments = await _fs.queryDoctorAppointments(
          doctorUserId: doctorUserId.isNotEmpty ? doctorUserId : null,
          patientUid: canSeeAll ? null : cachedUserId,
        );
        _selectedChamber = _chambers.isNotEmpty ? _chambers.first['name']?.toString() : null;
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _chambers {
    final raw = _doctor?['chambers'];
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().toList();
    }
    final chamber = (_doctor?['chamber'] ?? '').toString().trim();
    if (chamber.isEmpty) return const [];
    return [
      {'name': chamber, 'address': _doctor?['contact'] ?? '', 'availableDays': _doctor?['availableDays'] ?? const []},
    ];
  }

  @override
  Widget build(BuildContext context) {
    final doctor = _doctor;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor profile'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings_rounded),
          ),
          if (!_loading && doctor != null && widget.canEdit)
            IconButton(
              onPressed: _saving ? null : () => _editDoctor(doctor),
              icon: const Icon(Icons.edit_rounded),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : doctor == null
              ? const Center(child: Text('Doctor profile not found.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 32,
                                  child: Builder(
                                    builder: (context) {
                                      final name = (doctor['name'] ?? '').toString().trim();
                                      final initial = name.isEmpty ? 'D' : name[0].toUpperCase();
                                      return Text(initial);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text((doctor['name'] ?? '').toString(), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 4),
                                      Text((doctor['qualification'] ?? doctor['specialtySummary'] ?? '').toString(), style: Theme.of(context).textTheme.bodyMedium),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _chip(context, (doctor['category'] ?? 'Doctor').toString()),
                                          _chip(context, (doctor['division'] ?? '').toString()),
                                          _chip(context, (doctor['district'] ?? '').toString()),
                                          _chip(context, '⭐ ${((doctor['rating'] ?? 0) as num).toStringAsFixed(1)}'),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text((doctor['details'] ?? '').toString(), style: Theme.of(context).textTheme.bodyMedium),
                            const SizedBox(height: 12),
                            if ((doctor['profileImageUrl'] ?? '').toString().isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Image.network(doctor['profileImageUrl'].toString(), height: 180, width: double.infinity, fit: BoxFit.cover),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Chambers and availability', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 10),
                            if (_chambers.isEmpty)
                              const Text('No chamber information added yet.')
                            else
                              ..._chambers.map((chamber) {
                                final days = _normalizeDays(chamber['availableDays']);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text((chamber['name'] ?? 'Chamber').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                                          const SizedBox(height: 4),
                                          Text((chamber['address'] ?? chamber['contact'] ?? '').toString()),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: days.map((day) => Chip(label: Text(day))).toList(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Appointments', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                                if (widget.allowBooking)
                                  FilledButton.tonalIcon(
                                    onPressed: _bookAppointment,
                                    icon: const Icon(Icons.event_available_rounded),
                                    label: const Text('Book'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_appointments.isEmpty)
                              const Text('No appointments yet.')
                            else
                              ..._appointments.map(
                                (a) => Card(
                                  child: ListTile(
                                    leading: const Icon(Icons.calendar_month_rounded),
                                    title: Text((a['patientName'] ?? 'Appointment').toString()),
                                    subtitle: Text('${a['chamberName'] ?? ''}\n${a['appointmentAt'] ?? ''}'),
                                    isThreeLine: true,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Rating', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            Text('Average: ${((doctor['rating'] ?? 0) as num).toStringAsFixed(1)} from ${(doctor['ratingCount'] ?? 0)} reviews'),
                            const SizedBox(height: 12),
                            if (widget.allowBooking)
                              FilledButton.tonalIcon(
                                onPressed: _rateDoctor,
                                icon: const Icon(Icons.star_rounded),
                                label: const Text('Rate doctor'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _chip(BuildContext context, String text) {
    return Chip(label: Text(text));
  }

  List<String> _normalizeDays(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  Future<void> _bookAppointment() async {
    final appState = context.read<AppState>();
    final doctor = _doctor;
    if (doctor == null) return;
      if (appState.currentUserId == null || appState.currentUserId!.isEmpty) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to book an appointment.')));
      return;
    }
    final chambers = _chambers;
      if (chambers.isEmpty) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No chamber details available for booking.')));
      return;
    }

    String selectedChamber = _selectedChamber ?? chambers.first['name'].toString();
    DateTime? pickedDate;
    TimeOfDay? pickedTime;
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Book appointment'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedChamber,
                    items: chambers.map((c) => DropdownMenuItem(value: c['name'].toString(), child: Text(c['name'].toString()))).toList(),
                    onChanged: (value) => setDialogState(() => selectedChamber = value ?? selectedChamber),
                    decoration: const InputDecoration(labelText: 'Chamber'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (date != null) setDialogState(() => pickedDate = date);
                    },
                    icon: const Icon(Icons.date_range_rounded),
                    label: Text(pickedDate == null ? 'Pick date' : pickedDate!.toIso8601String().split('T').first),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                      if (time != null) setDialogState(() => pickedTime = time);
                    },
                    icon: const Icon(Icons.access_time_rounded),
                    label: Text(pickedTime == null ? 'Pick time' : pickedTime!.format(context)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: reasonController,
                    decoration: const InputDecoration(labelText: 'Reason for visit'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    maxLines: 3,
                  ),
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
              child: const Text('Book'),
            ),
          ],
        ),
      ),
    );

    if (!(confirmed ?? false) || pickedDate == null || pickedTime == null) return;

    final chamber = chambers.firstWhere((element) => element['name'].toString() == selectedChamber, orElse: () => chambers.first);
    final appointmentAt = DateTime(
      pickedDate!.year,
      pickedDate!.month,
      pickedDate!.day,
      pickedTime!.hour,
      pickedTime!.minute,
    );

    try {
      await _fs.saveDoctorAppointment({
        'doctorId': doctor['id']?.toString() ?? '',
        'doctorUserId': (doctor['doctorUserId'] ?? '').toString(),
        'doctorName': (doctor['name'] ?? '').toString(),
        'patientUid': appState.currentUserId ?? '',
        'patientName': appState.profile.name.isNotEmpty ? appState.profile.name : (appState.currentUserEmail ?? 'Patient'),
        'patientEmail': appState.currentUserEmail ?? '',
        'chamberName': chamber['name']?.toString() ?? selectedChamber,
        'chamberAddress': chamber['address']?.toString() ?? '',
        'appointmentAt': appointmentAt.toIso8601String(),
        'reason': reasonController.text.trim(),
        'status': 'pending',
      });
      if (mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appointment requested.')));
        await _load();
      }
    } catch (_) {
      if (mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to book appointment.')));
      }
    }
  }

  Future<void> _rateDoctor() async {
    final appState = context.read<AppState>();
    final doctor = _doctor;
    if (doctor == null) return;
      if (appState.currentUserId == null || appState.currentUserId!.isEmpty) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to rate a doctor.')));
      return;
    }
    double rating = 5;
    final reviewController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rate doctor'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                min: 1,
                max: 5,
                divisions: 4,
                value: rating,
                label: rating.toStringAsFixed(1),
                onChanged: (value) => setState(() => rating = value),
              ),
              Text('${rating.toStringAsFixed(1)} / 5'),
              TextField(controller: reviewController, decoration: const InputDecoration(labelText: 'Review (optional)'), maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Submit')),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    try {
      await _fs.saveDoctorRating(
        doctorId: doctor['id']?.toString() ?? '',
        doctorUserId: (doctor['doctorUserId'] ?? '').toString(),
        patientUid: appState.currentUserId ?? '',
        patientName: appState.profile.name.isNotEmpty ? appState.profile.name : (appState.currentUserEmail ?? 'Patient'),
        rating: rating,
        review: reviewController.text.trim(),
      );
      if (mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thank you for your rating.')));
        await _load();
      }
    } catch (_) {
      if (mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save rating.')));
      }
    }
  }

  Future<void> _editDoctor(Map<String, dynamic> doctor) async {
    final nameController = TextEditingController(text: doctor['name']?.toString() ?? '');
    final qualificationController = TextEditingController(text: doctor['qualification']?.toString() ?? '');
    final detailsController = TextEditingController(text: doctor['details']?.toString() ?? '');
    final imageController = TextEditingController(text: doctor['profileImageUrl']?.toString() ?? '');
    final contactController = TextEditingController(text: doctor['contact']?.toString() ?? '');
    final chambersController = TextEditingController(text: _serializeChambers(_chambers));
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit doctor profile'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: nameController, decoration: const InputDecoration(labelText: 'Name'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                TextFormField(controller: qualificationController, decoration: const InputDecoration(labelText: 'Qualification')),
                TextFormField(controller: contactController, decoration: const InputDecoration(labelText: 'Contact')),
                TextFormField(controller: imageController, decoration: const InputDecoration(labelText: 'Image URL')),
                TextFormField(controller: detailsController, decoration: const InputDecoration(labelText: 'Details'), maxLines: 3),
                TextFormField(
                  controller: chambersController,
                  decoration: const InputDecoration(labelText: 'Chambers'),
                  maxLines: 5,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Add at least one chamber' : null,
                ),
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
    );
    if (!(saved ?? false)) return;
    setState(() => _saving = true);
    try {
      final chambers = _parseChambers(chambersController.text);
      await _fs.saveDoctor({
        ...doctor,
        'name': nameController.text.trim(),
        'qualification': qualificationController.text.trim(),
        'contact': contactController.text.trim(),
        'details': detailsController.text.trim(),
        'profileImageUrl': imageController.text.trim(),
        'chambers': chambers,
        'chamber': chambers.isNotEmpty ? chambers.first['name'] : '',
      });
      await _load();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<Map<String, dynamic>> _parseChambers(String text) {
    return text.split('\n').map((line) {
      final parts = line.split('|').map((e) => e.trim()).toList();
      return {
        'name': parts.isNotEmpty ? parts[0] : 'Chamber',
        'address': parts.length > 1 ? parts[1] : '',
        'availableDays': parts.length > 2 ? parts[2].split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList() : <String>[],
      };
    }).where((entry) => (entry['name'] as String).trim().isNotEmpty).toList();
  }

  String _serializeChambers(List<Map<String, dynamic>> chambers) {
    return chambers.map((c) {
      final days = _normalizeDays(c['availableDays']).join(', ');
      return '${c['name']} | ${c['address'] ?? ''} | $days';
    }).join('\n');
  }
}
