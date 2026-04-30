import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:core/core.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const DashboardScreen({super.key, required this.profile});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
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

  DateTime _calendarMonth = DateTime.now();
  DateTime _filterMonth = DateTime.now();
  DateTime? _selectedDay;
  Map<String, List<Map<String, dynamic>>> _bookingsByDay = {};
  List<Map<String, dynamic>> _selectedDayBookings = [];

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
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
        _fadeCtrl.forward();
        return;
      }

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
      _fadeCtrl.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _fadeCtrl.forward();
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

  void _openMonthPicker() async {
    final result = await showDialog<DateTime>(
      context: context,
      builder: (_) => _MonthPickerDialog(selected: _filterMonth),
    );
    if (result != null) _loadBillingForMonth(result);
  }

  Future<void> _loadBillingForMonth(DateTime month) async {
    final client = SupabaseService.client;
    final businessId = widget.profile['business_id'];
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 1);
    try {
      final results = await Future.wait([
        client
            .from('invoices')
            .select('total')
            .eq('business_id', businessId)
            .eq('status', 'paid')
            .gte('issued_at', monthStart.toIso8601String())
            .lt('issued_at', monthEnd.toIso8601String()),
        client
            .from('purchase_invoices')
            .select('total')
            .eq('business_id', businessId)
            .eq('status', 'paid')
            .gte('issued_at', monthStart.toIso8601String())
            .lt('issued_at', monthEnd.toIso8601String()),
      ]);
      final sales = (results[0] as List).cast<Map<String, dynamic>>();
      final purchases = (results[1] as List).cast<Map<String, dynamic>>();
      final monthSales = sales.fold<double>(0, (s, i) => s + (i['total'] as num).toDouble());
      final monthPurchases = purchases.fold<double>(0, (s, i) => s + (i['total'] as num).toDouble());
      if (!mounted) return;
      setState(() {
        _filterMonth = month;
        _monthSales = monthSales;
        _monthPurchases = monthPurchases;
        _monthProfit = monthSales - monthPurchases;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _filterMonth = month);
    }
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

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildLoadingState();
    return FadeTransition(
      opacity: _fadeAnim,
      child: _isEmployee ? _buildEmployeeDashboard() : _buildAdminDashboard(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF0D1B2E),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1D6FEB).withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Padding(
              padding: EdgeInsets.all(13),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF1D6FEB),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Cargando datos…',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  // ─── EMPLOYEE DASHBOARD ──────────────────────────────────────────────────

  Widget _buildEmployeeDashboard() {
    final firstName =
        widget.profile['full_name']?.toString().split(' ').first ?? '';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDashboardHeader(firstName),
          const SizedBox(height: 24),
          _DarkKpiCard(
            icon: Icons.calendar_month_outlined,
            label: 'Tus reservas hoy',
            value: '$_todayBookings',
            delta: 'citas asignadas',
            deltaUp: true,
            sparkData: const [0.3, 0.5, 0.4, 0.7, 0.5, 0.8, 1.0],
            accentColor: const Color(0xFF1D6FEB),
          ),
          const SizedBox(height: 24),
          _buildSectionLabel('Reservas de hoy'),
          const SizedBox(height: 12),
          _buildBookingsCard(
            _upcomingBookings,
            emptyMessage: 'No tienes reservas hoy',
          ),
          if (_nextBookings.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSectionLabel('Próximas reservas'),
            const SizedBox(height: 12),
            _buildBookingsCard(_nextBookings, showDate: true),
          ],
        ],
      ),
    );
  }

  // ─── ADMIN DASHBOARD ─────────────────────────────────────────────────────

  Widget _buildAdminDashboard() {
    final firstName =
        widget.profile['full_name']?.toString().split(' ').first ?? '';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDashboardHeader(firstName),
          const SizedBox(height: 24),

          if (_notifications.isNotEmpty) ...[
            ..._notifications.map((n) => _buildNotificationCard(n)),
            const SizedBox(height: 20),
          ],

          _buildKpiGrid(),
          const SizedBox(height: 24),

          _buildBillingRow(),
          const SizedBox(height: 24),

          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 700) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildLeftColumn()),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: _buildRightPanel()),
                  ],
                );
              }
              return Column(
                children: [
                  _buildLeftColumn(),
                  const SizedBox(height: 16),
                  _buildRightPanel(),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDashboardHeader(String firstName) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getGreeting(),
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Hola, ',
                      style: GoogleFonts.dmSerifDisplay(
                        fontSize: 28,
                        color: const Color(0xFF0D1B2E),
                      ),
                    ),
                    TextSpan(
                      text: firstName,
                      style: GoogleFonts.dmSerifDisplay(
                        fontSize: 28,
                        color: const Color(0xFF1D6FEB),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _openMonthPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D1B2E).withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 13,
                    color: Color(0xFF1D6FEB),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _filterMonth.year == DateTime.now().year
                        ? _monthName(_filterMonth.month)
                        : '${_monthName(_filterMonth.month)} ${_filterMonth.year}',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0D1B2E),
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 600 ? 4 : 2;
        final w = (constraints.maxWidth - 12.0 * (cols - 1)) / cols;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: w,
              child: _DarkKpiCard(
                icon: Icons.calendar_month_outlined,
                label: 'Reservas hoy',
                value: '$_todayBookings',
                delta: '$_pendingBookings pendientes',
                deltaUp: _pendingBookings == 0,
                sparkData: const [0.4, 0.6, 0.3, 0.8, 0.5, 0.7, 0.9],
                accentColor: const Color(0xFF1D6FEB),
              ),
            ),
            SizedBox(
              width: w,
              child: _DarkKpiCard(
                icon: Icons.pending_actions_outlined,
                label: 'Por confirmar',
                value: '$_pendingBookings',
                delta: 'pendientes de confirmar',
                deltaUp: _pendingBookings == 0,
                sparkData: const [0.5, 0.3, 0.6, 0.4, 0.7, 0.3, 0.5],
                accentColor: const Color(0xFF16A34A),
              ),
            ),
            SizedBox(
              width: w,
              child: _DarkKpiCard(
                icon: Icons.inventory_2_outlined,
                label: 'Stock crítico',
                value: '$_criticalStock',
                delta: _criticalStock > 0 ? 'Requiere atención' : 'Todo en orden',
                deltaUp: _criticalStock == 0,
                sparkData: const [0.2, 0.4, 0.3, 0.5, 0.6, 0.4, 0.3],
                accentColor: const Color(0xFFD97706),
              ),
            ),
            SizedBox(
              width: w,
              child: _DarkKpiCard(
                icon: Icons.people_outline,
                label: 'Clientes',
                value: '$_totalClients',
                delta: 'registrados',
                deltaUp: true,
                sparkData: const [0.5, 0.6, 0.65, 0.7, 0.75, 0.8, 0.85],
                accentColor: const Color(0xFF7C3AED),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBillingRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(
        'Facturación — ${_filterMonth.year == DateTime.now().year ? _monthName(_filterMonth.month) : '${_monthName(_filterMonth.month)} ${_filterMonth.year}'}',
      ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth > 600 ? 3 : 1;
            final w = (constraints.maxWidth - 12.0 * (cols - 1)) / cols;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: w,
                  child: _BillingCard(
                    icon: Icons.trending_up_rounded,
                    label: 'Ingresos del mes',
                    value: '${_monthSales.toStringAsFixed(2)} €',
                    color: const Color(0xFF1D6FEB),
                    isUp: true,
                  ),
                ),
                SizedBox(
                  width: w,
                  child: _BillingCard(
                    icon: Icons.trending_down_rounded,
                    label: 'Gastos del mes',
                    value: '${_monthPurchases.toStringAsFixed(2)} €',
                    color: const Color(0xFFDC2626),
                    isUp: false,
                  ),
                ),
                SizedBox(
                  width: w,
                  child: _BillingCard(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Beneficio neto',
                    value: '${_monthProfit.toStringAsFixed(2)} €',
                    color: _monthProfit >= 0
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                    isUp: _monthProfit >= 0,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildLeftColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Próximas reservas'),
        const SizedBox(height: 12),
        _buildBookingsCard(
          _upcomingBookings,
          emptyMessage: 'Sin reservas próximas',
        ),
        const SizedBox(height: 20),
        _buildSectionLabel('Calendario de empleados'),
        const SizedBox(height: 12),
        _buildCalendar(),
      ],
    );
  }

  Widget _buildRightPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Alertas de stock'),
        const SizedBox(height: 12),
        _buildStockPanel(),
      ],
    );
  }

  // ─── BOOKINGS CARD (transaction style) ───────────────────────────────────

  Widget _buildBookingsCard(
    List<Map<String, dynamic>> bookings, {
    String emptyMessage = 'Sin datos',
    bool showDate = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D1B2E).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: bookings.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  emptyMessage,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ),
            )
          : Column(
              children: List.generate(bookings.length, (i) {
                return _buildTransactionRow(
                  bookings[i],
                  showDate: showDate,
                  isLast: i == bookings.length - 1,
                );
              }),
            ),
    );
  }

  Widget _buildTransactionRow(
    Map<String, dynamic> b, {
    required bool showDate,
    bool isLast = false,
  }) {
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
    final initial = clientName.isNotEmpty ? clientName[0].toUpperCase() : '?';

    const avatarColors = [
      Color(0xFF1D6FEB),
      Color(0xFF7C3AED),
      Color(0xFF16A34A),
      Color(0xFFD97706),
      Color(0xFFDC2626),
    ];
    final avatarColor = avatarColors[initial.codeUnitAt(0) % avatarColors.length];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFF1F5F9)),
              ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: avatarColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                initial,
                style: GoogleFonts.dmSerifDisplay(
                  fontSize: 15,
                  color: avatarColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clientName,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0D1B2E),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  serviceName,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (showDate)
                Text(
                  dateStr,
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              Text(
                timeStr,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D6FEB),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          _StatusBadge(status: status),
        ],
      ),
    );
  }

  // ─── STOCK PANEL ─────────────────────────────────────────────────────────

  Widget _buildStockPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D1B2E).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                Text(
                  'Productos bajo mínimo',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0D1B2E),
                  ),
                ),
                const Spacer(),
                if (_criticalStock > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Text(
                      '$_criticalStock críticos',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_lowStockProducts.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Stock en niveles correctos',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: const Color(0xFF16A34A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else
            ...List.generate(_lowStockProducts.length, (i) {
              final p = _lowStockProducts[i];
              final stock = p['stock'] as int;
              final minStock = p['min_stock'] as int;
              final critical = stock < (minStock / 2);
              final ratio =
                  minStock > 0 ? (stock / minStock).clamp(0.0, 1.0) : 0.0;
              final isLast = i == _lowStockProducts.length - 1;
              final barColor = critical
                  ? const Color(0xFFDC2626)
                  : const Color(0xFFD97706);

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : const Border(
                          bottom: BorderSide(color: Color(0xFFF1F5F9)),
                        ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['name'] ?? '',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF0D1B2E),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          LayoutBuilder(
                            builder: (context, constraints) => Stack(
                              children: [
                                Container(
                                  height: 3,
                                  width: constraints.maxWidth,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                Container(
                                  height: 3,
                                  width: constraints.maxWidth * ratio,
                                  decoration: BoxDecoration(
                                    color: barColor,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$stock/$minStock',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: barColor,
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

  // ─── NOTIFICATION CARD ────────────────────────────────────────────────────

  Widget _buildNotificationCard(Map<String, dynamic> n) {
    final employeeName = n['employee']?['full_name'] as String? ?? 'Empleado';
    final message = n['message'] as String? ?? '';
    final createdAt = DateTime.tryParse(n['created_at'] ?? '')?.toLocal();
    final timeStr = createdAt != null
        ? '${createdAt.day}/${createdAt.month} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: Color(0xFFD97706),
              size: 17,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employeeName,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: const Color(0xFF92400E),
                  ),
                ),
                if (timeStr.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    timeStr,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: const Color(0xFFD97706),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.check_circle_outline,
              color: Color(0xFF16A34A),
              size: 20,
            ),
            tooltip: 'Marcar como leído',
            onPressed: () => _markNotificationRead(n['id'] as String),
          ),
        ],
      ),
    );
  }

  // ─── CALENDAR ─────────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D1B2E).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CalNavButton(
                icon: Icons.chevron_left,
                onPressed: () => setState(() {
                  _calendarMonth =
                      _calendarMonth.subtract(const Duration(days: 7));
                  _selectedDay = null;
                  _selectedDayBookings = [];
                }),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.view_week_outlined,
                    size: 14,
                    color: Color(0xFF1D6FEB),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    '${monday.day}/${monday.month} — ${weekDays.last.day}/${weekDays.last.month}',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0D1B2E),
                    ),
                  ),
                ],
              ),
              _CalNavButton(
                icon: Icons.chevron_right,
                onPressed: () => setState(() {
                  _calendarMonth = _calendarMonth.add(const Duration(days: 7));
                  _selectedDay = null;
                  _selectedDayBookings = [];
                }),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(6, (i) {
              final date = weekDays[i];
              final key =
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              final bookings = _bookingsByDay[key] ?? [];
              final isToday = date.year == now.year &&
                  date.month == now.month &&
                  date.day == now.day;
              final isSelected = _selectedDay != null &&
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
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF0D1B2E)
                          : isToday
                              ? const Color(0xFFEEF5FF)
                              : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: isToday && !isSelected
                          ? Border.all(
                              color: const Color(0xFF1D6FEB),
                              width: 1.5,
                            )
                          : Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayLabels[i],
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.5)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${date.day}',
                          style: GoogleFonts.dmSerifDisplay(
                            fontSize: 18,
                            color: isSelected
                                ? Colors.white
                                : isToday
                                    ? const Color(0xFF1D6FEB)
                                    : const Color(0xFF0D1B2E),
                          ),
                        ),
                        const SizedBox(height: 5),
                        if (bookings.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF1D6FEB)
                                  : const Color(0xFF1D6FEB),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${bookings.length}',
                              style: GoogleFonts.dmSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
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
            const SizedBox(height: 18),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.people_outline,
                  size: 14,
                  color: Color(0xFF1D6FEB),
                ),
                const SizedBox(width: 7),
                Text(
                  'Empleados el ${_selectedDay!.day}/${_selectedDay!.month}',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0D1B2E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
      final initial = entry.key.isNotEmpty ? entry.key[0].toUpperCase() : '?';
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B2E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: GoogleFonts.dmSerifDisplay(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0D1B2E),
                    ),
                  ),
                  Text(
                    '${entry.value.length} reserva${entry.value.length > 1 ? 's' : ''}',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: const Color(0xFF94A3B8),
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
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
    }).toList();
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: const Color(0xFF1D6FEB),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF374151),
            letterSpacing: 0.9,
          ),
        ),
      ],
    );
  }

  String _monthName(int month) {
    const months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
    ];
    return months[month - 1];
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    final now = DateTime.now();
    const days = [
      'Lunes', 'Martes', 'Miércoles', 'Jueves',
      'Viernes', 'Sábado', 'Domingo',
    ];
    const months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    final dayName = days[now.weekday - 1];
    final monthName = months[now.month - 1];
    final greeting = hour < 12
        ? 'Buenos días'
        : hour < 20
            ? 'Buenas tardes'
            : 'Buenas noches';
    return '$dayName, ${now.day} de $monthName de ${now.year}  ·  $greeting';
  }
}

