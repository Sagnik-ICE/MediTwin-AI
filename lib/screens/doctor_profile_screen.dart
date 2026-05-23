import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/doctor_photo.dart';
import 'settings_screen.dart';

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({
    super.key,
    this.doctor,
    this.doctorId,
    this.allowBooking = true,
    this.canEdit = false,
    this.showSettingsButton = true,
  });

  final Map<String, dynamic>? doctor;
  final String? doctorId;
  final bool allowBooking;
  final bool canEdit;
  final bool showSettingsButton;

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

        final chambers = _chambers;
        _selectedChamber = chambers.isNotEmpty ? chambers.first['name']?.toString() : null;
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

  Map<String, dynamic>? _completedAppointmentForCurrentUser(String currentUserId) {
    if (currentUserId.trim().isEmpty) return null;

    for (final appointment in _appointments) {
      final patientUid = (appointment['patientUid'] ?? '').toString().trim();
      final status = (appointment['status'] ?? '').toString().trim().toLowerCase();
      final appointmentId = (appointment['id'] ?? '').toString().trim();

      if (patientUid == currentUserId && status == 'completed' && appointmentId.isNotEmpty) {
        return appointment;
      }
    }

    return null;
  }

  static const List<String> _weekDays = ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

  List<Map<String, dynamic>> get _chambers {
    final raw = _doctor?['chambers'];
    if (raw is List) {
      final chambers = raw.whereType<Map>().map((item) => _normalizeChamber(Map<String, dynamic>.from(item))).toList();
      if (chambers.isNotEmpty) return chambers;
    }

    final chamber = (_doctor?['chamber'] ?? '').toString().trim();
    if (chamber.isEmpty) return const [];

    final days = _stringList(_doctor?['availableDays']);
    return [
      {
        'id': 'legacy_0',
        'name': chamber,
        'address': (_doctor?['chamberAddress'] ?? _doctor?['contact'] ?? '').toString(),
        'days': days,
        'availableDays': days,
        'timeSlots': <Map<String, dynamic>>[],
      },
    ];
  }

  Map<String, dynamic> _normalizeChamber(Map<String, dynamic> chamber) {
    final days = _days(chamber);
    return {
      'id': (chamber['id'] ?? chamber['name'] ?? DateTime.now().microsecondsSinceEpoch).toString(),
      'name': (chamber['name'] ?? 'Chamber').toString().trim(),
      'address': (chamber['address'] ?? chamber['contact'] ?? '').toString().trim(),
      'days': days,
      'availableDays': days,
      'timeSlots': _timeSlots(chamber),
    };
  }

  List<String> _days(Map<String, dynamic> chamber) {
    final values = _stringList(chamber['days']).isNotEmpty
        ? _stringList(chamber['days'])
        : _stringList(chamber['availableDays']);
    return values.where((day) => _weekDays.contains(day)).toList();
  }

  List<Map<String, dynamic>> _timeSlots(Map<String, dynamic> chamber) {
    final raw = chamber['timeSlots'];
    if (raw is List) {
      return raw.whereType<Map>().map((item) {
        final map = Map<String, dynamic>.from(item);
        map['id'] = (map['id'] ?? DateTime.now().microsecondsSinceEpoch).toString();
        map['label'] = _slotLabel(map);
        return map;
      }).toList();
    }
    return <Map<String, dynamic>>[];
  }

  List<String> _stringList(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    if (raw is String && raw.trim().isNotEmpty) {
      return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  String _slotLabel(Map<String, dynamic> slot) {
    final explicit = (slot['label'] ?? '').toString().trim();
    final start = _parseTimeOfDay((slot['start'] ?? '').toString());
    final end = _parseTimeOfDay((slot['end'] ?? '').toString());
    if (start == null || end == null) return explicit.isEmpty ? 'Patient time' : explicit;
    return '${_displayTime(start)} - ${_displayTime(end)}';
  }

  TimeOfDay? _parseTimeOfDay(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _displayTime(TimeOfDay time) {
    final hour12 = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:${time.minute.toString().padLeft(2, '0')} $period';
  }

  int _weekdayIndex(String day) {
    switch (day) {
      case 'Mon':
        return DateTime.monday;
      case 'Tue':
        return DateTime.tuesday;
      case 'Wed':
        return DateTime.wednesday;
      case 'Thu':
        return DateTime.thursday;
      case 'Fri':
        return DateTime.friday;
      case 'Sat':
        return DateTime.saturday;
      case 'Sun':
        return DateTime.sunday;
      default:
        return -1;
    }
  }

  bool _dateMatchesChamber(DateTime date, Map<String, dynamic> chamber) {
    final days = _days(chamber);
    if (days.isEmpty) return true;
    return days.map(_weekdayIndex).contains(date.weekday);
  }

  @override
  Widget build(BuildContext context) {
    final doctor = _doctor;
    final appState = context.watch<AppState>();
    final currentUserId = appState.currentUserId ?? '';
    final doctorUserId = (doctor?['doctorUserId'] ?? '').toString().trim();
    final canManageAppointments = doctor != null &&
        (appState.isAdmin || (doctorUserId.isNotEmpty && doctorUserId == currentUserId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor profile'),
        actions: [
          if (widget.showSettingsButton && doctorUserId.isNotEmpty && doctorUserId == currentUserId)
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
              ? _EmptyDoctorState(onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                    children: [
                      _DoctorHero(
                        doctor: doctor,
                        isDedicated: _isDedicatedDoctor,
                        canBook: _canBookCurrentDoctor,
                        onBook: _bookAppointment,
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        icon: Icons.apartment_rounded,
                        title: 'Chambers and availability',
                        subtitle: _chambers.isEmpty
                            ? 'No chamber information has been added yet.'
                            : '${_chambers.length} chamber${_chambers.length == 1 ? '' : 's'} available',
                        trailing: canManageAppointments
                            ? OutlinedButton.icon(
                                onPressed: _saving ? null : _editChambers,
                                icon: const Icon(Icons.edit_calendar_rounded),
                                label: const Text('Edit schedule'),
                              )
                            : null,
                        child: _chambers.isEmpty
                            ? const _EmptySectionText('Chamber information will appear here once added.')
                            : Column(
                                children: _chambers
                                    .map((chamber) => _ChamberTile(chamber: chamber, days: _days(chamber), slots: _timeSlots(chamber)))
                                    .toList(),
                              ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        icon: Icons.event_note_rounded,
                        title: 'Appointments',
                        subtitle: canManageAppointments
                            ? 'Manage patient appointment requests.'
                            : _canBookCurrentDoctor
                                ? 'Request an appointment with this doctor.'
                                : 'Appointments are not enabled for this listing.',
                        trailing: _canBookCurrentDoctor
                            ? FilledButton.icon(
                                onPressed: _saving ? null : _bookAppointment,
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Book'),
                              )
                            : null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.allowBooking && !_isDedicatedDoctor) ...[
                              _NoticeBox(
                                icon: Icons.info_outline_rounded,
                                text: 'Appointments are available only for dedicated doctor profiles.',
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (_appointments.isEmpty)
                              const _EmptySectionText('No appointments yet.')
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
                      const SizedBox(height: 16),
                      _RatingPanel(
                        rating: _number(doctor['rating']),
                        ratingCount: _number(doctor['ratingCount']).toInt(),
                        canRate: widget.allowBooking && _isDedicatedDoctor && _completedAppointmentForCurrentUser(currentUserId) != null,
                        canEventuallyRate: widget.allowBooking && _isDedicatedDoctor,
                        onRate: _rateDoctor,
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

    final patientName = (appointment['patientName'] ?? 'Appointment').toString().trim();
    final chamberName = (appointment['chamberName'] ?? '').toString().trim();
    final reason = (appointment['reason'] ?? '').toString().trim();
    final slotLabel = (appointment['appointmentTimeLabel'] ?? appointment['slotLabel'] ?? '').toString().trim();
    final serialNumber = (appointment['serialNumber'] ?? '').toString().trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.accentMint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.calendar_month_rounded, color: AppTheme.primaryTeal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        patientName.isEmpty ? 'Appointment' : patientName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                      ),
                    ),
                    _statusChip(status),
                  ],
                ),
                const SizedBox(height: 8),
                _MetaLine(icon: Icons.schedule_rounded, text: _formatAppointmentDate(appointment['appointmentAt'])),
                if (slotLabel.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _MetaLine(icon: Icons.access_time_rounded, text: slotLabel),
                ],
                if (serialNumber.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _MetaLine(icon: Icons.confirmation_number_rounded, text: 'Serial no. $serialNumber'),
                ],
                if (chamberName.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _MetaLine(icon: Icons.location_on_outlined, text: chamberName),
                ],
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    reason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                  ),
                ],
              ],
            ),
          ),
          if (canManageAppointments || canPatientCancel) ...[
            const SizedBox(width: 6),
            PopupMenuButton<String>(
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
            ),
          ],
        ],
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

    final color = switch (status) {
      'confirmed' => AppTheme.primaryBlue,
      'completed' => AppTheme.primaryTeal,
      'cancelled' => Colors.redAccent,
      _ => Colors.orange,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
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

  List<String> _normalizeDays(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  num _number(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? 0;
    return 0;
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

  Map<String, dynamic> _cleanChamberForSave(Map<String, dynamic> chamber) {
    final days = _days(chamber);
    final slots = _timeSlots(chamber)
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

  String _formatTimeValue(TimeOfDay value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _editChambers() async {
    final doctor = _doctor;
    if (doctor == null) return;
    final doctorId = (doctor['id'] ?? '').toString().trim();
    if (doctorId.isEmpty) return;

    var drafts = _chambers.isEmpty ? [_newChamberDraft()] : _chambers.map((item) => Map<String, dynamic>.from(item)).toList();
    var saving = false;
    String? formError;

    String? validateSchedule() {
      if (drafts.isEmpty) return 'Add at least one chamber.';
      for (var i = 0; i < drafts.length; i++) {
        final chamber = drafts[i];
        final name = (chamber['name'] ?? '').toString().trim();
        if (name.isEmpty) return 'Enter chamber ${i + 1} name.';
        if (_days(chamber).isEmpty) return 'Select available days for $name.';
        if (_timeSlots(chamber).isEmpty) return 'Add at least one patient time for $name.';
      }
      return null;
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickSlotTime({required int chamberIndex, required int slotIndex, required String field}) async {
            final chamber = drafts[chamberIndex];
            final slots = _timeSlots(chamber);
            final current = slots[slotIndex][field]?.toString() ?? (field == 'start' ? '17:00' : '19:00');
            final parsed = _parseTimeOfDay(current) ?? const TimeOfDay(hour: 17, minute: 0);
            final picked = await showTimePicker(context: dialogContext, initialTime: parsed);
            if (picked == null) return;
            setDialogState(() {
              slots[slotIndex][field] = _formatTimeValue(picked);
              slots[slotIndex]['label'] = _slotLabel(slots[slotIndex]);
              drafts[chamberIndex]['timeSlots'] = slots;
            });
          }

          Future<void> submit() async {
            if (saving) return;
            final error = validateSchedule();
            if (error != null) {
              setDialogState(() => formError = error);
              return;
            }
            setDialogState(() {
              saving = true;
              formError = null;
            });
            final chambers = drafts.map(_cleanChamberForSave).toList();
            final days = <String>{};
            for (final chamber in chambers) {
              days.addAll(_days(chamber));
            }
            try {
              await _fs.saveDoctor({
                'id': doctorId,
                'chambers': chambers,
                'chamber': chambers.first['name'],
                'availableDays': days.toList(),
              });
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
            } catch (_) {
              if (dialogContext.mounted) {
                setDialogState(() {
                  saving = false;
                  formError = 'Failed to update schedule. Please try again.';
                });
              }
            }
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(width: 48, height: 5, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(99))),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Edit chambers and schedule', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                              const SizedBox(height: 4),
                              Text('Patients can book only from these chamber days and patient time blocks.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted)),
                            ]),
                          ),
                          IconButton(onPressed: saving ? null : () => Navigator.pop(dialogContext, false), icon: const Icon(Icons.close_rounded)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...List.generate(drafts.length, (index) {
                        final chamber = drafts[index];
                        return _ChamberScheduleEditor(
                          key: ValueKey(chamber['id']),
                          chamber: chamber,
                          index: index,
                          canRemove: drafts.length > 1,
                          saving: saving,
                          days: _weekDays,
                          onChanged: (updated) => setDialogState(() => drafts[index] = updated),
                          onRemove: () => setDialogState(() => drafts.removeAt(index)),
                          onAddSlot: () => setDialogState(() {
                            final slots = _timeSlots(chamber);
                            slots.add(_newSlotDraft());
                            drafts[index]['timeSlots'] = slots;
                          }),
                          onPickSlotTime: pickSlotTime,
                        );
                      }),
                      OutlinedButton.icon(
                        onPressed: saving ? null : () => setDialogState(() => drafts.add(_newChamberDraft())),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add another chamber'),
                      ),
                      if (formError != null) ...[
                        const SizedBox(height: 12),
                        Text(formError!, style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w800)),
                      ],
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: saving ? null : submit,
                        icon: saving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_rounded),
                        label: Text(saving ? 'Saving...' : 'Save schedule'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    if (saved == true && mounted) {
      await _load();
    }
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

    String? serialNumber;
    if (normalizedStatus == 'confirmed') {
      serialNumber = await _askSerialNumber(initialValue: (appointment['serialNumber'] ?? '').toString());
      if (serialNumber == null) return;
      // Let the serial input route finish closing before mutating the profile screen.
      // This avoids Flutter Web inherited-widget teardown assertions during dialog pop.
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
    }

    if (!mounted) return;
    setState(() => _saving = true);
    try {
      await _fs.updateDoctorAppointmentStatus(
        appointmentId: appointmentId,
        status: normalizedStatus,
        serialNumber: serialNumber,
      );

      if (!mounted) return;
      final label = normalizedStatus[0].toUpperCase() + normalizedStatus.substring(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(normalizedStatus == 'confirmed' && (serialNumber ?? '').isNotEmpty
            ? 'Appointment confirmed with serial no. $serialNumber.'
            : 'Appointment marked $label.')),
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

  Future<String?> _askSerialNumber({String initialValue = ''}) async {
    // Keep this serial input intentionally lightweight. On Flutter Web, disposing
    // dialog TextEditingControllers immediately after Navigator.pop can trigger
    // inherited-widget teardown assertions during the dialog close animation.
    final controller = TextEditingController(text: initialValue.trim());
    String? errorText;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Confirm appointment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    labelText: 'Patient serial number',
                    hintText: 'Example: 12',
                    errorText: errorText,
                    helperText: 'Visible to the patient after confirmation.',
                  ),
                  onSubmitted: (_) {
                    final value = controller.text.trim();
                    if (value.isEmpty) {
                      setDialogState(() => errorText = 'Serial number is required');
                      return;
                    }
                    Navigator.of(dialogContext).pop(value);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(null),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.isEmpty) {
                    setDialogState(() => errorText = 'Serial number is required');
                    return;
                  }
                  Navigator.of(dialogContext).pop(value);
                },
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      ),
    );

    // Do not dispose immediately after dialog pop on web; the route may still be
    // finalizing its frame. This controller is short-lived and the safe tradeoff
    // prevents the _dependents.isEmpty red-screen assertion.
    return result?.trim().isEmpty == true ? null : result?.trim();
  }

  Future<void> _bookAppointment() async {
    final appState = context.read<AppState>();
    final doctor = _doctor;
    if (doctor == null) return;

    if (!_isDedicatedDoctor) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointments can only be booked with dedicated doctor profiles.')),
      );
      return;
    }

    if (appState.currentUserId == null || appState.currentUserId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to book an appointment.')));
      return;
    }

    final doctorId = (doctor['id'] ?? '').toString().trim();
    final doctorUserId = (doctor['doctorUserId'] ?? '').toString().trim();

    if (doctorId.isEmpty || doctorUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This doctor profile is not ready for appointment booking.')),
      );
      return;
    }

    final chambers = _chambers.where((chamber) => _timeSlots(chamber).isNotEmpty).toList();
    if (chambers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This doctor has not added patient visiting times yet.')));
      return;
    }

    Map<String, dynamic> selectedChamber = chambers.first;
    DateTime? pickedDate;
    Map<String, dynamic>? selectedSlot = _timeSlots(selectedChamber).first;
    String? selectionError;
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final slots = _timeSlots(selectedChamber);
          if (selectedSlot == null || !slots.any((slot) => slot['id'] == selectedSlot?['id'])) {
            selectedSlot = slots.isEmpty ? null : slots.first;
          }

          return AlertDialog(
            title: const Text('Request appointment'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: (selectedChamber['id'] ?? selectedChamber['name']).toString(),
                      items: chambers
                          .map((c) => DropdownMenuItem(
                                value: (c['id'] ?? c['name']).toString(),
                                child: Text((c['name'] ?? 'Chamber').toString()),
                              ))
                          .toList(),
                      onChanged: (value) {
                        final next = chambers.firstWhere(
                          (element) => (element['id'] ?? element['name']).toString() == value,
                          orElse: () => chambers.first,
                        );
                        setDialogState(() {
                          selectedChamber = next;
                          selectedSlot = _timeSlots(next).isEmpty ? null : _timeSlots(next).first;
                          pickedDate = null;
                          selectionError = null;
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Chamber'),
                    ),
                    const SizedBox(height: 12),
                    _ScheduleSummary(chamber: selectedChamber, days: _days(selectedChamber), slots: _timeSlots(selectedChamber), slotLabel: _slotLabel),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final now = DateTime.now();
                        var initial = now.add(const Duration(days: 1));
                        for (var i = 0; i < 14; i++) {
                          final candidate = now.add(Duration(days: i + 1));
                          if (_dateMatchesChamber(candidate, selectedChamber)) {
                            initial = candidate;
                            break;
                          }
                        }
                        final date = await showDatePicker(
                          context: context,
                          firstDate: now,
                          lastDate: now.add(const Duration(days: 365)),
                          initialDate: initial,
                          selectableDayPredicate: (date) => _dateMatchesChamber(date, selectedChamber),
                        );
                        if (date != null) setDialogState(() {
                          pickedDate = date;
                          selectionError = null;
                        });
                      },
                      icon: const Icon(Icons.date_range_rounded),
                      label: Text(pickedDate == null ? 'Select available date' : _formatDateOnly(pickedDate!)),
                    ),
                    const SizedBox(height: 12),
                    Text('Patient time', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    if (slots.isEmpty)
                      const Text('No patient time is configured for this chamber.')
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: slots.map((slot) {
                          final selected = selectedSlot?['id'] == slot['id'];
                          return ChoiceChip(
                            label: Text(_slotLabel(slot)),
                            selected: selected,
                            onSelected: (_) => setDialogState(() {
                              selectedSlot = slot;
                              selectionError = null;
                            }),
                          );
                        }).toList(),
                      ),
                    if (selectionError != null) ...[
                      const SizedBox(height: 10),
                      Text(selectionError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
                    setDialogState(() => selectionError = 'Please select an available appointment date.');
                    return;
                  }
                  if (selectedSlot == null) {
                    setDialogState(() => selectionError = 'Please select a patient time.');
                    return;
                  }
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Request'),
              ),
            ],
          );
        },
      ),
    );

    if (!(confirmed ?? false) || pickedDate == null || selectedSlot == null) {
      reasonController.dispose();
      return;
    }

    final start = _parseTimeOfDay((selectedSlot!['start'] ?? '').toString()) ?? const TimeOfDay(hour: 0, minute: 0);
    final appointmentAt = DateTime(pickedDate!.year, pickedDate!.month, pickedDate!.day, start.hour, start.minute);
    final chamberId = (selectedChamber['id'] ?? selectedChamber['name']).toString();
    final slotId = (selectedSlot!['id'] ?? _slotLabel(selectedSlot!)).toString();
    final slotLabel = _slotLabel(selectedSlot!);

    try {
      await _fs.saveDoctorAppointment({
        'doctorId': doctorId,
        'doctorUserId': doctorUserId,
        'doctorName': (doctor['name'] ?? '').toString(),
        'patientUid': appState.currentUserId ?? '',
        'patientName': appState.profile.name.isNotEmpty ? appState.profile.name : (appState.currentUserEmail ?? 'Patient'),
        'patientEmail': appState.currentUserEmail ?? '',
        'chamberId': chamberId,
        'chamberName': (selectedChamber['name'] ?? 'Chamber').toString(),
        'chamberAddress': (selectedChamber['address'] ?? '').toString(),
        'slotId': slotId,
        'appointmentTimeLabel': slotLabel,
        'appointmentAt': appointmentAt,
        'reason': reasonController.text.trim(),
        'status': 'pending',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appointment requested.')));
        await _load();
      }
    } catch (_) {
      if (mounted) {
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to rate a doctor.')));
      return;
    }
    final completedAppointment = _completedAppointmentForCurrentUser(appState.currentUserId ?? '');
    final appointmentId = (completedAppointment?['id'] ?? '').toString().trim();

    if (appointmentId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ratings are available after a completed appointment.')),
        );
      }
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
        appointmentId: appointmentId,
        patientUid: appState.currentUserId ?? '',
        patientName: appState.profile.name.isNotEmpty ? appState.profile.name : (appState.currentUserEmail ?? 'Patient'),
        rating: rating,
        review: reviewController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thank you for your rating.')));
        await _load();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save rating.')));
      }
    } finally {
      reviewController.dispose();
    }
  }
}

