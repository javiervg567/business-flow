import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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

  static const int _pageSize = 10;
  int _salePage = 0;
  int _purchasePage = 0;
  DateTimeRange? _saleDateRange;
  DateTimeRange? _purchaseDateRange;

  List<Map<String, dynamic>> get _filteredSales {
    if (_saleDateRange == null) return _saleInvoices;
    return _saleInvoices.where((i) {
      final date = DateTime.tryParse(i['issued_at'] ?? '')?.toLocal();
      if (date == null) return false;
      final from = DateTime(
        _saleDateRange!.start.year,
        _saleDateRange!.start.month,
        _saleDateRange!.start.day,
      );
      final to = DateTime(
        _saleDateRange!.end.year,
        _saleDateRange!.end.month,
        _saleDateRange!.end.day,
        23,
        59,
        59,
      );
      return date.isAfter(from.subtract(const Duration(seconds: 1))) &&
          date.isBefore(to.add(const Duration(seconds: 1)));
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredPurchases {
    if (_purchaseDateRange == null) return _purchaseInvoices;
    return _purchaseInvoices.where((i) {
      final date = DateTime.tryParse(i['issued_at'] ?? '')?.toLocal();
      if (date == null) return false;
      final from = DateTime(
        _purchaseDateRange!.start.year,
        _purchaseDateRange!.start.month,
        _purchaseDateRange!.start.day,
      );
      final to = DateTime(
        _purchaseDateRange!.end.year,
        _purchaseDateRange!.end.month,
        _purchaseDateRange!.end.day,
        23,
        59,
        59,
      );
      return date.isAfter(from.subtract(const Duration(seconds: 1))) &&
          date.isBefore(to.add(const Duration(seconds: 1)));
    }).toList();
  }

  int get _saleTotalPages => (_filteredSales.length / _pageSize).ceil();
  int get _purchaseTotalPages => (_filteredPurchases.length / _pageSize).ceil();

  List<Map<String, dynamic>> get _paginatedSales {
    final start = _salePage * _pageSize;
    final end = (start + _pageSize).clamp(0, _filteredSales.length);
    return _filteredSales.sublist(start, end);
  }

  List<Map<String, dynamic>> get _paginatedPurchases {
    final start = _purchasePage * _pageSize;
    final end = (start + _pageSize).clamp(0, _filteredPurchases.length);
    return _filteredPurchases.sublist(start, end);
  }

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
      setState(() {
        _saleInvoices = data;
        _salePage = 0;
      });
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
      setState(() {
        _purchaseInvoices = data;
        _purchasePage = 0;
      });
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

  Future<void> _pickSaleDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _saleDateRange,
      locale: const Locale('es'),
    );
    if (range != null) {
      setState(() {
        _saleDateRange = range;
        _salePage = 0;
      });
    }
  }

  Future<void> _pickPurchaseDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _purchaseDateRange,
      locale: const Locale('es'),
    );
    if (range != null) {
      setState(() {
        _purchaseDateRange = range;
        _purchasePage = 0;
      });
    }
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
    if (_loadingSales) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: _DateRangeButton(
            dateRange: _saleDateRange,
            onTap: _pickSaleDateRange,
            onClear: () => setState(() {
              _saleDateRange = null;
              _salePage = 0;
            }),
          ),
        ),
        if (_filteredSales.isEmpty)
          Expanded(
            child: _buildEmpty('No hay facturas de venta', Icons.receipt_long),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadSales,
              child: ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: _paginatedSales.length,
                itemBuilder: (context, i) => _SaleInvoiceCard(
                  invoice: _paginatedSales[i],
                  onTap: () => _openSaleDetail(_paginatedSales[i]),
                  onStatusChange: (status) async {
                    await _invoiceService.updateSaleInvoiceStatus(
                      _paginatedSales[i]['id'],
                      status,
                    );
                    _loadSales();
                  },
                  onDelete: () => _deleteSaleInvoice(_paginatedSales[i]),
                  onDownload: () => _downloadSalePdf(_paginatedSales[i]),
                ),
              ),
            ),
          ),
        _buildPagination(
          currentPage: _salePage,
          totalPages: _saleTotalPages,
          total: _filteredSales.length,
          label: 'facturas',
          onFirst: () => setState(() => _salePage = 0),
          onPrev: () => setState(() => _salePage--),
          onNext: () => setState(() => _salePage++),
          onLast: () => setState(() => _salePage = _saleTotalPages - 1),
        ),
      ],
    );
  }

  Widget _buildPurchasesList() {
    if (_loadingPurchases) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: _DateRangeButton(
            dateRange: _purchaseDateRange,
            onTap: _pickPurchaseDateRange,
            onClear: () => setState(() {
              _purchaseDateRange = null;
              _purchasePage = 0;
            }),
          ),
        ),
        if (_filteredPurchases.isEmpty)
          Expanded(
            child: _buildEmpty(
              'No hay facturas de compra',
              Icons.local_shipping_outlined,
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadPurchases,
              child: ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: _paginatedPurchases.length,
                itemBuilder: (context, i) => _PurchaseInvoiceCard(
                  invoice: _paginatedPurchases[i],
                  onTap: () => _openPurchaseDetail(_paginatedPurchases[i]),
                  onStatusChange: (status) async {
                    await _invoiceService.updatePurchaseInvoiceStatus(
                      _paginatedPurchases[i]['id'],
                      status,
                    );
                    _loadPurchases();
                  },
                  onDelete: () =>
                      _deletePurchaseInvoice(_paginatedPurchases[i]),
                  onDownload: () =>
                      _downloadPurchasePdf(_paginatedPurchases[i]),
                ),
              ),
            ),
          ),
        _buildPagination(
          currentPage: _purchasePage,
          totalPages: _purchaseTotalPages,
          total: _filteredPurchases.length,
          label: 'facturas',
          onFirst: () => setState(() => _purchasePage = 0),
          onPrev: () => setState(() => _purchasePage--),
          onNext: () => setState(() => _purchasePage++),
          onLast: () => setState(() => _purchasePage = _purchaseTotalPages - 1),
        ),
      ],
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

  Widget _buildPagination({
    required int currentPage,
    required int totalPages,
    required int total,
    required String label,
    required VoidCallback onFirst,
    required VoidCallback onPrev,
    required VoidCallback onNext,
    required VoidCallback onLast,
  }) {
    if (totalPages <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Mostrando ${currentPage * _pageSize + 1}–${((currentPage + 1) * _pageSize).clamp(0, total)} de $total $label',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          Row(
            children: [
              IconButton(
                onPressed: currentPage > 0 ? onFirst : null,
                icon: const Icon(Icons.first_page),
                color: const Color(0xFF1D6FEB),
                disabledColor: const Color(0xFFCBD5E1),
              ),
              IconButton(
                onPressed: currentPage > 0 ? onPrev : null,
                icon: const Icon(Icons.chevron_left),
                color: const Color(0xFF1D6FEB),
                disabledColor: const Color(0xFFCBD5E1),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D6FEB),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${currentPage + 1} / $totalPages',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: currentPage < totalPages - 1 ? onNext : null,
                icon: const Icon(Icons.chevron_right),
                color: const Color(0xFF1D6FEB),
                disabledColor: const Color(0xFFCBD5E1),
              ),
              IconButton(
                onPressed: currentPage < totalPages - 1 ? onLast : null,
                icon: const Icon(Icons.last_page),
                color: const Color(0xFF1D6FEB),
                disabledColor: const Color(0xFFCBD5E1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _downloadSalePdf(Map<String, dynamic> invoice) async {
    try {
      final lines = await _invoiceService.fetchInvoiceLines(
        invoice['id'] as String,
      );
      final client = invoice['client'] as Map<String, dynamic>?;
      final clientName = client?['full_name'] as String? ?? 'Cliente';
      final number = invoice['number'] as String? ?? '';
      final date =
          DateTime.tryParse(invoice['issued_at'] as String? ?? '') ??
          DateTime.now();
      final subtotal = (invoice['subtotal'] as num?)?.toDouble() ?? 0.0;
      final tax = (invoice['tax_amount'] as num?)?.toDouble() ?? 0.0;
      final total = (invoice['total'] as num?)?.toDouble() ?? 0.0;

      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(44),
          build: (_) => _buildSalePdfPage(
            number: number,
            date: date,
            recipientLabel: 'CLIENTE',
            recipientName: clientName,
            lines: lines,
            subtotal: subtotal,
            tax: tax,
            total: total,
            type: 'FACTURA DE VENTA',
          ),
        ),
      );
      await Printing.layoutPdf(
        onLayout: (_) async => doc.save(),
        name: 'Factura_$number.pdf',
      );
    } catch (e) {
      if (mounted) _showError('Error al generar PDF: $e');
    }
  }

  Future<void> _downloadPurchasePdf(Map<String, dynamic> invoice) async {
    try {
      final linesData = await SupabaseService.client
          .from('purchase_invoice_lines')
          .select()
          .eq('purchase_invoice_id', invoice['id'])
          .order('created_at');
      final lines = List<Map<String, dynamic>>.from(linesData);
      final supplier =
          invoice['supplier_name'] as String? ?? 'Proveedor';
      final number = invoice['number'] as String? ?? '';
      final date =
          DateTime.tryParse(invoice['issued_at'] as String? ?? '') ??
          DateTime.now();
      final subtotal = (invoice['subtotal'] as num?)?.toDouble() ?? 0.0;
      final tax = (invoice['tax_amount'] as num?)?.toDouble() ?? 0.0;
      final total = (invoice['total'] as num?)?.toDouble() ?? 0.0;

      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(44),
          build: (_) => _buildSalePdfPage(
            number: number,
            date: date,
            recipientLabel: 'PROVEEDOR',
            recipientName: supplier,
            lines: lines,
            subtotal: subtotal,
            tax: tax,
            total: total,
            type: 'FACTURA DE COMPRA',
          ),
        ),
      );
      await Printing.layoutPdf(
        onLayout: (_) async => doc.save(),
        name: 'Compra_$number.pdf',
      );
    } catch (e) {
      if (mounted) _showError('Error al generar PDF: $e');
    }
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

// ── PDF HELPERS ───────────────────────────────────────────

pw.Widget _buildSalePdfPage({
  required String number,
  required DateTime date,
  required String recipientLabel,
  required String recipientName,
  required List<Map<String, dynamic>> lines,
  required double subtotal,
  required double tax,
  required double total,
  required String type,
}) {
  final dateStr = '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      // Header
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Business Flow',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Sistema de Gestión Empresarial',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                type,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                number,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Fecha: $dateStr',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 16),
      pw.Divider(color: PdfColors.blue200, thickness: 1.5),
      pw.SizedBox(height: 16),
      // Recipient
      pw.Text(
        recipientLabel,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey600,
          letterSpacing: 1.2,
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        recipientName,
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 20),
      // Lines header
      pw.Text(
        'CONCEPTOS',
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey600,
          letterSpacing: 1.2,
        ),
      ),
      pw.SizedBox(height: 6),
      pw.Table(
        border: pw.TableBorder(
          horizontalInside: const pw.BorderSide(
            width: 0.5,
            color: PdfColors.grey300,
          ),
        ),
        columnWidths: {
          0: const pw.FlexColumnWidth(5),
          1: const pw.FixedColumnWidth(50),
          2: const pw.FixedColumnWidth(80),
          3: const pw.FixedColumnWidth(80),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.blue50),
            children: [
              _pdfCell('Descripción', bold: true),
              _pdfCell('Cant.', bold: true),
              _pdfCell('P. unitario', bold: true),
              _pdfCell('Total', bold: true),
            ],
          ),
          ...lines.map((l) {
            final qty = (l['quantity'] as num).toDouble();
            final unitPrice = (l['unit_price'] as num).toDouble();
            final lineTotal = (l['total'] as num).toDouble();
            return pw.TableRow(
              children: [
                _pdfCell(l['description'] as String? ?? ''),
                _pdfCell(qty.toStringAsFixed(0)),
                _pdfCell('${unitPrice.toStringAsFixed(2)} €'),
                _pdfCell('${lineTotal.toStringAsFixed(2)} €'),
              ],
            );
          }),
        ],
      ),
      pw.SizedBox(height: 20),
      // Totals aligned right
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.SizedBox(
          width: 220,
          child: pw.Column(
            children: [
              _pdfTotalRow('Subtotal', subtotal),
              pw.SizedBox(height: 4),
              _pdfTotalRow('IVA', tax),
              pw.SizedBox(height: 4),
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 4),
              _pdfTotalRow('TOTAL', total, bold: true),
            ],
          ),
        ),
      ),
      pw.Spacer(),
      pw.Divider(color: PdfColors.grey300),
      pw.SizedBox(height: 4),
      pw.Text(
        'Documento generado por Business Flow · ${DateTime.now().year}',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
        textAlign: pw.TextAlign.center,
      ),
    ],
  );
}

