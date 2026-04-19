import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'home_screen.dart';

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
        // Negocios del cliente
        SupabaseService.client
            .from('business_clients')
            .select('business_id, businesses(id, name, address, phone)')
            .eq('client_id', clientId),
        // Todos los negocios disponibles
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
    try {
      await SupabaseService.client.from('business_clients').insert({
        'business_id': business['id'],
        'client_id': widget.profile['id'],
      });

      // Actualizar business_id del perfil al nuevo negocio
      await SupabaseService.client
          .from('profiles')
          .update({'business_id': business['id']})
          .eq('id', widget.profile['id']);

      _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Te has unido a ${business['name']}'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al unirse al negocio'),
          backgroundColor: Color(0xFFDC2626),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.grid_view_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Business Flow',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Selecciona un negocio',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      await AuthService.signOut();
                      if (!mounted) return;
                      Navigator.of(context).pushReplacementNamed('/');
                    },
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Salir'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Text(
                'Hola, ${widget.profile['full_name']?.toString().split(' ').first ?? ''}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                '¿A qué negocio vas hoy?',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),

              if (_loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                // Mis negocios
                if (_myBusinesses.isNotEmpty) ...[
                  const Text(
                    'MIS NEGOCIOS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._myBusinesses.map(
                    (b) => _BusinessCard(
                      business: b,
                      onTap: () => _selectBusiness(b),
                      joined: true,
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Unirse a otro negocio
                GestureDetector(
                  onTap: () => setState(() => _showJoin = !_showJoin),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF16A34A),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Color(0xFF16A34A),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Unirme a otro negocio',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                              Text(
                                'Descubre negocios disponibles',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
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
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F2)),
                      ),
                      child: const Center(
                        child: Text(
                          'No hay más negocios disponibles',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
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
            ],
          ),
        ),
      ),
    );
  }
}

// ── TARJETA DE NEGOCIO ────────────────────────────────────

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
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F2)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: joined
                  ? const Color(0xFF16A34A)
                  : const Color(0xFF64748B),
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
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
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (address != null)
                    Text(
                      address,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  if (phone != null)
                    Text(
                      phone,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
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
                style: TextStyle(
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
