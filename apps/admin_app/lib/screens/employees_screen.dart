import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:core/core.dart';

class EmployeesScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const EmployeesScreen({super.key, required this.profile});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _employees = [];
  Map<String, List<Map<String, dynamic>>> _employeeServices = {};
  Map<String, List<Map<String, dynamic>>> _todayBookings = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final client = SupabaseService.client;
      final businessId = widget.profile['business_id'];
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      final results = await Future.wait([
        client
            .from('profiles')
            .select()
            .eq('business_id', businessId)
            .eq('role', 'employee')
            .order('full_name'),
        client
            .from('bookings')
            .select(
              'id, employee_id, status, start_at, end_at,'
              'service:services(name),'
              'client:profiles!bookings_client_id_fkey(full_name)',
            )
            .eq('business_id', businessId)
            .gte('start_at', todayStart.toIso8601String())
            .lt('start_at', todayEnd.toIso8601String())
            .neq('status', 'cancelled')
            .order('start_at'),
      ]);

      final employees = (results[0] as List).cast<Map<String, dynamic>>();
      final bookings = (results[1] as List).cast<Map<String, dynamic>>();

      final Map<String, List<Map<String, dynamic>>> todayBookings = {};
      for (final b in bookings) {
        final empId = b['employee_id'] as String? ?? '';
        todayBookings.putIfAbsent(empId, () => []).add(b);
      }

      final Map<String, List<Map<String, dynamic>>> employeeServices = {};
      if (employees.isNotEmpty) {
        final ids = employees.map((e) => e['id'] as String).toList();
        final svcRes = await client
            .from('employees_services')
            .select('employee_id, service:services(id, name)')
            .inFilter('employee_id', ids);

        for (final row in (svcRes as List)) {
          final empId = row['employee_id'] as String? ?? '';
          final svc = row['service'] as Map<String, dynamic>?;
          if (svc != null) {
            employeeServices.putIfAbsent(empId, () => []).add(svc);
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _employees = employees;
        _employeeServices = employeeServices;
        _todayBookings = todayBookings;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '--:--';
    final dt = DateTime.tryParse(isoString)?.toLocal();
    if (dt == null) return '--:--';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return RefreshIndicator(
          onRefresh: _loadData,
          color: const Color(0xFF1D6FEB),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(isWide ? 28 : 16),
            child: _loading ? _buildLoading() : _buildContent(isWide),
          ),
        );
      },
    );
  }

  Widget _buildLoading() {
    return Column(
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1B2E),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF1D6FEB),
                    strokeWidth: 2,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Cargando empleados…',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddEmployeeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddEmployeeDialog(
        businessId: widget.profile['business_id'] as String,
        onSuccess: _loadData,
      ),
    );
  }

  Widget _buildContent(bool isWide) {
    final withBookings = _employees
        .where((e) => (_todayBookings[e['id']]?.isNotEmpty ?? false))
        .length;
    final without = _employees.length - withBookings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildKpiRow(withBookings, without, isWide),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(child: _buildSectionLabel('Empleados en plantilla')),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _showAddEmployeeDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D6FEB),
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1D6FEB).withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.person_add_outlined,
                        color: Colors.white,
                        size: 15,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'Dar de alta',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_employees.isEmpty)
          _buildEmptyState()
        else if (isWide)
          _buildTwoColumnGrid()
        else
          _buildSingleColumnList(),
      ],
    );
  }

  Widget _buildKpiRow(int withBookings, int without, bool isWide) {
    return Row(
      children: [
        Expanded(
          child: _KpiChip(
            label: 'Plantilla',
            value: '${_employees.length}',
            icon: Icons.people_outline_rounded,
            color: const Color(0xFF1D6FEB),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiChip(
            label: 'Con reservas',
            value: '$withBookings',
            icon: Icons.event_available_rounded,
            color: const Color(0xFFD97706),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiChip(
            label: 'Disponibles',
            value: '$without',
            icon: Icons.check_circle_outline_rounded,
            color: const Color(0xFF16A34A),
          ),
        ),
      ],
    );
  }

  void _showChangePasswordDialog(Map<String, dynamic> employee) {
    showDialog(
      context: context,
      builder: (_) => _ChangePasswordDialog(employee: employee),
    );
  }

  Widget _buildTwoColumnGrid() {
    final left = <Widget>[];
    final right = <Widget>[];
    for (int i = 0; i < _employees.length; i++) {
      final card = Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _EmployeeCard(
          employee: _employees[i],
          services: _employeeServices[_employees[i]['id']] ?? [],
          todayBookings: _todayBookings[_employees[i]['id']] ?? [],
          formatTime: _formatTime,
          getInitials: _getInitials,
          onChangePassword: () => _showChangePasswordDialog(_employees[i]),
        ),
      );
      if (i.isEven) {
        left.add(card);
      } else {
        right.add(card);
      }
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(children: left)),
        const SizedBox(width: 16),
        Expanded(child: Column(children: right)),
      ],
    );
  }

  Widget _buildSingleColumnList() {
    return Column(
      children: _employees
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _EmployeeCard(
                employee: e,
                services: _employeeServices[e['id']] ?? [],
                todayBookings: _todayBookings[e['id']] ?? [],
                formatTime: _formatTime,
                getInitials: _getInitials,
                onChangePassword: () => _showChangePasswordDialog(e),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B2E),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                color: Color(0xFF1D6FEB),
                size: 22,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No hay empleados registrados',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
}

class _KpiChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D1B2E).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.dmSerifDisplay(
                    fontSize: 22,
                    color: const Color(0xFF0D1B2E),
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  final Map<String, dynamic> employee;
  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> todayBookings;
  final String Function(String?) formatTime;
  final String Function(String) getInitials;
  final VoidCallback onChangePassword;

  const _EmployeeCard({
    required this.employee,
    required this.services,
    required this.todayBookings,
    required this.formatTime,
    required this.getInitials,
    required this.onChangePassword,
  });

  @override
  Widget build(BuildContext context) {
    final name = employee['full_name'] as String? ?? '';
    final email = employee['email'] as String? ?? '';
    final phone = employee['phone'] as String?;
    final initials = getInitials(name);
    final hasBusyToday = todayBookings.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1B2E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: GoogleFonts.dmSerifDisplay(
                        fontSize: 16,
                        color: Colors.white,
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
                        name,
                        style: GoogleFonts.dmSerifDisplay(
                          fontSize: 16,
                          color: const Color(0xFF0D1B2E),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: const Color(0xFF94A3B8),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: hasBusyToday
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: hasBusyToday
                          ? const Color(0xFFFDE68A)
                          : const Color(0xFFBBF7D0),
                    ),
                  ),
                  child: Text(
                    hasBusyToday
                        ? '${todayBookings.length} ${todayBookings.length == 1 ? 'reserva' : 'reservas'}'
                        : 'Libre hoy',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: hasBusyToday
                          ? const Color(0xFFD97706)
                          : const Color(0xFF16A34A),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Cambiar contraseña',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onChangePassword,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(
                        Icons.lock_reset_outlined,
                        size: 15,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (phone != null && phone.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.phone_outlined,
                    size: 12,
                    color: Color(0xFFCBD5E1),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    phone,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),

          if (services.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SERVICIOS',
                    style: GoogleFonts.dmSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: services
                        .map(
                          (s) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF5FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFBFD7FF),
                              ),
                            ),
                            child: Text(
                              s['name'] as String? ?? '',
                              style: GoogleFonts.dmSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF1D6FEB),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),

          if (todayBookings.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 11,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'AGENDA DE HOY',
                          style: GoogleFonts.dmSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF94A3B8),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...todayBookings.map((b) {
                    final time = formatTime(b['start_at'] as String?);
                    final clientName =
                        (b['client'] as Map?)?['full_name'] as String? ?? '—';
                    final serviceName =
                        (b['service'] as Map?)?['name'] as String? ?? '—';
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            time,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1D6FEB),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              clientName,
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: const Color(0xFF374151),
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              serviceName,
                              style: GoogleFonts.dmSans(
                                fontSize: 10,
                                color: const Color(0xFF94A3B8),
                              ),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AddEmployeeDialog extends StatefulWidget {
  final String businessId;
  final VoidCallback onSuccess;

  const _AddEmployeeDialog({required this.businessId, required this.onSuccess});

  @override
  State<_AddEmployeeDialog> createState() => _AddEmployeeDialogState();
}

class _AddEmployeeDialogState extends State<_AddEmployeeDialog> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final password = _passCtrl.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Nombre, email y contraseña son obligatorios');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'La contraseña debe tener al menos 6 caracteres');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final adminRefreshToken =
        SupabaseService.client.auth.currentSession?.refreshToken;

    try {
      final res = await SupabaseService.client.auth.signUp(
        email: email,
        password: password,
      );

      final newUserId = res.user?.id;
      if (newUserId == null) throw Exception('No se pudo crear el usuario');

      if (adminRefreshToken != null) {
        await SupabaseService.client.auth.setSession(adminRefreshToken);
      }

      await SupabaseService.client.from('profiles').insert({
        'id': newUserId,
        'business_id': widget.businessId,
        'role': 'employee',
        'full_name': name,
        'email': email,
        if (phone.isNotEmpty) 'phone': phone,
      });

      widget.onSuccess();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      // Intentar restaurar la sesión del admin aunque haya fallado
      if (adminRefreshToken != null) {
        await SupabaseService.client.auth.setSession(adminRefreshToken);
      }
      if (!mounted) return;
      setState(() {
        _error =
            'Error al crear el empleado. Verifica que el email no exista ya.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D6FEB).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person_add_outlined,
                      color: Color(0xFF1D6FEB),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dar de alta empleado',
                          style: GoogleFonts.dmSerifDisplay(
                            fontSize: 20,
                            color: const Color(0xFF0D1B2E),
                          ),
                        ),
                        Text(
                          'Se creará una cuenta de acceso para el empleado',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _loading
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF94A3B8),
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              const SizedBox(height: 24),

              _label('Nombre completo'),
              const SizedBox(height: 6),
              _field(_nameCtrl, 'Ej. Lucía Ramírez'),
              const SizedBox(height: 16),

              _label('Correo electrónico'),
              const SizedBox(height: 6),
              _field(
                _emailCtrl,
                'empleado@empresa.es',
                type: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              _label('Teléfono (opcional)'),
              const SizedBox(height: 6),
              _field(_phoneCtrl, '+34 600 000 000', type: TextInputType.phone),
              const SizedBox(height: 16),

              _label('Contraseña temporal'),
              const SizedBox(height: 6),
              TextField(
                controller: _passCtrl,
                obscureText: _obscurePass,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: const Color(0xFF0D1B2E),
                ),
                decoration: _fieldDeco('Mínimo 6 caracteres').copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePass
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                      color: const Color(0xFF94A3B8),
                    ),
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                  ),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFDC2626),
                        size: 15,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Text(
                        'Cancelar',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1D6FEB),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Crear empleado',
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text.toUpperCase(),
    style: GoogleFonts.dmSans(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF374151),
      letterSpacing: 0.7,
    ),
  );

  Widget _field(
    TextEditingController ctrl,
    String hint, {
    TextInputType type = TextInputType.text,
  }) => TextField(
    controller: ctrl,
    keyboardType: type,
    style: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF0D1B2E)),
    decoration: _fieldDeco(hint),
  );

  InputDecoration _fieldDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.dmSans(color: const Color(0xFFCBD5E1), fontSize: 14),
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: Color(0xFF1D6FEB), width: 1.5),
    ),
  );
}

