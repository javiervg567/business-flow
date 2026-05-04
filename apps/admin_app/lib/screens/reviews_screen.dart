import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:core/core.dart';

class ReviewsScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const ReviewsScreen({super.key, required this.profile});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _reviews = [];
  int _filterRating = 0;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final client = SupabaseService.client;
      final businessId = widget.profile['business_id'];

      final data = await client
          .from('reviews')
          .select(
            '*, client:profiles!reviews_client_id_fkey(full_name), booking:bookings!reviews_booking_id_fkey(service:services(name))',
          )
          .eq('business_id', businessId)
          .order('created_at', ascending: false);

      setState(() {
        _reviews = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filterRating == 0) return _reviews;
    return _reviews.where((r) => r['rating'] == _filterRating).toList();
  }

  double get _avgRating {
    if (_reviews.isEmpty) return 0;
    final sum = _reviews.fold<int>(0, (acc, r) => acc + (r['rating'] as int));
    return sum / _reviews.length;
  }

  int _countByRating(int rating) =>
      _reviews.where((r) => r['rating'] == rating).length;

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(
            child: CircularProgressIndicator(color: Color(0xFF1D6FEB)),
          )
        : _reviews.isEmpty
        ? _buildEmpty()
        : _buildContent();
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF5FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.star_outline_rounded,
              size: 36,
              color: Color(0xFF1D6FEB),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Aún no hay reseñas',
            style: GoogleFonts.dmSerifDisplay(
              fontSize: 20,
              color: const Color(0xFF0D1B2E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Las reseñas de tus clientes aparecerán aquí',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryCard(),
                        const SizedBox(width: 16),
                        Expanded(child: _buildDistributionCard()),
                      ],
                    )
                  : Column(
                      children: [
                        _buildSummaryCard(),
                        const SizedBox(height: 16),
                        _buildDistributionCard(),
                      ],
                    ),
              const SizedBox(height: 24),
              _buildFilterRow(),
              const SizedBox(height: 12),
              ..._filtered.map(_buildReviewCard),
              if (_filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No hay reseñas con $_filterRating estrella${_filterRating == 1 ? '' : 's'}',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard() {
    final avg = _avgRating;
    return Container(
      width: 180,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Valoración media',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF94A3B8),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            avg.toStringAsFixed(1),
            style: GoogleFonts.dmSerifDisplay(
              fontSize: 48,
              color: const Color(0xFF0D1B2E),
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          _buildStars(avg, size: 18),
          const SizedBox(height: 8),
          Text(
            '${_reviews.length} reseña${_reviews.length == 1 ? '' : 's'}',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Distribución',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF94A3B8),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(5, (i) {
            final rating = 5 - i;
            final count = _countByRating(rating);
            final pct =
                _reviews.isEmpty ? 0.0 : count / _reviews.length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(
                    '$rating',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.star_rounded,
                    size: 13,
                    color: Color(0xFFFBBF24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 7,
                        backgroundColor: const Color(0xFFF1F5F9),
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF1D6FEB),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 24,
                    child: Text(
                      '$count',
                      textAlign: TextAlign.end,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: 'Todas',
            selected: _filterRating == 0,
            onTap: () => setState(() => _filterRating = 0),
          ),
          const SizedBox(width: 8),
          ...List.generate(5, (i) {
            final rating = 5 - i;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _FilterChip(
                label: '$rating ★',
                selected: _filterRating == rating,
                onTap: () => setState(() => _filterRating = rating),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final clientName =
        review['client']?['full_name'] as String? ?? 'Cliente';
    final serviceName =
        review['booking']?['service']?['name'] as String? ?? '';
    final rating = review['rating'] as int;
    final comment = review['comment'] as String?;
    final createdAt = DateTime.tryParse(review['created_at'] as String? ?? '');
    final dateStr = createdAt != null
        ? '${createdAt.day}/${createdAt.month}/${createdAt.year}'
        : '';
    final initials = _getInitials(clientName);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF0D1B2E),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                initials,
                style: GoogleFonts.dmSerifDisplay(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        clientName,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0D1B2E),
                        ),
                      ),
                    ),
                    Text(
                      dateStr,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildStars(rating.toDouble(), size: 14),
                    if (serviceName.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF5FF),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          serviceName,
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1D6FEB),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (comment != null && comment.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    comment,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: const Color(0xFF374151),
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStars(double value, {double size = 16}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < value.floor();
        final half = !filled && i < value;
        return Icon(
          filled
              ? Icons.star_rounded
              : half
              ? Icons.star_half_rounded
              : Icons.star_outline_rounded,
          size: size,
          color: const Color(0xFFFBBF24),
        );
      }),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1D6FEB) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? const Color(0xFF1D6FEB)
                : const Color(0xFFE2E8F2),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
