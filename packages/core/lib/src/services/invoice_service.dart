import 'package:supabase_flutter/supabase_flutter.dart';

class InvoiceService {
  final SupabaseClient _client;
  InvoiceService(this._client);

  // ── VENTAS ──────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchSaleInvoices() async {
    final data = await _client
        .from('invoices')
        .select('*, client:profiles(id, full_name, email)')
        .order('issued_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> fetchInvoiceLines(String invoiceId) async {
    final data = await _client
        .from('invoice_lines')
        .select()
        .eq('invoice_id', invoiceId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> createSaleInvoice({
    required String clientId,
    String? bookingId,
    required String number,
    required List<Map<String, dynamic>> lines,
    required double taxRate,
  }) async {
    final subtotal = lines.fold<double>(
      0,
      (sum, l) => sum + (l['quantity'] as double) * (l['unit_price'] as double),
    );
    final taxAmount = subtotal * taxRate;
    final total = subtotal + taxAmount;

    final invoice = await _client
        .from('invoices')
        .insert({
          'client_id': clientId,
          'booking_id': bookingId,
          'number': number,
          'subtotal': subtotal,
          'tax_amount': taxAmount,
          'total': total,
          'status': 'pending',
        })
        .select()
        .single();

    final invoiceId = invoice['id'] as String;

    final lineRows = lines.map((l) {
      final qty = l['quantity'] as double;
      final price = l['unit_price'] as double;
      return {
        'invoice_id': invoiceId,
        'description': l['description'],
        'quantity': qty,
        'unit_price': price,
        'total': qty * price,
      };
    }).toList();

    await _client.from('invoice_lines').insert(lineRows);
  }

  // ── COMPRAS ─────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchPurchaseInvoices() async {
    final data = await _client
        .from('purchase_invoices')
        .select()
        .order('issued_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> createPurchaseInvoice({
    required String businessId,
    required String supplierName,
    required String number,
    required List<Map<String, dynamic>> lines,
    required double taxRate,
  }) async {
    final subtotal = lines.fold<double>(
      0,
      (sum, l) => sum + (l['quantity'] as double) * (l['unit_price'] as double),
    );
    final taxAmount = subtotal * taxRate;
    final total = subtotal + taxAmount;

    final invoice = await _client
        .from('purchase_invoices')
        .insert({
          'business_id': businessId,
          'supplier_name': supplierName,
          'number': number,
          'subtotal': subtotal,
          'tax_amount': taxAmount,
          'total': total,
          'status': 'pending',
        })
        .select()
        .single();

    final invoiceId = invoice['id'] as String;

    final lineRows = lines.map((l) {
      final qty = l['quantity'] as double;
      final price = l['unit_price'] as double;
      return {
        'purchase_invoice_id': invoiceId,
        'product_id': l['product_id'],
        'description': l['description'],
        'quantity': qty,
        'unit_price': price,
        'total': qty * price,
      };
    }).toList();

    await _client.from('purchase_invoice_lines').insert(lineRows);

    // Sumar stock de los productos comprados
    final productLines = lines.where((l) => l['product_id'] != null).toList();
    for (final line in productLines) {
      final productId = line['product_id'] as String;
      final qty = (line['quantity'] as double).round();

      final product = await _client
          .from('products')
          .select('stock')
          .eq('id', productId)
          .single();

      final currentStock = (product['stock'] as num).toInt();
      final newStock = currentStock + qty;

      await _client
          .from('products')
          .update({'stock': newStock})
          .eq('id', productId);
    }
  }

  // ── CAMBIAR ESTADO ───────────────────────────────────────

  Future<void> updateSaleInvoiceStatus(String id, String status) async {
    await _client.from('invoices').update({'status': status}).eq('id', id);
  }

  Future<void> updatePurchaseInvoiceStatus(String id, String status) async {
    await _client
        .from('purchase_invoices')
        .update({'status': status})
        .eq('id', id);
  }

  // ── FINALIZAR RESERVA ────────────────────────────────────

  Future<void> finalizeBooking({
    required String bookingId,
    required String clientId,
    required String number,
    required List<Map<String, dynamic>> lines,
    required double taxRate,
  }) async {
    final subtotal = lines.fold<double>(
      0,
      (sum, l) => sum + (l['quantity'] as double) * (l['unit_price'] as double),
    );
    final taxAmount = subtotal * taxRate;
    final total = subtotal + taxAmount;

    final invoice = await _client
        .from('invoices')
        .insert({
          'business_id': (await _client
              .from('profiles')
              .select('business_id')
              .eq('id', clientId)
              .single())['business_id'],
          'client_id': clientId,
          'booking_id': bookingId,
          'number': number,
          'subtotal': subtotal,
          'tax_amount': taxAmount,
          'total': total,
          'status': 'paid',
        })
        .select()
        .single();

    final invoiceId = invoice['id'] as String;

    final lineRows = lines.map((l) {
      final qty = l['quantity'] as double;
      final price = l['unit_price'] as double;
      return {
        'invoice_id': invoiceId,
        'description': l['description'],
        'quantity': qty,
        'unit_price': price,
        'total': qty * price,
      };
    }).toList();

    await _client.from('invoice_lines').insert(lineRows);

    // Descontar stock de los productos vendidos
    final productLines = lines.where((l) => l['product_id'] != null).toList();
    for (final line in productLines) {
      final productId = line['product_id'] as String;
      final qty = (line['quantity'] as double).round();

      final product = await _client
          .from('products')
          .select('stock')
          .eq('id', productId)
          .single();

      final currentStock = (product['stock'] as num).toInt();
      final newStock = (currentStock - qty).clamp(0, 999999);

      await _client
          .from('products')
          .update({'stock': newStock})
          .eq('id', productId);
    }

    await _client
        .from('bookings')
        .update({'status': 'completed'})
        .eq('id', bookingId);
  }
}
