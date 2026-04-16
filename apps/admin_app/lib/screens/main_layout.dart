import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'bookings_screen.dart';
import 'inventory_screen.dart';
import 'invoices_screen.dart';
import 'profile_screen.dart';

class MainLayout extends StatefulWidget {
  final Map<String, dynamic> profile;
  const MainLayout({super.key, required this.profile});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  late final List<_NavItem> _navItems;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();

    _navItems = const [
      _NavItem(icon: Icons.grid_view_rounded, label: 'Dashboard'),
      _NavItem(icon: Icons.calendar_month, label: 'Reservas'),
      _NavItem(icon: Icons.inventory_2, label: 'Inventario'),
      _NavItem(icon: Icons.receipt_long, label: 'Facturas'),
      _NavItem(icon: Icons.person_outline, label: 'Perfil'),
    ];

    _screens = [
      DashboardScreen(profile: widget.profile),
      const BookingsScreen(),
      const InventoryScreen(),
      const InvoicesScreen(),
      ProfileScreen(profile: widget.profile),
    ];
  }

  void _onItemTapped(int index) {
    setState(() => _currentIndex = index);
  }

  Future<void> _handleLogout() async {
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Escritorio: sidebar + contenido
        if (constraints.maxWidth > 800) {
          return _buildDesktopLayout();
        }
        // Móvil: bottom nav + contenido
        return _buildMobileLayout();
      },
    );
  }

  // ==================== ESCRITORIO ====================
  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 220,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Color(0xFFE2E8F2))),
            ),
            child: Column(
              children: [
                // Logo
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE2E8F2)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D6FEB),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.grid_view_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Business Flow',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'v1.0 · Beta',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Sección "Principal"
                const _SidebarSection(title: 'Principal'),
                // Items de navegación
                ..._navItems
                    .asMap()
                    .entries
                    .where((entry) => entry.key < _navItems.length - 1)
                    .map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      return _SidebarItem(
                        icon: item.icon,
                        label: item.label,
                        selected: _currentIndex == i,
                        onTap: () => _onItemTapped(i),
                      );
                    }),

                const Spacer(),

                // Usuario
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F2))),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _onItemTapped(_navItems.length - 1),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFF1D6FEB),
                            child: Text(
                              _getInitials(widget.profile['full_name'] ?? ''),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.profile['full_name'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  widget.profile['role'] == 'admin'
                                      ? 'Administrador'
                                      : 'Empleado',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: Color(0xFF64748B),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Contenido principal
          Expanded(
            child: Column(
              children: [
                // Top bar
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE2E8F2)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _navItems[_currentIndex].label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Pantalla activa
                Expanded(
                  child: Container(
                    color: const Color(0xFFF4F6FA),
                    child: _screens[_currentIndex],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== MÓVIL ====================
  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: AppBar(
        title: Text(_navItems[_currentIndex].label),
        backgroundColor: const Color(0xFF1D6FEB),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _handleLogout),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onItemTapped,
        indicatorColor: const Color(0xFF1D6FEB).withValues(alpha: 0.1),
        destinations: _navItems
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                label: item.label,
              ),
            )
            .toList(),
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

// ==================== WIDGETS AUXILIARES ====================

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _SidebarSection extends StatelessWidget {
  final String title;
  const _SidebarSection({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Color(0xFF64748B),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: selected ? const Color(0xFFEEF5FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected
                      ? const Color(0xFF1D6FEB)
                      : const Color(0xFF64748B),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                    color: selected
                        ? const Color(0xFF1D6FEB)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
