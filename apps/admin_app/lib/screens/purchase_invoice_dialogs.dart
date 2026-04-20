import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'sale_invoice_dialogs.dart';

// ── CREAR FACTURA DE COMPRA ───────────────────────────────

class CreatePurchaseInvoiceDialog extends StatefulWidget {
  final InvoiceService invoiceService;
  final Map<String, dynamic> profile;

  const CreatePurchaseInvoiceDialog({
    super.key,
    required this.invoiceService,
    required this.profile,
  });

  @override
  State<CreatePurchaseInvoiceDialog> createState() =>
      _CreatePurchaseInvoiceDialogState();
}

class _CreatePurchaseInvoiceDialogState
    extends State<CreatePurchaseInvoiceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _numberCtrl = TextEditingController();
  final _taxCtrl = TextEditingController(text: '21');

  bool _saving = false;
  bool _loadingSuppliers = true;
  bool _loadingProducts = true;
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _products = [];
  Map<String, dynamic>? _selectedSupplier;

  final List<InvoiceLineItem> _lines = [];

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
    _loadProducts();
    _loadNextNumber();
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _taxCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNextNumber() async {
    try {
      final number = await widget.invoiceService.generatePurchaseInvoiceNumber(
        widget.profile['business_id'] as String,
      );
      if (!mounted) return;
      _numberCtrl.text = number;
    } catch (e) {
      // Si falla dejamos el campo vacío
    }
  }

  Future<void> _loadSuppliers() async {
    try {
      final data = await SupabaseService.client
          .from('suppliers')
          .select('id, name, contact_name, phone')
          .eq('business_id', widget.profile['business_id'])
          .order('name');
      if (!mounted) return;
      setState(() => _suppliers = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      // Si falla, seguimos sin proveedores
    } finally {
      if (mounted) setState(() => _loadingSuppliers = false);
    }
  }

  Future<void> _loadProducts() async {
    try {
      final data = await SupabaseService.client
          .from('products')
          .select('id, name, price, purchase_price, stock, min_stock')
          .eq('business_id', widget.profile['business_id'])
          .order('name');
      if (!mounted) return;
      setState(() => _products = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      // Si falla, seguimos sin productos
    } finally {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  double get _subtotal =>
      _lines.fold(0, (sum, l) => sum + l.quantity * l.unitPrice);
  double get _taxRate => double.tryParse(_taxCtrl.text) ?? 0;
  double get _taxAmount => _subtotal * (_taxRate / 100);
  double get _total => _subtotal + _taxAmount;

  void _addManualLine() => setState(() => _lines.add(InvoiceLineItem()));
  void _removeLine(int i) {
    if (_lines.length > 1) setState(() => _lines.removeAt(i));
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showSupplierPicker() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Seleccionar proveedor',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: SizedBox(
          width: 360,
          height: 400,
          child: _loadingSuppliers
              ? const Center(child: CircularProgressIndicator())
              : _suppliers.isEmpty
              ? const Center(
                  child: Text(
                    'No hay proveedores registrados',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                )
              : ListView.separated(
                  itemCount: _suppliers.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (_, i) {
                    final supplier = _suppliers[i];
                    final contactName = supplier['contact_name'] as String?;
                    final phone = supplier['phone'] as String?;
                    return ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.store_outlined,
                          color: Color(0xFF16A34A),
                          size: 18,
                        ),
                      ),
                      title: Text(
                        supplier['name'] as String? ?? '',
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: contactName != null || phone != null
                          ? Text(
                              [?contactName, ?phone].join(' · '),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF94A3B8),
                              ),
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _selectedSupplier = supplier);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }

  void _showProductPicker() {
    String stockFilter = 'Todos';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final filtered = _products.where((p) {
            final stock = (p['stock'] as num?)?.toInt() ?? 0;
            final minStock = (p['min_stock'] as num?)?.toInt() ?? 0;
            return switch (stockFilter) {
              'Crítico' => stock < minStock,
              'Bajo' => stock >= minStock && stock < minStock * 1.5,
              _ => true,
            };
          }).toList();

          return AlertDialog(
            title: const Text(
              'Seleccionar producto',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            content: SizedBox(
              width: 360,
              height: 460,
              child: Column(
                children: [
                  Row(
                    children: ['Todos', 'Crítico', 'Bajo'].map((f) {
                      final selected = stockFilter == f;
                      final color = switch (f) {
                        'Crítico' => const Color(0xFFDC2626),
                        'Bajo' => const Color(0xFFD97706),
                        _ => const Color(0xFF1D6FEB),
                      };
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => setDlg(() => stockFilter = f),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: selected ? color : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected
                                    ? color
                                    : const Color(0xFFE2E8F2),
                              ),
                            ),
                            child: Text(
                              f,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: Color(0xFFE2E8F2)),
                  Expanded(
                    child: _loadingProducts
                        ? const Center(child: CircularProgressIndicator())
                        : filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'No hay productos',
                              style: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const Divider(
                              height: 1,
                              color: Color(0xFFF1F5F9),
                            ),
                            itemBuilder: (_, i) {
                              final product = filtered[i];
                              final salePrice =
                                  (product['price'] as num?)?.toDouble() ?? 0.0;
                              final purchasePrice =
                                  (product['purchase_price'] as num?)
                                      ?.toDouble() ??
                                  salePrice;
                              final stock =
                                  (product['stock'] as num?)?.toInt() ?? 0;
                              final minStock =
                                  (product['min_stock'] as num?)?.toInt() ?? 0;
                              final statusColor = stock < minStock
                                  ? const Color(0xFFDC2626)
                                  : stock < minStock * 1.5
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF16A34A);

                              return ListTile(
                                leading: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.inventory_2_outlined,
                                    color: Color(0xFF1D6FEB),
                                    size: 18,
                                  ),
                                ),
                                title: Text(
                                  product['name'] as String? ?? '',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                subtitle: Text(
                                  'Stock: $stock uds · mín. $minStock',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: statusColor,
                                  ),
                                ),
                                trailing: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Compra: ${purchasePrice.toStringAsFixed(2)} €',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF16A34A),
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      'Venta: ${salePrice.toStringAsFixed(2)} €',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  setState(() {
                                    _lines.add(
                                      InvoiceLineItem()
                                        ..description =
                                            product['name'] as String? ?? ''
                                        ..quantity = 1.0
                                        ..unitPrice = purchasePrice
                                        ..productId = product['id'] as String?,
                                    );
                                  });
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSupplier == null) {
      _showError('Selecciona un proveedor');
      return;
    }
    if (_lines.isEmpty) {
      _showError('Añade al menos una línea');
      return;
    }
    if (_lines.any((l) => l.description.isEmpty)) {
      _showError('Rellena la descripción de todas las líneas');
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.invoiceService.createPurchaseInvoice(
        businessId: widget.profile['business_id'] as String,
        supplierName: _selectedSupplier!['name'] as String,
        number: _numberCtrl.text.trim(),
        lines: _lines
            .map(
              (l) => {
                'description': l.description,
                'quantity': l.quantity,
                'unit_price': l.unitPrice,
                'product_id': l.productId,
              },
            )
            .toList(),
        taxRate: _taxRate / 100,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showError('Error guardando factura: $e');
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
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTitle(),
                const SizedBox(height: 20),
                _buildSupplierSelector(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildNumberField()),
                    const SizedBox(width: 12),
                    SizedBox(width: 90, child: _buildTaxField()),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Líneas',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                ..._lines.asMap().entries.map(
                  (e) => InvoiceLineRow(
                    item: e.value,
                    index: e.key,
                    onRemove: () => _removeLine(e.key),
                    onChanged: () => setState(() {}),
                  ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _showProductPicker,
                      icon: const Icon(Icons.inventory_2_outlined, size: 16),
                      label: const Text('Añadir del stock'),
                    ),
                    TextButton.icon(
                      onPressed: _addManualLine,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Añadir manual'),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _buildTotals(),
                const SizedBox(height: 20),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return const Row(
      children: [
        Icon(Icons.local_shipping_outlined, color: Color(0xFF16A34A), size: 22),
        SizedBox(width: 10),
        Text(
          'Nueva factura de compra',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildSupplierSelector() {
    return GestureDetector(
      onTap: _showSupplierPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: _selectedSupplier == null
                ? const Color(0xFFE2E8F2)
                : const Color(0xFF16A34A),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              Icons.store_outlined,
              size: 18,
              color: _selectedSupplier == null
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF16A34A),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _selectedSupplier?['name'] as String? ??
                    'Seleccionar proveedor',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _selectedSupplier == null
                      ? const Color(0xFF64748B)
                      : Colors.black,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberField() {
    return TextFormField(
      controller: _numberCtrl,
      decoration: invoiceInputDeco('Número', Icons.tag),
      validator: (v) => v == null || v.isEmpty ? 'Obligatorio' : null,
    );
  }

  Widget _buildTaxField() {
    return TextFormField(
      controller: _taxCtrl,
      decoration: invoiceInputDeco('IVA %', Icons.percent),
      keyboardType: TextInputType.number,
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildTotals() {
    return Column(
      children: [
        InvoiceTotalRow(label: 'Subtotal', value: _subtotal),
        InvoiceTotalRow(
          label: 'IVA (${_taxRate.toStringAsFixed(0)}%)',
          value: _taxAmount,
        ),
        const Divider(height: 8),
        InvoiceTotalRow(label: 'Total', value: _total, bold: true),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
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
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

// ── DETALLE FACTURA DE COMPRA ─────────────────────────────

class PurchaseInvoiceDetailSheet extends StatefulWidget {
  final Map<String, dynamic> invoice;
  final InvoiceService invoiceService;

  const PurchaseInvoiceDetailSheet({
    super.key,
    required this.invoice,
    required this.invoiceService,
  });

  @override
  State<PurchaseInvoiceDetailSheet> createState() =>
      _PurchaseInvoiceDetailSheetState();
}

class _PurchaseInvoiceDetailSheetState
    extends State<PurchaseInvoiceDetailSheet> {
  List<Map<String, dynamic>> _lines = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.client
          .from('purchase_invoice_lines')
          .select()
          .eq('purchase_invoice_id', widget.invoice['id'])
          .order('created_at');
      if (!mounted) return;
      setState(() {
        _lines = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoice = widget.invoice;
    final total = (invoice['total'] as num).toDouble();
    final subtotal = (invoice['subtotal'] as num).toDouble();
    final tax = (invoice['tax_amount'] as num).toDouble();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              invoice['number'] ?? '',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              invoice['supplier_name'] ?? '',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
            const SizedBox(height: 20),
            const Text(
              'Líneas',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_lines.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'Sin líneas',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView(
                  controller: ctrl,
                  children: [
                    ..._lines.map((l) => InvoiceDetailLineRow(line: l)),
                    const Divider(height: 24),
                    InvoiceTotalRow(label: 'Subtotal', value: subtotal),
                    InvoiceTotalRow(label: 'IVA', value: tax),
                    const Divider(height: 8),
                    InvoiceTotalRow(label: 'Total', value: total, bold: true),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
