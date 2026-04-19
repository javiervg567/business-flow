import 'package:flutter/material.dart';
import 'package:core/core.dart';

class ClientBookingsScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const ClientBookingsScreen({super.key, required this.profile});

  @override
  State<ClientBookingsScreen> createState() => _ClientBookingsScreenState();
}

class _ClientBookingsScreenState extends State<ClientBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  List<Map<String, dynamic>> _upcoming = [];
  List<Map<String, dynamic>> _past = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    setState(() => _loading = true);
    try {
      final client = SupabaseService.client;
      final clientId = widget.profile['id'];
      final now = DateTime.now();

      final results = await Future.wait([
        client
            .from('bookings')
            .select(
              '*, service:services(name, duration_minutes, price), employee:profiles!bookings_employee_id_fkey(full_name)',
            )
            .eq('client_id', clientId)
            .gte('start_at', now.toIso8601String())
            .neq('status', 'cancelled')
            .order('start_at'),
        client
            .from('bookings')
            .select(
              '*, service:services(name, duration_minutes, price), employee:profiles!bookings_employee_id_fkey(full_name)',
            )
            .eq('client_id', clientId)
            .or('start_at.lt.${now.toIso8601String()},status.eq.cancelled')
            .order('start_at', ascending: false)
            .limit(20),
      ]);

      if (!mounted) return;
      setState(() {
        _upcoming = (results[0] as List).cast<Map<String, dynamic>>();
        _past = (results[1] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _cancelBooking(String bookingId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Cancelar cita',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: const Text('¿Seguro que quieres cancelar esta cita?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SupabaseService.client
          .from('bookings')
          .update({'status': 'cancelled'})
          .eq('id', bookingId);
      _loadBookings();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cita cancelada'),
          backgroundColor: Color(0xFF64748B),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al cancelar'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _showNewBookingDialog() async {
    final businessId = widget.profile['business_id'];
    List<Map<String, dynamic>> services = [];
    List<Map<String, dynamic>> employees = [];

    try {
      final results = await Future.wait([
        SupabaseService.client
            .from('services')
            .select('id, name, duration_minutes, price')
            .eq('business_id', businessId)
            .eq('active', true)
            .order('name'),
        SupabaseService.client
            .from('profiles')
            .select('id, full_name')
            .eq('business_id', businessId)
            .inFilter('role', ['admin', 'employee'])
            .order('full_name'),
      ]);
      services = (results[0] as List).cast<Map<String, dynamic>>();
      employees = (results[1] as List).cast<Map<String, dynamic>>();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al cargar servicios'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }
    if (!mounted) return;

    Map<String, dynamic>? selService;
    Map<String, dynamic>? selEmployee;
    DateTime? selDate;
    TimeOfDay? selTime;

    DateTime nextWorkday(DateTime date) {
      var d = date;
      while (d.weekday == DateTime.sunday) {
        d = d.add(const Duration(days: 1));
      }
      return d;
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final dateStr = selDate != null
              ? '${selDate!.day.toString().padLeft(2, '0')}/${selDate!.month.toString().padLeft(2, '0')}/${selDate!.year}'
              : null;
          final timeStr = selTime != null
              ? '${selTime!.hour.toString().padLeft(2, '0')}:${selTime!.minute.toString().padLeft(2, '0')}'
              : null;

          return AlertDialog(
            title: const Text(
              'Nueva cita',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Servicio *'),
                    const SizedBox(height: 6),
                    _dropdown<Map<String, dynamic>>(
                      hint: 'Seleccionar servicio',
                      value: selService,
                      items: services,
                      label: (s) =>
                          '${s['name']}  ·  ${s['duration_minutes']} min  ·  ${(s['price'] as num).toStringAsFixed(2)}€',
                      onChanged: (v) => setDlg(() => selService = v),
                    ),
                    const SizedBox(height: 14),
                    _label('Empleado (opcional)'),
                    const SizedBox(height: 6),
                    _nullableDropdown(
                      hint: 'Sin preferencia',
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
                              _pickerBtn(
                                label: dateStr ?? 'Seleccionar',
                                icon: Icons.calendar_today,
                                onTap: () async {
                                  final d = await showDatePicker(
                                    context: ctx,
                                    initialDate: nextWorkday(DateTime.now()),
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(
                                      const Duration(days: 365),
                                    ),
                                    selectableDayPredicate: (day) =>
                                        day.weekday != DateTime.sunday,
                                  );
                                  if (d != null) setDlg(() => selDate = d);
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
                              _pickerBtn(
                                label: timeStr ?? 'Seleccionar',
                                icon: Icons.access_time,
                                onTap: () async {
                                  final t = await showTimePicker(
                                    context: ctx,
                                    initialTime: TimeOfDay.now(),
                                  );
                                  if (t != null) setDlg(() => selTime = t);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
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
                    (selService == null || selDate == null || selTime == null)
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
                                selService!['duration_minutes'] as int? ?? 60,
                          ),
                        );
                        try {
                          await SupabaseService.client.from('bookings').insert({
                            'business_id': businessId,
                            'client_id': widget.profile['id'],
                            'employee_id': selEmployee?['id'],
                            'service_id': selService!['id'],
                            'start_at': startAt.toUtc().toIso8601String(),
                            'end_at': endAt.toUtc().toIso8601String(),
                            'status': 'pending',
                          });
                          if (!ctx.mounted) return;
                          Navigator.of(ctx).pop();
                          _loadBookings();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cita solicitada correctamente'),
                              backgroundColor: Color(0xFF16A34A),
                            ),
                          );
                        } catch (e) {
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Error al crear la cita'),
                              backgroundColor: Color(0xFFDC2626),
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Solicitar cita'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mis citas',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Gestiona tus reservas',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showNewBookingDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nueva cita'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F2)),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: const Color(0xFF16A34A),
                  borderRadius: BorderRadius.circular(8),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF64748B),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Próximas'),
                  Tab(text: 'Historial'),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildList(_upcoming, upcoming: true),
                      _buildList(_past, upcoming: false),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    List<Map<String, dynamic>> bookings, {
    required bool upcoming,
  }) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              upcoming ? Icons.calendar_today_outlined : Icons.history,
              size: 48,
              color: const Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 12),
            Text(
              upcoming ? 'No tienes citas próximas' : 'Sin historial',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBookings,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: bookings.length,
        itemBuilder: (ctx, i) => _BookingCard(
          booking: bookings[i],
          upcoming: upcoming,
          onCancel: upcoming
              ? () => _cancelBooking(bookings[i]['id'] as String)
              : null,
        ),
      ),
    );
  }
}

// ── TARJETA DE CITA ───────────────────────────────────────

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool upcoming;
  final VoidCallback? onCancel;

  const _BookingCard({
    required this.booking,
    required this.upcoming,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final service = booking['service'];
    final employee = booking['employee'];
    final startAt = DateTime.tryParse(booking['start_at'] ?? '')?.toLocal();
    final status = booking['status'] as String? ?? '';

    final dateStr = startAt != null
        ? '${startAt.day.toString().padLeft(2, '0')}/${startAt.month.toString().padLeft(2, '0')}/${startAt.year}'
        : '—';
    final timeStr = startAt != null
        ? '${startAt.hour.toString().padLeft(2, '0')}:${startAt.minute.toString().padLeft(2, '0')}'
        : '—';

    final statusConfig = switch (status) {
      'confirmed' => (
        label: 'Confirmada',
        color: const Color(0xFF16A34A),
        bg: const Color(0xFFF0FDF4),
      ),
      'pending' => (
        label: 'Pendiente',
        color: const Color(0xFFD97706),
        bg: const Color(0xFFFFFBEB),
      ),
      'completed' => (
        label: 'Completada',
        color: const Color(0xFF0D9488),
        bg: const Color(0xFFF0FDFA),
      ),
      'cancelled' => (
        label: 'Cancelada',
        color: const Color(0xFFDC2626),
        bg: const Color(0xFFFEF2F2),
      ),
      _ => (
        label: status,
        color: const Color(0xFF64748B),
        bg: const Color(0xFFF1F5F9),
      ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusConfig.bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusConfig.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusConfig.color,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                dateStr,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            service?['name'] ?? 'Servicio',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(
                timeStr,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              if (employee != null) ...[
                const SizedBox(width: 12),
                const Icon(
                  Icons.person_outline,
                  size: 14,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(width: 4),
                Text(
                  employee['full_name'] ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
          if (service?['price'] != null) ...[
            const SizedBox(height: 6),
            Text(
              '${(service['price'] as num).toStringAsFixed(2)} €',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF16A34A),
              ),
            ),
          ],
          if (upcoming && onCancel != null && status != 'cancelled') ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onCancel,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cancel_outlined,
                    size: 16,
                    color: Color(0xFFDC2626),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Cancelar cita',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── HELPERS ───────────────────────────────────────────────

Widget _label(String text) =>
    Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)));

Widget _dropdown<T>({
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
        items: items
            .map(
              (item) => DropdownMenuItem<T>(
                value: item,
                child: Text(label(item), overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    ),
  );
}

Widget _nullableDropdown({
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
              'Sin preferencia',
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

Widget _pickerBtn({
  required String label,
  required IconData icon,
  required VoidCallback onTap,
}) {
  return OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 15),
    label: Text(label, style: const TextStyle(fontSize: 12)),
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF16A34A),
      side: const BorderSide(color: Color(0xFFE2E8F2)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      alignment: Alignment.centerLeft,
    ),
  );
}
