import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'sale_invoice_dialogs.dart';

class FinalizeBookingDialog extends StatefulWidget {
  final Map<String, dynamic> booking;
  final Map<String, dynamic> profile;

  const FinalizeBookingDialog({
    super.key,
    required this.booking,
    required this.profile,
  });

  @override
  State<FinalizeBookingDialog> createState() => _FinalizeBookingDialogState();
}

class _FinalizeBookingDialogState extends State<FinalizeBookingDialog> {
  final _invoiceService = InvoiceService(SupabaseService.client);
  final _taxCtrl = TextEditingController(text: '21');
  bool _saving = false;
  bool _loadingProducts = true;
  List<Map<String, dynamic>> _products = [];

  late List<InvoiceLineItem> _lines;

  @override
  void initState() {
    super.initState();
    final service = widget.booking['service'] as Map<String, dynamic>?;
    final serviceName = service?['name'] as String? ?? 'Servicio';
    final servicePrice = (service?['price'] as num?)?.toDouble() ?? 0.0;

    _lines = [
      InvoiceLineItem()
        ..description = serviceName
        ..quantity = 1.0
        ..unitPrice = servicePrice,
    ];

    _loadProducts();
  }

  @override
  void dispose() {
    _taxCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final data = await SupabaseService.client
          .from('products')
          .select('id, name, price, stock, min_stock')
          .eq('business_id', widget.profile['business_id'])
          .order('name');
      if (!mounted) return;
      setState(() => _products = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      // Si falla, no mostramos productos
    } finally {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  double get _taxRate => double.tryParse(_taxCtrl.text) ?? 0;
  double get _subtotal =>
      _lines.fold(0, (sum, l) => sum + l.quantity * l.unitPrice);
  double get _taxAmount => _subtotal * (_taxRate / 100);
  double get _total => _subtotal + _taxAmount;

  void _removeLine(int i) {
    if (_lines.length > 1) setState(() => _lines.removeAt(i));
  }

  void _addManualLine() {
    setState(() => _lines.add(InvoiceLineItem()));
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
                    'No hay productos en stock',
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
                    return ListTile(
                      title: Text(
                        product['name'] as String? ?? '',
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        'Stock: $stock uds',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      trailing: Text(
                        '${price.toStringAsFixed(2)} €',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1D6FEB),
                        ),
                      ),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final stock = (product['stock'] as num?)?.toInt() ?? 0;
                        final minStock =
                            (product['min_stock'] as num?)?.toInt() ?? 0;

                        if (stock <= minStock) {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx2) => AlertDialog(
                              title: const Text(
                                'Stock bajo',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              content: Text(
                                'El producto "${product['name']}" tiene stock bajo '
                                '($stock uds, mínimo $minStock uds). '
                                '¿Seguro que quieres añadirlo?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx2, false),
                                  child: const Text(
                                    'Cancelar',
                                    style: TextStyle(color: Color(0xFF64748B)),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx2, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFD97706),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Añadir igualmente'),
                                ),
                              ],
                            ),
                          );
                          if (confirm != true) return;
                        }

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

  Future<String> _generateNumber() async {
    final count = await SupabaseService.client
        .from('invoices')
        .select('id')
        .eq('business_id', widget.profile['business_id']);
    final n = (count as List).length + 1;
    return 'F-${n.toString().padLeft(4, '0')}';
  }

  Future<void> _save() async {
    if (_lines.any((l) => l.description.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rellena la descripción de todas las líneas'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final number = await _generateNumber();
      await _invoiceService.finalizeBooking(
        bookingId: widget.booking['id'] as String,
        clientId: widget.booking['client_id'] as String,
        number: number,
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientName =
        widget.booking['client']?['full_name'] as String? ?? 'Cliente';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      color: Color(0xFF1D6FEB),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Finalizar y cobrar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          clientName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // IVA
              SizedBox(
                width: 100,
                child: TextFormField(
                  controller: _taxCtrl,
                  decoration: invoiceInputDeco('IVA %', Icons.percent),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 16),

              // Líneas
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

              // Botones de añadir
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

              // Totales
              InvoiceTotalRow(label: 'Subtotal', value: _subtotal),
              InvoiceTotalRow(
                label: 'IVA (${_taxRate.toStringAsFixed(0)}%)',
                value: _taxAmount,
              ),
              const Divider(height: 8),
              InvoiceTotalRow(label: 'Total', value: _total, bold: true),
              const SizedBox(height: 20),

              // Botones acción
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: const Text('Confirmar cobro'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
