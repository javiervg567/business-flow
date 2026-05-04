import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:core/core.dart';

class ClientInvoicesScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const ClientInvoicesScreen({super.key, required this.profile});

  @override
  State<ClientInvoicesScreen> createState() => _ClientInvoicesScreenState();
}

class _ClientInvoicesScreenState extends State<ClientInvoicesScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _invoices = [];

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.client
          .from('invoices')
          .select('*, invoice_lines(*)')
          .eq('client_id', widget.profile['id'])
          .order('issued_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _invoices = (data as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _showDetail(Map<String, dynamic> invoice) {
    final lines = (invoice['invoice_lines'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InvoiceDetailSheet(invoice: invoice, lines: lines),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(color: Color(0xFF0D1B2E)),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _InvoicesGridPainter()),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mis facturas',
                        style: GoogleFonts.dmSerifDisplay(
                          fontSize: 26,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'Consulta tu historial de pagos',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF16A34A)),
                  )
                : _invoices.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        color: const Color(0xFF16A34A),
                        onRefresh: _loadInvoices,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _invoices.length,
                          itemBuilder: (_, i) => _InvoiceCard(
                            invoice: _invoices[i],
                            onTap: () => _showDetail(_invoices[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 26,
              color: Color(0xFF86EFAC),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No tienes facturas',
            style: GoogleFonts.dmSerifDisplay(
              fontSize: 20,
              color: const Color(0xFF0D1B2E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tus facturas aparecerán aquí',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final Map<String, dynamic> invoice;
  final VoidCallback onTap;
  const _InvoiceCard({required this.invoice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final number = invoice['number'] as String? ?? '—';
    final status = invoice['status'] as String? ?? 'pending';
    final total = invoice['total'] as num? ?? 0;
    final issuedAt = DateTime.tryParse(invoice['issued_at'] ?? '')?.toLocal();
    final dateStr = issuedAt != null
        ? '${issuedAt.day.toString().padLeft(2, '0')}/${issuedAt.month.toString().padLeft(2, '0')}/${issuedAt.year}'
        : '—';

    final statusConfig = switch (status) {
      'paid' => (
        label: 'Pagada',
        color: const Color(0xFF16A34A),
        bg: const Color(0xFFF0FDF4),
      ),
      'pending' => (
        label: 'Pendiente',
        color: const Color(0xFFD97706),
        bg: const Color(0xFFFFFBEB),
      ),
      'cancelled' => (
        label: 'Cancelada',
        color: const Color(0xFFDC2626),
        bg: const Color(0xFFFEF2F2),
      ),
      _ => (
        label: status,
        color: const Color(0xFF64748B),
        bg: const Color(0xFFF1F5F9),
      ),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D1B2E).withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.receipt_outlined,
                color: Color(0xFF16A34A),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Factura $number',
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: 16,
                      color: const Color(0xFF0D1B2E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateStr,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: const Color(0xFF94A3B8),
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
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0D1B2E),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusConfig.bg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusConfig.label,
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusConfig.color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }
}


class _InvoiceDetailSheet extends StatelessWidget {
  final Map<String, dynamic> invoice;
  final List<Map<String, dynamic>> lines;
  const _InvoiceDetailSheet({required this.invoice, required this.lines});

  @override
  Widget build(BuildContext context) {
    final number = invoice['number'] as String? ?? '—';
    final status = invoice['status'] as String? ?? 'pending';
    final subtotal = invoice['subtotal'] as num? ?? 0;
    final taxAmount = invoice['tax_amount'] as num? ?? 0;
    final total = invoice['total'] as num? ?? 0;
    final issuedAt = DateTime.tryParse(invoice['issued_at'] ?? '')?.toLocal();
    final pdfUrl = invoice['pdf_url'] as String?;

    final dateStr = issuedAt != null
        ? '${issuedAt.day.toString().padLeft(2, '0')}/${issuedAt.month.toString().padLeft(2, '0')}/${issuedAt.year}'
        : '—';

    final statusConfig = switch (status) {
      'paid' => (
        label: 'Pagada',
        color: const Color(0xFF16A34A),
        bg: const Color(0xFFF0FDF4),
      ),
      'pending' => (
        label: 'Pendiente',
        color: const Color(0xFFD97706),
        bg: const Color(0xFFFFFBEB),
      ),
      'cancelled' => (
        label: 'Cancelada',
        color: const Color(0xFFDC2626),
        bg: const Color(0xFFFEF2F2),
      ),
      _ => (
        label: status,
        color: const Color(0xFF64748B),
        bg: const Color(0xFFF1F5F9),
      ),
    };

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF4F6FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Factura $number',
                          style: GoogleFonts.dmSerifDisplay(
                            fontSize: 22,
                            color: const Color(0xFF0D1B2E),
                          ),
                        ),
                        Text(
                          dateStr,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusConfig.bg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusConfig.label,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusConfig.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            if (lines.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: lines.asMap().entries.map((entry) {
                    final i = entry.key;
                    final line = entry.value;
                    final desc = line['description'] as String? ?? '';
                    final qty = line['quantity'] as num? ?? 1;
                    final unitPrice = line['unit_price'] as num? ?? 0;
                    final lineTotal = qty * unitPrice;
                    final isLast = i == lines.length - 1;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: isLast
                            ? null
                            : const Border(
                                bottom: BorderSide(color: Color(0xFFF1F5F9)),
                              ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  desc,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF0D1B2E),
                                  ),
                                ),
                                if (qty != 1)
                                  Text(
                                    '${qty.toStringAsFixed(0)} × ${unitPrice.toStringAsFixed(2)} €',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 11,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '${lineTotal.toStringAsFixed(2)} €',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0D1B2E),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            Container(
              margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _totalRow('Subtotal', subtotal, bold: false),
                  const SizedBox(height: 6),
                  _totalRow('IVA', taxAmount, bold: false),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                  ),
                  _totalRow('Total', total, bold: true, green: true),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 16),
                      label: Text(
                        'Cerrar',
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (pdfUrl != null && pdfUrl.isNotEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Abriendo PDF...',
                                style: GoogleFonts.dmSans(),
                              ),
                              backgroundColor: const Color(0xFF16A34A),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'PDF no disponible para esta factura',
                                style: GoogleFonts.dmSans(),
                              ),
                              backgroundColor: const Color(0xFF64748B),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.download_outlined, size: 16),
                      label: Text(
                        'Descargar',
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalRow(
    String label,
    num amount, {
    required bool bold,
    bool green = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: bold ? 14 : 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: bold ? const Color(0xFF0D1B2E) : const Color(0xFF64748B),
          ),
        ),
        Text(
          '${amount.toStringAsFixed(2)} €',
          style: GoogleFonts.dmSans(
            fontSize: bold ? 16 : 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: green ? const Color(0xFF16A34A) : const Color(0xFF0D1B2E),
          ),
        ),
      ],
    );
  }
}

class _InvoicesGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A2F4A).withValues(alpha: 0.45)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const spacing = 48.0;
    for (double x = 0; x < size.width + spacing; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height + spacing; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final glowPaint = Paint()
      ..color = const Color(0xFF16A34A).withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.25),
      60,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
