import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/core.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_svg.dart';
import '../ar_fitting/ar_fitting_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _catalogService = CatalogService();
  final _reservationService = ReservationService();
  final _branchService = BranchService();

  Product? _product;
  ProductVariant? _selectedVariant;
  bool _isLoading = true;
  bool _isFavorite = false;
  bool _togglingFavorite = false;
  bool _reserving = false;
  String? _errorMessage;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final p = await _catalogService.getProductDetail(widget.productId);
      setState(() {
        _product = p;
        if (p.variantes.isNotEmpty) {
          _selectedVariant = p.variantes.firstWhere(
            (v) => v.stockDisponible > 0,
            orElse: () => p.variantes.first,
          );
        }
        _isLoading = false;
      });
      try {
        final favorites = await _catalogService.getFavorites();
        if (mounted) {
          setState(
            () => _isFavorite = favorites.any(
              (item) => item.id == widget.productId,
            ),
          );
        }
      } catch (_) {
        // Product detail remains available even if the authenticated list fails.
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'No se pudo cargar la información de la prenda.';
        _isLoading = false;
      });
    }
  }

  void _addToCart() async {
    if (_selectedVariant == null) return;
    final cart = context.read<CartService>();

    try {
      await cart.addItem(_selectedVariant!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.forest,
            content: Text(
              '${_product!.nombre} (${_selectedVariant!.color}, ${_selectedVariant!.talla}) añadida al perchero',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('No se pudo añadir al perchero.'),
          ),
        );
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (_product == null || _togglingFavorite) return;
    final previous = _isFavorite;
    setState(() {
      _isFavorite = !previous;
      _togglingFavorite = true;
    });
    try {
      if (previous) {
        await _catalogService.removeFavorite(widget.productId);
      } else {
        await _catalogService.addFavorite(widget.productId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.forest,
            content: Text(
              previous
                  ? 'Prenda eliminada de favoritos.'
                  : 'Prenda guardada en favoritos.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isFavorite = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo cambiar el favorito.')),
        );
      }
    } finally {
      if (mounted) setState(() => _togglingFavorite = false);
    }
  }

  Future<void> _createReservation() async {
    if (_selectedVariant == null || _product == null || _reserving) return;
    setState(() => _reserving = true);
    try {
      final results = await Future.wait([
        _branchService.getBranches(),
        _branchService.getProductAvailability(_product!.id),
      ]);
      final branches = results[0] as List<Branch>;
      final availability = (results[1] as List<BranchStock>)
          .where(
            (row) =>
                row.varianteId == _selectedVariant!.id &&
                row.stockDisponible > 0,
          )
          .toList();
      final branchById = {for (final branch in branches) branch.id: branch};
      if (!mounted) return;
      if (availability.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.warning,
            content: Text(
              'Esta talla y color no están disponibles para reserva en showroom.',
            ),
          ),
        );
        return;
      }

      final branchId = await showModalBottomSheet<int>(
        context: context,
        backgroundColor: AppColors.paperLight,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'ELIGE TU SHOWROOM',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.3,
                    color: AppColors.forest,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${_product!.nombre} · ${_selectedVariant!.color} · talla ${_selectedVariant!.talla}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                ...availability.map((row) {
                  final branch = branchById[row.sucursalId];
                  return Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.storefront_outlined,
                        color: AppColors.forest,
                      ),
                      title: Text(
                        branch?.nombre ?? 'Sucursal ${row.sucursalId}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${branch?.direccion ?? ''}\n${row.stockDisponible} disponibles',
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () => Navigator.pop(sheetContext, row.sucursalId),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      );
      if (branchId == null || !mounted) return;

      final reservation = await _reservationService.createReservation(
        varianteId: _selectedVariant!.id,
        sucursalId: branchId,
        observacion: 'Reserva desde la ficha móvil de ${_product!.nombre}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.forest,
            content: Text(
              'Reserva ${reservation.codigoPublico} confirmada por 48 horas.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.danger,
            content: Text(
              'No se pudo crear la reserva. Revisa la conexión e inténtalo otra vez.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _reserving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(_product?.nombre ?? 'Detalle de Prenda'),
        actions: [
          if (_product != null)
            IconButton(
              onPressed: _togglingFavorite ? null : _toggleFavorite,
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: AppColors.acid,
              ),
              tooltip: _isFavorite
                  ? 'Quitar de favoritos'
                  : 'Guardar en favoritos',
            ),
          if (_product != null)
            IconButton(
              icon: AppSvg.raw(AppSvg.sparkle, size: 20, color: AppColors.acid),
              tooltip: 'Probar en Espejo AR',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ArFittingScreen(
                      product: _product!,
                      initialVariant: _selectedVariant,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.forest),
            )
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : _product == null
          ? const Center(child: Text('Prenda no encontrada'))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // IMAGE CAROUSEL
                        SizedBox(
                          height: 320,
                          child: Stack(
                            children: [
                              PageView.builder(
                                itemCount: _product!.allImageUrls.isNotEmpty
                                    ? _product!.allImageUrls.length
                                    : 1,
                                onPageChanged: (i) =>
                                    setState(() => _currentImageIndex = i),
                                itemBuilder: (context, index) {
                                  final url = _product!.allImageUrls.isNotEmpty
                                      ? _product!.allImageUrls[index]
                                      : '';
                                  return Container(
                                    color: AppColors.paperDark,
                                    child: url.isNotEmpty
                                        ? Image.network(
                                            url,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Center(
                                                  child: AppSvg.raw(
                                                    AppSvg.tshirt,
                                                    size: 64,
                                                    color: AppColors.forest,
                                                  ),
                                                ),
                                          )
                                        : Center(
                                            child: AppSvg.raw(
                                              AppSvg.tshirt,
                                              size: 64,
                                              color: AppColors.forest,
                                            ),
                                          ),
                                  );
                                },
                              ),
                              Positioned(
                                top: 12,
                                left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.ink,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: Text(
                                    'Calidad Q${_product!.calidadNivel}',
                                    style: const TextStyle(
                                      color: AppColors.acid,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                              if (_product!.allImageUrls.length > 1)
                                Positioned(
                                  bottom: 10,
                                  left: 0,
                                  right: 0,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(
                                      _product!.allImageUrls.length,
                                      (dotIndex) => Container(
                                        width: 6,
                                        height: 6,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _currentImageIndex == dotIndex
                                              ? AppColors.forest
                                              : AppColors.lineStrong,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // INFO CARD
                        Container(
                          padding: const EdgeInsets.all(20),
                          color: AppColors.white,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _product!.nombre,
                                style: const TextStyle(
                                  fontFamily: 'serif',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.forestDark,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Bs ${_product!.precio.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.forest,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 12),

                              // VARIANTS SELECTOR
                              const Text(
                                'SELECCIONA VARIANTE (COLOR Y TALLA)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                  color: AppColors.textMutedStrong,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _product!.variantes.map((v) {
                                  final isSelected =
                                      _selectedVariant?.id == v.id;
                                  final hasStock = v.stockDisponible > 0;
                                  return ChoiceChip(
                                    selected: isSelected,
                                    label: Text(
                                      '${v.color} · ${v.talla} (${v.stockDisponible} en stock)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? AppColors.white
                                            : (hasStock
                                                  ? AppColors.textMain
                                                  : AppColors.textMuted),
                                      ),
                                    ),
                                    selectedColor: AppColors.forest,
                                    backgroundColor: hasStock
                                        ? AppColors.paperLight
                                        : AppColors.paperDark,
                                    onSelected: hasStock
                                        ? (_) => setState(
                                            () => _selectedVariant = v,
                                          )
                                        : null,
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),

                              // BOTÓN PROBADOR AR INTERACTIVO
                              InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ArFittingScreen(
                                        product: _product!,
                                        initialVariant: _selectedVariant,
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.forestDark,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: AppColors.acid.withAlpha(90),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      AppSvg.raw(
                                        AppSvg.sparkle,
                                        size: 20,
                                        color: AppColors.acid,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'PROBADOR VIRTUAL AR & CALCE POR TALLA',
                                              style: TextStyle(
                                                color: AppColors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.8,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Pruébate esta prenda en talla ${_selectedVariant?.talla ?? "M"}, ajusta tu silueta y compara holguras en vivo.',
                                              style: const TextStyle(
                                                color: AppColors.paper,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.arrow_forward_ios,
                                        size: 14,
                                        color: AppColors.acid,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // MATERIAL & DETAILS
                              if (_product!.material != null) ...[
                                Row(
                                  children: [
                                    const Text(
                                      'Material / Tela: ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      _product!.material!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textMutedStrong,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],

                              if (_product!.descripcion != null &&
                                  _product!.descripcion!.isNotEmpty) ...[
                                const Text(
                                  'Descripción',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _product!.descripcion!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: AppColors.textMain,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              // AI TAGS
                              if (_product!.tagsAi != null &&
                                  _product!.tagsAi!.isNotEmpty) ...[
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: _product!.tagsAi!.map((tag) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.paper,
                                        borderRadius: BorderRadius.circular(2),
                                        border: Border.all(
                                          color: AppColors.line,
                                        ),
                                      ),
                                      child: Text(
                                        '#$tag',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.forest,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // BOTTOM ACTION BAR
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    border: Border(
                      top: BorderSide(color: AppColors.lineStrong),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _reserving ? null : _createReservation,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AppSvg.raw(
                                  AppSvg.clock,
                                  size: 16,
                                  color: AppColors.forest,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _reserving
                                      ? 'Consultando...'
                                      : 'Reservar 48h',
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _addToCart,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AppSvg.raw(
                                  AppSvg.bag,
                                  size: 16,
                                  color: AppColors.white,
                                ),
                                const SizedBox(width: 6),
                                const Text('Al Perchero'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
