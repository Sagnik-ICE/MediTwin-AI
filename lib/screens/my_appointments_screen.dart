import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/firestore_service.dart';
import 'doctor_profile_screen.dart';

class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> {
  final _fs = FirestoreService();
  List<Map<String, dynamic>> _appointments = const [];
  bool _loading = true;
  bool _updating = false;
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    final userId = appState.currentUserId?.trim() ?? '';

    if (userId.isEmpty) {
      if (mounted) {
        setState(() {
          _appointments = const [];
          _loading = false;
          _lastUserId = null;
        });
      }
      return;
    }

    setState(() {
      _loading = true;
      _lastUserId = userId;
    });

    final items = await _fs.queryDoctorAppointments(patientUid: userId);

    if (!mounted) return;
    if (_lastUserId != userId) return;

    setState(() {
      _appointments = items;
      _loading = false;
    });
  }

  Future<void> _cancelAppointment(Map<String, dynamic> appointment) async {
    if (_updating) return;

    final appointmentId = (appointment['id'] ?? '').toString().trim();
    if (appointmentId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel appointment?'),
        content: const Text('This will cancel your appointment request. You can book again from the doctor profile if needed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel appointment'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _updating = true);

    try {
      await _fs.updateDoctorAppointmentStatus(
        appointmentId: appointmentId,
        status: 'cancelled',
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment cancelled.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not cancel this appointment. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  void _openDoctor(Map<String, dynamic> appointment) {
    final doctorId = (appointment['doctorId'] ?? '').toString().trim();
    if (doctorId.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DoctorProfileScreen(
          doctorId: doctorId,
          allowBooking: true,
          canEdit: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = _appointments.where(_isUpcomingOrActive).toList();
    final past = _appointments.where((item) => !_isUpcomingOrActive(item)).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  _HeroPanel(total: _appointments.length, active: upcoming.length),
                  const SizedBox(height: 18),
                  if (_loading)
                    const _LoadingCard()
                  else if (_appointments.isEmpty)
                    const _EmptyAppointmentsCard()
                  else ...[
                    _SectionHeader(
                      title: 'Upcoming and active',
                      subtitle: 'Track booked requests, confirmed visits, and serial numbers.',
                      count: upcoming.length,
                    ),
                    const SizedBox(height: 12),
                    if (upcoming.isEmpty)
                      const _SoftNotice(text: 'No upcoming appointments.')
                    else
                      ...upcoming.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _AppointmentCard(
                            appointment: item,
                            updating: _updating,
                            onCancel: _canPatientCancel(item) ? () => _cancelAppointment(item) : null,
                            onOpenDoctor: () => _openDoctor(item),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    _SectionHeader(
                      title: 'Past history',
                      subtitle: 'Completed and cancelled appointment records.',
                      count: past.length,
                    ),
                    const SizedBox(height: 12),
                    if (past.isEmpty)
                      const _SoftNotice(text: 'No past appointments yet.')
                    else
                      ...past.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _AppointmentCard(
                            appointment: item,
                            compact: true,
                            updating: _updating,
                            onCancel: null,
                            onOpenDoctor: () => _openDoctor(item),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isUpcomingOrActive(Map<String, dynamic> appointment) {
    final status = _statusOf(appointment);
    if (status == 'cancelled' || status == 'completed') return false;

    final at = _dateFrom(appointment['appointmentAt']);
    if (at == null) return true;

    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    return !at.isBefore(startOfToday);
  }

  bool _canPatientCancel(Map<String, dynamic> appointment) {
    final status = _statusOf(appointment);
    return status == 'pending' || status == 'confirmed';
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.total, required this.active});

  final int total;
  final int active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.tertiary],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withOpacity(0.18),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 680;
          final titleBlock = Column(
            crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.24)),
                ),
                child: const Icon(Icons.event_note_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                'My appointments',
                textAlign: wide ? TextAlign.left : TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Follow appointment requests, confirmed visits, and doctor-assigned serial numbers.',
                textAlign: wide ? TextAlign.left : TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withOpacity(0.88),
                  height: 1.35,
                ),
              ),
            ],
          );

          final metrics = Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: wide ? WrapAlignment.end : WrapAlignment.center,
            children: [
              _HeroMetric(label: 'Active', value: active.toString()),
              _HeroMetric(label: 'Total', value: total.toString()),
            ],
          );

          if (!wide) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                titleBlock,
                const SizedBox(height: 20),
                metrics,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: titleBlock),
              const SizedBox(width: 24),
              metrics,
            ],
          );
        },
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 116,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.86),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle, required this.count});

  final String title;
  final String subtitle;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colors.primaryContainer.withOpacity(0.55),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.primary.withOpacity(0.18)),
          ),
          child: Text(
            count.toString(),
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.updating,
    required this.onOpenDoctor,
    this.onCancel,
    this.compact = false,
  });

  final Map<String, dynamic> appointment;
  final bool updating;
  final VoidCallback onOpenDoctor;
  final VoidCallback? onCancel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final status = _statusOf(appointment);
    final statusColor = _statusColor(status, colors);
    final appointmentAt = _dateFrom(appointment['appointmentAt']);
    final doctorName = _firstNonEmpty([
      appointment['doctorName'],
      appointment['displayName'],
      appointment['name'],
    ], fallback: 'Doctor');
    final chamberName = _firstNonEmpty([appointment['chamberName'], appointment['chamber']], fallback: 'Chamber not specified');
    final timeBlock = _firstNonEmpty([appointment['timeBlock'], appointment['timeLabel']], fallback: 'Time block not specified');
    final reason = _firstNonEmpty([appointment['reason']], fallback: 'No reason added');
    final serial = (appointment['serialNumber'] ?? '').toString().trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant.withOpacity(0.72)),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
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
                  color: colors.primaryContainer.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.local_hospital_rounded, color: colors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctorName,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appointmentAt == null ? 'Date not assigned' : _formatDateTime(appointmentAt),
                      style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _StatusBadge(label: status, color: statusColor),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoChip(icon: Icons.meeting_room_rounded, label: chamberName),
              _InfoChip(icon: Icons.schedule_rounded, label: timeBlock),
              if (serial.isNotEmpty) _InfoChip(icon: Icons.confirmation_number_rounded, label: 'Serial $serial'),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withOpacity(0.48),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                reason,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onOpenDoctor,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Doctor profile'),
              ),
              const Spacer(),
              if (onCancel != null)
                TextButton.icon(
                  onPressed: updating ? null : onCancel,
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Cancel'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.outlineVariant.withOpacity(0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.primary),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Text(
        _titleCase(label),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SoftNotice extends StatelessWidget {
  const _SoftNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant.withOpacity(0.75)),
      ),
      child: Text(text, style: TextStyle(color: colors.onSurfaceVariant)),
    );
  }
}

