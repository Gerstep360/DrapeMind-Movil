import 'package:flutter/material.dart';
import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/segundo_parcial/cu30_resenas/cu30_review_models.dart';
import 'package:drapemind_mobile/segundo_parcial/cu30_resenas/cu30_review_service.dart';

class ProductReviewsWidget extends StatefulWidget {
  final int productId;
  final String productName;
  final ReviewService? service;

  const ProductReviewsWidget({
    super.key,
    required this.productId,
    this.productName = 'Prenda',
    this.service,
  });

  @override
  State<ProductReviewsWidget> createState() => _ProductReviewsWidgetState();
}

class _ProductReviewsWidgetState extends State<ProductReviewsWidget> {
  late final ReviewService _service = widget.service ?? ReviewService();

  bool _loading = true;
  bool _submitting = false;
  bool _showForm = false;
  ProductReviewsResponse? _data;
  String? _errorMessage;
  int _generation = 0;

  @override
  void didUpdateWidget(covariant ProductReviewsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId) {
      _data = null;
      _showForm = false;
      _submitting = false;
      _selectedRating = 5;
      _titleController.clear();
      _commentController.clear();
      _fetchReviews();
    }
  }

  // Form controllers
  int _selectedRating = 5;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchReviews() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final res = await _service.getProductReviews(widget.productId);
      if (!mounted || generation != _generation) return;
      setState(() {
        _data = res;
        _loading = false;
        if (res.miResena != null) {
          _selectedRating = res.miResena!.calificacion;
          _titleController.text = res.miResena!.titulo ?? '';
          _commentController.text = res.miResena!.comentario;
        }
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _errorMessage = 'No se pudieron cargar las opiniones.';
      });
    }
  }

  Future<void> _submitReview() async {
    final comment = _commentController.text.trim();
    if (comment.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor escribe un comentario de al menos 3 caracteres.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _service.submitReview(
        productId: widget.productId,
        rating: _selectedRating,
        title: _titleController.text.trim(),
        comment: comment,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _showForm = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Reseña guardada con éxito!'),
          backgroundColor: AppColors.success,
        ),
      );
      _fetchReviews();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'No se pudo guardar tu opinión. Conservamos tu texto para que reintentes.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _deleteReview() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.ink, width: 2),
          borderRadius: BorderRadius.circular(0),
        ),
        title: const Text(
          '¿ELIMINAR RESEÑA?',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          '¿Estás seguro de que deseas eliminar tu opinión de esta prenda?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'CANCELAR',
              style: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: AppColors.ink, width: 2),
                borderRadius: BorderRadius.circular(0),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'ELIMINAR',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await _service.deleteReview(widget.productId);
      if (!mounted) return;
      _commentController.clear();
      _titleController.clear();
      if (!mounted) return;
      setState(() {
        _selectedRating = 5;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu reseña ha sido eliminada.'),
          backgroundColor: AppColors.ink,
        ),
      );
      _fetchReviews();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'No se pudo eliminar tu opinión. Inténtalo de nuevo.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMessage != null)
            Row(
              children: [
                Expanded(child: Text(_errorMessage!)),
                TextButton(
                  onPressed: _fetchReviews,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          // Opinions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'OPINIONES',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
              if (!_showForm)
                GestureDetector(
                  onTap: () => setState(() => _showForm = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lime,
                      border: Border.all(color: AppColors.ink, width: 2),
                      boxShadow: const [
                        BoxShadow(color: AppColors.ink, offset: Offset(2, 2)),
                      ],
                    ),
                    child: Text(
                      _data?.miResena != null ? '✎ EDITAR' : '★ CALIFICAR',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(color: AppColors.ink),
              ),
            )
          else if (_data != null) ...[
            // Tarjeta Resumen de Puntuación
            _buildScoreSummaryCard(_data!),
            const SizedBox(height: 14),

            // Formulario expandible
            if (_showForm) _buildReviewForm(),

            const SizedBox(height: 14),

            // Lista de opiniones
            if (_data!.resenas.isEmpty)
              _buildEmptyState()
            else
              ..._data!.resenas.map((rev) => _buildReviewCard(rev)),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreSummaryCard(ProductReviewsResponse data) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.paperLight,
        border: Border.all(color: AppColors.ink, width: 2),
        boxShadow: const [
          BoxShadow(color: AppColors.ink, offset: Offset(3, 3)),
        ],
      ),
      child: Row(
        children: [
          // Puntuación promedio
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                data.promedio.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < data.promedio.round()
                        ? Icons.star
                        : Icons.star_border,
                    size: 16,
                    color: const Color(0xFFFFB800),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${data.total} ${data.total == 1 ? "opinión" : "opiniones"}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Barras de distribución
          Expanded(
            child: Column(
              children: [5, 4, 3, 2, 1].map((stars) {
                final count = data.distribucion[stars.toString()] ?? 0;
                final pct = data.total > 0 ? (count / data.total) : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    children: [
                      Text(
                        '$stars★',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.paperDark,
                            border: Border.all(color: AppColors.ink, width: 1),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: pct.clamp(0.0, 1.0),
                            child: Container(color: AppColors.lime),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '($count)',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewForm() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.paperLight,
        border: Border.all(color: AppColors.ink, width: 2),
        boxShadow: const [
          BoxShadow(color: AppColors.ink, offset: Offset(3, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _data?.miResena != null
                ? 'ACTUALIZAR TU OPINIÓN'
                : 'DEJA TU OPINIÓN',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),

          // Selector de estrellas
          Wrap(
            spacing: 4,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Calificación: ',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              ...List.generate(
                5,
                (i) => GestureDetector(
                  onTap: () => setState(() => _selectedRating = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: Icon(
                      i < _selectedRating ? Icons.star : Icons.star_border,
                      size: 26,
                      color: const Color(0xFFFFB800),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Título
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Título (opcional)',
              labelStyle: TextStyle(fontSize: 12, color: AppColors.textMuted),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.ink, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.ink, width: 2),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),

          // Comentario
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Comentario sobre la prenda *',
              labelStyle: TextStyle(fontSize: 12, color: AppColors.textMuted),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.ink, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.ink, width: 2),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),

          // Botones de acción
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.lime,
                    foregroundColor: AppColors.ink,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(color: AppColors.ink, width: 2),
                      borderRadius: BorderRadius.circular(0),
                    ),
                  ),
                  onPressed: _submitting ? null : _submitReview,
                  child: Text(
                    _submitting ? 'GUARDANDO...' : 'PUBLICAR',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.ink,
                  side: const BorderSide(color: AppColors.ink, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(0),
                  ),
                ),
                onPressed: () => setState(() => _showForm = false),
                child: const Text(
                  'CANCELAR',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _reviewDate(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    return date == null ? '' : '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildReviewCard(ProductReviewItem rev) {
    final isMine = _data?.miResena?.id == rev.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMine ? const Color(0xFFFFFEEB) : AppColors.paperLight,
        border: Border.all(color: AppColors.ink, width: 1.5),
        boxShadow: const [
          BoxShadow(color: AppColors.ink, offset: Offset(2, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.lime,
                    child: Text(
                      rev.usuarioNombre.isNotEmpty
                          ? rev.usuarioNombre[0].toUpperCase()
                          : 'C',
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rev.usuarioNombre,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          _reviewDate(rev.creadoEn),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: List.generate(
                      5,
                      (i) => Icon(
                        i < rev.calificacion ? Icons.star : Icons.star_border,
                        size: 14,
                        color: const Color(0xFFFFB800),
                      ),
                    ),
                  ),
                  if (rev.compraVerificada) ...[
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cyan,
                        border: Border.all(color: AppColors.ink, width: 1),
                      ),
                      child: const Text(
                        '✓ VERIFICADA',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (rev.titulo != null && rev.titulo!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              rev.titulo!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            rev.comentario,
            style: const TextStyle(
              fontSize: 11,
              height: 1.4,
              color: Color(0xFF333333),
            ),
          ),
          if (isMine) ...[
            const Divider(color: AppColors.line, height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _showForm = true),
                  child: const Text(
                    'Editar',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                GestureDetector(
                  onTap: _deleteReview,
                  child: const Text(
                    'Eliminar',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.danger,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.paperLight,
        border: Border.all(color: AppColors.line, width: 1.5),
      ),
      child: const Column(
        children: [
          Text(
            'Sin opiniones aún',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '¡Sé el primero en calificar esta prenda!',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
