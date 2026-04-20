import 'package:flutter/material.dart';
import 'package:core/core.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const DashboardScreen({super.key, required this.profile});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  bool _isEmployee = false;
  int _todayBookings = 0;
  int _pendingBookings = 0;
  int _criticalStock = 0;
  int _totalClients = 0;
  double _monthSales = 0;
  double _monthPurchases = 0;
  double _monthProfit = 0;
  List<Map<String, dynamic>> _upcomingBookings = [];
  List<Map<String, dynamic>> _nextBookings = [];
  List<Map<String, dynamic>> _lowStockProducts = [];
  List<Map<String, dynamic>> _notifications = [];

  // Calendario
  DateTime _calendarMonth = DateTime.now();
  DateTime? _selectedDay;
  Map<String, List<Map<String, dynamic>>> _bookingsByDay = {};
  List<Map<String, dynamic>> _selectedDayBookings = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final client = SupabaseService.client;
      final businessId = widget.profile['business_id'];
      final role = widget.profile['role'] as String? ?? '';
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 1);

      setState(() => _isEmployee = role == 'employee');

      if (_isEmployee) {
        final employeeId = widget.profile['id'];
        final results = await Future.wait([
          client
              .from('bookings')
              .select(
                '*, client:profiles!bookings_client_id_fkey(full_name), service:services(name)',
              )
              .eq('business_id', businessId)
              .eq('employee_id', employeeId)
              .gte('start_at', todayStart.toIso8601String())
              .lt('start_at', todayEnd.toIso8601String())
              .order('start_at'),
          client
              .from('bookings')
              .select(
                '*, client:profiles!bookings_client_id_fkey(full_name), service:services(name)',
              )
              .eq('business_id', businessId)
              .eq('employee_id', employeeId)
              .gte('start_at', todayEnd.toIso8601String())
              .neq('status', 'cancelled')
              .order('start_at')
              .limit(5),
        ]);

        if (!mounted) return;
        setState(() {
          _upcomingBookings = (results[0] as List).cast<Map<String, dynamic>>();
          _todayBookings = _upcomingBookings.length;
          _nextBookings = (results[1] as List).cast<Map<String, dynamic>>();
          _loading = false;
        });
        return;
      }

      // Dashboard admin
      final results = await Future.wait([
        client
            .from('bookings')
            .select('id')
            .eq('business_id', businessId)
            .gte('start_at', todayStart.toIso8601String())
            .lt('start_at', todayEnd.toIso8601String()),
        client
            .from('bookings')
            .select('id')
            .eq('business_id', businessId)
            .eq('status', 'pending'),
        client
            .from('products')
            .select('stock, min_stock, name, sku')
            .eq('business_id', businessId),
        client
            .from('profiles')
            .select('id')
            .eq('business_id', businessId)
            .eq('role', 'client'),
        client
            .from('bookings')
            .select(
              '*, client:profiles!bookings_client_id_fkey(full_name), service:services(name)',
            )
            .eq('business_id', businessId)
            .gte('start_at', now.toIso8601String())
            .neq('status', 'cancelled')
            .order('start_at')
            .limit(5),
        client
            .from('invoices')
            .select('total')
            .eq('business_id', businessId)
            .eq('status', 'paid')
            .gte('issued_at', monthStart.toIso8601String()),
        client
            .from('purchase_invoices')
            .select('total')
            .eq('business_id', businessId)
            .eq('status', 'paid')
            .gte('issued_at', monthStart.toIso8601String()),
        client
            .from('bookings')
            .select(
              '*, employee:profiles!bookings_employee_id_fkey(full_name), service:services(name), client:profiles!bookings_client_id_fkey(full_name)',
            )
            .eq('business_id', businessId)
            .gte('start_at', monthStart.toIso8601String())
            .lt('start_at', monthEnd.toIso8601String())
            .neq('status', 'cancelled'),
        client
            .from('stock_notifications')
            .select(
              '*, employee:profiles!stock_notifications_employee_id_fkey(full_name)',
            )
            .eq('business_id', businessId)
            .eq('read', false)
            .order('created_at', ascending: false),
      ]);

      final allProducts = (results[2] as List).cast<Map<String, dynamic>>();
      final lowStock = allProducts
          .where((p) => (p['stock'] as int) < (p['min_stock'] as int))
          .toList();
      final salesList = (results[5] as List).cast<Map<String, dynamic>>();
      final purchasesList = (results[6] as List).cast<Map<String, dynamic>>();
      final monthSales = salesList.fold<double>(
        0,
        (sum, i) => sum + (i['total'] as num).toDouble(),
      );
      final monthPurchases = purchasesList.fold<double>(
        0,
        (sum, i) => sum + (i['total'] as num).toDouble(),
      );

      final calBookings = (results[7] as List).cast<Map<String, dynamic>>();
      final Map<String, List<Map<String, dynamic>>> byDay = {};
      for (final b in calBookings) {
        final d = DateTime.tryParse(b['start_at'] ?? '')?.toLocal();
        if (d != null) {
          final key =
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          byDay.putIfAbsent(key, () => []).add(b);
        }
      }

      if (!mounted) return;
      setState(() {
        _todayBookings = (results[0] as List).length;
        _pendingBookings = (results[1] as List).length;
        _criticalStock = lowStock.length;
        _totalClients = (results[3] as List).length;
        _upcomingBookings = (results[4] as List).cast<Map<String, dynamic>>();
        _lowStockProducts = lowStock;
        _monthSales = monthSales;
        _monthPurchases = monthPurchases;
        _monthProfit = monthSales - monthPurchases;
        _bookingsByDay = byDay;
        _notifications = (results[8] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadCalendarMonth() async {
    try {
      final client = SupabaseService.client;
      final businessId = widget.profile['business_id'];
      final monthStart = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
      final monthEnd = DateTime(
        _calendarMonth.year,
        _calendarMonth.month + 1,
        1,
      );

      final res = await client
          .from('bookings')
          .select(
            '*, employee:profiles!bookings_employee_id_fkey(full_name), service:services(name), client:profiles!bookings_client_id_fkey(full_name)',
          )
          .eq('business_id', widget.profile['business_id'])
          .gte('start_at', monthStart.toIso8601String())
          .lt('start_at', monthEnd.toIso8601String())
          .neq('status', 'cancelled');

      final calBookings = (res as List).cast<Map<String, dynamic>>();
      final Map<String, List<Map<String, dynamic>>> byDay = {};
      for (final b in calBookings) {
        final d = DateTime.tryParse(b['start_at'] ?? '')?.toLocal();
        if (d != null) {
          final key =
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          byDay.putIfAbsent(key, () => []).add(b);
        }
      }
      if (!mounted) return;
      setState(() {
        _bookingsByDay = byDay;
        _selectedDay = null;
        _selectedDayBookings = [];
      });
    } catch (e) {}
  }

  Future<void> _markNotificationRead(String id) async {
    try {
      await SupabaseService.client
          .from('stock_notifications')
          .update({'read': true})
          .eq('id', id);
      setState(() => _notifications.removeWhere((n) => n['id'] == id));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_isEmployee) return _buildEmployeeDashboard();
    return _buildAdminDashboard();
  }

  // ==================== DASHBOARD EMPLEADO ====================

  Widget _buildEmployeeDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getGreeting(),
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            'Hola, ${widget.profile['full_name']?.toString().split(' ').first ?? ''}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),

          // KPI reservas hoy
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF5FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.calendar_month,
                    color: Color(0xFF1D6FEB),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tus reservas hoy',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    Text(
                      '$_todayBookings',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Reservas de hoy
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reservas de hoy',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                if (_upcomingBookings.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        'No tienes reservas hoy',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                else
                  ..._upcomingBookings.map(
                    (b) => _buildBookingRow(b, showDate: false),
                  ),
              ],
            ),
          ),

          // Próximas reservas
          if (_nextBookings.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Próximas reservas',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  ..._nextBookings.map(
                    (b) => _buildBookingRow(b, showDate: true),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBookingRow(Map<String, dynamic> b, {required bool showDate}) {
    final clientName = b['client']?['full_name'] ?? 'Cliente';
    final serviceName = b['service']?['name'] ?? 'Servicio';
    final startAt = DateTime.tryParse(b['start_at'] ?? '')?.toLocal();
    final timeStr = startAt != null
        ? '${startAt.hour.toString().padLeft(2, '0')}:${startAt.minute.toString().padLeft(2, '0')}'
        : '--:--';
    final dateStr = startAt != null
        ? '${startAt.day.toString().padLeft(2, '0')}/${startAt.month.toString().padLeft(2, '0')}'
        : '--';
    final status = b['status'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Container(
            width: showDate ? 52 : 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF5FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (showDate)
                  Text(
                    dateStr,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1D6FEB),
                    ),
                  ),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: showDate ? 10 : 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1D6FEB),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clientName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  serviceName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          _StatusBadge(status: status),
        ],
      ),
    );
  }

  // ==================== DASHBOARD ADMIN ====================

  Widget _buildAdminDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getGreeting(),
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            'Hola, ${widget.profile['full_name']?.toString().split(' ').first ?? ''}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),

          if (_notifications.isNotEmpty) ...[
            _buildSectionLabel('Avisos de empleados'),
            const SizedBox(height: 10),
            ..._notifications.map((n) => _buildNotificationCard(n)),
            const SizedBox(height: 20),
          ],

          _buildSectionLabel('Operaciones'),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth > 700 ? 4 : 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _kpi(
                    constraints,
                    crossCount,
                    icon: Icons.calendar_month,
                    iconBg: const Color(0xFFEEF5FF),
                    iconColor: const Color(0xFF1D6FEB),
                    label: 'Reservas hoy',
                    value: '$_todayBookings',
                    delta: '$_pendingBookings pendientes',
                    deltaPositive: true,
                  ),
                  _kpi(
                    constraints,
                    crossCount,
                    icon: Icons.pending_actions,
                    iconBg: const Color(0xFFF0FDF4),
                    iconColor: const Color(0xFF16A34A),
                    label: 'Por confirmar',
                    value: '$_pendingBookings',
                    delta: 'reservas pendientes',
                    deltaPositive: _pendingBookings == 0,
                  ),
                  _kpi(
                    constraints,
                    crossCount,
                    icon: Icons.inventory_2,
                    iconBg: const Color(0xFFFFFBEB),
                    iconColor: const Color(0xFFD97706),
                    label: 'Stock crítico',
                    value: '$_criticalStock',
                    delta: _criticalStock > 0
                        ? 'Requiere atención'
                        : 'Todo en orden',
                    deltaPositive: _criticalStock == 0,
                  ),
                  _kpi(
                    constraints,
                    crossCount,
                    icon: Icons.people_outline,
                    iconBg: const Color(0xFFF5F3FF),
                    iconColor: const Color(0xFF7C3AED),
                    label: 'Clientes',
                    value: '$_totalClients',
                    delta: 'registrados',
                    deltaPositive: true,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 20),
          _buildSectionLabel(
            'Facturación — ${_monthName(DateTime.now().month)}',
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth > 700 ? 3 : 1;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _kpi(
                    constraints,
                    crossCount,
                    icon: Icons.trending_up,
                    iconBg: const Color(0xFFEEF5FF),
                    iconColor: const Color(0xFF1D6FEB),
                    label: 'Ingresos del mes',
                    value: '${_monthSales.toStringAsFixed(2)} €',
                    delta: 'facturas de venta pagadas',
                    deltaPositive: true,
                  ),
                  _kpi(
                    constraints,
                    crossCount,
                    icon: Icons.trending_down,
                    iconBg: const Color(0xFFFEF2F2),
                    iconColor: const Color(0xFFDC2626),
                    label: 'Gastos del mes',
                    value: '${_monthPurchases.toStringAsFixed(2)} €',
                    delta: 'facturas de compra pagadas',
                    deltaPositive: false,
                  ),
                  _kpi(
                    constraints,
                    crossCount,
                    icon: Icons.account_balance_wallet_outlined,
                    iconBg: _monthProfit >= 0
                        ? const Color(0xFFF0FDF4)
                        : const Color(0xFFFEF2F2),
                    iconColor: _monthProfit >= 0
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                    label: 'Beneficio neto',
                    value: '${_monthProfit.toStringAsFixed(2)} €',
                    delta: _monthProfit >= 0 ? 'positivo' : 'negativo',
                    deltaPositive: _monthProfit >= 0,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 20),
          _buildSectionLabel('Calendario de empleados'),
          const SizedBox(height: 10),
          _buildCalendar(),

          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 700) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildUpcomingBookings()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildStockAlerts()),
                  ],
                );
              }
              return Column(
                children: [
                  _buildUpcomingBookings(),
                  const SizedBox(height: 16),
                  _buildStockAlerts(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> n) {
    final employeeName = n['employee']?['full_name'] as String? ?? 'Empleado';
    final message = n['message'] as String? ?? '';
    final createdAt = DateTime.tryParse(n['created_at'] ?? '')?.toLocal();
    final timeStr = createdAt != null
        ? '${createdAt.day}/${createdAt.month} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_outlined,
            color: Color(0xFFD97706),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employeeName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF92400E),
                  ),
                ),
                if (timeStr.isNotEmpty)
                  Text(
                    timeStr,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFD97706),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check, color: Color(0xFF16A34A), size: 18),
            tooltip: 'Marcar como leído',
            onPressed: () => _markNotificationRead(n['id'] as String),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    final monday = _calendarMonth.subtract(
      Duration(days: _calendarMonth.weekday - 1),
    );
    final now = DateTime.now();
    final weekDays = List.generate(
      6,
      (i) => DateTime(monday.year, monday.month, monday.day + i),
    );
    const dayLabels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Color(0xFF1D6FEB)),
                onPressed: () => setState(() {
                  _calendarMonth = _calendarMonth.subtract(
                    const Duration(days: 7),
                  );
                  _selectedDay = null;
                  _selectedDayBookings = [];
                }),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.view_week_outlined,
                    size: 16,
                    color: Color(0xFF1D6FEB),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${monday.day}/${monday.month} — ${weekDays.last.day}/${weekDays.last.month}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Color(0xFF1D6FEB)),
                onPressed: () => setState(() {
                  _calendarMonth = _calendarMonth.add(const Duration(days: 7));
                  _selectedDay = null;
                  _selectedDayBookings = [];
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(6, (i) {
              final date = weekDays[i];
              final key =
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              final bookings = _bookingsByDay[key] ?? [];
              final isToday =
                  date.year == now.year &&
                  date.month == now.month &&
                  date.day == now.day;
              final isSelected =
                  _selectedDay != null &&
                  _selectedDay!.year == date.year &&
                  _selectedDay!.month == date.month &&
                  _selectedDay!.day == date.day;

              return Expanded(
                child: GestureDetector(
                  onTap: bookings.isNotEmpty
                      ? () => setState(() {
                          _selectedDay = date;
                          _selectedDayBookings = bookings;
                        })
                      : null,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF1D6FEB)
                          : isToday
                          ? const Color(0xFFEEF5FF)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: isToday && !isSelected
                          ? Border.all(
                              color: const Color(0xFF1D6FEB),
                              width: 1.5,
                            )
                          : Border.all(color: const Color(0xFFE2E8F2)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayLabels[i],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : isToday
                                ? const Color(0xFF1D6FEB)
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (bookings.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.3)
                                  : const Color(0xFF1D6FEB),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${bookings.length}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 18),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
          if (_selectedDay != null && _selectedDayBookings.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFE2E8F2)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.people_outline,
                  size: 16,
                  color: Color(0xFF1D6FEB),
                ),
                const SizedBox(width: 6),
                Text(
                  'Empleados el ${_selectedDay!.day}/${_selectedDay!.month}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ..._buildEmployeesByDay(_selectedDayBookings),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildEmployeesByDay(List<Map<String, dynamic>> bookings) {
    final Map<String, List<Map<String, dynamic>>> byEmployee = {};
    for (final b in bookings) {
      final name = b['employee']?['full_name'] as String? ?? 'Sin asignar';
      byEmployee.putIfAbsent(name, () => []).add(b);
    }

    return byEmployee.entries.map((entry) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F2)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF1D6FEB),
              child: Text(
                entry.key.isNotEmpty ? entry.key[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${entry.value.length} reserva${entry.value.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: entry.value.take(3).map((b) {
                final t = DateTime.tryParse(b['start_at'] ?? '')?.toLocal();
                final timeStr = t != null
                    ? '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'
                    : '--:--';
                final service = b['service']?['name'] ?? '';
                return Text(
                  '$timeStr · $service',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Color(0xFF64748B),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _kpi(
    BoxConstraints constraints,
    int crossCount, {
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String value,
    required String delta,
    required bool deltaPositive,
  }) {
    final width = (constraints.maxWidth - 12 * (crossCount - 1)) / crossCount;
    return SizedBox(
      width: width,
      child: _KpiCard(
        icon: icon,
        iconBg: iconBg,
        iconColor: iconColor,
        label: label,
        value: value,
        delta: delta,
        deltaUp: deltaPositive,
      ),
    );
  }

  Widget _buildUpcomingBookings() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Próximas reservas',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (_upcomingBookings.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Sin reservas próximas',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
              ),
            )
          else
            ..._upcomingBookings.map((b) {
              final clientName = b['client']?['full_name'] ?? 'Desconocido';
              final serviceName = b['service']?['name'] ?? 'Sin servicio';
              final startAt = DateTime.tryParse(b['start_at'] ?? '')?.toLocal();
              final timeStr = startAt != null
                  ? '${startAt.hour.toString().padLeft(2, '0')}:${startAt.minute.toString().padLeft(2, '0')}'
                  : '--:--';
              final status = b['status'] as String? ?? '';
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        clientName,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        serviceName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: Text(
                        timeStr,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    _StatusBadge(status: status),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildStockAlerts() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Alertas de stock',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              if (_criticalStock > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_criticalStock críticos',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_lowStockProducts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Stock en niveles correctos',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
              ),
            )
          else
            ..._lowStockProducts.map((p) {
              final stock = p['stock'] as int;
              final minStock = p['min_stock'] as int;
              final critical = stock < (minStock / 2);
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        p['name'] ?? '',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      '$stock uds',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: critical
                            ? const Color(0xFFDC2626)
                            : const Color(0xFFD97706),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'mín: $minStock',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return months[month - 1];
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    final now = DateTime.now();
    const days = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    final dayName = days[now.weekday - 1];
    final monthName = months[now.month - 1];
    final greeting = hour < 12
        ? 'Buenos días'
        : hour < 20
        ? 'Buenas tardes'
        : 'Buenas noches';
    return '$dayName, ${now.day} de $monthName de ${now.year} · $greeting';
  }
}

// ==================== WIDGETS AUXILIARES ====================

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String value;
  final String delta;
  final bool deltaUp;

  const _KpiCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.delta,
    required this.deltaUp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            delta,
            style: TextStyle(
              fontSize: 11,
              color: deltaUp
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final config = switch (status) {
      'confirmed' => (
        bg: const Color(0xFFF0FDF4),
        text: const Color(0xFF16A34A),
        label: 'Confirmada',
      ),
      'pending' => (
        bg: const Color(0xFFFFFBEB),
        text: const Color(0xFFD97706),
        label: 'Pendiente',
      ),
      'completed' => (
        bg: const Color(0xFFEEF5FF),
        text: const Color(0xFF1D6FEB),
        label: 'Completada',
      ),
      'cancelled' => (
        bg: const Color(0xFFFEF2F2),
        text: const Color(0xFFDC2626),
        label: 'Cancelada',
      ),
      _ => (
        bg: const Color(0xFFF1F5F9),
        text: const Color(0xFF64748B),
        label: status,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: config.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        config.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: config.text,
        ),
      ),
    );
  }
}
