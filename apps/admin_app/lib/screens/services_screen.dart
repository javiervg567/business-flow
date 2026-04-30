import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:core/core.dart';
import 'package:image_picker/image_picker.dart';

class ServicesScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const ServicesScreen({super.key, required this.profile});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _services = [];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      final res = await SupabaseService.client
          .from('services')
          .select()
          .eq('business_id', widget.profile['business_id'])
          .order('name');
      if (!mounted) return;
      setState(() {
        _services = (res as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> service) async {
    final newValue = !(service['active'] as bool);
    try {
      await SupabaseService.client
          .from('services')
          .update({'active': newValue})
          .eq('id', service['id'] as String);
      setState(() {
        final idx = _services.indexWhere((s) => s['id'] == service['id']);
        if (idx >= 0) _services[idx] = {..._services[idx], 'active': newValue};
      });
    } catch (_) {}
  }

  Future<void> _deleteService(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Eliminar servicio',
          style: GoogleFonts.dmSerifDisplay(
            fontSize: 20,
            color: const Color(0xFF0D1B2E),
          ),
        ),
        content: Text(
          '¿Estás seguro? Esta acción no se puede deshacer y podría afectar a reservas existentes.',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            color: const Color(0xFF64748B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.dmSans(color: const Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Eliminar',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await SupabaseService.client.from('services').delete().eq('id', id);
      setState(() => _services.removeWhere((s) => s['id'] == id));
    } catch (_) {}
  }

  void _openServiceDialog({Map<String, dynamic>? service}) {
    showDialog(
      context: context,
      builder: (ctx) => _ServiceDialog(
        profile: widget.profile,
        service: service,
        onSaved: (saved) {
          setState(() {
            if (service == null) {
              _services.add(saved);
              _services.sort(
                (a, b) => (a['name'] as String).compareTo(b['name'] as String),
              );
            } else {
              final idx = _services.indexWhere((s) => s['id'] == saved['id']);
              if (idx >= 0) _services[idx] = saved;
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _search.isEmpty
        ? _services
        : _services
              .where(
                (s) => (s['name'] as String).toLowerCase().contains(
                  _search.toLowerCase(),
                ),
              )
              .toList();

    return Column(
      children: [
        _buildToolbar(),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF1D6FEB),
                    strokeWidth: 2,
                  ),
                )
              : filtered.isEmpty
              ? _buildEmpty()
              : _buildServiceList(filtered),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: const Color(0xFF0D1B2E),
              ),
              decoration: InputDecoration(
                hintText: 'Buscar servicio…',
                hintStyle: GoogleFonts.dmSans(color: const Color(0xFFCBD5E1)),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color(0xFF94A3B8),
                  size: 20,
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFF1D6FEB),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => _openServiceDialog(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D6FEB),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: Text(
              'Nuevo servicio',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
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
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF5FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.design_services_outlined,
              color: Color(0xFF1D6FEB),
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _search.isEmpty ? 'Sin servicios' : 'Sin resultados',
            style: GoogleFonts.dmSerifDisplay(
              fontSize: 22,
              color: const Color(0xFF0D1B2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _search.isEmpty
                ? 'Añade tu primer servicio con el botón de arriba'
                : 'Prueba con otro término de búsqueda',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceList(List<Map<String, dynamic>> services) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const padding = 20.0;
        const gap = 16.0;
        final cols = constraints.maxWidth > 720 ? 2 : 1;
        final cardWidth = cols == 1
            ? constraints.maxWidth - padding * 2
            : (constraints.maxWidth - padding * 2 - gap) / 2;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(padding),
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: services
                .map(
                  (s) => SizedBox(
                    width: cardWidth,
                    child: _ServiceCard(
                      service: s,
                      onEdit: () => _openServiceDialog(service: s),
                      onDelete: () => _deleteService(s['id'] as String),
                      onToggle: () => _toggleActive(s),
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

// ─── SERVICE CARD ─────────────────────────────────────────────────────────────

class _ServiceCard extends StatelessWidget {
  final Map<String, dynamic> service;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _ServiceCard({
    required this.service,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final name = service['name'] as String? ?? '';
    final description = service['description'] as String? ?? '';
    final durationMin = service['duration_minutes'] as int? ?? 0;
    final price = (service['price'] as num?)?.toDouble() ?? 0.0;
    final active = service['active'] as bool? ?? true;
    final imageUrl = service['image_url'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D1B2E).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: const Color(0xFFEEF5FF),
                              child: const Icon(
                                Icons.design_services_outlined,
                                color: Color(0xFF1D6FEB),
                                size: 20,
                              ),
                            ),
                          )
                        : Container(
                            color: const Color(0xFFEEF5FF),
                            child: const Icon(
                              Icons.design_services_outlined,
                              color: Color(0xFF1D6FEB),
                              size: 20,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0D1B2E),
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          description,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _ActiveBadge(active: active),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _InfoChip(
                  icon: Icons.schedule_outlined,
                  label: '$durationMin min',
                ),
                const SizedBox(width: 8),
                _InfoChip(
                  icon: Icons.euro_outlined,
                  label: price.toStringAsFixed(2),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),
            Row(
              children: [
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: onToggle,
                    child: Row(
                      children: [
                        Icon(
                          active
                              ? Icons.toggle_on_outlined
                              : Icons.toggle_off_outlined,
                          size: 16,
                          color: active
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          active ? 'Activo' : 'Inactivo',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: active
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                _IconBtn(
                  icon: Icons.edit_outlined,
                  color: const Color(0xFF1D6FEB),
                  onTap: onEdit,
                ),
                const SizedBox(width: 8),
                _IconBtn(
                  icon: Icons.delete_outline,
                  color: const Color(0xFFDC2626),
                  onTap: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  final bool active;
  const _ActiveBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFF0FDF4) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Text(
        active ? 'Activo' : 'Inactivo',
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: active ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF64748B)),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

// ─── SERVICE DIALOG ───────────────────────────────────────────────────────────

class _ServiceDialog extends StatefulWidget {
  final Map<String, dynamic> profile;
  final Map<String, dynamic>? service;
  final void Function(Map<String, dynamic> saved) onSaved;

  const _ServiceDialog({
    required this.profile,
    required this.service,
    required this.onSaved,
  });

  @override
  State<_ServiceDialog> createState() => _ServiceDialogState();
}

class _ServiceDialogState extends State<_ServiceDialog> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _imageUrl;
  late final TextEditingController _duration;
  late final TextEditingController _price;
  late bool _active;
  bool _saving = false;
  bool _uploadingImage = false;
  String? _error;

  bool get _isEdit => widget.service != null;

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    _name = TextEditingController(text: s?['name'] as String? ?? '');
    _description = TextEditingController(
      text: s?['description'] as String? ?? '',
    );
    _imageUrl = TextEditingController(
      text: s?['image_url'] as String? ?? '',
    );
    _duration = TextEditingController(
      text: s != null ? '${s['duration_minutes']}' : '',
    );
    _price = TextEditingController(
      text: s != null ? (s['price'] as num).toStringAsFixed(2) : '',
    );
    _active = s?['active'] as bool? ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _imageUrl.dispose();
    _duration.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;

    setState(() => _uploadingImage = true);
    try {
      final Uint8List bytes = await file.readAsBytes();
      final ext = file.name.contains('.')
          ? file.name.split('.').last.toLowerCase()
          : 'jpg';
      final path =
          '${widget.profile['business_id']}/${DateTime.now().millisecondsSinceEpoch}.$ext';

      await SupabaseService.client.storage
          .from('service-images')
          .uploadBinary(path, bytes);

      final publicUrl = SupabaseService.client.storage
          .from('service-images')
          .getPublicUrl(path);

      if (!mounted) return;
      setState(() {
        _imageUrl.text = publicUrl;
        _uploadingImage = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _uploadingImage = false;
        _error = 'Error al subir la imagen. Inténtalo de nuevo.';
      });
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final durationStr = _duration.text.trim();
    final priceStr = _price.text.trim().replaceAll(',', '.');

    if (name.isEmpty || durationStr.isEmpty || priceStr.isEmpty) {
      setState(() => _error = 'Nombre, duración y precio son obligatorios.');
      return;
    }

    final duration = int.tryParse(durationStr);
    final price = double.tryParse(priceStr);

    if (duration == null || duration <= 0) {
      setState(
        () => _error = 'La duración debe ser un número entero positivo.',
      );
      return;
    }
    if (price == null || price < 0) {
      setState(() => _error = 'El precio debe ser un número válido.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final data = {
        'name': name,
        'description': _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        'image_url': _imageUrl.text.trim().isEmpty
            ? null
            : _imageUrl.text.trim(),
        'duration_minutes': duration,
        'price': price,
        'active': _active,
      };

      final Map<String, dynamic> saved;

      if (_isEdit) {
        saved = await SupabaseService.client
            .from('services')
            .update(data)
            .eq('id', widget.service!['id'] as String)
            .select()
            .single();
      } else {
        saved = await SupabaseService.client
            .from('services')
            .insert({...data, 'business_id': widget.profile['business_id']})
            .select()
            .single();
      }

      if (!mounted) return;
      widget.onSaved(saved);
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Error al guardar. Inténtalo de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF5FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.design_services_outlined,
                      color: Color(0xFF1D6FEB),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isEdit ? 'Editar servicio' : 'Nuevo servicio',
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: 22,
                      color: const Color(0xFF0D1B2E),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Color(0xFF94A3B8),
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _DialogField(
                label: 'Nombre *',
                controller: _name,
                hint: 'Ej: Corte de cabello',
              ),
              const SizedBox(height: 16),
              _DialogField(
                label: 'Descripción',
                controller: _description,
                hint: 'Descripción breve del servicio…',
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              _ImagePickerField(
                imageUrl: _imageUrl.text,
                uploading: _uploadingImage,
                onPick: _pickAndUploadImage,
                onRemove: () => setState(() => _imageUrl.text = ''),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _DialogField(
                      label: 'Duración (min) *',
                      controller: _duration,
                      hint: 'Ej: 45',
                      inputType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _DialogField(
                      label: 'Precio (€) *',
                      controller: _price,
                      hint: 'Ej: 25.00',
                      inputType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
              if (_isEdit) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'ESTADO',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF374151),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const Spacer(),
                    Switch(
                      value: _active,
                      onChanged: (v) => setState(() => _active = v),
                      activeThumbColor: const Color(0xFF1D6FEB),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _active ? 'Activo' : 'Inactivo',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _active
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Color(0xFFEF4444),
                        size: 15,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: const Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: Text(
                        'Cancelar',
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D6FEB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
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
                              'Guardar',
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w600,
                              ),
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

class _ImagePickerField extends StatelessWidget {
  final String imageUrl;
  final bool uploading;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _ImagePickerField({
    required this.imageUrl,
    required this.uploading,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'IMAGEN DEL SERVICIO',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF374151),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 7),
        GestureDetector(
          onTap: (uploading || hasImage) ? null : onPick,
          child: Container(
            height: 130,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasImage
                    ? const Color(0xFF1D6FEB).withValues(alpha: 0.3)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: uploading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF1D6FEB),
                      strokeWidth: 2,
                    ),
                  )
                : hasImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (ctx, err, st) => _placeholder(),
                    ),
                  )
                : _placeholder(),
          ),
        ),
        if (hasImage && !uploading) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton.icon(
                onPressed: onPick,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1D6FEB),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.edit_outlined, size: 13),
                label: Text(
                  'Cambiar',
                  style: GoogleFonts.dmSans(fontSize: 12),
                ),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: onRemove,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.delete_outline, size: 13),
                label: Text(
                  'Eliminar',
                  style: GoogleFonts.dmSans(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _placeholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.add_photo_alternate_outlined,
          color: Color(0xFF94A3B8),
          size: 28,
        ),
        const SizedBox(height: 8),
        Text(
          'Toca para añadir imagen',
          style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 3),
        Text(
          'JPG, PNG o WEBP',
          style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFFCBD5E1)),
        ),
      ],
    );
  }
}

class _DialogField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? inputType;
  final List<TextInputFormatter>? inputFormatters;

  const _DialogField({
    required this.label,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.inputType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF374151),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: inputType,
          inputFormatters: inputFormatters,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            color: const Color(0xFF0D1B2E),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.dmSans(
              color: const Color(0xFFCBD5E1),
              fontSize: 14,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
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
