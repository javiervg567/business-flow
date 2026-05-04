import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:core/core.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'bookings_screen.dart';
import 'inventory_screen.dart';
import 'invoices_screen.dart';
import 'services_screen.dart';
import 'employees_screen.dart';
import 'reviews_screen.dart';
import 'profile_screen.dart';
import 'logo_mark.dart';

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

  bool get _isAdmin => widget.profile['role'] == 'admin';

  @override
  void initState() {
    super.initState();

    if (_isAdmin) {
      _navItems = const [
        _NavItem(icon: Icons.grid_view_rounded, label: 'Dashboard'),
        _NavItem(icon: Icons.calendar_month, label: 'Reservas'),
        _NavItem(icon: Icons.inventory_2, label: 'Inventario'),
        _NavItem(icon: Icons.design_services_outlined, label: 'Servicios'),
        _NavItem(icon: Icons.receipt_long, label: 'Facturas'),
        _NavItem(icon: Icons.badge_outlined, label: 'Empleados'),
        _NavItem(icon: Icons.star_outline_rounded, label: 'Reseñas'),
        _NavItem(icon: Icons.person_outline, label: 'Perfil'),
      ];
      _screens = [
        DashboardScreen(profile: widget.profile),
        BookingsScreen(profile: widget.profile),
        const InventoryScreen(),
        ServicesScreen(profile: widget.profile),
        InvoicesScreen(profile: widget.profile),
        EmployeesScreen(profile: widget.profile),
        ReviewsScreen(profile: widget.profile),
        ProfileScreen(profile: widget.profile),
      ];
    } else {
      _navItems = const [
        _NavItem(icon: Icons.grid_view_rounded, label: 'Dashboard'),
        _NavItem(icon: Icons.calendar_month, label: 'Reservas'),
        _NavItem(icon: Icons.inventory_2, label: 'Inventario'),
        _NavItem(icon: Icons.person_outline, label: 'Perfil'),
      ];
      _screens = [
        DashboardScreen(profile: widget.profile),
        BookingsScreen(profile: widget.profile),
        const InventoryScreen(),
        ProfileScreen(profile: widget.profile),
      ];
    }
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
        if (constraints.maxWidth > 800) return _buildDesktopLayout();
        return _buildMobileLayout();
      },
    );
  }

  // ==================== ESCRITORIO ====================
  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 220,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Color(0xFFE2E8F2))),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 15,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE2E8F2)),
                    ),
                  ),
                  child: Row(
                    children: [
                      const BarsLogoMark(size: 34, borderRadius: 9),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Business Flow',
                            style: GoogleFonts.dmSerifDisplay(
                              fontSize: 15,
                              color: const Color(0xFF0D1B2E),
                            ),
                          ),
                          Text(
                            'v1.0 · Beta',
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (!_isAdmin)
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
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
                          Icons.badge_outlined,
                          size: 14,
                          color: Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Modo empleado',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: const Color(0xFF16A34A),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                const _SidebarSection(title: 'Principal'),

                ..._navItems
                    .asMap()
                    .entries
                    .where((e) => e.key < _navItems.length - 1)
                    .map(
                      (e) => _SidebarItem(
                        icon: e.value.icon,
                        label: e.value.label,
                        selected: _currentIndex == e.key,
                        onTap: () => _onItemTapped(e.key),
                      ),
                    ),

                const Spacer(),

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
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D1B2E),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Center(
                              child: Text(
                                _getInitials(widget.profile['full_name'] ?? ''),
                                style: GoogleFonts.dmSerifDisplay(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
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
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF0D1B2E),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _isAdmin ? 'Administrador' : 'Empleado',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Column(
              children: [
                Container(
                  height: 54,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE2E8F2)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D6FEB),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _navItems[_currentIndex].label.toUpperCase(),
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF374151),
                          letterSpacing: 0.9,
                        ),
                      ),
                    ],
                  ),
                ),
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

  static const _adminPrimaryIndices = [0, 1, 4, 7];
  static const _adminMoreIndices = [2, 3, 5, 6];

  int get _mobileNavSelectedIndex {
    final pos = _adminPrimaryIndices.indexOf(_currentIndex);
    return pos >= 0 ? pos : 4;
  }

  Widget _buildMobileLayout() {
    final title = _navItems[_currentIndex].label;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: GoogleFonts.dmSerifDisplay(fontSize: 20, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0D1B2E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: _isAdmin
          ? _buildAdminMobileNav()
          : NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: _onItemTapped,
              backgroundColor: Colors.white,
              indicatorColor: const Color(0xFF1D6FEB).withValues(alpha: 0.12),
              surfaceTintColor: Colors.transparent,
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

  Widget _buildAdminMobileNav() {
    return NavigationBar(
      selectedIndex: _mobileNavSelectedIndex,
      onDestinationSelected: (i) {
        if (i == 4) {
          _showMoreSheet();
        } else {
          _onItemTapped(_adminPrimaryIndices[i]);
        }
      },
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFF1D6FEB).withValues(alpha: 0.12),
      surfaceTintColor: Colors.transparent,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.grid_view_rounded),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_month),
          label: 'Reservas',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long),
          label: 'Facturas',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Perfil',
        ),
        NavigationDestination(
          icon: Icon(Icons.more_horiz_rounded),
          label: 'Más',
        ),
      ],
    );
  }

  void _showMoreSheet() {
    final moreItems = _adminMoreIndices.map((i) => _navItems[i]).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MoreSheet(
        items: moreItems,
        screenIndices: _adminMoreIndices,
        currentIndex: _currentIndex,
        onTap: (screenIndex) {
          Navigator.pop(context);
          _onItemTapped(screenIndex);
        },
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }
}

// ==================== WIDGETS AUXILIARES ====================

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _MoreSheet extends StatelessWidget {
  final List<_NavItem> items;
  final List<int> screenIndices;
  final int currentIndex;
  final void Function(int screenIndex) onTap;

  const _MoreSheet({
    required this.items,
    required this.screenIndices,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1B2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Más opciones',
            style: GoogleFonts.dmSerifDisplay(
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.2,
            children: List.generate(items.length, (i) {
              final selected = screenIndices[i] == currentIndex;
              return GestureDetector(
                onTap: () => onTap(screenIndices[i]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF1D6FEB)
                        : Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF1D6FEB)
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(items[i].icon, size: 20, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        items[i].label,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _SidebarSection extends StatelessWidget {
  final String title;
  const _SidebarSection({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.dmSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF94A3B8),
          letterSpacing: 1.0,
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
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
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
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected
                          ? const Color(0xFF1D6FEB)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1D6FEB),
                      shape: BoxShape.circle,
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