// ─── WIDGETS AUXILIARES ───────────────────────────────────────────────────────

class _DarkKpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String delta;
  final bool deltaUp;
  final List<double> sparkData;
  final Color accentColor;

  const _DarkKpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.delta,
    required this.deltaUp,
    required this.sparkData,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2E),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D1B2E).withValues(alpha: 0.20),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 17, color: accentColor),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: deltaUp
                        ? const Color(0xFF16A34A).withValues(alpha: 0.15)
                        : const Color(0xFFDC2626).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        deltaUp
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 10,
                        color: deltaUp
                            ? const Color(0xFF4ADE80)
                            : const Color(0xFFF87171),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        deltaUp ? 'OK' : '!',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: deltaUp
                              ? const Color(0xFF4ADE80)
                              : const Color(0xFFF87171),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.dmSerifDisplay(
                    fontSize: 26,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  delta,
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: SizedBox(
              height: 54,
              width: double.infinity,
              child: CustomPaint(
                painter: _SparklinePainter(
                  color: accentColor,
                  data: sparkData,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BillingCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isUp;

  const _BillingCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isUp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D1B2E).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.dmSerifDisplay(
                    fontSize: 18,
                    color: const Color(0xFF0D1B2E),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: color,
            size: 22,
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final Color color;
  final List<double> data;

  const _SparklinePainter({required this.color, required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.35),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final linePath = Path();
    final fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - (data[i] * size.height * 0.8) - size.height * 0.05;

      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(0, size.height);
        fillPath.lineTo(x, y);
      } else {
        final prevX = ((i - 1) / (data.length - 1)) * size.width;
        final prevY =
            size.height - (data[i - 1] * size.height * 0.8) - size.height * 0.05;
        final cpX = (prevX + x) / 2;
        linePath.cubicTo(cpX, prevY, cpX, y, x, y);
        fillPath.cubicTo(cpX, prevY, cpX, y, x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => false;
}

class _CalNavButton extends StatelessWidget {
  const _CalNavButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFEEF5FF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD0E4FF)),
        ),
        child: Icon(icon, color: const Color(0xFF1D6FEB), size: 18),
      ),
    );
  }
}