class _DoctorHero extends StatelessWidget {
  const _DoctorHero({
    required this.doctor,
    required this.isDedicated,
    required this.canBook,
    required this.onBook,
  });

  final Map<String, dynamic> doctor;
  final bool isDedicated;
  final bool canBook;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final name = (doctor['name'] ?? 'Doctor').toString().trim();
    final qualification = (doctor['qualification'] ?? doctor['specialtySummary'] ?? '').toString().trim();
    final details = (doctor['details'] ?? '').toString().trim();
    final category = (doctor['category'] ?? 'Doctor').toString().trim();
    final division = (doctor['division'] ?? '').toString().trim();
    final district = (doctor['district'] ?? '').toString().trim();
    final rating = doctor['rating'] is num ? doctor['rating'] as num : num.tryParse((doctor['rating'] ?? '0').toString()) ?? 0;
    final ratingCount = doctor['ratingCount'] is num ? doctor['ratingCount'] as num : num.tryParse((doctor['ratingCount'] ?? '0').toString()) ?? 0;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(34),
        boxShadow: AppTheme.softShadow(),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          final header = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DoctorPhoto(
                name: name,
                imageUrl: (doctor['profileImageUrl'] ?? '').toString(),
                size: wide ? 112 : 86,
                radius: 28,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Doctor' : name,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    if (qualification.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        qualification,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.88),
                              height: 1.35,
                            ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _HeroPill(icon: Icons.medical_services_rounded, text: category),
                        if (district.isNotEmpty || division.isNotEmpty)
                          _HeroPill(icon: Icons.location_on_rounded, text: [district, division].where((e) => e.isNotEmpty).join(', ')),
                        _HeroPill(icon: Icons.star_rounded, text: '${rating.toStringAsFixed(1)} · ${ratingCount.toInt()} reviews'),
                        _HeroPill(icon: isDedicated ? Icons.verified_rounded : Icons.badge_outlined, text: isDedicated ? 'Dedicated profile' : 'Listed doctor'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              header,
              if (details.isNotEmpty) ...[
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
                  ),
                  child: Text(
                    details,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.90),
                          height: 1.45,
                        ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (canBook)
                    FilledButton.icon(
                      onPressed: onBook,
                      icon: const Icon(Icons.event_available_rounded),
                      label: const Text('Book appointment'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryBlue,
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => Scrollable.ensureVisible(
                      context,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    ),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    label: const Text('View details'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.55)),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.accentMint,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: AppTheme.primaryTeal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ChamberTile extends StatelessWidget {
  const _ChamberTile({required this.chamber, required this.days, required this.slots});

  final Map<String, dynamic> chamber;
  final List<String> days;
  final List<Map<String, dynamic>> slots;

  @override
  Widget build(BuildContext context) {
    final name = (chamber['name'] ?? 'Chamber').toString().trim();
    final address = (chamber['address'] ?? chamber['contact'] ?? '').toString().trim();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceTint,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.local_hospital_rounded, color: AppTheme.primaryBlue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name.isEmpty ? 'Chamber' : name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          if (address.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(address, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted)),
          ],
          if (days.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Available days', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: days.map((day) => _MiniChip(label: day, icon: Icons.calendar_today_rounded)).toList(),
            ),
          ],
          if (slots.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Patient visiting times', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: slots.map((slot) => _MiniChip(label: (slot['label'] ?? 'Patient time').toString(), icon: Icons.access_time_rounded)).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleSummary extends StatelessWidget {
  const _ScheduleSummary({required this.chamber, required this.days, required this.slots, required this.slotLabel});

  final Map<String, dynamic> chamber;
  final List<String> days;
  final List<Map<String, dynamic>> slots;
  final String Function(Map<String, dynamic>) slotLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceTint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if ((chamber['address'] ?? '').toString().trim().isNotEmpty) ...[
          _MetaLine(icon: Icons.place_rounded, text: (chamber['address'] ?? '').toString()),
          const SizedBox(height: 8),
        ],
        if (days.isNotEmpty) Wrap(spacing: 6, runSpacing: 6, children: days.map((day) => _MiniChip(label: day, icon: Icons.calendar_today_rounded)).toList()),
        if (slots.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: slots.map((slot) => _MiniChip(label: slotLabel(slot), icon: Icons.access_time_rounded)).toList()),
        ],
      ]),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primaryTeal),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
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

class _RatingPanel extends StatelessWidget {
  const _RatingPanel({
    required this.rating,
    required this.ratingCount,
    required this.canRate,
    required this.canEventuallyRate,
    required this.onRate,
  });