pw.Widget _pdfCell(String text, {bool bold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
    child: pw.Text(
      text,
      style: bold
          ? pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)
          : const pw.TextStyle(fontSize: 10),
    ),
  );
}

pw.Widget _pdfTotalRow(String label, double value, {bool bold = false}) {
  final style = bold
      ? pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)
      : const pw.TextStyle(fontSize: 11, color: PdfColors.grey700);
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(label, style: style),
      pw.Text('${value.toStringAsFixed(2)} €', style: style),
    ],
  );
}

// ── FILTRO FECHAS ─────────────────────────────────────────

class _DateRangeButton extends StatelessWidget {
  final DateTimeRange? dateRange;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DateRangeButton({
    required this.dateRange,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasRange = dateRange != null;
    final label = hasRange
        ? '${dateRange!.start.day}/${dateRange!.start.month}/${dateRange!.start.year} – ${dateRange!.end.day}/${dateRange!.end.month}/${dateRange!.end.year}'
        : 'Filtrar por fechas';

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: hasRange ? const Color(0xFFEEF5FF) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasRange ? const Color(0xFF1D6FEB) : const Color(0xFFE2E8F2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.date_range,
              size: 16,
              color: hasRange
                  ? const Color(0xFF1D6FEB)
                  : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: hasRange
                    ? const Color(0xFF1D6FEB)
                    : const Color(0xFF64748B),
              ),
            ),
            if (hasRange) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onClear,
                child: const Icon(
                  Icons.close,
                  size: 14,
                  color: Color(0xFF1D6FEB),
                ),
              ),
            ],
          ],
        ),
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
  final VoidCallback onDownload;

  const _SaleInvoiceCard({
    required this.invoice,
    required this.onTap,
    required this.onStatusChange,
    required this.onDelete,
    required this.onDownload,
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: onDownload,
                        child: const Icon(
                          Icons.download_outlined,
                          color: Color(0xFF1D6FEB),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
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
  final VoidCallback onDownload;

  const _PurchaseInvoiceCard({
    required this.invoice,
    required this.onTap,
    required this.onStatusChange,
    required this.onDelete,
    required this.onDownload,
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: onDownload,
                        child: const Icon(
                          Icons.download_outlined,
                          color: Color(0xFF1D6FEB),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
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