class _MonthPickerDialog extends StatefulWidget {
  final DateTime selected;
  const _MonthPickerDialog({required this.selected});

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year;

  static const _months = [
    'Enero', 'Febrero', 'Marzo', 'Abril',
    'Mayo', 'Junio', 'Julio', 'Agosto',
    'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  @override
  void initState() {
    super.initState();
    _year = widget.selected.year;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NavBtn(
                    icon: Icons.chevron_left,
                    onPressed: () => setState(() => _year--),
                  ),
                  Text(
                    '$_year',
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: 22,
                      color: const Color(0xFF0D1B2E),
                    ),
                  ),
                  _NavBtn(
                    icon: Icons.chevron_right,
                    onPressed: _year < now.year
                        ? () => setState(() => _year++)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 2.1,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: 12,
                itemBuilder: (ctx, i) {
                  final month = i + 1;
                  final isFuture =
                      _year == now.year && month > now.month;
                  final isSelected = _year == widget.selected.year &&
                      month == widget.selected.month;
                  return GestureDetector(
                    onTap: isFuture
                        ? null
                        : () => Navigator.of(ctx).pop(DateTime(_year, month)),
                    child: MouseRegion(
                      cursor: isFuture
                          ? SystemMouseCursors.basic
                          : SystemMouseCursors.click,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF1D6FEB)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF1D6FEB)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _months[i],
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : isFuture
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF0D1B2E),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  const _NavBtn({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: MouseRegion(
        cursor: onPressed != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: onPressed != null
                ? const Color(0xFFEEF5FF)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: onPressed != null
                  ? const Color(0xFFD0E4FF)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: onPressed != null
                ? const Color(0xFF1D6FEB)
                : const Color(0xFFCBD5E1),
          ),
        ),
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
        border: const Color(0xFFBBF7D0),
        text: const Color(0xFF16A34A),
        label: 'Confirmada',
      ),
      'pending' => (
        bg: const Color(0xFFFFFBEB),
        border: const Color(0xFFFDE68A),
        text: const Color(0xFFD97706),
        label: 'Pendiente',
      ),
      'completed' => (
        bg: const Color(0xFFEEF5FF),
        border: const Color(0xFFBFDBFE),
        text: const Color(0xFF1D6FEB),
        label: 'Completada',
      ),
      'cancelled' => (
        bg: const Color(0xFFFEF2F2),
        border: const Color(0xFFFCA5A5),
        text: const Color(0xFFDC2626),
        label: 'Cancelada',
      ),
      _ => (
        bg: const Color(0xFFF1F5F9),
        border: const Color(0xFFE2E8F0),
        text: const Color(0xFF64748B),
        label: status,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: config.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: config.border),
      ),
      child: Text(
        config.label,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: config.text,
        ),
      ),
    );
  }
}
