import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:core/core.dart';
import 'bookings_screen.dart';
import 'invoices_screen.dart';
import 'profile_screen.dart';
import 'business_selection_screen.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const HomeScreen({super.key, required this.profile});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  void navigateTo(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  void initState() {
    super.initState();
    _screens = [
      ClientHomeTab(profile: widget.profile),
      ClientBookingsScreen(profile: widget.profile),
      ClientInvoicesScreen(profile: widget.profile),
      _BusinessesTab(profile: widget.profile),
      ClientProfileScreen(profile: widget.profile),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF16A34A).withValues(alpha: 0.12),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: Color(0xFF16A34A)),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month, color: Color(0xFF16A34A)),
            label: 'Mis citas',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: Color(0xFF16A34A)),
            label: 'Facturas',
          ),
          NavigationDestination(
            icon: Icon(Icons.store_outlined),
            selectedIcon: Icon(Icons.store, color: Color(0xFF16A34A)),
            label: 'Negocios',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: Color(0xFF16A34A)),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class ClientHomeTab extends StatefulWidget {
  final Map<String, dynamic> profile;
  const ClientHomeTab({super.key, required this.profile});

  @override
  State<ClientHomeTab> createState() => _ClientHomeTabState();
}

class _ClientHomeTabState extends State<ClientHomeTab> {
  bool _loading = true;
  Map<String, dynamic>? _nextBooking;
  Map<String, dynamic>? _business;
  List<Map<String, dynamic>> _services = [];
  bool _soonAlert = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final client = SupabaseService.client;
      final clientId = widget.profile['id'];
      final businessId = widget.profile['business_id'];
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
            .order('start_at')
            .limit(1),
        client
            .from('businesses')
            .select('id, name, phone, address')
            .eq('id', businessId)
            .limit(1),
        client
            .from('services')
            .select('id, name, duration_minutes, price, description, image_url')
            .eq('business_id', businessId)
            .eq('active', true)
            .order('name'),
      ]);

      if (!mounted) return;
      final bookings = (results[0] as List).cast<Map<String, dynamic>>();
      final businesses = (results[1] as List).cast<Map<String, dynamic>>();
      final services = (results[2] as List).cast<Map<String, dynamic>>();

      bool soonAlert = false;
      if (bookings.isNotEmpty) {
        final startAt = DateTime.tryParse(bookings.first['start_at'] ?? '');
        if (startAt != null) {
          final diff = startAt.toUtc().difference(DateTime.now().toUtc());
          soonAlert = diff.inMinutes >= 0 && diff.inHours <= 24;
        }
      }

      setState(() {
        _nextBooking = bookings.isNotEmpty ? bookings.first : null;
        _business = businesses.isNotEmpty ? businesses.first : null;
        _services = services;
        _soonAlert = soonAlert;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF16A34A)),
      );
    }

    final firstName =
        widget.profile['full_name']?.toString().split(' ').first ?? '';
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Buenos días'
        : hour < 20
        ? 'Buenas tardes'
        : 'Buenas noches';
    final initials = _getInitials(widget.profile['full_name'] ?? '');

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(color: Color(0xFF0D1B2E)),
              child: Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: _HomeGridPainter())),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$greeting,',
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                firstName,
                                style: GoogleFonts.dmSerifDisplay(
                                  fontSize: 28,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A),
                            borderRadius: BorderRadius.circular(11),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF16A34A).withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: GoogleFonts.dmSerifDisplay(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (_soonAlert && _nextBooking != null) ...[
              Container(
                margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.notifications_outlined,
                        size: 18,
                        color: Color(0xFFD97706),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recordatorio de cita',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF92400E),
                            ),
                          ),
                          Text(
                            'Tienes una cita en las próximas 24 horas',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: const Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_business != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.store_outlined,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _business!['name'] ?? 'Tu negocio',
                                  style: GoogleFonts.dmSans(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_business!['address'] != null)
                                  Text(
                                    _business!['address'],
                                    style: GoogleFonts.dmSans(
                                      color: Colors.white.withValues(alpha: 0.80),
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context
                                .findAncestorStateOfType<_HomeScreenState>()
                                ?.navigateTo(3),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Cambiar',
                                style: GoogleFonts.dmSans(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  const _SectionLabel('Próxima cita'),
                  const SizedBox(height: 10),
                  if (_nextBooking == null)
                    _EmptyBookingCard(
                      onBook: () => context
                          .findAncestorStateOfType<_HomeScreenState>()
                          ?.navigateTo(1),
                    )
                  else
                    _buildNextBookingCard(_nextBooking!),

                  const SizedBox(height: 28),

                  Row(
                    children: [
                      const Expanded(child: _SectionLabel('Nuestros servicios')),
                      if (_services.isNotEmpty)
                        Text(
                          '${_services.length} disponibles',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_services.isEmpty)
                    _emptyCard('No hay servicios disponibles')
                  else
                    ListView.separated(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: _services.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _ServiceCard(service: _services[i]),
                    ),

                  const SizedBox(height: 28),

                  if (_business != null) ...[
                    const _SectionLabel('Tu negocio'),
                    const SizedBox(height: 10),
                    Container(
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
                          _businessInfoRow(
                            Icons.store_outlined,
                            _business!['name'] ?? 'Negocio',
                            isLast: _business!['address'] == null && _business!['phone'] == null,
                          ),
                          if (_business!['address'] != null)
                            _businessInfoRow(
                              Icons.location_on_outlined,
                              _business!['address'],
                              isLast: _business!['phone'] == null,
                            ),
                          if (_business!['phone'] != null)
                            _businessInfoRow(
                              Icons.phone_outlined,
                              _business!['phone'],
                              isLast: true,
                            ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextBookingCard(Map<String, dynamic> booking) {
    final service = booking['service'];
    final employee = booking['employee'];
    final startAt = DateTime.tryParse(booking['start_at'] ?? '')?.toLocal();
    final status = booking['status'] as String? ?? '';

    final dateStr = startAt != null
        ? '${_weekday(startAt.weekday)}, ${startAt.day} de ${_month(startAt.month)}'
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
      _ => (
        label: status,
        color: const Color(0xFF64748B),
        bg: const Color(0xFFF1F5F9),
      ),
    };

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
              const Icon(Icons.calendar_today, size: 13, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(
                dateStr,
                style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            service?['name'] ?? 'Servicio',
            style: GoogleFonts.dmSerifDisplay(
              fontSize: 20,
              color: const Color(0xFF0D1B2E),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(
                timeStr,
                style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF64748B)),
              ),
              if (employee != null) ...[
                const SizedBox(width: 14),
                const Icon(Icons.person_outline, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text(
                  employee['full_name'] ?? '',
                  style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF64748B)),
                ),
              ],
            ],
          ),
          if (service?['price'] != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
        ],
      ),
    );
  }

  Widget _businessInfoRow(IconData icon, String text, {required bool isLast}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFF16A34A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF0D1B2E)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF94A3B8)),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }

  String _weekday(int w) {
    const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return days[w - 1];
  }

  String _month(int m) {
    const months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    return months[m - 1];
  }
}

class _EmptyBookingCard extends StatelessWidget {
  final VoidCallback onBook;
  const _EmptyBookingCard({required this.onBook});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_today_outlined,
              size: 24,
              color: Color(0xFF86EFAC),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No tienes citas próximas',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Reserva tu próxima visita',
            style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onBook,
              icon: const Icon(Icons.add, size: 16),
              label: Text(
                'Pedir cita',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final Map<String, dynamic> service;
  const _ServiceCard({required this.service});

  @override
  Widget build(BuildContext context) {
    final imageUrl = service['image_url'] as String?;
    final name = service['name'] as String? ?? '';
    final description = service['description'] as String?;
    final duration = service['duration_minutes'] as int?;
    final price = service['price'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D1B2E).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              bottomLeft: Radius.circular(14),
            ),
            child: SizedBox(
              width: 90,
              height: 90,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _placeholder(),
                    )
                  : _placeholder(),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0D1B2E),
                    ),
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (duration != null) ...[
                        const Icon(
                          Icons.access_time,
                          size: 13,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$duration min',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (price != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${(price as num).toStringAsFixed(2)} €',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFF0FDF4),
      child: const Icon(Icons.spa_outlined, size: 32, color: Color(0xFF86EFAC)),
    );
  }
}

class _BusinessesTab extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _BusinessesTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Icon(
                  Icons.store_outlined,
                  size: 30,
                  color: Color(0xFF16A34A),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Mis negocios',
                style: GoogleFonts.dmSerifDisplay(
                  fontSize: 22,
                  color: const Color(0xFF0D1B2E),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Cambia entre tus negocios favoritos',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => BusinessSelectionScreen(profile: profile),
                      ),
                    );
                  },
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: Text(
                    'Ver y cambiar negocio',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: const Color(0xFF16A34A),
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

class _HomeGridPainter extends CustomPainter {
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
      ..color = const Color(0xFF16A34A).withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.20),
      80,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
