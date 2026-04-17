import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'sale_invoice_dialogs.dart';

// ── CREAR FACTURA DE COMPRA ───────────────────────────────

class CreatePurchaseInvoiceDialog extends StatefulWidget {
  final InvoiceService invoiceService;
  const CreatePurchaseInvoiceDialog({super.key, required this.invoiceService});

  @override
  State<CreatePurchaseInvoiceDialog> createState() =>
      _CreatePurchaseInvoiceDialogState();
}

class _CreatePurchaseInvoiceDialogState
    extends State<CreatePurchaseInvoiceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _numberCtrl = TextEditingController();
  final _supplierCtrl = TextEditingController();
  final _taxCtrl = TextEditingController(text: '21');

  bool _saving = false;
  final List<InvoiceLineItem> _lines = [InvoiceLineItem()];

  @override
  void dispose() {
    _numberCtrl.dispose();
    _supplierCtrl.dispose();
    _taxCtrl.dispose();
    super.dispose();
  }

  double get _subtotal =>
      _lines.fold(0, (sum, l) => sum + l.quantity * l.unitPrice);
  double get _taxRate => double.tryParse(_taxCtrl.text) ?? 0;
  double get _taxAmount => _subtotal * (_taxRate / 100);
  double get _total => _subtotal + _taxAmount;

  void _addLine() => setState(() => _lines.add(InvoiceLineItem()));
  void _removeLine(int i) {
    if (_lines.length > 1) setState(() => _lines.removeAt(i));
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lines.any((l) => l.description.isEmpty)) {
      _showError('Rellena la descripción de todas las líneas');
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.invoiceService.createPurchaseInvoice(
        supplierName: _supplierCtrl.text.trim(),
        number: _numberCtrl.text.trim(),
        lines: _lines
            .map(
              (l) => {
                'description': l.description,
                'quantity': l.quantity,
                'unit_price': l.unitPrice,
                'product_id': null,
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
                Row(
                  children: [
                    Expanded(child: _buildSupplierField()),
                    const SizedBox(width: 12),
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
                TextButton.icon(
                  onPressed: _addLine,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Añadir línea'),
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

  Widget _buildSupplierField() {
    return TextFormField(
      controller: _supplierCtrl,
      decoration: invoiceInputDeco('Proveedor', Icons.store_outlined),
      validator: (v) => v == null || v.isEmpty ? 'Obligatorio' : null,
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
            backgroundColor: const Color(0xFF16A34A),
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
    final data = await SupabaseService.client
        .from('purchase_invoice_lines')
        .select()
        .eq('purchase_invoice_id', widget.invoice['id'])
        .order('created_at');
    setState(() {
      _lines = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
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
              const Center(child: CircularProgressIndicator())
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
