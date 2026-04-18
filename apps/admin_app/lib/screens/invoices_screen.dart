import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'sale_invoice_dialogs.dart';
import 'purchase_invoice_dialogs.dart';
import 'suppliers_screen.dart';

class InvoicesScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const InvoicesScreen({super.key, required this.profile});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _invoiceService = InvoiceService(SupabaseService.client);
  final _suppliersKey = GlobalKey<SuppliersTabState>();

  List<Map<String, dynamic>> _saleInvoices = [];
  List<Map<String, dynamic>> _purchaseInvoices = [];
  bool _loadingSales = true;
  bool _loadingPurchases = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSales();
    _loadPurchases();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSales() async {
    setState(() => _loadingSales = true);
    try {
      final data = await _invoiceService.fetchSaleInvoices();
      setState(() => _saleInvoices = data);
    } catch (e) {
      _showError('Error cargando facturas de venta: $e');
    } finally {
      setState(() => _loadingSales = false);
    }
  }

  Future<void> _loadPurchases() async {
    setState(() => _loadingPurchases = true);
    try {
      final data = await _invoiceService.fetchPurchaseInvoices();
      setState(() => _purchaseInvoices = data);
    } catch (e) {
      _showError('Error cargando facturas de compra: $e');
    } finally {
      setState(() => _loadingPurchases = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Future<void> _deleteSaleInvoice(Map<String, dynamic> invoice) async {
    final number = invoice['number'] as String? ?? '';

    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Eliminar factura',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: Text(
          '¿Eliminar la factura $number? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (first != true || !mounted) return;

    final second = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          '¿Seguro?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Confirma que quieres eliminar definitivamente la factura $number y todas sus líneas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Sí, eliminar definitivamente'),
          ),
        ],
      ),
    );

    if (second != true || !mounted) return;

    try {
      await SupabaseService.client
          .from('invoices')
          .delete()
          .eq('id', invoice['id']);
      _loadSales();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Factura $number eliminada'),
          backgroundColor: const Color(0xFF1D6FEB),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Error al eliminar: $e');
    }
  }

  Future<void> _deletePurchaseInvoice(Map<String, dynamic> invoice) async {
    final number = invoice['number'] as String? ?? '';

    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Eliminar factura',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: Text('¿Eliminar la factura de compra $number?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (first != true || !mounted) return;

    final second = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          '¿Seguro?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Confirma que quieres eliminar definitivamente la factura $number.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Sí, eliminar definitivamente'),
          ),
        ],
      ),
    );

    if (second != true || !mounted) return;

    try {
      await SupabaseService.client
          .from('purchase_invoices')
          .delete()
          .eq('id', invoice['id']);
      _loadPurchases();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Factura $number eliminada'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Error al eliminar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildTabs(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSalesList(),
                _buildPurchasesList(),
                SuppliersTab(key: _suppliersKey, profile: widget.profile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Facturas',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2),
                Text(
                  'Gestiona facturas de venta y compra',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          _buildAddButton(),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return ListenableBuilder(
      listenable: _tabController,
      builder: (context, _) {
        final index = _tabController.index;
        if (index == 2) {
          return ElevatedButton.icon(
            onPressed: () => _suppliersKey.currentState?.openForm(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nuevo proveedor'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D6FEB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
        return ElevatedButton.icon(
          onPressed: () {
            if (index == 0) _openCreateSale();
            if (index == 1) _openCreatePurchase();
          },
          icon: const Icon(Icons.add, size: 18),
          label: Text(index == 0 ? 'Nueva venta' : 'Nueva compra'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1D6FEB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F2)),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: const Color(0xFF1D6FEB),
            borderRadius: BorderRadius.circular(8),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF64748B),
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'Ventas'),
            Tab(text: 'Compras'),
            Tab(text: 'Proveedores'),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesList() {
    if (_loadingSales) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_saleInvoices.isEmpty) {
      return _buildEmpty('No hay facturas de venta', Icons.receipt_long);
    }
    return RefreshIndicator(
      onRefresh: _loadSales,
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _saleInvoices.length,
        itemBuilder: (context, i) => _SaleInvoiceCard(
          invoice: _saleInvoices[i],
          onTap: () => _openSaleDetail(_saleInvoices[i]),
          onStatusChange: (status) async {
            await _invoiceService.updateSaleInvoiceStatus(
              _saleInvoices[i]['id'],
              status,
            );
            _loadSales();
          },
          onDelete: () => _deleteSaleInvoice(_saleInvoices[i]),
        ),
      ),
    );
  }

  Widget _buildPurchasesList() {
    if (_loadingPurchases) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_purchaseInvoices.isEmpty) {
      return _buildEmpty(
        'No hay facturas de compra',
        Icons.local_shipping_outlined,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadPurchases,
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _purchaseInvoices.length,
        itemBuilder: (context, i) => _PurchaseInvoiceCard(
          invoice: _purchaseInvoices[i],
          onTap: () => _openPurchaseDetail(_purchaseInvoices[i]),
          onStatusChange: (status) async {
            await _invoiceService.updatePurchaseInvoiceStatus(
              _purchaseInvoices[i]['id'],
              status,
            );
            _loadPurchases();
          },
          onDelete: () => _deletePurchaseInvoice(_purchaseInvoices[i]),
        ),
      ),
    );
  }

  Widget _buildEmpty(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: const Color(0xFFCBD5E1)),
          const SizedBox(height: 12),
          Text(
            msg,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
          ),
        ],
      ),
    );
  }

  void _openCreateSale() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => CreateSaleInvoiceDialog(invoiceService: _invoiceService),
    );
    if (result == true) _loadSales();
  }

  void _openCreatePurchase() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => CreatePurchaseInvoiceDialog(
        invoiceService: _invoiceService,
        profile: widget.profile,
      ),
    );
    if (result == true) _loadPurchases();
  }

  void _openSaleDetail(Map<String, dynamic> invoice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SaleInvoiceDetailSheet(
        invoice: invoice,
        invoiceService: _invoiceService,
      ),
    );
  }

  void _openPurchaseDetail(Map<String, dynamic> invoice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PurchaseInvoiceDetailSheet(
        invoice: invoice,
        invoiceService: _invoiceService,
      ),
    );
  }
}

