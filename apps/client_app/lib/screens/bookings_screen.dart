import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  Map<String, int> _reviewRatings = {};

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

      final pastIds = _past.map((b) => b['id'] as String).toList();
      await _loadReviews(pastIds);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadReviews(List<String> bookingIds) async {
    if (bookingIds.isEmpty) return;
    try {
      final data = await SupabaseService.client
          .from('reviews')
          .select('booking_id, rating')
          .inFilter('booking_id', bookingIds);
      if (!mounted) return;
      final map = <String, int>{};
      for (final r in (data as List)) {
        map[r['booking_id'] as String] = r['rating'] as int;
      }
      setState(() => _reviewRatings = map);
    } catch (_) {
      // la tabla de reseñas puede no estar migrada aún
    }
  }

  Future<void> _rateBooking(String bookingId) async {
    int selectedRating = 0;
    final commentCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Valorar cita',
            style: GoogleFonts.dmSerifDisplay(
              fontSize: 20,
              color: const Color(0xFF0D1B2E),
            ),
          ),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '¿Cómo fue tu experiencia?',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    return GestureDetector(
                      onTap: () => setDlg(() => selectedRating = i + 1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          i < selectedRating ? Icons.star : Icons.star_border,
                          size: 36,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: commentCtrl,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: const Color(0xFF0D1B2E),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Añade un comentario (opcional)',
                    hintStyle: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: const Color(0xFF94A3B8),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(0xFF16A34A),
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                    isDense: true,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                commentCtrl.dispose();
                Navigator.pop(ctx);
              },
              child: Text(
                'Cancelar',
                style: GoogleFonts.dmSans(color: const Color(0xFF64748B)),
              ),
            ),
            ElevatedButton(
              onPressed: selectedRating == 0
                  ? null
                  : () async {
                      final comment = commentCtrl.text.trim();
                      try {
                        await SupabaseService.client.from('reviews').insert({
                          'booking_id': bookingId,
                          'client_id': widget.profile['id'],
                          'business_id': widget.profile['business_id'],
                          'rating': selectedRating,
                          if (comment.isNotEmpty) 'comment': comment,
                        });
                        if (!ctx.mounted) return;
                        commentCtrl.dispose();
                        Navigator.pop(ctx);
                        final pastIds =
                            _past.map((b) => b['id'] as String).toList();
                        await _loadReviews(pastIds);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '¡Gracias por tu valoración!',
                              style: GoogleFonts.dmSans(),
                            ),
                            backgroundColor: const Color(0xFF16A34A),
                          ),
                        );
                      } catch (e) {
                        if (!ctx.mounted) return;
                        commentCtrl.dispose();
                        Navigator.pop(ctx);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Error al enviar valoración',
                              style: GoogleFonts.dmSans(),
                            ),
                            backgroundColor: const Color(0xFFDC2626),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Enviar',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelBooking(String bookingId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Cancelar cita',
          style: GoogleFonts.dmSerifDisplay(
            fontSize: 20,
            color: const Color(0xFF0D1B2E),
          ),
        ),
        content: Text(
          '¿Seguro que quieres cancelar esta cita?',
          style: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'No',
              style: GoogleFonts.dmSans(color: const Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Sí, cancelar',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
            ),
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
        SnackBar(
          content: Text('Cita cancelada', style: GoogleFonts.dmSans()),
          backgroundColor: const Color(0xFF64748B),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cancelar', style: GoogleFonts.dmSans()),
          backgroundColor: const Color(0xFFDC2626),
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
        SnackBar(
          content: Text('Error al cargar servicios', style: GoogleFonts.dmSans()),
          backgroundColor: const Color(0xFFDC2626),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Nueva cita',
              style: GoogleFonts.dmSerifDisplay(
                fontSize: 20,
                color: const Color(0xFF0D1B2E),
              ),
            ),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DlgLabel('Servicio *'),
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
                    _DlgLabel('Empleado (opcional)'),
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
                              _DlgLabel('Fecha *'),
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
                              _DlgLabel('Hora *'),
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
                child: Text(
                  'Cancelar',
                  style: GoogleFonts.dmSans(color: const Color(0xFF64748B)),
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
                            SnackBar(
                              content: Text(
                                'Cita solicitada correctamente',
                                style: GoogleFonts.dmSans(),
                              ),
                              backgroundColor: const Color(0xFF16A34A),
                            ),
                          );
                        } catch (e) {
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Error al crear la cita',
                                style: GoogleFonts.dmSans(),
                              ),
                              backgroundColor: const Color(0xFFDC2626),
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Solicitar cita',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                ),
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
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(color: Color(0xFF0D1B2E)),
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _BookingsGridPainter())),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mis citas',
                              style: GoogleFonts.dmSerifDisplay(
                                fontSize: 26,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              'Gestiona tus reservas',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _showNewBookingDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(
                          'Nueva cita',
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6FA),
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
                labelStyle: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                unselectedLabelStyle: GoogleFonts.dmSans(fontSize: 13),
                tabs: const [
                  Tab(text: 'Próximas'),
                  Tab(text: 'Historial'),
                ],
              ),
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF16A34A)),
                  )
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
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6FA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                upcoming ? Icons.calendar_today_outlined : Icons.history,
                size: 26,
                color: const Color(0xFFCBD5E1),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              upcoming ? 'No tienes citas próximas' : 'Sin historial',
              style: GoogleFonts.dmSans(
                color: const Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF16A34A),
      onRefresh: _loadBookings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        itemBuilder: (ctx, i) {
          final id = bookings[i]['id'] as String;
          final status = bookings[i]['status'] as String? ?? '';
          return _BookingCard(
            booking: bookings[i],
            upcoming: upcoming,
            onCancel: upcoming ? () => _cancelBooking(id) : null,
            existingRating: _reviewRatings[id],
            onRate: (!upcoming && status == 'completed' && !_reviewRatings.containsKey(id))
                ? () => _rateBooking(id)
                : null,
          );
        },
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool upcoming;
  final VoidCallback? onCancel;
  final int? existingRating;
  final VoidCallback? onRate;

  const _BookingCard({
    required this.booking,
    required this.upcoming,
    this.onCancel,
    this.existingRating,
    this.onRate,
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D1B2E).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusConfig.bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusConfig.label,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusConfig.color,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                dateStr,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            service?['name'] ?? 'Servicio',
            style: GoogleFonts.dmSerifDisplay(
              fontSize: 18,
              color: const Color(0xFF0D1B2E),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(
                timeStr,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                ),
              ),
              if (employee != null) ...[
                const SizedBox(width: 12),
                const Icon(Icons.person_outline, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text(
                  employee['full_name'] ?? '',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
          if (service?['price'] != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${(service['price'] as num).toStringAsFixed(2)} €',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF16A34A),
                ),
              ),
            ),
          ],
          if (upcoming && onCancel != null && status != 'cancelled') ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onCancel,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cancel_outlined,
                    size: 15,
                    color: Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Cancelar cita',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: const Color(0xFFDC2626),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (!upcoming && status == 'completed') ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 8),
            if (existingRating != null)
              Row(
                children: [
                  ...List.generate(
                    5,
                    (i) => Icon(
                      i < existingRating! ? Icons.star : Icons.star_border,
                      size: 16,
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Tu valoración',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              )
            else if (onRate != null)
              GestureDetector(
                onTap: onRate,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_border,
                      size: 15,
                      color: Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Valorar esta cita',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: const Color(0xFFF59E0B),
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

class _DlgLabel extends StatelessWidget {
  final String text;
  const _DlgLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF374151),
      ),
    );
  }
}

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
          style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF94A3B8)),
        ),
        isExpanded: true,
        style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF0D1B2E)),
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
          style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF94A3B8)),
        ),
        isExpanded: true,
        style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF0D1B2E)),
        items: [
          DropdownMenuItem<Map<String, dynamic>?>(
            value: null,
            child: Text(
              'Sin preferencia',
              style: GoogleFonts.dmSans(
                color: const Color(0xFF94A3B8),
                fontSize: 13,
              ),
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
    icon: Icon(icon, size: 14),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF16A34A),
      textStyle: GoogleFonts.dmSans(fontSize: 12),
      side: const BorderSide(color: Color(0xFFE2E8F2)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      alignment: Alignment.centerLeft,
    ),
  );
}

class _BookingsGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A2F4A).withValues(alpha: 0.45)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const spacing = 48.0;
    for (double x = 0; x < size.width + spacing; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height + spacing; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final glowPaint = Paint()
      ..color = const Color(0xFF16A34A).withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.30),
      60,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
