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
  int _todayBookings = 0;
  int _pendingBookings = 0;
  int _criticalStock = 0;
  int _totalClients = 0;
  double _monthSales = 0;
  double _monthPurchases = 0;
  double _monthProfit = 0;
  List<Map<String, dynamic>> _upcomingBookings = [];
  List<Map<String, dynamic>> _lowStockProducts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final client = SupabaseService.client;
      final businessId = widget.profile['business_id'];
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      final monthStart = DateTime(now.year, now.month, 1);

      final results = await Future.wait([
        // Reservas de hoy
        client
            .from('bookings')
            .select('id')
            .eq('business_id', businessId)
            .gte('start_at', todayStart.toIso8601String())
            .lt('start_at', todayEnd.toIso8601String()),

        // Reservas pendientes
        client
            .from('bookings')
            .select('id')
            .eq('business_id', businessId)
            .eq('status', 'pending'),

        // Todos los productos (para calcular stock crítico)
        client
            .from('products')
            .select('stock, min_stock, name, sku')
            .eq('business_id', businessId),

        // Total clientes
        client
            .from('profiles')
            .select('id')
            .eq('business_id', businessId)
            .eq('role', 'client'),

        // Próximas reservas
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

        // Facturas de venta del mes (paid)
        client
            .from('invoices')
            .select('total')
            .eq('business_id', businessId)
            .eq('status', 'paid')
            .gte('issued_at', monthStart.toIso8601String()),

        // Facturas de compra del mes (paid)
        client
            .from('purchase_invoices')
            .select('total')
            .eq('business_id', businessId)
            .eq('status', 'paid')
            .gte('issued_at', monthStart.toIso8601String()),
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
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

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

          // KPIs operacionales
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

          // KPIs financieros del mes
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

          // Próximas reservas + Stock crítico
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