// ── TARJETA VENTA ─────────────────────────────────────────

class _SaleInvoiceCard extends StatelessWidget {
  final Map<String, dynamic> invoice;
  final VoidCallback onTap;
  final void Function(String) onStatusChange;
  final VoidCallback onDelete;

  const _SaleInvoiceCard({
    required this.invoice,
    required this.onTap,
    required this.onStatusChange,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final client = invoice['client'] as Map<String, dynamic>?;
    final clientName = client?['full_name'] ?? 'Cliente desconocido';
    final status = invoice['status'] as String;
    final total = (invoice['total'] as num).toDouble();
    final date = DateTime.parse(invoice['issued_at']).toLocal();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Color(0xFF1D6FEB),
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice['number'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      clientName,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${date.day}/${date.month}/${date.year}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${total.toStringAsFixed(2)} €',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _StatusBadge(status: status),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onDelete,
                    child: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFDC2626),
                      size: 18,
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

// ── TARJETA COMPRA ────────────────────────────────────────

class _PurchaseInvoiceCard extends StatelessWidget {
  final Map<String, dynamic> invoice;
  final VoidCallback onTap;
  final void Function(String) onStatusChange;
  final VoidCallback onDelete;

  const _PurchaseInvoiceCard({
    required this.invoice,
    required this.onTap,
    required this.onStatusChange,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final supplier = invoice['supplier_name'] as String? ?? 'Proveedor';
    final status = invoice['status'] as String;
    final total = (invoice['total'] as num).toDouble();
    final date = DateTime.parse(invoice['issued_at']).toLocal();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: Color(0xFF16A34A),
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice['number'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      supplier,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${date.day}/${date.month}/${date.year}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${total.toStringAsFixed(2)} €',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _StatusBadge(status: status),
                  const SizedBox(height: 6),
                  if (status == 'pending')
                    GestureDetector(
                      onTap: () => onStatusChange('paid'),
                      child: const Icon(
                        Icons.check_circle_outline,
                        color: Color(0xFF16A34A),
                        size: 18,
                      ),
                    ),
                  if (status == 'pending') const SizedBox(height: 4),
                  GestureDetector(
                    onTap: onDelete,
                    child: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFDC2626),
                      size: 18,
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

// ── BADGE DE ESTADO ───────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final config = switch (status) {
      'paid' => (
        label: 'Pagada',
        color: const Color(0xFF16A34A),
        bg: const Color(0xFFF0FDF4),
      ),
      'cancelled' => (
        label: 'Cancelada',
        color: const Color(0xFFDC2626),
        bg: const Color(0xFFFEF2F2),
      ),
      _ => (
        label: 'Pendiente',
        color: const Color(0xFFD97706),
        bg: const Color(0xFFFFFBEB),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: config.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        config.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: config.color,
        ),
      ),
    );
  }
}
