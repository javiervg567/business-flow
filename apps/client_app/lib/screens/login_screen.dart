import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:core/core.dart';
import 'business_selection_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2E),
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _LoginGridPainter())),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      const _ClientLogoMark(size: 58),
                      const SizedBox(height: 18),
                      Text(
                        'Business Flow',
                        style: GoogleFonts.dmSerifDisplay(
                          fontSize: 30,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Portal de clientes',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 32),

                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.30),
                              blurRadius: 40,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F6FA),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _ToggleTab(
                                      label: 'Iniciar sesión',
                                      active: _isLogin,
                                      onTap: () =>
                                          setState(() => _isLogin = true),
                                    ),
                                    _ToggleTab(
                                      label: 'Crear cuenta',
                                      active: !_isLogin,
                                      onTap: () =>
                                          setState(() => _isLogin = false),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_isLogin)
                              _LoginForm()
                            else
                              _RegisterForm(
                                onRegistered: () =>
                                    setState(() => _isLogin = true),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToggleTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF16A34A) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends StatefulWidget {
  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await AuthService.signIn(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      final role = profile['role'] as String;
      if (role != 'client') {
        await AuthService.signOut();
        setState(() {
          _error = 'Esta app es solo para clientes';
          _loading = false;
        });
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BusinessSelectionScreen(profile: profile),
        ),
      );
    } catch (e) {
      setState(() {
        _error = 'Email o contraseña incorrectos';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FormLabel('Correo electrónico'),
          const SizedBox(height: 6),
          _FormField(
            _emailCtrl,
            'tu@email.com',
            type: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          _FormLabel('Contraseña'),
          const SizedBox(height: 6),
          TextField(
            controller: _passCtrl,
            obscureText: _obscure,
            onSubmitted: (_) => _login(),
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: const Color(0xFF0D1B2E),
            ),
            decoration: _inputDeco('••••••••').copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFF94A3B8),
                  size: 18,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _loading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Entrar',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorBox(_error!),
          ],
        ],
      ),
    );
  }
}

class _RegisterForm extends StatefulWidget {
  final VoidCallback onRegistered;
  const _RegisterForm({required this.onRegistered});

  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final pass = _passCtrl.text;
    final pass2 = _pass2Ctrl.text;

    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Rellena todos los campos obligatorios');
      return;
    }
    if (pass != pass2) {
      setState(() => _error = 'Las contraseñas no coinciden');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'La contraseña debe tener al menos 6 caracteres');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await SupabaseService.client.auth.signUp(
        email: email,
        password: pass,
      );

      final userId = response.user?.id;
      if (userId == null) throw Exception('Error al crear usuario');
      await Future.delayed(const Duration(seconds: 1));

      final businesses = await SupabaseService.client
          .from('businesses')
          .select('id')
          .limit(1);

      if (businesses.isEmpty) throw Exception('No se encontró ningún negocio');
      final businessId = businesses.first['id'];

      await SupabaseService.client.rpc(
        'create_client_profile',
        params: {
          'p_id': userId,
          'p_email': email,
          'p_full_name': name,
          'p_phone': phone.isEmpty ? null : phone,
          'p_business_id': businessId,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cuenta creada correctamente. Inicia sesión.',
            style: GoogleFonts.dmSans(),
          ),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
      widget.onRegistered();
    } catch (e, stack) {
      print('ERROR: $e');
      print('STACK: $stack');
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FormLabel('Nombre completo *'),
          const SizedBox(height: 6),
          _FormField(_nameCtrl, 'Tu nombre'),
          const SizedBox(height: 14),
          _FormLabel('Correo electrónico *'),
          const SizedBox(height: 6),
          _FormField(
            _emailCtrl,
            'tu@email.com',
            type: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          _FormLabel('Teléfono (opcional)'),
          const SizedBox(height: 6),
          _FormField(_phoneCtrl, '600 000 000', type: TextInputType.phone),
          const SizedBox(height: 14),
          _FormLabel('Contraseña *'),
          const SizedBox(height: 6),
          TextField(
            controller: _passCtrl,
            obscureText: _obscure,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: const Color(0xFF0D1B2E),
            ),
            decoration: _inputDeco('Mínimo 6 caracteres').copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFF94A3B8),
                  size: 18,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _FormLabel('Confirmar contraseña *'),
          const SizedBox(height: 6),
          _FormField(_pass2Ctrl, '••••••••', obscure: true),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _loading ? null : _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Crear cuenta',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorBox(_error!),
          ],
        ],
      ),
    );
  }
}

class _FormLabel extends StatelessWidget {
  final String text;
  const _FormLabel(this.text);

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

class _FormField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final TextInputType type;
  final bool obscure;
  const _FormField(
    this.ctrl,
    this.hint, {
    this.type = TextInputType.text,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      obscureText: obscure,
      style: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF0D1B2E)),
      decoration: _inputDeco(hint),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String msg;
  const _ErrorBox(this.msg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: const Color(0xFF991B1B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _inputDeco(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.dmSans(color: const Color(0xFFCBD5E1), fontSize: 14),
    filled: true,
    fillColor: const Color(0xFFFAFAFC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFE2E8F2)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFE2E8F2)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF16A34A), width: 1.5),
    ),
  );
}

class _ClientLogoMark extends StatelessWidget {
  final double size;
  const _ClientLogoMark({this.size = 52});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF16A34A),
        borderRadius: BorderRadius.circular(size * 0.23),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withValues(alpha: 0.40),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: CustomPaint(painter: _BarsPainter()),
    );
  }
}

class _BarsPainter extends CustomPainter {
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

class _LoginGridPainter extends CustomPainter {
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
      ..color = const Color(0xFF16A34A).withValues(alpha: 0.09)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.12),
      120,
      glowPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.10, size.height * 0.80),
      80,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
