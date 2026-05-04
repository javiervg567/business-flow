import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:core/core.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class BusinessSelectionScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const BusinessSelectionScreen({super.key, required this.profile});

  @override
  State<BusinessSelectionScreen> createState() =>
      _BusinessSelectionScreenState();
}

class _BusinessSelectionScreenState extends State<BusinessSelectionScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _myBusinesses = [];
  List<Map<String, dynamic>> _allBusinesses = [];
  bool _showJoin = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final clientId = widget.profile['id'];

      final results = await Future.wait([
        SupabaseService.client
            .from('business_clients')
            .select('business_id, businesses(id, name, address, phone)')
            .eq('client_id', clientId),
        SupabaseService.client
            .from('businesses')
            .select('id, name, address, phone'),
      ]);

      final myRaw = (results[0] as List).cast<Map<String, dynamic>>();
      final allRaw = (results[1] as List).cast<Map<String, dynamic>>();

      final myBusinessIds = myRaw
          .map((r) => r['business_id'] as String)
          .toSet();

      setState(() {
        _myBusinesses = myRaw
            .map((r) => r['businesses'] as Map<String, dynamic>)
            .toList();
        _allBusinesses = allRaw
            .where((b) => !myBusinessIds.contains(b['id']))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _joinBusiness(Map<String, dynamic> business) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await SupabaseService.client.from('business_clients').insert({
        'business_id': business['id'],
        'client_id': widget.profile['id'],
      });

      await SupabaseService.client
          .from('profiles')
          .update({'business_id': business['id']})
          .eq('id', widget.profile['id']);

      _loadData();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Te has unido a ${business['name']}',
            style: GoogleFonts.dmSans(),
          ),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Error al unirse al negocio',
            style: GoogleFonts.dmSans(),
          ),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  void _selectBusiness(Map<String, dynamic> business) {
    final updatedProfile = Map<String, dynamic>.from(widget.profile);
    updatedProfile['business_id'] = business['id'];

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomeScreen(profile: updatedProfile)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstName =
        widget.profile['full_name']?.toString().split(' ').first ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(color: Color(0xFF0D1B2E)),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _SelectionGridPainter()),
                ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A),
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF16A34A).withValues(
                                      alpha: 0.35,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: CustomPaint(painter: _MiniBarsPainter()),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Business Flow',
                                  style: GoogleFonts.dmSerifDisplay(
                                    fontSize: 15,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Portal de clientes',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 10,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () async {
                                final nav = Navigator.of(context);
                                await AuthService.signOut();
                                if (!mounted) return;
                                nav.pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.logout,
                                      size: 14,
                                      color: Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Salir',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 12,
                                        color: const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'Hola, $firstName',
                          style: GoogleFonts.dmSerifDisplay(
                            fontSize: 28,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '¿A qué negocio vas hoy?',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF16A34A),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_myBusinesses.isNotEmpty) ...[
                          _sectionLabel('Mis negocios'),
                          const SizedBox(height: 10),
                          ..._myBusinesses.map(
                            (b) => _BusinessCard(
                              business: b,
                              onTap: () => _selectBusiness(b),
                              joined: true,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        GestureDetector(
                          onTap: () => setState(() => _showJoin = !_showJoin),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF16A34A),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF16A34A).withValues(
                                    alpha: 0.08,
                                  ),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    color: Color(0xFF16A34A),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Unirme a otro negocio',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF16A34A),
                                        ),
                                      ),
                                      Text(
                                        'Descubre negocios disponibles',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 11,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  _showJoin
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: const Color(0xFF16A34A),
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (_showJoin) ...[
                          const SizedBox(height: 10),
                          if (_allBusinesses.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F2),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'No hay más negocios disponibles',
                                  style: GoogleFonts.dmSans(
                                    color: const Color(0xFF94A3B8),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            )
                          else
                            ..._allBusinesses.map(
                              (b) => _BusinessCard(
                                business: b,
                                onTap: () => _joinBusiness(b),
                                joined: false,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
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

class _BusinessCard extends StatelessWidget {
  final Map<String, dynamic> business;
  final VoidCallback onTap;
  final bool joined;

  const _BusinessCard({
    required this.business,
    required this.onTap,
    required this.joined,
  });

  @override
  Widget build(BuildContext context) {
    final name = business['name'] as String? ?? 'Negocio';
    final address = business['address'] as String?;
    final phone = business['phone'] as String?;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
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
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: joined
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF64748B),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: GoogleFonts.dmSerifDisplay(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
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
                  if (address != null)
                    Text(
                      address,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  if (phone != null)
                    Text(
                      phone,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: joined
                    ? const Color(0xFFF0FDF4)
                    : const Color(0xFF16A34A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                joined ? 'Entrar' : 'Unirme',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: joined ? const Color(0xFF16A34A) : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _SelectionGridPainter extends CustomPainter {
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
      Offset(size.width * 0.85, size.height * 0.20),
      90,
      glowPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.10, size.height * 0.80),
      55,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MiniBarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final barW = w * (16 / 120);
    final bottomY = h * (100 / 120);
    final startX = w * (22 / 120);
    final step = w * (22 / 120);
    final barHeights = [h * (28 / 120), h * (46 / 120), h * (64 / 120)];
    const opacities = [0.45, 0.75, 1.0];
    const rx = Radius.circular(2.5);

    for (int i = 0; i < 3; i++) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: opacities[i])
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            startX + i * step,
            bottomY - barHeights[i],
            barW,
            barHeights[i],
          ),
          rx,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
