import 'package:flutter/material.dart';
import 'package:core/core.dart';

class BookingsScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const BookingsScreen({super.key, required this.profile});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _filtered = [];
  String _search = '';
  String _statusFilter = 'Todos';

  static const _statusFilters = [
    'Todos',
    'Pendiente',
    'Confirmada',
    'Completada',
    'Cancelada',
  ];

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _loading = true);
    try {
      final res = await SupabaseService.client
          .from('bookings')
          .select(
            '*, '
            'client:profiles!bookings_client_id_fkey(full_name, phone), '
            'employee:profiles!bookings_employee_id_fkey(full_name), '
            'service:services(name, duration_minutes, price)',
          )
          .eq('business_id', widget.profile['business_id'])
          .order('start_at', ascending: false);

      final bookings = (res as List).cast<Map<String, dynamic>>();
      setState(() {
        _bookings = bookings;
        _loading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filtered = _bookings.where((b) {
        final clientName =
            (b['client']?['full_name'] as String? ?? '').toLowerCase();
        final matchSearch =
            _search.isEmpty || clientName.contains(_search.toLowerCase());
        final matchStatus =
            _statusFilter == 'Todos' ||
            _statusLabel(b['status'] as String? ?? '') == _statusFilter;
        return matchSearch && matchStatus;
      }).toList();
    });
  }

  String _statusLabel(String status) => switch (status) {
    'pending' => 'Pendiente',
    'confirmed' => 'Confirmada',
    'completed' => 'Completada',
    'cancelled' => 'Cancelada',
    'waitlist' => 'Lista espera',
    _ => status,
  };

  Future<void> _updateStatus(String bookingId, String newStatus) async {
    try {
      await SupabaseService.client
          .from('bookings')
          .update({'status': newStatus})
          .eq('id', bookingId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reserva ${_statusLabel(newStatus).toLowerCase()}',
          ),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
      _loadBookings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al actualizar el estado'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _confirmAction(
    String title,
    String message,
    VoidCallback onConfirm,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(message, style: const TextStyle(fontSize: 14)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D6FEB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Confirmar'),
              ),
            ],
          ),
    );
    if (ok == true) onConfirm();
  }

  Future<void> _showNewBookingDialog() async {
    List<Map<String, dynamic>> clients = [];
    List<Map<String, dynamic>> employees = [];
    List<Map<String, dynamic>> services = [];

    try {
      final businessId = widget.profile['business_id'];
      final results = await Future.wait([
        SupabaseService.client
            .from('profiles')
            .select('id, full_name')
            .eq('business_id', businessId)
            .eq('role', 'client')
            .order('full_name'),
        SupabaseService.client
            .from('profiles')
            .select('id, full_name')
            .eq('business_id', businessId)
            .inFilter('role', ['admin', 'employee'])
            .order('full_name'),
        SupabaseService.client
            .from('services')
            .select('id, name, duration_minutes, price')
            .eq('business_id', businessId)
            .eq('active', true)
            .order('name'),
      ]);
      clients = (results[0] as List).cast<Map<String, dynamic>>();
      employees = (results[1] as List).cast<Map<String, dynamic>>();
      services = (results[2] as List).cast<Map<String, dynamic>>();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al cargar datos'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }
    if (!mounted) return;

    Map<String, dynamic>? selClient;
    Map<String, dynamic>? selEmployee;
    Map<String, dynamic>? selService;
    DateTime? selDate;
    TimeOfDay? selTime;
    final notesCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, setDlg) {
              final dateStr =
                  selDate != null
                      ? '${selDate!.day.toString().padLeft(2, '0')}/'
                          '${selDate!.month.toString().padLeft(2, '0')}/'
                          '${selDate!.year}'
                      : null;
              final timeStr =
                  selTime != null
                      ? '${selTime!.hour.toString().padLeft(2, '0')}:'
                          '${selTime!.minute.toString().padLeft(2, '0')}'
                      : null;

              return AlertDialog(
                title: const Text(
                  'Nueva reserva',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                content: SizedBox(
                  width: 440,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Cliente *'),
                        const SizedBox(height: 6),
                        _dropdownField<Map<String, dynamic>>(
                          hint: 'Seleccionar cliente',
                          value: selClient,
                          items: clients,
                          label: (c) => c['full_name'] as String,
                          onChanged: (v) => setDlg(() => selClient = v),
                        ),
                        const SizedBox(height: 14),
                        _label('Servicio *'),
                        const SizedBox(height: 6),
                        _dropdownField<Map<String, dynamic>>(
                          hint: 'Seleccionar servicio',
                          value: selService,
                          items: services,
                          label:
                              (s) =>
                                  '${s['name']}  ·  '
                                  '${s['duration_minutes']} min  ·  '
                                  '${(s['price'] as num).toStringAsFixed(2)}€',
                          onChanged: (v) => setDlg(() => selService = v),
                        ),
                        const SizedBox(height: 14),
                        _label('Empleado'),
                        const SizedBox(height: 6),
                        _nullableDropdownField(
                          hint: 'Sin asignar',
                          value: selEmployee,
                          items: employees,
                          label: (e) => e['full_name'] as String,
                          onChanged: (v) => setDlg(() => selEmployee = v),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _label('Fecha *'),
                                  const SizedBox(height: 6),
                                  _pickerButton(
                                    label: dateStr ?? 'Seleccionar',
                                    icon: Icons.calendar_today,
                                    onTap: () async {
                                      final d = await showDatePicker(
                                        context: ctx,
                                        initialDate: DateTime.now(),
                                        firstDate: DateTime.now().subtract(
                                          const Duration(days: 30),
                                        ),
                                        lastDate: DateTime.now().add(
                                          const Duration(days: 365),
                                        ),
                                      );
                                      if (d != null) {
                                        setDlg(() => selDate = d);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _label('Hora *'),
                                  const SizedBox(height: 6),
                                  _pickerButton(
                                    label: timeStr ?? 'Seleccionar',
                                    icon: Icons.access_time,
                                    onTap: () async {
                                      final t = await showTimePicker(
                                        context: ctx,
                                        initialTime: TimeOfDay.now(),
                                      );
                                      if (t != null) {
                                        setDlg(() => selTime = t);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _label('Notas (opcional)'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: notesCtrl,
                          maxLines: 2,
                          decoration: _inputDecoration('Observaciones...'),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                  ElevatedButton(
                    onPressed:
                        (selClient == null ||
                                selService == null ||
                                selDate == null ||
                                selTime == null)
                            ? null
                            : () async {
                              final startAt = DateTime(
                                selDate!.year,
                                selDate!.month,
                                selDate!.day,
                                selTime!.hour,
                                selTime!.minute,
                              );
                              final endAt = startAt.add(
                                Duration(
                                  minutes:
                                      selService!['duration_minutes'] as int? ??
                                      60,
                                ),
                              );
                              try {
                                await SupabaseService.client
                                    .from('bookings')
                                    .insert({
                                      'business_id':
                                          widget.profile['business_id'],
                                      'client_id': selClient!['id'],
                                      'employee_id': selEmployee?['id'],
                                      'service_id': selService!['id'],
                                      'start_at':
                                          startAt.toUtc().toIso8601String(),
                                      'end_at': endAt.toUtc().toIso8601String(),
                                      'status': 'pending',
                                      'notes':
                                          notesCtrl.text.trim().isEmpty
                                              ? null
                                              : notesCtrl.text.trim(),
                                    });
                                if (!ctx.mounted) return;
                                Navigator.of(ctx).pop();
                                _loadBookings();
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Reserva creada correctamente'),
                                    backgroundColor: Color(0xFF16A34A),
                                  ),
                                );
                              } catch (e) {
                                if (!ctx.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Error al crear la reserva'),
                                    backgroundColor: Color(0xFFDC2626),
                                  ),
                                );
                              }
                            },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D6FEB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Crear reserva'),
                  ),
                ],
              );
            },
          ),
    );
    notesCtrl.dispose();
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
  );

  Widget _dropdownField<T>({
    required String hint,
    required T? value,
    required List<T> items,
    required String Function(T) label,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(
            hint,
            style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
          isExpanded: true,
          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
          items:
              items
                  .map(
                    (item) => DropdownMenuItem<T>(
                      value: item,
                      child: Text(
                        label(item),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _nullableDropdownField({
    required String hint,
    required Map<String, dynamic>? value,
    required List<Map<String, dynamic>> items,
    required String Function(Map<String, dynamic>) label,
    required ValueChanged<Map<String, dynamic>?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>?>(
          value: value,
          hint: Text(
            hint,
            style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
          isExpanded: true,
          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
          items: [
            const DropdownMenuItem<Map<String, dynamic>?>(
              value: null,
              child: Text(
                'Sin asignar',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
            ),
            ...items.map(
              (item) => DropdownMenuItem<Map<String, dynamic>?>(
                value: item,
                child: Text(label(item), overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _pickerButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1D6FEB),
        side: const BorderSide(color: Color(0xFFE2E8F2)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        alignment: Alignment.centerLeft,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF1D6FEB), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final pendingCount =
        _bookings.where((b) => b['status'] == 'pending').length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Alerta de pendientes
          if (pendingCount > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.pending_actions,
                    color: Color(0xFFD97706),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$pendingCount reservas pendientes de confirmación.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
            ),

          // Barra de filtros
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                height: 38,
                child: TextField(
                  onChanged: (v) {
                    _search = v;
                    _applyFilters();
                  },
                  decoration: InputDecoration(
                    hintText: 'Buscar por cliente...',
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(0xFF1D6FEB),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),

              // Filtros de estado
              ..._statusFilters.map((filter) {
                final selected = _statusFilter == filter;
                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    setState(() => _statusFilter = filter);
                    _applyFilters();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF1D6FEB) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF1D6FEB)
                            : const Color(0xFFE2E8F2),
                      ),
                    ),
                    child: Text(
                      filter,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: selected
                            ? Colors.white
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                );
              }),

              ElevatedButton.icon(
                onPressed: _showNewBookingDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nueva reserva'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D6FEB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tabla / Lista
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F2)),
              ),
              child: _filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay reservas que coincidan',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) =>
                          constraints.maxWidth > 600
                              ? _buildTable()
                              : _buildList(),
                    ),
            ),
          ),

          // Footer
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Mostrando ${_filtered.length} de ${_bookings.length} reservas',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return SingleChildScrollView(
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.5),
          1: FlexColumnWidth(2),
          2: FlexColumnWidth(1.8),
          3: FlexColumnWidth(1.8),
          4: FlexColumnWidth(1.5),
          5: FlexColumnWidth(2.2),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F2))),
            ),
            children: [
              _TableHeader('Cliente', paddingLeft: 16),
              _TableHeader('Servicio'),
              _TableHeader('Empleado'),
              _TableHeader('Fecha / Hora'),
              _TableHeader('Estado'),
              _TableHeader(''),
            ],
          ),
          ..._filtered.map(_buildTableRow),
        ],
      ),
    );
  }

  TableRow _buildTableRow(Map<String, dynamic> b) {
    final clientName =
        b['client']?['full_name'] as String? ?? 'Desconocido';
    final employeeName = b['employee']?['full_name'] as String? ?? '—';
    final serviceName = b['service']?['name'] as String? ?? '—';
    final status = b['status'] as String? ?? '';
    final startAt = DateTime.tryParse(b['start_at'] ?? '')?.toLocal();
    final dateStr =
        startAt != null
            ? '${startAt.day.toString().padLeft(2, '0')}/'
                '${startAt.month.toString().padLeft(2, '0')}/'
                '${startAt.year}'
            : '—';
    final timeStr =
        startAt != null
            ? '${startAt.hour.toString().padLeft(2, '0')}:'
                '${startAt.minute.toString().padLeft(2, '0')}'
            : '—';

    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 0, 12),
          child: Text(
            clientName,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            serviceName,
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            employeeName,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dateStr, style: const TextStyle(fontSize: 12)),
              Text(
                timeStr,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: _BookingStatusBadge(status: status),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: _buildActions(b, clientName, compact: false),
        ),
      ],
    );
  }

  Widget _buildList() {
    return ListView.separated(
      itemCount: _filtered.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
      itemBuilder: (ctx, i) {
        final b = _filtered[i];
        final clientName =
            b['client']?['full_name'] as String? ?? 'Desconocido';
        final serviceName = b['service']?['name'] as String? ?? '—';
        final status = b['status'] as String? ?? '';
        final startAt = DateTime.tryParse(b['start_at'] ?? '')?.toLocal();
        final dateTimeStr =
            startAt != null
                ? '${startAt.day.toString().padLeft(2, '0')}/'
                    '${startAt.month.toString().padLeft(2, '0')}/'
                    '${startAt.year}  '
                    '${startAt.hour.toString().padLeft(2, '0')}:'
                    '${startAt.minute.toString().padLeft(2, '0')}'
                : '—';

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          title: Text(
            clientName,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                serviceName,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dateTimeStr,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BookingStatusBadge(status: status),
              const SizedBox(width: 4),
              _buildActions(b, clientName, compact: true),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActions(
    Map<String, dynamic> b,
    String clientName, {
    required bool compact,
  }) {
    final status = b['status'] as String? ?? '';
    final id = b['id'] as String;

    if (status == 'completed' || status == 'cancelled') {
      return const SizedBox.shrink();
    }

    if (compact) {
      return PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF64748B)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        itemBuilder:
            (_) => [
              if (status == 'pending')
                const PopupMenuItem(
                  value: 'confirm',
                  child: Text('Confirmar', style: TextStyle(fontSize: 13)),
                ),
              if (status == 'confirmed')
                const PopupMenuItem(
                  value: 'complete',
                  child: Text('Completar', style: TextStyle(fontSize: 13)),
                ),
              const PopupMenuItem(
                value: 'cancel',
                child: Text(
                  'Cancelar',
                  style: TextStyle(fontSize: 13, color: Color(0xFFDC2626)),
                ),
              ),
            ],
        onSelected: (action) {
          switch (action) {
            case 'confirm':
              _confirmAction(
                'Confirmar reserva',
                '¿Confirmar la reserva de $clientName?',
                () => _updateStatus(id, 'confirmed'),
              );
            case 'complete':
              _confirmAction(
                'Completar reserva',
                '¿Marcar como completada la reserva de $clientName?',
                () => _updateStatus(id, 'completed'),
              );
            case 'cancel':
              _confirmAction(
                'Cancelar reserva',
                '¿Cancelar la reserva de $clientName?',
                () => _updateStatus(id, 'cancelled'),
              );
          }
        },
      );
    }

    return Wrap(
      spacing: 4,
      children: [
        if (status == 'pending')
          TextButton(
            onPressed: () => _confirmAction(
              'Confirmar reserva',
              '¿Confirmar la reserva de $clientName?',
              () => _updateStatus(id, 'confirmed'),
            ),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF16A34A),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
            ),
            child: const Text('Confirmar', style: TextStyle(fontSize: 12)),
          ),
        if (status == 'confirmed')
          TextButton(
            onPressed: () => _confirmAction(
              'Completar reserva',
              '¿Marcar como completada la reserva de $clientName?',
              () => _updateStatus(id, 'completed'),
            ),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF1D6FEB),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
            ),
            child: const Text('Completar', style: TextStyle(fontSize: 12)),
          ),
        TextButton(
          onPressed: () => _confirmAction(
            'Cancelar reserva',
            '¿Cancelar la reserva de $clientName?',
            () => _updateStatus(id, 'cancelled'),
          ),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFDC2626),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: Size.zero,
          ),
          child: const Text('Cancelar', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}

// ==================== WIDGETS AUXILIARES ====================

class _BookingStatusBadge extends StatelessWidget {
  final String status;
  const _BookingStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final styles = <String, (Color, Color, String)>{
      'pending': (const Color(0xFFFFFBEB), const Color(0xFFD97706), 'Pendiente'),
      'confirmed': (
        const Color(0xFFF0FDF4),
        const Color(0xFF16A34A),
        'Confirmada',
      ),
      'completed': (
        const Color(0xFFEEF5FF),
        const Color(0xFF1D6FEB),
        'Completada',
      ),
      'cancelled': (
        const Color(0xFFFEF2F2),
        const Color(0xFFDC2626),
        'Cancelada',
      ),
      'waitlist': (
        const Color(0xFFF5F3FF),
        const Color(0xFF7C3AED),
        'Lista espera',
      ),
    };

    final style =
        styles[status] ??
        (const Color(0xFFF1F5F9), const Color(0xFF64748B), status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: style.$1,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        style.$3,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: style.$2,
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String label;
  final double paddingLeft;
  const _TableHeader(this.label, {this.paddingLeft = 0});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(paddingLeft, 10, 0, 10),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF64748B),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
