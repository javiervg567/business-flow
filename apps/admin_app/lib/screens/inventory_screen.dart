import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:core/core.dart';
import 'product_form_dialog.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:mobile_scanner/mobile_scanner.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  bool _loading = true;
  bool _isEmployee = false;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filtered = [];
  String _search = '';
  String _categoryFilter = 'Todas';
  String _statusFilter = 'Todos';
  List<String> _categories = ['Todas'];

  static const int _pageSize = 10;
  int _currentPage = 0;

  static const _displayNames = {
    'tintes': 'Tintes',
    'champus': 'Champús',
    'tratamientos': 'Tratamientos',
    'unas': 'Uñas',
    'Todas': 'Todas',
  };

  bool _isMobile() {
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    try {
      final profile = await AuthService.getCurrentProfile();
      final businessId = profile?['business_id'];
      final role = profile?['role'] as String? ?? '';

      setState(() => _isEmployee = role == 'employee');

      final res = await SupabaseService.client
          .from('products')
          .select()
          .eq('business_id', businessId)
          .order('name');

      final products = (res as List).cast<Map<String, dynamic>>();
      final cats =
          products
              .map((p) => p['category'] as String? ?? 'Sin categoría')
              .toSet()
              .toList()
            ..sort();

      setState(() {
        _products = products;
        _categories = ['Todas', ...cats];
        _loading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _currentPage = 0;
      _filtered = _products.where((p) {
        final name = (p['name'] as String? ?? '').toLowerCase();
        final sku = (p['sku'] as String? ?? '').toLowerCase();
        final cat = p['category'] as String? ?? '';
        final stock = p['stock'] as int? ?? 0;
        final minStock = p['min_stock'] as int? ?? 0;

        final matchSearch =
            _search.isEmpty ||
            name.contains(_search.toLowerCase()) ||
            sku.contains(_search.toLowerCase());
        final matchCat = _categoryFilter == 'Todas' || cat == _categoryFilter;
        final matchStatus = switch (_statusFilter) {
          'Crítico' => stock < minStock,
          'Bajo' => stock >= minStock && stock < minStock * 1.5,
          'OK' => stock >= minStock * 1.5,
          _ => true,
        };
        return matchSearch && matchCat && matchStatus;
      }).toList();
    });
  }

  List<Map<String, dynamic>> get _paginated {
    final start = _currentPage * _pageSize;
    final end = (start + _pageSize).clamp(0, _filtered.length);
    return _filtered.sublist(start, end);
  }

  int get _totalPages => (_filtered.length / _pageSize).ceil();

  Future<void> _showNotifyAdminDialog(Map<String, dynamic> product) async {
    final msgCtrl = TextEditingController(
      text: 'He usado ${product['name']} y el stock ha bajado.',
    );
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(
              Icons.notifications_outlined,
              color: Color(0xFF1D6FEB),
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'Notificar al administrador',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mensaje',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: msgCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Describe el uso del producto...',
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(12),
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
                    borderSide: const BorderSide(
                      color: Color(0xFF1D6FEB),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final msg = msgCtrl.text.trim();
              if (msg.isEmpty) return;
              try {
                final profile = await AuthService.getCurrentProfile();
                await SupabaseService.client
                    .from('stock_notifications')
                    .insert({
                      'business_id': profile?['business_id'],
                      'employee_id': profile?['id'],
                      'message': msg,
                    });
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notificación enviada al administrador'),
                    backgroundColor: Color(0xFF16A34A),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error al enviar la notificación'),
                    backgroundColor: Color(0xFFDC2626),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D6FEB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    msgCtrl.dispose();
  }

  Future<void> _showAddStockDialog(Map<String, dynamic> product) async {
    final skuController = TextEditingController();
    final qtyController = TextEditingController();
    final reasonController = TextEditingController();
    bool searchDone = false;
    Map<String, dynamic>? foundProduct = product.isNotEmpty ? product : null;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text(
            'Añadir stock',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SKU del producto',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: skuController,
                        decoration: _inputDecoration(
                          foundProduct?['sku'] ?? 'Ej: TIN-0042',
                        ),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final sku = skuController.text.trim().toUpperCase();
                        if (sku.isEmpty) return;
                        try {
                          final profile = await AuthService.getCurrentProfile();
                          final res = await SupabaseService.client
                              .from('products')
                              .select()
                              .eq('business_id', profile?['business_id'])
                              .eq('sku', sku)
                              .single();
                          setDialogState(() {
                            foundProduct = res;
                            searchDone = true;
                          });
                        } catch (_) {
                          setDialogState(() {
                            foundProduct = null;
                            searchDone = true;
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D6FEB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Buscar'),
                    ),
                  ],
                ),
                if (searchDone) ...[
                  const SizedBox(height: 12),
                  if (foundProduct == null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Color(0xFFDC2626),
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Producto no encontrado',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: Color(0xFF16A34A),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              foundProduct!['name'],
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ),
                          Text(
                            'Stock actual: ${foundProduct!['stock']} uds',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                if (foundProduct != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Cantidad a añadir',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('Ej: 10'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Motivo (opcional)',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonController,
                    decoration: _inputDecoration('Ej: Reposición proveedor'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
            if (foundProduct != null)
              ElevatedButton(
                onPressed: () async {
                  final qty = int.tryParse(qtyController.text.trim());
                  if (qty == null || qty <= 0) return;
                  try {
                    final profile = await AuthService.getCurrentProfile();
                    final newStock = (foundProduct!['stock'] as int) + qty;
                    await SupabaseService.client
                        .from('products')
                        .update({'stock': newStock})
                        .eq('id', foundProduct!['id']);
                    await SupabaseService.client
                        .from('stock_movements')
                        .insert({
                          'product_id': foundProduct!['id'],
                          'type': 'in',
                          'quantity': qty,
                          'reason': reasonController.text.trim().isEmpty
                              ? 'Reposición manual'
                              : reasonController.text.trim(),
                          'created_by': profile?['id'],
                        });
                    if (!ctx.mounted) return;
                    Navigator.of(ctx).pop();
                    _loadProducts();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Stock actualizado: ${foundProduct!['name']} → $newStock uds',
                        ),
                        backgroundColor: const Color(0xFF16A34A),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Error al actualizar el stock'),
                        backgroundColor: Color(0xFFDC2626),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D6FEB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Confirmar'),
              ),
          ],
        ),
      ),
    );
    skuController.dispose();
    qtyController.dispose();
    reasonController.dispose();
  }

  Future<void> _showNewProductDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const ProductFormDialog(),
    );
    if (result == true) _loadProducts();
  }

  Future<void> _openScanner() async {
    final sku = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _ScannerScreen()),
    );
    if (sku == null || !mounted) return;
    try {
      final profile = await AuthService.getCurrentProfile();
      final res = await SupabaseService.client
          .from('products')
          .select()
          .eq('business_id', profile?['business_id'])
          .eq('sku', sku.toUpperCase())
          .single();
      if (!mounted) return;
      _showAddStockDialog(res);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Producto con SKU "$sku" no encontrado'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B2E),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1D6FEB).withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Padding(
                padding: EdgeInsets.all(13),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF1D6FEB),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Cargando inventario…',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      );
    }

    final criticalCount = _products
        .where((p) => (p['stock'] as int) < (p['min_stock'] as int))
        .length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (criticalCount > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFD97706),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$criticalCount productos con stock crítico.',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: const Color(0xFF92400E),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                height: 38,
                child: TextField(
                  onChanged: (v) {
                    _search = v;
                    _applyFilters();
                  },
                  decoration: InputDecoration(
                    hintText: 'Buscar producto o SKU...',
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.zero,
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
                      borderSide: const BorderSide(
                        color: Color(0xFF1D6FEB),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              _FilterDropdown(
                value: _categoryFilter,
                items: _categories,
                displayNames: _displayNames,
                onChanged: (v) {
                  _categoryFilter = v;
                  _applyFilters();
                },
              ),
              ...[
                ('Todos', null),
                ('Crítico', const Color(0xFFDC2626)),
                ('Bajo', const Color(0xFFD97706)),
                ('OK', const Color(0xFF16A34A)),
              ].map((filter) {
                final selected = _statusFilter == filter.$1;
                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    setState(() => _statusFilter = filter.$1);
                    _applyFilters();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF1D6FEB) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF1D6FEB)
                            : const Color(0xFFE2E8F2),
                      ),
                    ),
                    child: Text(
                      filter.$1,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: selected
                            ? Colors.white
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                );
              }),
              // Botones solo para admin
              if (!_isEmployee) ...[
                OutlinedButton.icon(
                  onPressed: _showNewProductDialog,
                  icon: const Icon(Icons.add_box_outlined, size: 18),
                  label: const Text('Nuevo producto'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1D6FEB),
                    side: const BorderSide(color: Color(0xFF1D6FEB)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddStockDialog({}),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Añadir stock'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D6FEB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                if (!kIsWeb && _isMobile())
                  ElevatedButton.icon(
                    onPressed: _openScanner,
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: const Text('Escanear'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F2)),
              ),
              child: _filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay productos que coincidan',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) =>
                          constraints.maxWidth > 600
                          ? _buildTable()
                          : _buildList(),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    if (_totalPages <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Mostrando ${_currentPage * _pageSize + 1}–${((_currentPage + 1) * _pageSize).clamp(0, _filtered.length)} de ${_filtered.length} productos',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        Row(
          children: [
            IconButton(
              onPressed: _currentPage > 0
                  ? () => setState(() => _currentPage = 0)
                  : null,
              icon: const Icon(Icons.first_page),
              color: const Color(0xFF1D6FEB),
              disabledColor: const Color(0xFFCBD5E1),
            ),
            IconButton(
              onPressed: _currentPage > 0
                  ? () => setState(() => _currentPage--)
                  : null,
              icon: const Icon(Icons.chevron_left),
              color: const Color(0xFF1D6FEB),
              disabledColor: const Color(0xFFCBD5E1),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1D6FEB),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${_currentPage + 1} / $_totalPages',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              onPressed: _currentPage < _totalPages - 1
                  ? () => setState(() => _currentPage++)
                  : null,
              icon: const Icon(Icons.chevron_right),
              color: const Color(0xFF1D6FEB),
              disabledColor: const Color(0xFFCBD5E1),
            ),
            IconButton(
              onPressed: _currentPage < _totalPages - 1
                  ? () => setState(() => _currentPage = _totalPages - 1)
                  : null,
              icon: const Icon(Icons.last_page),
              color: const Color(0xFF1D6FEB),
              disabledColor: const Color(0xFFCBD5E1),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTable() {
    return SingleChildScrollView(
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(3),
          1: FlexColumnWidth(1.5),
          2: FlexColumnWidth(1),
          3: FlexColumnWidth(2),
          4: FlexColumnWidth(1.5),
          5: FlexColumnWidth(0.8),
          6: FlexColumnWidth(1),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F2))),
            ),
            children: [
              _TableHeader('Producto', paddingLeft: 16),
              _TableHeader('Categoría'),
              _TableHeader('Precio'),
              _TableHeader('Stock'),
              _TableHeader('Estado'),
              _TableHeader('Venta'),
              _TableHeader(''),
            ],
          ),
          ..._paginated.map((p) => _buildTableRow(p)),
        ],
      ),
    );
  }

  TableRow _buildTableRow(Map<String, dynamic> product) {
    final stock = product['stock'] as int? ?? 0;
    final minStock = product['min_stock'] as int? ?? 0;
    final stockStatus = _getStockStatus(stock, minStock);
    final barWidth = minStock > 0
        ? (stock / (minStock * 2)).clamp(0.0, 1.0)
        : 1.0;
    final forSale = product['for_sale'] as bool? ?? true;

    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product['name'] ?? '',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'SKU: ${product['sku'] ?? 'N/A'}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: _CategoryBadge(
            category: product['category'] ?? '',
            displayNames: _displayNames,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            '${(product['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}€',
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$stock uds',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: stockStatus.$2,
                ),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: barWidth,
                  backgroundColor: const Color(0xFFE2E8F2),
                  valueColor: AlwaysStoppedAnimation<Color>(stockStatus.$2),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'mín. $minStock uds',
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: _StockBadge(status: stockStatus.$1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Icon(
            forSale ? Icons.check_circle_outline : Icons.block_outlined,
            size: 18,
            color: forSale ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: _isEmployee
              ? TextButton(
                  onPressed: () => _showNotifyAdminDialog(product),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFD97706),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                  ),
                  child: const Text('Avisar', style: TextStyle(fontSize: 12)),
                )
              : TextButton(
                  onPressed: () async {
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (_) => ProductFormDialog(product: product),
                    );
                    if (result == true) _loadProducts();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1D6FEB),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                  child: const Text('Editar', style: TextStyle(fontSize: 12)),
                ),
        ),
      ],
    );
  }

  Widget _buildList() {
    return ListView.separated(
      itemCount: _paginated.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
      itemBuilder: (ctx, i) {
        final p = _paginated[i];
        final stock = p['stock'] as int? ?? 0;
        final minStock = p['min_stock'] as int? ?? 0;
        final stockStatus = _getStockStatus(stock, minStock);
        final forSale = p['for_sale'] as bool? ?? true;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          title: Text(
            p['name'] ?? '',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SKU: ${p['sku'] ?? 'N/A'}',
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 4),
              Text(
                '$stock uds · mín. $minStock',
                style: TextStyle(fontSize: 12, color: stockStatus.$2),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StockBadge(status: stockStatus.$1),
              const SizedBox(width: 4),
              Icon(
                forSale ? Icons.check_circle_outline : Icons.block_outlined,
                size: 16,
                color: forSale
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 4),
              _isEmployee
                  ? IconButton(
                      icon: const Icon(
                        Icons.notifications_outlined,
                        color: Color(0xFFD97706),
                        size: 18,
                      ),
                      onPressed: () => _showNotifyAdminDialog(p),
                    )
                  : IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: Color(0xFF1D6FEB),
                        size: 18,
                      ),
                      onPressed: () async {
                        final result = await showDialog<bool>(
                          context: context,
                          builder: (_) => ProductFormDialog(product: p),
                        );
                        if (result == true) _loadProducts();
                      },
                    ),
            ],
          ),
        );
      },
    );
  }

  (String, Color) _getStockStatus(int stock, int minStock) {
    if (stock < minStock) return ('Crítico', const Color(0xFFDC2626));
    if (stock < minStock * 1.5) return ('Bajo', const Color(0xFFD97706));
    return ('OK', const Color(0xFF16A34A));
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
        borderSide: const BorderSide(color: Color(0xFF1D6FEB), width: 1.5),
      ),
    );
  }
}