class _EmptyAppointmentsCard extends StatelessWidget {
  const _EmptyAppointmentsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.outlineVariant.withOpacity(0.7)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colors.primaryContainer.withOpacity(0.55),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(Icons.event_available_rounded, color: colors.primary, size: 32),
          ),
          const SizedBox(height: 14),
          Text(
            'No appointments yet',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Book a dedicated doctor from the Doctors page. Your requests and serial numbers will appear here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.outlineVariant.withOpacity(0.7)),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

String _statusOf(Map<String, dynamic> appointment) {
  final status = (appointment['status'] ?? 'pending').toString().trim().toLowerCase();
  return status.isEmpty ? 'pending' : status;
}

Color _statusColor(String status, ColorScheme colors) {
  switch (status) {
    case 'confirmed':
      return colors.primary;
    case 'completed':
      return Colors.teal.shade700;
    case 'cancelled':
      return colors.error;
    case 'pending':
    default:
      return Colors.orange.shade800;
  }
}

DateTime? _dateFrom(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

String _formatDateTime(DateTime date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final hour12 = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  return '${date.day} ${months[date.month - 1]} ${date.year}, $hour12:$minute $period';
}

String _firstNonEmpty(List<dynamic> values, {required String fallback}) {
  for (final value in values) {
    final text = (value ?? '').toString().trim();
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

String _titleCase(String value) {
  final text = value.trim();
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1).toLowerCase();
}
