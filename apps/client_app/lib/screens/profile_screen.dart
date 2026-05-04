import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:core/core.dart';
import 'login_screen.dart';

class ClientProfileScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const ClientProfileScreen({super.key, required this.profile});

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: widget.profile['full_name'] as String? ?? '',
    );
    _phoneCtrl = TextEditingController(
      text: widget.profile['phone'] as String? ?? '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await SupabaseService.client
          .from('profiles')
          .update({
            'full_name': _nameCtrl.text.trim(),
            'phone': _phoneCtrl.text.trim().isEmpty
                ? null
                : _phoneCtrl.text.trim(),
          })
          .eq('id', widget.profile['id']);
      if (!mounted) return;
      setState(() {
        _editing = false;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Perfil actualizado', style: GoogleFonts.dmSans()),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    } catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar', style: GoogleFonts.dmSans()),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _logout() async {
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
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
    final name = widget.profile['full_name'] as String? ?? '';
    final email = widget.profile['email'] as String? ?? '';
    final initials = _getInitials(name);

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(color: Color(0xFF0D1B2E)),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _ProfileBannerPainter()),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 48, 24, 40),
                  child: Column(
                    children: [
                      Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF16A34A,
                              ).withValues(alpha: 0.42),
                              blurRadius: 30,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            initials,
                            style: GoogleFonts.dmSerifDisplay(
                              fontSize: 30,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        name,
                        style: GoogleFonts.dmSerifDisplay(
                          fontSize: 28,
                          color: Colors.white,
                          height: 1.1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF16A34A,
                          ).withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(
                              0xFF86EFAC,
                            ).withValues(alpha: 0.45),
                          ),
                        ),
                        child: Text(
                          'Cliente',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF86EFAC),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _sectionLabel('Información personal'),
                    if (!_editing)
                      GestureDetector(
                        onTap: () => setState(() => _editing = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.edit_outlined,
                                size: 13,
                                color: Color(0xFF16A34A),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Editar',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF16A34A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

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
                      _editing
                          ? _editableRow(
                              icon: Icons.person_outline,
                              label: 'Nombre completo',
                              ctrl: _nameCtrl,
                              hint: 'Tu nombre',
                              isLast: false,
                            )
                          : _infoRow(
                              icon: Icons.person_outline,
                              label: 'Nombre completo',
                              value: _nameCtrl.text.isEmpty
                                  ? '—'
                                  : _nameCtrl.text,
                              isLast: false,
                            ),
                      _infoRow(
                        icon: Icons.email_outlined,
                        label: 'Correo electrónico',
                        value: email,
                        isLast: false,
                      ),
                      _editing
                          ? _editableRow(
                              icon: Icons.phone_outlined,
                              label: 'Teléfono',
                              ctrl: _phoneCtrl,
                              hint: '600 000 000',
                              type: TextInputType.phone,
                              isLast: true,
                            )
                          : _infoRow(
                              icon: Icons.phone_outlined,
                              label: 'Teléfono',
                              value: _phoneCtrl.text.isEmpty
                                  ? 'No especificado'
                                  : _phoneCtrl.text,
                              isLast: true,
                            ),
                    ],
                  ),
                ),

                if (_editing) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() => _editing = false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            side: const BorderSide(color: Color(0xFFE2E8F2)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Cancelar',
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Guardar',
                                  style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 32),
                _sectionLabel('Preguntas frecuentes'),
                const SizedBox(height: 12),
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Column(
                      children: _kFaqs.asMap().entries.map((entry) {
                        final i = entry.key;
                        final faq = entry.value;
                        return Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 2,
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(
                              18,
                              0,
                              18,
                              14,
                            ),
                            leading: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.help_outline,
                                size: 16,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                            title: Text(
                              faq.$1,
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF0D1B2E),
                              ),
                            ),
                            iconColor: const Color(0xFF16A34A),
                            collapsedIconColor: const Color(0xFF94A3B8),
                            shape: i < _kFaqs.length - 1
                                ? const Border(
                                    bottom: BorderSide(
                                      color: Color(0xFFF1F5F9),
                                    ),
                                  )
                                : null,
                            collapsedShape: i < _kFaqs.length - 1
                                ? const Border(
                                    bottom: BorderSide(
                                      color: Color(0xFFF1F5F9),
                                    ),
                                  )
                                : null,
                            children: [
                              Text(
                                faq.$2,
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  color: const Color(0xFF64748B),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _logout,
                    child: Container(
                      height: 52,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFDC2626,
                            ).withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.logout_rounded,
                            color: Color(0xFFDC2626),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Cerrar sesión',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isLast,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFF64748B)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF94A3B8),
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF0D1B2E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _editableRow({
    required IconData icon,
    required String label,
    required TextEditingController ctrl,
    required String hint,
    required bool isLast,
    TextInputType type = TextInputType.text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFF16A34A)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF94A3B8),
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: ctrl,
                  keyboardType: type,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: const Color(0xFF0D1B2E),
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: GoogleFonts.dmSans(
                      color: const Color(0xFFCBD5E1),
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFFAFAFC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    isDense: true,
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
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _kFaqs = [
  (
    '¿Cómo cancelo una cita?',
    'Ve a "Mis citas", selecciona la cita que quieres cancelar y pulsa "Cancelar cita". Solo puedes cancelar citas con estado Pendiente o Confirmada.',
  ),
  (
    '¿Puedo pertenecer a varios negocios?',
    'Sí. Ve a la pestaña "Negocios" y pulsa "Unirme a otro negocio" para descubrir negocios disponibles y unirte a ellos.',
  ),
  (
    '¿Cómo cambio mi contraseña?',
    'Por el momento el cambio de contraseña se realiza mediante el enlace "Olvidé mi contraseña" en la pantalla de inicio de sesión.',
  ),
  (
    '¿Dónde están mis facturas?',
    'En la pestaña "Facturas" de la barra de navegación inferior. Desde ahí puedes consultarlas y descargar el PDF si está disponible.',
  ),
  (
    '¿Cómo dejo una valoración?',
    'Una vez finalizada tu cita, aparecerá un botón "Valorar esta cita" en la sección "Historial" de Mis citas. Pulsa para dejar tu puntuación y comentario.',
  ),
  (
    '¿Qué pasa si llego tarde a mi cita?',
    'Te recomendamos avisar al negocio lo antes posible. Dependiendo de la disponibilidad, podrán atenderte o será necesario reprogramar la cita.',
  ),
];

class _ProfileBannerPainter extends CustomPainter {
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
      Offset(size.width * 0.85, size.height * 0.15),
      100,
      glowPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.10, size.height * 0.85),
      60,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
