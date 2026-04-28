import 'package:flutter/material.dart';
import 'package:core/core.dart';

// ── CREAR FACTURA DE VENTA ────────────────────────────────

class CreateSaleInvoiceDialog extends StatefulWidget {
  final InvoiceService invoiceService;
  const CreateSaleInvoiceDialog({super.key, required this.invoiceService});

  @override
  State<CreateSaleInvoiceDialog> createState() =>
      _CreateSaleInvoiceDialogState();
}

class _CreateSaleInvoiceDialogState extends State<CreateSaleInvoiceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _numberCtrl = TextEditingController();
  final _taxCtrl = TextEditingController(text: '21');

  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _products = [];
  String? _selectedClientId;
  bool _loadingClients = true;
  bool _loadingProducts = true;
  bool _saving = false;

  final List<InvoiceLineItem> _lines = [];

  @override
  void initState() {
    super.initState();
    _loadClients();
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
      final profile = await AuthService.getCurrentProfile();
      final number = await widget.invoiceService.generateSaleInvoiceNumber(
        profile?['business_id'] as String,
      );
      if (!mounted) return;
      _numberCtrl.text = number;
    } catch (e) {}
  }

  Future<void> _loadClients() async {
    try {
      final data = await SupabaseService.client
          .from('profiles')
          .select('id, full_name, email')
          .eq('role', 'client')
          .order('full_name');
      if (!mounted) return;
      setState(() => _clients = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      _showError('Error cargando clientes: $e');
    } finally {
      if (mounted) setState(() => _loadingClients = false);
    }
  }

  Future<void> _loadProducts() async {
    try {
      final data = await SupabaseService.client
          .from('products')
          .select('id, name, price, stock, min_stock, for_sale')
          .eq('for_sale', true)
          .order('name');
      if (!mounted) return;
      setState(() => _products = List<Map<String, dynamic>>.from(data));
    } finally {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  double get _subtotal =>
      _lines.fold(0, (sum, l) => sum + l.quantity * l.unitPrice);
  double get _taxAmount => _subtotal * (_taxRate / 100);
  double get _total => _subtotal + _taxAmount;
  double get _taxRate => double.tryParse(_taxCtrl.text) ?? 0;

  void _addManualLine() => setState(() => _lines.add(InvoiceLineItem()));
  void _removeLine(int i) => setState(() => _lines.removeAt(i));

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showProductPicker() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Seleccionar producto',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: SizedBox(
          width: 360,
          height: 400,
          child: _loadingProducts
              ? const Center(child: CircularProgressIndicator())
              : _products.isEmpty
              ? const Center(
                  child: Text(
                    'No hay productos disponibles',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                )
              : ListView.separated(
                  itemCount: _products.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (_, i) {
                    final product = _products[i];
                    final price = (product['price'] as num?)?.toDouble() ?? 0.0;
                    final stock = (product['stock'] as num?)?.toInt() ?? 0;
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
                        'Stock: $stock uds',
                        style: TextStyle(fontSize: 12, color: statusColor),
                      ),
                      trailing: Text(
                        '${price.toStringAsFixed(2)} €',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1D6FEB),
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _lines.add(
                            InvoiceLineItem()
                              ..description = product['name'] as String? ?? ''
                              ..quantity = 1.0
                              ..unitPrice = price
                              ..productId = product['id'] as String?,
                          );
                        });
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClientId == null) {
      _showError('Selecciona un cliente');
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
      final paid = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(
            '¿La factura está pagada?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          content: const Text(
            'Indica si el cliente ha pagado en este momento o si queda pendiente.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Pendiente',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Pagada'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      await widget.invoiceService.createSaleInvoice(
        clientId: _selectedClientId!,
        number: _numberCtrl.text.trim(),
        lines: _lines
            .map(
              (l) => {
                'description': l.description,
                'quantity': l.quantity,
                'unit_price': l.unitPrice,
              },
            )
            .toList(),
        taxRate: _taxRate / 100,
        status: (paid == true) ? 'paid' : 'pending',
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
                _buildTitle(
                  'Nueva factura de venta',
                  Icons.receipt_long,
                  const Color(0xFF1D6FEB),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _buildNumberField()),
                    const SizedBox(width: 12),
                    SizedBox(width: 100, child: _buildTaxField()),
                  ],
                ),
                const SizedBox(height: 16),
                _buildClientDropdown(),
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
                      label: const Text('Añadir producto'),
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

  Widget _buildTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildNumberField() {
    return TextFormField(
      controller: _numberCtrl,
      decoration: invoiceInputDeco('Número de factura', Icons.tag),
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

  Widget _buildClientDropdown() {
    if (_loadingClients) {
      return const Center(child: CircularProgressIndicator());
    }
    return DropdownButtonFormField<String>(
      initialValue: _selectedClientId,
      decoration: invoiceInputDeco('Cliente', Icons.person_outline),
      items: _clients
          .map(
            (c) => DropdownMenuItem(
              value: c['id'] as String,
              child: Text(c['full_name'] ?? c['email'] ?? ''),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() => _selectedClientId = v),
      validator: (v) => v == null ? 'Selecciona un cliente' : null,
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

// ── DETALLE FACTURA DE VENTA ──────────────────────────────

class SaleInvoiceDetailSheet extends StatefulWidget {
  final Map<String, dynamic> invoice;
  final InvoiceService invoiceService;

  const SaleInvoiceDetailSheet({
    super.key,
    required this.invoice,
    required this.invoiceService,
  });

  @override
  State<SaleInvoiceDetailSheet> createState() => _SaleInvoiceDetailSheetState();
}

class _SaleInvoiceDetailSheetState extends State<SaleInvoiceDetailSheet> {
  List<Map<String, dynamic>> _lines = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await widget.invoiceService.fetchInvoiceLines(
        widget.invoice['id'],
      );
      if (!mounted) return;
      setState(() {
        _lines = data;
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
    final client = invoice['client'] as Map<String, dynamic>?;
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
              client?['full_name'] ?? '',
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

// ── WIDGETS COMPARTIDOS ───────────────────────────────────

class InvoiceLineItem {
  String description = '';
  double quantity = 1;
  double unitPrice = 0;
  String? productId;
}

class InvoiceLineRow extends StatelessWidget {
  final InvoiceLineItem item;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const InvoiceLineRow({
    super.key,
    required this.item,
    required this.index,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: TextFormField(
              initialValue: item.description,
              decoration: invoiceInputDeco('Descripción', Icons.label_outline),
              onChanged: (v) {
                item.description = v;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: TextFormField(
              initialValue: item.quantity.toString(),
              decoration: invoiceInputDeco('Cant.', null),
              keyboardType: TextInputType.number,
              onChanged: (v) {
                item.quantity = double.tryParse(v) ?? 1;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: TextFormField(
              initialValue: item.unitPrice.toString(),
              decoration: invoiceInputDeco('Precio €', null),
              keyboardType: TextInputType.number,
              onChanged: (v) {
                item.unitPrice = double.tryParse(v) ?? 0;
                onChanged();
              },
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(
              Icons.delete_outline,
              color: Color(0xFFDC2626),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class InvoiceDetailLineRow extends StatelessWidget {
  final Map<String, dynamic> line;
  const InvoiceDetailLineRow({super.key, required this.line});

  @override
  Widget build(BuildContext context) {
    final qty = (line['quantity'] as num).toDouble();
    final price = (line['unit_price'] as num).toDouble();
    final total = (line['total'] as num).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line['description'] ?? '',
                  style: const TextStyle(fontSize: 14),
                ),
                Text(
                  '${qty.toStringAsFixed(0)} x ${price.toStringAsFixed(2)} €',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${total.toStringAsFixed(2)} €',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class InvoiceTotalRow extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;

  const InvoiceTotalRow({
    super.key,
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: bold ? 15 : 13,
              color: bold ? Colors.black : const Color(0xFF64748B),
            ),
          ),
          Text(
            '${value.toStringAsFixed(2)} €',
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: bold ? 15 : 13,
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration invoiceInputDeco(String label, IconData? icon) {
  return InputDecoration(
    labelText: label,
    prefixIcon: icon != null ? Icon(icon, size: 18) : null,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}
