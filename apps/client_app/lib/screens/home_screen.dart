import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'bookings_screen.dart';
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
        indicatorColor: const Color(0xFF16A34A).withValues(alpha: 0.1),
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

// ==================== HOME TAB ====================

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

      setState(() {
        _nextBooking = bookings.isNotEmpty ? bookings.first : null;
        _business = businesses.isNotEmpty ? businesses.first : null;
        _services = services;
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

    final firstName =
        widget.profile['full_name']?.toString().split(' ').first ?? '';
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Buenos días'
        : hour < 20
        ? 'Buenas tardes'
        : 'Buenas noches';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$greeting,',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        firstName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF16A34A),
                  child: Text(
                    firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Banner negocio
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_business!['address'] != null)
                            Text(
                              _business!['address'],
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context
                          .findAncestorStateOfType<_HomeScreenState>()
                          ?.navigateTo(2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Cambiar',
                          style: TextStyle(
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
              const SizedBox(height: 20),
            ],

            // Próxima cita
            const Text(
              'PRÓXIMA CITA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            if (_nextBooking == null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F2)),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 36,
                      color: Color(0xFFCBD5E1),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'No tienes citas próximas',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Reserva tu próxima visita',
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => context
                          .findAncestorStateOfType<_HomeScreenState>()
                          ?.navigateTo(1),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Pedir cita'),
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
              )
            else
              _buildNextBookingCard(_nextBooking!),

            const SizedBox(height: 28),

            // ── NUESTROS SERVICIOS ──────────────────────────────
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'NUESTROS SERVICIOS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (_services.isNotEmpty)
                  Text(
                    '${_services.length} disponibles',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            if (_services.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F2)),
                ),
                child: const Center(
                  child: Text(
                    'No hay servicios disponibles',
                    style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  ),
                ),
              )
            else
              ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: _services.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _ServiceCard(service: _services[i]),
              ),

            const SizedBox(height: 20),

            // Info del negocio
            if (_business != null) ...[
              const Text(
                'TU NEGOCIO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F2)),
                ),
                child: Column(
                  children: [
                    _businessRow(
                      Icons.store_outlined,
                      _business!['name'] ?? 'Negocio',
                    ),
                    if (_business!['address'] != null)
                      _businessRow(
                        Icons.location_on_outlined,
                        _business!['address'],
                      ),
                    if (_business!['phone'] != null)
                      _businessRow(Icons.phone_outlined, _business!['phone']),
                    _businessRow(
                      Icons.schedule_outlined,
                      'Lun–Sáb · 9:00 – 20:00',
                    ),
                  ],
                ),
              ),
            ],
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
              const Icon(
                Icons.calendar_today,
                size: 14,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 4),
              Text(
                dateStr,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            service?['name'] ?? 'Servicio',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
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
            const SizedBox(height: 8),
            Text(
              '${(service['price'] as num).toStringAsFixed(2)} €',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF16A34A),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _businessRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF16A34A)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  String _weekday(int w) {
    const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return days[w - 1];
  }

  String _month(int m) {
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
    return months[m - 1];
  }
}

// ── TARJETA DE SERVICIO ────────────────────────────────────────────────────────

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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
            child: SizedBox(
              width: 90,
              height: 90,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
          ),
          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
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
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
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
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF16A34A),
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

// ==================== NEGOCIOS TAB ====================

class _BusinessesTab extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _BusinessesTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.store_outlined,
                size: 32,
                color: Color(0xFF16A34A),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Mis negocios',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cambia entre tus negocios favoritos',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => BusinessSelectionScreen(profile: profile),
                  ),
                );
              },
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: const Text('Ver y cambiar negocio'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
