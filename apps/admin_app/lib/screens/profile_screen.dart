import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  final Map<String, dynamic> profile;
  const ProfileScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final name = profile['full_name'] ?? '';
    final email = profile['email'] ?? '';
    final phone = profile['phone'] ?? 'Sin teléfono';
    final role = profile['role'] as String? ?? '';
    final roleName = role == 'admin' ? 'Administrador' : 'Empleado';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Avatar grande
          CircleAvatar(
            radius: 40,
            backgroundColor: const Color(0xFF1D6FEB),
            child: Text(
              _getInitials(name),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF5FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              roleName,
              style: const TextStyle(fontSize: 12, color: Color(0xFF1D6FEB)),
            ),
          ),
          const SizedBox(height: 32),

          // Datos del perfil
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Información personal',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                _ProfileRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: email,
                ),
                const Divider(height: 24),
                _ProfileRow(
                  icon: Icons.phone_outlined,
                  label: 'Teléfono',
                  value: phone,
                ),
                const Divider(height: 24),
                _ProfileRow(
                  icon: Icons.badge_outlined,
                  label: 'Rol',
                  value: roleName,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Botón de cerrar sesión
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 500),
            child: OutlinedButton.icon(
              onPressed: () async {
                await AuthService.signOut();
                if (!context.mounted) return;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Cerrar sesión'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ],
    );
  }
}
