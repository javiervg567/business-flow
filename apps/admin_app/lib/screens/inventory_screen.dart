import 'package:flutter/material.dart';
import 'package:core/core.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filtered = [];
  String _search = '';
  String _categoryFilter = 'Todas';
  String _statusFilter = 'Todos';
  List<String> _categories = ['Todas'];

  static const _displayNames = {
    'tintes': 'Tintes',
    'champus': 'Champús',
    'tratamientos': 'Tratamientos',
    'unas': 'Uñas',
    'Todas': 'Todas',
  };

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
    final nameController = TextEditingController();
    final skuController = TextEditingController();
    final categoryController = TextEditingController();
    final priceController = TextEditingController();
    final stockController = TextEditingController();
    final minStockController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Nuevo producto',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dialogField(
                  'Nombre del producto *',
                  nameController,
                  'Ej: Tinte rubio ceniza',
                ),
                const SizedBox(height: 12),
                _dialogField('SKU', skuController, 'Ej: TIN-0042'),
                const SizedBox(height: 12),
                _dialogField(
                  'Categoría',
                  categoryController,
                  'Ej: tintes, champus, unas...',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Precio (€)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: priceController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration('0.00'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Stock inicial',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: stockController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration('0'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Stock mínimo',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: minStockController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration('0'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
              final name = nameController.text.trim();
              if (name.isEmpty) return;

              try {
                final profile = await AuthService.getCurrentProfile();
                await SupabaseService.client.from('products').insert({
                  'business_id': profile?['business_id'],
                  'name': name,
                  'sku': skuController.text.trim().toUpperCase(),
                  'category': categoryController.text.trim().toLowerCase(),
                  'price': double.tryParse(priceController.text) ?? 0.0,
                  'stock': int.tryParse(stockController.text) ?? 0,
                  'min_stock': int.tryParse(minStockController.text) ?? 0,
                });

                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                _loadProducts();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Producto "$name" creado correctamente'),
                    backgroundColor: const Color(0xFF16A34A),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error al crear el producto'),
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
            child: const Text('Crear producto'),
          ),
        ],
      ),
    );

    nameController.dispose();
    skuController.dispose();
    categoryController.dispose();
    priceController.dispose();
    stockController.dispose();
    minStockController.dispose();
  }

  Widget _dialogField(
    String label,
    TextEditingController controller,
    String hint,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 6),
        TextField(controller: controller, decoration: _inputDecoration(hint)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final criticalCount = _products
        .where((p) => (p['stock'] as int) < (p['min_stock'] as int))
        .length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Alerta crítica
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
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
            ),

          // Barra de filtros
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Buscador
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

              // Filtro categoría
              _FilterDropdown(
                value: _categoryFilter,
                items: _categories,
                displayNames: _displayNames,
                onChanged: (v) {
                  _categoryFilter = v;
                  _applyFilters();
                },
              ),

              // Filtros de estado
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

              // Botones
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
            ],
          ),
          const SizedBox(height: 16),

          // Tabla / Lista
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
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 600) {
                          return _buildTable();
                        }
                        return _buildList();
                      },
                    ),
            ),
          ),

          // Footer
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Mostrando ${_filtered.length} de ${_products.length} productos',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
        ],
      ),
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
          5: FlexColumnWidth(1),
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
              _TableHeader(''),
            ],
          ),
          ..._filtered.map((p) => _buildTableRow(p)),
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
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: TextButton(
            onPressed: () => _showAddStockDialog(product),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF1D6FEB),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: const Text('Editar', style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _buildList() {
    return ListView.separated(
      itemCount: _filtered.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
      itemBuilder: (ctx, i) {
        final p = _filtered[i];
        final stock = p['stock'] as int? ?? 0;
        final minStock = p['min_stock'] as int? ?? 0;
        final stockStatus = _getStockStatus(stock, minStock);

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
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Color(0xFF1D6FEB),
                ),
                onPressed: () => _showAddStockDialog(p),
              ),
            ],
          ),
        );
      },
    );
  }

  (String, Color) _getStockStatus(int stock, int minStock) {
    if (stock < minStock) {
      return ('Crítico', const Color(0xFFDC2626));
    } else if (stock < minStock * 1.5) {
      return ('Bajo', const Color(0xFFD97706));
    }
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
                  child: Text(displayNames[cat] ?? cat),
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
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF64748B),
          letterSpacing: 0.5,
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
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: style.$2,
        ),
      ),
    );
  }
}
