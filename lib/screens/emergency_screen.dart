import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/bd_locations.dart';
import '../providers/app_state.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/debug_logger.dart';
import '../widgets/glass_card.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  final _searchController = TextEditingController();
  final _fs = FirestoreService();

  String? _selectedType;
  String _query = '';
  String _division = 'All';
  String _district = 'All';
  String _bloodGroup = 'All';
  bool _loading = false;
  bool _saving = false;
  List<Map<String, dynamic>> _items = [];

  static const List<String> _divisions = BdLocations.divisions;
  static const List<String> _districts = BdLocations.districts;
  static const List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openType(String type) async {
    setState(() {
      _selectedType = type;
      _query = '';
      _searchController.clear();
      _division = 'All';
      _district = 'All';
      _bloodGroup = 'All';
      _items = [];
    });
    await _reload();
  }

  Future<void> _reload() async {
    final type = _selectedType;
    if (type == null || _loading) return;

    setState(() => _loading = true);
    try {
      if (type == 'donor') {
        _items = await _fs.queryDonors(
          bloodGroup: _bloodGroup == 'All' ? null : _bloodGroup,
          division: _division == 'All' ? null : _division,
          district: _district == 'All' ? null : _district,
          limit: 2000,
        );
      } else {
        _items = await _fs.queryEmergencyResources(
          type: type,
          division: _division == 'All' ? null : _division,
          district: _district == 'All' ? null : _district,
          limit: 2000,
        );
      }
    } catch (e, st) {
      DebugLogger.error('Failed to load emergency entries', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load emergency records.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> get _availableDistricts {
    if (_division == 'All') return _districts;
    final filtered = BdLocations.districtsFor(_division);
    return filtered.isEmpty ? _districts : filtered;
  }

  List<Map<String, dynamic>> get _filteredItems {
    final q = _normalizeSearch(_query);
    return _items.where((item) {
      if (q.isEmpty) return true;
      return _searchableText(item).contains(q);
    }).toList();
  }

  String _normalizeSearch(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r"[^\p{L}\p{N}\s+.-]+", unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _searchableText(Map<String, dynamic> item) {
    final fields = <Object?>[
      item['name'],
      item['type'],
      item['division'],
      item['district'],
      item['bloodGroup'],
      item['contact'],
      item['phone'],
      item['note'],
      item['details'],
      item['address'],
      item['location'],
    ];
    return _normalizeSearch(fields.whereType<Object>().map((value) => value.toString()).join(' '));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final isAdmin = appState.isAdmin;
        return Scaffold(
          body: SafeArea(
            child: _selectedType == null ? _landing(context, isAdmin) : _panel(context, isAdmin),
          ),
        );
      },
    );
  }

  Widget _landing(BuildContext context, bool isAdmin) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
      children: [
        _heroCard(context, isAdmin),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 760;
            final width = isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: width,
                  child: _categoryCard(
                    context,
                    type: 'ambulance',
                    icon: Icons.emergency_share_rounded,
                    title: 'Ambulance',
                    subtitle: 'Emergency transfer and road support contacts.',
                    onTap: () => _openType('ambulance'),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _categoryCard(
                    context,
                    type: 'hospital',
                    icon: Icons.local_hospital_rounded,
                    title: 'Hospital',
                    subtitle: 'Nearby hospital and emergency department details.',
                    onTap: () => _openType('hospital'),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _categoryCard(
                    context,
                    type: 'blood_bank',
                    icon: Icons.bloodtype_rounded,
                    title: 'Blood bank',
                    subtitle: 'Blood bank contact and location information.',
                    onTap: () => _openType('blood_bank'),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _categoryCard(
                    context,
                    type: 'donor',
                    icon: Icons.volunteer_activism_rounded,
                    title: 'Donor',
                    subtitle: 'Registered donor contact records by blood group.',
                    onTap: () => _openType('donor'),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _heroCard(BuildContext context, bool isAdmin) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: AppTheme.brandGradient,
        boxShadow: AppTheme.softShadow(opacity: 0.10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;

          final titleBlock = Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emergency support',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  isAdmin
                      ? 'Manage reliable emergency contacts, facilities, blood banks, and donor records.'
                      : 'Find essential emergency contacts by category and location.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          );

          final headerRow = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: const Icon(Icons.emergency_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              titleBlock,
            ],
          );

          if (wide) {
            return headerRow;
          }

          return headerRow;
        },
      ),
    );
  }

  Widget _categoryCard(
    BuildContext context, {
    required String type,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _typeColor(type).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: _typeColor(type), size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.arrow_forward_rounded, color: Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _panel(BuildContext context, bool isAdmin) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 110),
      children: [
        _sectionHeaderCard(context),
        const SizedBox(height: 16),
        _filterCard(context, isAdmin),
        const SizedBox(height: 16),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 50),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_filteredItems.isEmpty)
          _emptyState(context)
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final cardWidth = isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: _filteredItems
                    .map(
                      (item) => SizedBox(
                        width: cardWidth,
                        child: _recordCard(context, item, isAdmin),
                      ),
                    )
                    .toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _sectionHeaderCard(BuildContext context) {
    final type = _selectedType ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppTheme.softShadow(opacity: 0.10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton.filledTonal(
            tooltip: 'Back',
            onPressed: () => setState(() {
              _selectedType = null;
              _items = [];
              _query = '';
              _searchController.clear();
            }),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.14),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _typeTitle(type),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Search location-based records and contact details quickly.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _reload,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.14),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget _filterCard(BuildContext context, bool isAdmin) {
    final type = _selectedType ?? '';
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _typeColor(type).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(_typeIcon(type), color: _typeColor(type)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _typeTitle(type),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_filteredItems.length} record${_filteredItems.length == 1 ? '' : 's'} available',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (isAdmin)
                FilledButton.icon(
                  onPressed: _saving ? null : () => _openEntryForm(type: type),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add'),
                ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value.trim()),
            decoration: const InputDecoration(
              labelText: 'Search records',
              hintText: 'Name, contact, district, note, address, or blood group',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              final districtItems = _availableDistricts;
              final fields = <Widget>[
                _filterDropdown(
                  label: 'Division',
                  value: _division,
                  items: _divisions,
                  onChanged: (value) async {
                    setState(() {
                      _division = value ?? 'All';
                      final districts = _availableDistricts;
                      if (_district != 'All' && !districts.contains(_district)) {
                        _district = 'All';
                      }
                    });
                    await _reload();
                  },
                ),
                _filterDropdown(
                  label: 'District',
                  value: _district,
                  items: districtItems,
                  onChanged: (value) async {
                    setState(() => _district = value ?? 'All');
                    await _reload();
                  },
                ),
                if (_selectedType == 'donor')
                  _filterDropdown(
                    label: 'Blood group',
                    value: _bloodGroup,
                    items: _bloodGroups,
                    onChanged: (value) async {
                      setState(() => _bloodGroup = value ?? 'All');
                      await _reload();
                    },
                  ),
              ];
              if (!wide) {
                return Column(
                  children: [
                    for (int i = 0; i < fields.length; i++) ...[
                      fields[i],
                      if (i != fields.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  for (int i = 0; i < fields.length; i++) ...[
                    Expanded(child: fields[i]),
                    if (i != fields.length - 1) const SizedBox(width: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _filterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final values = ['All', ...items];
    final safeValue = values.contains(value) ? value : 'All';
    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      items: values.map((item) => DropdownMenuItem<String>(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _recordCard(BuildContext context, Map<String, dynamic> item, bool isAdmin) {
    final type = (item['type'] ?? _selectedType ?? '').toString();
    final contact = _contactText(item);
    final note = _noteText(item);
    final location = _locationText(item);
    final bloodGroup = (item['bloodGroup'] ?? '').toString().trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDetails(item),
        borderRadius: BorderRadius.circular(26),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.70)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _typeColor(type).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(_typeIcon(type), color: _typeColor(type)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (item['name'] ?? 'Unnamed record').toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _chip(context, _typeTitle(type), icon: _typeIcon(type)),
                            if (bloodGroup.isNotEmpty) _chip(context, bloodGroup, icon: Icons.bloodtype_rounded),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isAdmin)
                    PopupMenuButton<String>(
                      tooltip: 'Manage record',
                      onSelected: (value) {
                        if (value == 'edit') _openEntryForm(type: type, existing: item);
                        if (value == 'delete') _deleteEntry(item);
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    )
                  else
                    Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 16),
              _infoLine(context, Icons.place_rounded, location.isEmpty ? 'Location not added' : location),
              const SizedBox(height: 8),
              _infoLine(context, Icons.call_rounded, contact.isEmpty ? 'Contact not added' : contact),
              if (note.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    note,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.35),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label, {required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _infoLine(BuildContext context, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.35),
          ),
        ),
      ],
    );
  }

  Widget _emptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.65)),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.search_off_rounded, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 14),
          Text(
            'No matching records',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Try a different search term, location, or filter.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetails(Map<String, dynamic> item) async {
    final type = (item['type'] ?? _selectedType ?? '').toString();
    final contact = _contactText(item);
    final note = _noteText(item);
    final location = _locationText(item);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _typeColor(type).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(_typeIcon(type), color: _typeColor(type)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (item['name'] ?? '').toString(),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(_typeTitle(type), style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _detailRow(context, 'Location', location.isEmpty ? 'Not added' : location),
                _detailRow(context, 'Contact', contact.isEmpty ? 'Not added' : contact),
                if ((item['bloodGroup'] ?? '').toString().trim().isNotEmpty)
                  _detailRow(context, 'Blood group', item['bloodGroup'].toString()),
                if (note.isNotEmpty) _detailRow(context, 'Details', note),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 5),
            Text(value, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Future<void> _openEntryForm({required String type, Map<String, dynamic>? existing}) async {
    final nameController = TextEditingController(text: existing?['name']?.toString() ?? '');
    final contactController = TextEditingController(text: (existing?['contact'] ?? existing?['phone'] ?? '').toString());
    final addressController = TextEditingController(text: (existing?['address'] ?? existing?['location'] ?? '').toString());
    final noteController = TextEditingController(text: (existing?['note'] ?? existing?['details'] ?? '').toString());
    final formKey = GlobalKey<FormState>();

    String? selectedDivision = _divisions.contains(existing?['division']?.toString() ?? '')
        ? existing!['division'].toString()
        : null;
    String? selectedDistrict = _districts.contains(existing?['district']?.toString() ?? '')
        ? existing!['district'].toString()
        : null;
    String? selectedBloodGroup = _bloodGroups.contains(existing?['bloodGroup']?.toString() ?? '')
        ? existing!['bloodGroup'].toString()
        : null;

    List<String> dialogDistricts() {
      if (selectedDivision == null || selectedDivision!.isEmpty) return _districts;
      final filtered = BdLocations.districtsFor(selectedDivision!);
      return filtered.isEmpty ? _districts : filtered;
    }

    try {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheetState) {
            final title = existing == null ? 'Add ${_typeTitle(type)}' : 'Edit ${_typeTitle(type)}';
            return Padding(
              padding: EdgeInsets.fromLTRB(18, 6, 18, 18 + MediaQuery.of(context).viewInsets.bottom),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: _typeColor(type).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(_typeIcon(type), color: _typeColor(type)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 3),
                                  Text('Keep contact information accurate and concise.', style: Theme.of(context).textTheme.bodyMedium),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        _sectionLabel(context, 'Basic information'),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: nameController,
                          decoration: InputDecoration(labelText: _nameLabel(type), prefixIcon: const Icon(Icons.badge_rounded)),
                          textInputAction: TextInputAction.next,
                          validator: (value) => _required(value, label: _nameLabel(type)),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: contactController,
                          decoration: const InputDecoration(labelText: 'Phone or contact number', prefixIcon: Icon(Icons.call_rounded)),
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          validator: (value) => _required(value, label: 'Contact'),
                        ),
                        const SizedBox(height: 18),
                        _sectionLabel(context, 'Location'),
                        const SizedBox(height: 10),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final wide = constraints.maxWidth >= 560;
                            final divisionField = _formDropdown(
                              label: 'Division',
                              value: selectedDivision,
                              items: _divisions,
                              onChanged: (value) => setSheetState(() {
                                selectedDivision = value;
                                final districts = dialogDistricts();
                                if (selectedDistrict != null && !districts.contains(selectedDistrict)) {
                                  selectedDistrict = null;
                                }
                              }),
                            );
                            final districtField = _formDropdown(
                              label: 'District',
                              value: selectedDistrict,
                              items: dialogDistricts(),
                              onChanged: (value) => setSheetState(() => selectedDistrict = value),
                            );
                            if (!wide) {
                              return Column(children: [divisionField, const SizedBox(height: 12), districtField]);
                            }
                            return Row(children: [Expanded(child: divisionField), const SizedBox(width: 12), Expanded(child: districtField)]);
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: addressController,
                          decoration: const InputDecoration(labelText: 'Address or service area', prefixIcon: Icon(Icons.location_on_rounded)),
                          textInputAction: TextInputAction.next,
                        ),
                        if (type == 'donor') ...[
                          const SizedBox(height: 18),
                          _sectionLabel(context, 'Donor details'),
                          const SizedBox(height: 10),
                          _formDropdown(
                            label: 'Blood group',
                            value: selectedBloodGroup,
                            items: _bloodGroups,
                            onChanged: (value) => setSheetState(() => selectedBloodGroup = value),
                          ),
                        ],
                        const SizedBox(height: 18),
                        _sectionLabel(context, 'Additional notes'),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: noteController,
                          decoration: InputDecoration(
                            labelText: _noteLabel(type),
                            prefixIcon: const Icon(Icons.notes_rounded),
                          ),
                          minLines: 3,
                          maxLines: 5,
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _saving ? null : () => Navigator.pop(sheetContext, false),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _saving
                                    ? null
                                    : () {
                                        if (formKey.currentState?.validate() ?? false) {
                                          Navigator.pop(sheetContext, true);
                                        }
                                      },
                                icon: const Icon(Icons.check_rounded),
                                label: Text(existing == null ? 'Save record' : 'Update record'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );

      if (saved != true) return;
      if (selectedDivision == null || selectedDivision!.isEmpty || selectedDistrict == null || selectedDistrict!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Division and district are required.')));
        }
        return;
      }
      if (type == 'donor' && (selectedBloodGroup == null || selectedBloodGroup!.isEmpty)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Blood group is required.')));
        }
        return;
      }

      setState(() => _saving = true);
      final payload = <String, dynamic>{
        if (existing?['id'] != null) 'id': existing!['id'],
        'type': type,
        'name': nameController.text.trim(),
        'division': selectedDivision,
        'district': selectedDistrict,
        'contact': contactController.text.trim(),
        'phone': contactController.text.trim(),
        'address': addressController.text.trim(),
        'location': addressController.text.trim(),
        'note': noteController.text.trim(),
        'details': noteController.text.trim(),
        if (type == 'donor') 'bloodGroup': selectedBloodGroup,
      };

      if (type == 'donor') {
        await _fs.saveDonor(payload);
      } else {
        await _fs.saveEmergencyResource(payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_typeTitle(type)} saved.')));
        await _reload();
      }
    } catch (e, st) {
      DebugLogger.error('Failed to save emergency record', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save the record.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
      nameController.dispose();
      contactController.dispose();
      addressController.dispose();
      noteController.dispose();
    }
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
    );
  }

  String? _required(String? value, {required String label}) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
  }

  Widget _formDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value != null && items.contains(value) ? value : null,
      decoration: InputDecoration(labelText: label),
      items: items.map((item) => DropdownMenuItem<String>(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
      validator: (selected) => selected == null || selected.isEmpty ? '$label is required' : null,
    );
  }

  Future<void> _deleteEntry(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    final type = (item['type'] ?? _selectedType ?? '').toString();
    if (id.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete record?'),
        content: Text('This will permanently remove ${item['name'] ?? 'this record'}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      if (type == 'donor') {
        await _fs.deleteDonor(id);
      } else {
        await _fs.deleteEmergencyResource(id);
      }
      if (mounted) await _reload();
    } catch (e, st) {
      DebugLogger.error('Failed to delete emergency record', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not delete the record.')));
      }
    }
  }


  String _locationText(Map<String, dynamic> item) {
    final division = (item['division'] ?? '').toString().trim();
    final district = (item['district'] ?? '').toString().trim();
    final address = (item['address'] ?? item['location'] ?? '').toString().trim();
    return [address, district, division].where((value) => value.isNotEmpty).join(', ');
  }

  String _contactText(Map<String, dynamic> item) {
    return (item['contact'] ?? item['phone'] ?? '').toString().trim();
  }

  String _noteText(Map<String, dynamic> item) {
    return (item['note'] ?? item['details'] ?? '').toString().trim();
  }

  String _nameLabel(String type) {
    switch (type) {
      case 'ambulance':
        return 'Ambulance service name';
      case 'hospital':
        return 'Hospital name';
      case 'blood_bank':
        return 'Blood bank name';
      case 'donor':
        return 'Donor name';
      default:
        return 'Name';
    }
  }

  String _noteLabel(String type) {
    switch (type) {
      case 'ambulance':
        return 'Coverage area, availability, or vehicle note';
      case 'hospital':
        return 'Emergency unit, facilities, or instructions';
      case 'blood_bank':
        return 'Inventory note or operating hours';
      case 'donor':
        return 'Availability or preferred contact time';
      default:
        return 'Note / details';
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'ambulance':
        return Icons.emergency_share_rounded;
      case 'hospital':
        return Icons.local_hospital_rounded;
      case 'blood_bank':
        return Icons.bloodtype_rounded;
      case 'donor':
        return Icons.volunteer_activism_rounded;
      default:
        return Icons.health_and_safety_rounded;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'ambulance':
        return const Color(0xFFD94841);
      case 'hospital':
        return const Color(0xFF1976D2);
      case 'blood_bank':
        return const Color(0xFFC62828);
      case 'donor':
        return const Color(0xFF00897B);
      default:
        return const Color(0xFF0FAFA5);
    }
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
