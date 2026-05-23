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
    if (!mounted) return;

    setState(() => _loading = true);

    try {
      final appState = context.read<AppState>();
      final cachedUserId = (appState.currentUserId ?? '').trim();
      final cachedIsAdmin = appState.isAdmin;

      // Always refetch the public doctor document. Previously, this screen kept
      // the first _doctor map in memory and never reloaded it after returning
      // from Settings → Profile, so the private profile showed the new name but
      // the doctor home/list card still showed stale data.
      final explicitDoctorId = widget.doctorId?.trim() ?? '';
      final currentDoctorId = (_doctor?['id'] ?? widget.doctor?['id'] ?? '').toString().trim();

      Map<String, dynamic>? freshDoctor;
      if (explicitDoctorId.isNotEmpty) {
        freshDoctor = await _fs.getDoctorById(explicitDoctorId);
      } else if (currentDoctorId.isNotEmpty) {
        freshDoctor = await _fs.getDoctorById(currentDoctorId);
      } else if (cachedUserId.isNotEmpty) {
        freshDoctor = await _fs.getDoctorByUserId(cachedUserId);
      }

      if (!mounted) return;

      // If logout/login changed while the public doctor document was loading,
      // do not continue with appointment queries using a stale user id.
      final liveUserId = (context.read<AppState>().currentUserId ?? '').trim();
      if (liveUserId != cachedUserId) return;

      _doctor = freshDoctor ?? _doctor ?? widget.doctor;

      if (_doctor != null) {
        final doctorUserId = (_doctor!['doctorUserId'] ?? '').toString().trim();
        if (doctorUserId.isNotEmpty && cachedUserId.isNotEmpty) {
          final canSeeAll = cachedIsAdmin || doctorUserId == cachedUserId;
          final fetchedAppointments = await _fs.queryDoctorAppointments(
            doctorUserId: doctorUserId,
            patientUid: canSeeAll ? null : cachedUserId,
          );

          if (!mounted) return;
          final currentUserIdAfterQuery = (context.read<AppState>().currentUserId ?? '').trim();
          if (currentUserIdAfterQuery != cachedUserId) return;

          _appointments = fetchedAppointments;
        } else {
          _appointments = <Map<String, dynamic>>[];
        }
        _selectedChamber = _chambers.isNotEmpty ? _chambers.first['name']?.toString() : null;
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _isDedicatedDoctor {
    final doctor = _doctor;
    if (doctor == null) return false;

    final doctorUserId = (doctor['doctorUserId'] ?? '').toString().trim();
    final hasDedicatedProfile = doctor['hasDedicatedProfile'] == true;
    final acceptsAppointments = doctor['acceptsAppointments'] != false;

    return hasDedicatedProfile && doctorUserId.isNotEmpty && acceptsAppointments;
  }

  bool get _canBookCurrentDoctor => widget.allowBooking && _isDedicatedDoctor;

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
    final appState = context.watch<AppState>();
    final currentUserId = appState.currentUserId ?? '';
    final doctorUserId = (doctor?['doctorUserId'] ?? '').toString().trim();
    final canManageAppointments = doctor != null &&
        (appState.isAdmin ||
            (doctorUserId.isNotEmpty && doctorUserId == currentUserId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor profile'),
        actions: [
          if (doctorUserId.isNotEmpty && doctorUserId == currentUserId)
            IconButton(
              tooltip: 'Profile settings',
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
                if (mounted) {
                  await context.read<AppState>().refreshAuthState();
                  await _load();
                }
              },
              icon: const Icon(Icons.settings_rounded),
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
                                child: Image.network(
                                  doctor['profileImageUrl'].toString(),
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    height: 180,
                                    width: double.infinity,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    ),
                                    child: const Icon(Icons.broken_image_rounded, size: 42),
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
                                if (_canBookCurrentDoctor)
                                  FilledButton.tonalIcon(
                                    onPressed: _bookAppointment,
                                    icon: const Icon(Icons.event_available_rounded),
                                    label: const Text('Book'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (widget.allowBooking && !_isDedicatedDoctor) ...[
                              const Text(
                                'Appointments are available only for dedicated doctor profiles.',
                              ),
                              const SizedBox(height: 8),
                            ],
                            if (_appointments.isEmpty)
                              const Text('No appointments yet.')
                            else
                              ..._appointments.map(
                                (a) => _appointmentCard(
                                  appointment: a,
                                  currentUserId: currentUserId,
                                  canManageAppointments: canManageAppointments,
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

  Widget _appointmentCard({
    required Map<String, dynamic> appointment,
    required String currentUserId,
    required bool canManageAppointments,
  }) {
    final status = _appointmentStatus(appointment);
    final patientUid = (appointment['patientUid'] ?? '').toString().trim();
    final canPatientCancel = !canManageAppointments &&
        patientUid.isNotEmpty &&
        patientUid == currentUserId &&
        (status == 'pending' || status == 'confirmed');

    return Card(
      child: ListTile(
        leading: const Icon(Icons.calendar_month_rounded),
        title: Text((appointment['patientName'] ?? 'Appointment').toString()),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text((appointment['chamberName'] ?? '').toString()),
            Text(_formatAppointmentDate(appointment['appointmentAt'])),
            const SizedBox(height: 6),
            _statusChip(status),
          ],
        ),
        isThreeLine: true,
        trailing: canManageAppointments || canPatientCancel
            ? PopupMenuButton<String>(
                tooltip: 'Appointment actions',
                onSelected: _saving
                    ? null
                    : (value) {
                        if (value == 'delete') {
                          _deleteAppointment(appointment);
                          return;
                        }
                        _updateAppointmentStatus(appointment, value);
                      },
                itemBuilder: (context) => [
                  if (canManageAppointments) ...[
                    const PopupMenuItem(value: 'confirmed', child: Text('Mark confirmed')),
                    const PopupMenuItem(value: 'completed', child: Text('Mark completed')),
                    const PopupMenuItem(value: 'cancelled', child: Text('Mark cancelled')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'delete', child: Text('Delete permanently')),
                  ] else if (canPatientCancel)
                    const PopupMenuItem(value: 'cancelled', child: Text('Cancel appointment')),
                ],
              )
            : null,
      ),
    );
  }

  Widget _statusChip(String status) {
    final label = switch (status) {
      'confirmed' => 'Confirmed',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => 'Pending',
    };

    final icon = switch (status) {
      'confirmed' => Icons.check_circle_outline_rounded,
      'completed' => Icons.done_all_rounded,
      'cancelled' => Icons.cancel_outlined,
      _ => Icons.hourglass_top_rounded,
    };

    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }


  String _formatAppointmentDate(dynamic value) {
    final date = _parseDate(value);
    if (date == null) return 'Date not set';

    final hour12 = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.day} ${_monthName(date.month)} ${date.year}, $hour12:$minute $period';
  }

  String _formatDateOnly(DateTime date) {
    return '${date.day} ${_monthName(date.month)} ${date.year}';
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    try {
      final converted = value.toDate();
      if (converted is DateTime) return converted;
    } catch (_) {
      // Ignore unsupported date shapes.
    }
    return null;
  }

  String _monthName(int month) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (month < 1 || month > 12) return '';
    return names[month - 1];
  }

  String _appointmentStatus(Map<String, dynamic> appointment) {
    final status = (appointment['status'] ?? 'pending').toString().trim().toLowerCase();
    if (status == 'confirmed' || status == 'completed' || status == 'cancelled') {
      return status;
    }
    return 'pending';
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

  Future<void> _deleteAppointment(Map<String, dynamic> appointment) async {
    final appointmentId = (appointment['id'] ?? '').toString().trim();

    if (appointmentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment ID is missing.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete appointment?'),
        content: const Text(
          'This will permanently delete the appointment. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_forever_rounded),
            label: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!(confirmed ?? false)) return;

    setState(() => _saving = true);
    try {
      await _fs.deleteDoctorAppointment(appointmentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment deleted permanently.')),
        );
        await _load();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete appointment.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateAppointmentStatus(Map<String, dynamic> appointment, String status) async {
    final appointmentId = (appointment['id'] ?? '').toString().trim();
    final normalizedStatus = status.trim().toLowerCase();

    if (appointmentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment ID is missing.')),
      );
      return;
    }

    if (normalizedStatus != 'confirmed' &&
        normalizedStatus != 'completed' &&
        normalizedStatus != 'cancelled' &&
        normalizedStatus != 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unsupported appointment status.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _fs.updateDoctorAppointmentStatus(
        appointmentId: appointmentId,
        status: normalizedStatus,
      );

      if (!mounted) return;
      final label = normalizedStatus[0].toUpperCase() + normalizedStatus.substring(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Appointment marked $label.')),
      );
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update appointment.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _bookAppointment() async {
    final appState = context.read<AppState>();
    final doctor = _doctor;
    if (doctor == null) return;

    if (!_isDedicatedDoctor) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointments can only be booked with dedicated doctor profiles.'),
        ),
      );
      return;
    }

    if (appState.currentUserId == null || appState.currentUserId!.isEmpty) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to book an appointment.')));
      return;
    }

    final doctorId = (doctor['id'] ?? '').toString().trim();
    final doctorUserId = (doctor['doctorUserId'] ?? '').toString().trim();

    if (doctorId.isEmpty || doctorUserId.isEmpty) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This doctor profile is not ready for appointment booking.')),
      );
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
    String? selectionError;
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
                    label: Text(pickedDate == null ? 'Pick date' : _formatDateOnly(pickedDate!)),
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
                  if (selectionError != null) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        selectionError!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  ],
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
                if (!(formKey.currentState?.validate() ?? false)) return;

                if (pickedDate == null) {
                  setDialogState(() => selectionError = 'Please select an appointment date.');
                  return;
                }

                if (pickedTime == null) {
                  setDialogState(() => selectionError = 'Please select an appointment time.');
                  return;
                }

                Navigator.pop(dialogContext, true);
              },
              child: const Text('Book'),
            ),
          ],
        ),
      ),
    );

    if (!(confirmed ?? false) || pickedDate == null || pickedTime == null) {
      reasonController.dispose();
      return;
    }

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
        'doctorId': doctorId,
        'doctorUserId': doctorUserId,
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
    } finally {
      reasonController.dispose();
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
    if (!(confirmed ?? false)) {
      reviewController.dispose();
      return;
    }
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
    } finally {
      reviewController.dispose();
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
    if (!(saved ?? false)) {
      nameController.dispose();
      qualificationController.dispose();
      detailsController.dispose();
      imageController.dispose();
      contactController.dispose();
      chambersController.dispose();
      return;
    }
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
      nameController.dispose();
      qualificationController.dispose();
      detailsController.dispose();
      imageController.dispose();
      contactController.dispose();
      chambersController.dispose();
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
