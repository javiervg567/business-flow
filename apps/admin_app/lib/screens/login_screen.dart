import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:core/core.dart';
import 'main_layout.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscurePassword = true;
  bool _emailFocused = false;
  bool _passwordFocused = false;

  late final AnimationController _entranceCtrl;
  late final Animation<double> _formFade;
  late final Animation<Offset> _formSlide;
  late final Animation<double> _panelFade;
  late final Animation<Offset> _panelSlide;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _panelFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    );
    _panelSlide = Tween<Offset>(
      begin: const Offset(-0.05, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    ));

    _formFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
    );
    _formSlide = Tween<Offset>(
      begin: const Offset(0, 0.07),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
    ));

    _entranceCtrl.forward();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await AuthService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      final role = profile['role'] as String;
      if (role == 'client') {
        await AuthService.signOut();
        setState(() {
          _error = 'Esta app es solo para administradores y empleados';
          _loading = false;
        });
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MainLayout(profile: profile)),
      );
    } catch (e) {
      setState(() {
        _error = 'Email o contraseña incorrectos';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2E),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return _buildDesktopLayout();
          }
          return _buildMobileLayout();
        },
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(
          flex: 42,
          child: SlideTransition(
            position: _panelSlide,
            child: FadeTransition(
              opacity: _panelFade,
              child: const _LeftPanel(),
            ),
          ),
        ),
        Expanded(
          flex: 58,
          child: Container(
            color: Colors.white,
            child: Center(
              child: SlideTransition(
                position: _formSlide,
                child: FadeTransition(
                  opacity: _formFade,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: _buildForm(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        SlideTransition(
          position: _panelSlide,
          child: FadeTransition(
            opacity: _panelFade,
            child: const _MobileHeader(),
          ),
        ),
        Expanded(
          child: Container(
            color: Colors.white,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 36, 28, 32),
              child: SlideTransition(
                position: _formSlide,
                child: FadeTransition(
                  opacity: _formFade,
                  child: _buildForm(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bienvenido\nde nuevo',
              style: GoogleFonts.dmSerifDisplay(
                fontSize: 44,
                height: 1.1,
                color: const Color(0xFF0D1B2E),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Accede a tu panel de gestión',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                color: const Color(0xFF6B7280),
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 48),

            _fieldLabel('Correo electrónico'),
            const SizedBox(height: 8),
            Focus(
              onFocusChange: (v) => setState(() => _emailFocused = v),
              child: TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  color: const Color(0xFF0D1B2E),
                ),
                decoration: _fieldDecoration(
                  'tu@empresa.es',
                  isFocused: _emailFocused,
                ),
              ),
            ),
            const SizedBox(height: 24),

            _fieldLabel('Contraseña'),
            const SizedBox(height: 8),
            Focus(
              onFocusChange: (v) => setState(() => _passwordFocused = v),
              child: TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  color: const Color(0xFF0D1B2E),
                ),
                decoration: _fieldDecoration(
                  '••••••••',
                  isFocused: _passwordFocused,
                ).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: const Color(0xFF9CA3AF),
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                onSubmitted: (_) => _handleLogin(),
              ),
            ),
            const SizedBox(height: 36),

            _LoginButton(loading: _loading, onPressed: _handleLogin),

            if (_error != null) ...[
              const SizedBox(height: 16),
              _ErrorBanner(message: _error!),
            ],

            const SizedBox(height: 40),
            Center(
              child: Text(
                '¿Problemas para acceder?\nContacta con soporte',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: const Color(0xFFB0B9C6),
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF374151),
        letterSpacing: 0.8,
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint, {required bool isFocused}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.dmSans(
        color: const Color(0xFFCBD5E1),
        fontSize: 15,
      ),
      filled: true,
      fillColor:
          isFocused ? const Color(0xFFF0F6FF) : const Color(0xFFF8FAFC),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: Color(0xFF1D6FEB), width: 1.5),
      ),
    );
  }
}

// ─── Left panel ──────────────────────────────────────────────────────────────

class _LeftPanel extends StatelessWidget {
  const _LeftPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D1B2E),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _BlueprintPainter()),
          ),
          Padding(
            padding: const EdgeInsets.all(52),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LogoMark(),
                const SizedBox(height: 20),
                Text(
                  'Business\nFlow',
                  style: GoogleFonts.dmSerifDisplay(
                    fontSize: 58,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  height: 2,
                  width: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D6FEB),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Tu negocio,\nbajo control.',
                  style: GoogleFonts.dmSans(
                    fontSize: 17,
                    color: const Color(0xFF7A9BBF),
                    height: 1.65,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const Spacer(),
                Text(
                  '© 2026 Business Flow',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: const Color(0xFF2E4A67),
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

class _LogoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF1D6FEB),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D6FEB).withValues(alpha:0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(
        Icons.grid_view_rounded,
        color: Colors.white,
        size: 26,
      ),
    );
  }
}

// ─── Mobile header ────────────────────────────────────────────────────────────

class _MobileHeader extends StatelessWidget {
  const _MobileHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0D1B2E),
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.of(context).padding.top + 24,
        24,
        28,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1D6FEB),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1D6FEB).withValues(alpha:0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.grid_view_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Business Flow',
                style: GoogleFonts.dmSerifDisplay(
                  fontSize: 22,
                  color: Colors.white,
                ),
              ),
              Text(
                'Panel de administración',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: const Color(0xFF7A9BBF),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Login button ─────────────────────────────────────────────────────────────

class _LoginButton extends StatefulWidget {
  const _LoginButton({required this.loading, required this.onPressed});
  final bool loading;
  final VoidCallback onPressed;

  @override
  State<_LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<_LoginButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) {
        _pressCtrl.reverse();
        if (!widget.loading) widget.onPressed();
      },
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: 52,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2979F2), Color(0xFF0D52C7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1D6FEB).withValues(alpha:0.38),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Center(
            child: widget.loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Acceder al panel',
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Error banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: const Color(0xFF991B1B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Background geometric painter ────────────────────────────────────────────

class _BlueprintPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF1A2F4A).withValues(alpha:0.45)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const spacing = 56.0;
    for (double x = 0; x < size.width + spacing; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height + spacing; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final glowFill = Paint()
      ..color = const Color(0xFF1D6FEB).withValues(alpha:0.07)
      ..style = PaintingStyle.fill;
    final glowStroke = Paint()
      ..color = const Color(0xFF1D6FEB).withValues(alpha:0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final cx = size.width * 0.82;
    final cy = size.height * 0.14;
    canvas.drawCircle(Offset(cx, cy), 170, glowFill);
    canvas.drawCircle(Offset(cx, cy), 170, glowStroke);
    canvas.drawCircle(Offset(cx, cy), 215, glowStroke);
    canvas.drawCircle(Offset(cx, cy), 260, glowStroke);

    final cx2 = size.width * 0.12;
    final cy2 = size.height * 0.87;
    canvas.drawCircle(Offset(cx2, cy2), 90, glowFill);
    canvas.drawCircle(Offset(cx2, cy2), 90, glowStroke);

    final diagPaint = Paint()
      ..color = const Color(0xFF1D6FEB).withValues(alpha:0.13)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(size.width * 0.48, size.height * 0.62),
      Offset(size.width * 1.15, size.height * 0.18),
      diagPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.36, size.height * 0.72),
      Offset(size.width * 1.15, size.height * 0.28),
      diagPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