// ==================== SCANNER ====================

class _ScannerScreen extends StatefulWidget {
  const _ScannerScreen();
  @override
  State<_ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<_ScannerScreen> {
  bool _scanned = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear producto'),
        backgroundColor: const Color(0xFF1D6FEB),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_scanned) return;
              final barcode = capture.barcodes.firstOrNull;
              final value = barcode?.rawValue;
              if (value != null && value.isNotEmpty) {
                _scanned = true;
                Navigator.pop(context, value);
              }
            },
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF1D6FEB), width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Apunta al código de barras o QR del producto',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== WIDGETS AUXILIARES ====================

class _FilterDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final Map<String, String> displayNames;
  final ValueChanged<String> onChanged;

  const _FilterDropdown({
    required this.value,
    required this.items,
    required this.displayNames,
    required this.onChanged,
  });

  static const _displayNames = {
    'tintes': 'Tintes',
    'champus': 'Champús',
    'tratamientos': 'Tratamientos',
    'unas': 'Uñas',
    'Todas': 'Todas',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
          items: items
              .map(
                (cat) => DropdownMenuItem(
                  value: cat,
                  child: Text(_displayNames[cat] ?? cat),
                ),
              )
              .toList(),
          onChanged: (v) => onChanged(v!),
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String label;
  final double paddingLeft;
  const _TableHeader(this.label, {this.paddingLeft = 0});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(paddingLeft, 10, 0, 10),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF374151),
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String category;
  final Map<String, String> displayNames;
  const _CategoryBadge({required this.category, required this.displayNames});

  @override
  Widget build(BuildContext context) {
    final colors = {
      'tintes': (const Color(0xFFEEF5FF), const Color(0xFF1D6FEB)),
      'champus': (const Color(0xFFF5F3FF), const Color(0xFF7C3AED)),
      'tratamientos': (const Color(0xFFF0FDF4), const Color(0xFF16A34A)),
      'unas': (const Color(0xFFFFF0F3), const Color(0xFFE11D48)),
    };
    final colorPair =
        colors[category.toLowerCase()] ??
        (const Color(0xFFF1F5F9), const Color(0xFF64748B));
    final displayName = displayNames[category.toLowerCase()] ?? category;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorPair.$1,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        displayName,
        style: TextStyle(fontSize: 11, color: colorPair.$2),
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  final String status;
  const _StockBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final styles = {
      'Crítico': (const Color(0xFFFEF2F2), const Color(0xFFDC2626)),
      'Bajo': (const Color(0xFFFFFBEB), const Color(0xFFD97706)),
      'OK': (const Color(0xFFF0FDF4), const Color(0xFF16A34A)),
    };
    final style =
        styles[status] ?? (const Color(0xFFF1F5F9), const Color(0xFF64748B));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: style.$1,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: style.$2,
        ),
      ),
    );
  }
}