// ── Diálogo cambio de contraseña ──────────────────────────────────────────────

class _ChangePasswordDialog extends StatefulWidget {
  final Map<String, dynamic> employee;

  const _ChangePasswordDialog({required this.employee});

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  bool _loading = false;
  bool _sent = false;
  String? _error;

  Future<void> _sendReset() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final email = widget.employee['email'] as String? ?? '';
      await SupabaseService.client.auth.resetPasswordForEmail(email);
      if (mounted) {
        setState(() {
          _sent = true;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo enviar el correo. Inténtalo de nuevo.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.employee['full_name'] as String? ?? '';
    final email = widget.employee['email'] as String? ?? '';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D6FEB).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.lock_reset_outlined,
                      color: Color(0xFF1D6FEB),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cambiar contraseña',
                          style: GoogleFonts.dmSerifDisplay(
                            fontSize: 20,
                            color: const Color(0xFF0D1B2E),
                          ),
                        ),
                        Text(
                          name,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _loading
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF94A3B8),
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              const SizedBox(height: 20),

              if (_sent) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: Color(0xFF16A34A),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Correo enviado',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF16A34A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'El empleado recibirá un enlace en $email para establecer su nueva contraseña.',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: const Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0D1B2E),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: Text(
                      'Cerrar',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Se enviará un enlace de restablecimiento al correo del empleado. Deberá abrirlo para establecer su nueva contraseña.',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF5FF),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: const Color(0xFFBFD7FF)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.email_outlined,
                        size: 15,
                        color: Color(0xFF1D6FEB),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          email,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1D6FEB),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFDC2626),
                          size: 15,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _loading
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Text(
                          'Cancelar',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _loading ? null : _sendReset,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1D6FEB),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Enviar enlace',
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
