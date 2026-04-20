import 'package:flutter/material.dart';
import 'package:core/core.dart';

class SuppliersTab extends StatefulWidget {
  final Map<String, dynamic> profile;
  const SuppliersTab({super.key, required this.profile});

  @override
  State<SuppliersTab> createState() => SuppliersTabState();
}

class SuppliersTabState extends State<SuppliersTab> {
  List<Map<String, dynamic>> _suppliers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.client
          .from('suppliers')
          .select()
          .eq('business_id', widget.profile['business_id'])
          .order('name');
      if (!mounted) return;
      setState(() => _suppliers = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      if (!mounted) return;
      _showError('Error cargando proveedores: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void openForm() => _openForm();

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Future<void> _openForm({Map<String, dynamic>? supplier}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _SupplierFormDialog(profile: widget.profile, supplier: supplier),
    );
    if (result == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> supplier) async {
    final name = supplier['name'] as String? ?? '';

    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Eliminar proveedor',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: Text('¿Eliminar el proveedor "$name"?'),
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
        content: Text('Confirma que quieres eliminar definitivamente "$name".'),
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
          .from('suppliers')
          .delete()
          .eq('id', supplier['id']);
      _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Proveedor "$name" eliminado'),
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
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_suppliers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.store_outlined, size: 48, color: Color(0xFFCBD5E1)),
            SizedBox(height: 12),
            Text(
              'No hay proveedores registrados',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _suppliers.length,
        itemBuilder: (_, i) => _SupplierCard(
          supplier: _suppliers[i],
          onEdit: () => _openForm(supplier: _suppliers[i]),
          onDelete: () => _delete(_suppliers[i]),
        ),
      ),
    );
  }
}

// ── TARJETA PROVEEDOR ─────────────────────────────────────

class _SupplierCard extends StatelessWidget {
  final Map<String, dynamic> supplier;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SupplierCard({
    required this.supplier,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = supplier['name'] as String? ?? '';
    final contactName = supplier['contact_name'] as String?;
    final email = supplier['email'] as String?;
    final phone = supplier['phone'] as String?;
    final notes = supplier['notes'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: Colors.white,
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
                Icons.store_outlined,
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
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (contactName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      contactName,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                  if (email != null || phone != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      [?email, ?phone].join(' · '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                  if (notes != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      notes,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: Color(0xFF1D6FEB),
                    size: 18,
                  ),
                  tooltip: 'Editar',
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFDC2626),
                    size: 18,
                  ),
                  tooltip: 'Eliminar',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── FORMULARIO PROVEEDOR ──────────────────────────────────

class _SupplierFormDialog extends StatefulWidget {
  final Map<String, dynamic> profile;
  final Map<String, dynamic>? supplier;

  const _SupplierFormDialog({required this.profile, this.supplier});

  @override
  State<_SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends State<_SupplierFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _contactCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _notesCtrl;
  bool _saving = false;

  bool get _isEditing => widget.supplier != null;

  @override
  void initState() {
    super.initState();
    final s = widget.supplier;
    _nameCtrl = TextEditingController(text: s?['name'] as String? ?? '');
    _contactCtrl = TextEditingController(
      text: s?['contact_name'] as String? ?? '',
    );
    _emailCtrl = TextEditingController(text: s?['email'] as String? ?? '');
    _phoneCtrl = TextEditingController(text: s?['phone'] as String? ?? '');
    _notesCtrl = TextEditingController(text: s?['notes'] as String? ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final data = {
      'business_id': widget.profile['business_id'],
      'name': _nameCtrl.text.trim(),
      'contact_name': _contactCtrl.text.trim().isEmpty
          ? null
          : _contactCtrl.text.trim(),
      'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    };

    try {
      if (_isEditing) {
        await SupabaseService.client
            .from('suppliers')
            .update(data)
            .eq('id', widget.supplier!['id']);
      } else {
        await SupabaseService.client.from('suppliers').insert(data);
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.store_outlined,
                      color: Color(0xFF16A34A),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _isEditing ? 'Editar proveedor' : 'Nuevo proveedor',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: _deco('Nombre *', Icons.store_outlined),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Obligatorio' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contactCtrl,
                  decoration: _deco(
                    'Persona de contacto',
                    Icons.person_outline,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _emailCtrl,
                        decoration: _deco('Email', Icons.email_outlined),
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneCtrl,
                        decoration: _deco('Teléfono', Icons.phone_outlined),
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  decoration: _deco('Notas', Icons.notes_outlined),
                  maxLines: 2,
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
                          : Text(_isEditing ? 'Guardar cambios' : 'Crear'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _deco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}
