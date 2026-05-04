import 'package:flutter/material.dart';
import 'package:core/core.dart';

class ProductFormDialog extends StatefulWidget {
  final Map<String, dynamic>? product;

  const ProductFormDialog({super.key, this.product});

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _skuCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _purchasePriceCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _minStockCtrl;
  late bool _forSale;
  bool _saving = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p?['name'] as String? ?? '');
    _skuCtrl = TextEditingController(text: p?['sku'] as String? ?? '');
    _categoryCtrl = TextEditingController(
      text: p?['category'] as String? ?? '',
    );
    _priceCtrl = TextEditingController(
      text: p != null ? (p['price'] as num?)?.toStringAsFixed(2) ?? '0.00' : '',
    );
    _purchasePriceCtrl = TextEditingController(
      text: p != null
          ? (p['purchase_price'] as num?)?.toStringAsFixed(2) ?? '0.00'
          : '',
    );
    _stockCtrl = TextEditingController(
      text: p != null ? '${p['stock'] ?? 0}' : '',
    );
    _minStockCtrl = TextEditingController(
      text: p != null ? '${p['min_stock'] ?? 0}' : '',
    );
    _forSale = p?['for_sale'] as bool? ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _categoryCtrl.dispose();
    _priceCtrl.dispose();
    _purchasePriceCtrl.dispose();
    _stockCtrl.dispose();
    _minStockCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final profile = await AuthService.getCurrentProfile();
      final data = {
        'business_id': profile?['business_id'],
        'name': _nameCtrl.text.trim(),
        'sku': _skuCtrl.text.trim().toUpperCase(),
        'category': _categoryCtrl.text.trim().toLowerCase(),
        'price': double.tryParse(_priceCtrl.text) ?? 0.0,
        'purchase_price': double.tryParse(_purchasePriceCtrl.text) ?? 0.0,
        'stock': int.tryParse(_stockCtrl.text) ?? 0,
        'min_stock': int.tryParse(_minStockCtrl.text) ?? 0,
        'for_sale': _forSale,
      };

      if (_isEditing) {
        await SupabaseService.client
            .from('products')
            .update(data)
            .eq('id', widget.product!['id']);
      } else {
        await SupabaseService.client.from('products').insert(data);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.inventory_2_outlined,
                        color: Color(0xFF1D6FEB),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _isEditing ? 'Editar producto' : 'Nuevo producto',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _field(
                    'Nombre *',
                    _nameCtrl,
                    'Ej: Tinte rubio ceniza',
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Obligatorio' : null,
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(child: _field('SKU', _skuCtrl, 'Ej: TIN-0042')),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field('Categoría', _categoryCtrl, 'Ej: tintes'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          'Precio venta (€)',
                          _priceCtrl,
                          '0.00',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          'Precio compra (€)',
                          _purchasePriceCtrl,
                          '0.00',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  _buildMarginIndicator(),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          _isEditing ? 'Stock' : 'Stock inicial',
                          _stockCtrl,
                          '0',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          'Stock mínimo',
                          _minStockCtrl,
                          '0',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F2)),
                    ),
                    child: SwitchListTile(
                      value: _forSale,
                      onChanged: (v) => setState(() => _forSale = v),
                      title: const Text(
                        'Disponible para venta al cliente',
                        style: TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        _forSale
                            ? 'El cliente puede comprar este producto'
                            : 'Solo uso interno del negocio',
                        style: TextStyle(
                          fontSize: 11,
                          color: _forSale
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF64748B),
                        ),
                      ),
                      activeThumbColor: const Color(0xFF1D6FEB),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D6FEB),
                          foregroundColor: Colors.white,
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
                                _isEditing
                                    ? 'Guardar cambios'
                                    : 'Crear producto',
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarginIndicator() {
    final salePrice = double.tryParse(_priceCtrl.text) ?? 0.0;
    final purchasePrice = double.tryParse(_purchasePriceCtrl.text) ?? 0.0;

    if (salePrice <= 0 || purchasePrice <= 0) return const SizedBox.shrink();

    final margin = ((salePrice - purchasePrice) / salePrice * 100);
    final isPositive = margin > 0;
    final color = isPositive
        ? const Color(0xFF16A34A)
        : const Color(0xFFDC2626);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isPositive ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isPositive ? Icons.trending_up : Icons.trending_down,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            'Margen: ${margin.toStringAsFixed(1)}%  '
            '(${(salePrice - purchasePrice).toStringAsFixed(2)} € por unidad)',
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    String hint, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
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
    );
  }
}