  final num rating;
  final int ratingCount;
  final bool canRate;
  final bool canEventuallyRate;
  final VoidCallback onRate;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.star_rounded,
      title: 'Patient rating',
      subtitle: ratingCount == 0 ? 'No reviews yet.' : '$ratingCount completed appointment review${ratingCount == 1 ? '' : 's'}',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.warning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.warning.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, color: AppTheme.warning, size: 20),
            const SizedBox(width: 6),
            Text(
              rating.toStringAsFixed(1),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canRate)
            FilledButton.icon(
              onPressed: onRate,
              icon: const Icon(Icons.rate_review_rounded),
              label: const Text('Rate doctor'),
            )
          else if (canEventuallyRate)
            const _EmptySectionText('You can rate this doctor after a completed appointment.')
          else
            const _EmptySectionText('Ratings are available for dedicated doctor profiles.'),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
          ),
        ),
      ],
    );
  }
}

class _NoticeBox extends StatelessWidget {
  const _NoticeBox({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceTint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _EmptySectionText extends StatelessWidget {
  const _EmptySectionText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
    );
  }
}

class _EmptyDoctorState extends StatelessWidget {
  const _EmptyDoctorState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppTheme.border),
            boxShadow: AppTheme.softShadow(),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.accentMint,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(Icons.person_search_rounded, color: AppTheme.primaryTeal, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                'Doctor profile not found',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                'This profile may have been removed or is not linked correctly.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
