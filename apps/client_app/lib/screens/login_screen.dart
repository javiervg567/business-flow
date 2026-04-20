import 'package:flutter/material.dart';
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
      backgroundColor: const Color(0xFFF4F6FA),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.grid_view_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Business Flow',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Portal de clientes',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 32),

                // Toggle
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F2)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isLogin = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _isLogin
                                  ? const Color(0xFF16A34A)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Iniciar sesión',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: _isLogin
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isLogin = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !_isLogin
                                  ? const Color(0xFF16A34A)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Crear cuenta',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: !_isLogin
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (_isLogin)
                  _LoginForm()
                else
                  _RegisterForm(
                    onRegistered: () {
                      setState(() => _isLogin = true);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── FORMULARIO LOGIN ──────────────────────────────────────

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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Correo electrónico'),
          const SizedBox(height: 6),
          _field(_emailCtrl, 'tu@email.com', type: TextInputType.emailAddress),
          const SizedBox(height: 16),
          _label('Contraseña'),
          const SizedBox(height: 6),
          TextField(
            controller: _passCtrl,
            obscureText: _obscure,
            onSubmitted: (_) => _login(),
            decoration: _inputDeco('••••••••').copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _loading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
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
                  : const Text(
                      'Entrar',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _errorBox(_error!),
          ],
        ],
      ),
    );
  }
}

// ── FORMULARIO REGISTRO ───────────────────────────────────

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
        const SnackBar(
          content: Text('Cuenta creada correctamente. Inicia sesión.'),
          backgroundColor: Color(0xFF16A34A),
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Nombre completo *'),
          const SizedBox(height: 6),
          _field(_nameCtrl, 'Tu nombre'),
          const SizedBox(height: 14),
          _label('Correo electrónico *'),
          const SizedBox(height: 6),
          _field(_emailCtrl, 'tu@email.com', type: TextInputType.emailAddress),
          const SizedBox(height: 14),
          _label('Teléfono (opcional)'),
          const SizedBox(height: 6),
          _field(_phoneCtrl, '600 000 000', type: TextInputType.phone),
          const SizedBox(height: 14),
          _label('Contraseña *'),
          const SizedBox(height: 6),
          TextField(
            controller: _passCtrl,
            obscureText: _obscure,
            decoration: _inputDeco('Mínimo 6 caracteres').copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _label('Confirmar contraseña *'),
          const SizedBox(height: 6),
          _field(_pass2Ctrl, '••••••••', obscure: true),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _loading ? null : _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
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
                  : const Text(
                      'Crear cuenta',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _errorBox(_error!),
          ],
        ],
      ),
    );
  }
}

// ── HELPERS ───────────────────────────────────────────────

Widget _label(String text) =>
    Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)));

Widget _field(
  TextEditingController ctrl,
  String hint, {
  TextInputType type = TextInputType.text,
  bool obscure = false,
}) {
  return TextField(
    controller: ctrl,
    keyboardType: type,
    obscureText: obscure,
    decoration: _inputDeco(hint),
  );
}

InputDecoration _inputDeco(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
    filled: true,
    fillColor: Colors.white,
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

Widget _errorBox(String msg) {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFFCA5A5)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            msg,
            style: const TextStyle(fontSize: 13, color: Color(0xFF991B1B)),
          ),
        ),
      ],
    ),
  );
}
