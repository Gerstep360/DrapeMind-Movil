import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drapemind_mobile/compartido/componentes/productos/dm_product_card.dart';
import 'package:drapemind_mobile/core/core.dart';
import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/core/theme/app_svg.dart';
import 'package:drapemind_mobile/paquetes/catalogo_comercializacion/buscar_filtrar_prendas/aplicacion/filtrar_prendas.dart';
import 'package:drapemind_mobile/paquetes/catalogo_comercializacion/buscar_filtrar_prendas/dominio/catalog_filter.dart';
import 'package:drapemind_mobile/paquetes/catalogo_comercializacion/consultar_detalle_talla_color_variante/presentacion/product_detail_screen.dart';
import 'package:drapemind_mobile/paquetes/catalogo_comercializacion/gestionar_favoritos/presentacion/favorites_screen.dart';
import 'package:drapemind_mobile/paquetes/notificaciones/presentacion/notifications_screen.dart';

class CatalogScreen extends StatefulWidget {
  final VoidCallback? onOpenAiStudio;
  const CatalogScreen({super.key, this.onOpenAiStudio});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _catalogService = CatalogService();
  final _filterProducts = const FiltrarPrendas();
  final _searchController = TextEditingController();
  final _aiQueryController = TextEditingController();

  List<Category> _categories = [];
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  Set<int> _favoriteIds = {};

  int? _selectedCategoryId;
  String _selectedGender = 'TODOS';
  double? _maxPriceFilter;
  String _activeOccasion = 'TODOS';
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _aiQueryController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cats = await _catalogService.getCategories();
      final prods = await _catalogService.getProducts();

      // Load favorites if user is authenticated
      try {
        final favs = await _catalogService.getFavorites();
        _favoriteIds = favs.map((f) => f.id).toSet();
      } catch (_) {}

      setState(() {
        _categories = cats;
        _allProducts = prods;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() {
        _errorMessage = 'No se pudo conectar al showroom de DrapeMind.';
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredProducts = _filterProducts(
        products: _allProducts,
        categories: _categories,
        filter: CatalogFilter(
          categoryId: _selectedCategoryId,
          gender: _selectedGender,
          maxPrice: _maxPriceFilter,
          query: _searchController.text,
          semanticQuery: _aiQueryController.text,
        ),
      );
    });
  }

  void _filterByCollection(String occasion) {
    final preset = CatalogPresets.byKey(occasion);
    setState(() {
      _activeOccasion = preset.key;
      if (preset.clearsFilters) {
        _selectedCategoryId = null;
        _selectedGender = 'TODOS';
        _maxPriceFilter = null;
        _aiQueryController.clear();
        _searchController.clear();
      } else {
        _aiQueryController.text = preset.semanticQuery;
        _maxPriceFilter = preset.maxPrice;
      }
    });
    _applyFilters();
  }

  String _getOccasionDisplayName(String occasion) =>
      CatalogPresets.byKey(occasion).label;

  void _showAiStylistSidebar() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AiStylistDrawerSheet(
        activeOccasion: _activeOccasion,
        aiQueryController: _aiQueryController,
        onSelectOccasion: (occ) {
          _filterByCollection(occ);
        },
        onSearchQuery: () {
          _applyFilters();
        },
        onOpenAiStudio: () {
          final q = _aiQueryController.text.trim();
          if (q.isNotEmpty) {
            context.read<AiSocketService>().sendMessage(
              'Recomiéndame las mejores combinaciones y opciones para: $q',
            );
          }
          widget.onOpenAiStudio?.call();
        },
      ),
    );
  }

  Future<void> _toggleFavorite(Product product) async {
    final isFav = _favoriteIds.contains(product.id);
    setState(() {
      if (isFav) {
        _favoriteIds.remove(product.id);
      } else {
        _favoriteIds.add(product.id);
      }
    });

    try {
      final res = await _catalogService.toggleFavorite(product.id);
      if (mounted) {
        setState(() {
          if (res) {
            _favoriteIds.add(product.id);
          } else {
            _favoriteIds.remove(product.id);
          }
        });
      }
    } catch (_) {
      // Revert if API failed
      if (mounted) {
        setState(() {
          if (isFav) {
            _favoriteIds.add(product.id);
          } else {
            _favoriteIds.remove(product.id);
          }
        });
      }
    }
  }

  void _quickAddToCart(Product product) async {
    final cart = context.read<CartService>();
    final variant = product.variantes.firstWhere(
      (v) => v.stockDisponible > 0,
      orElse: () => product.variantes.isNotEmpty
          ? product.variantes.first
          : ProductVariant(
              id: product.id,
              productoId: product.id,
              sku: '',
              color: 'Único',
              talla: 'Única',
              stockTotal: 1,
              stockReservado: 0,
              stockDisponible: 1,
            ),
    );

    try {
      await cart.addItem(variant.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.ink,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.lime,
                    shape: BoxShape.circle,
                  ),
                  child: AppSvg.raw(
                    AppSvg.check,
                    size: 14,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${product.nombre} agregada al perchero',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: const Text(
              'No se pudo agregar al perchero.',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        titleSpacing: 16,
        elevation: 0,
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: AppColors.ink,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'D',
                  style: TextStyle(
                    color: AppColors.lime,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'DrapeMind',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.cyan,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'SHOWROOM',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.favorite_border, color: AppColors.ink, size: 22),
                if (_favoriteIds.isNotEmpty)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        '${_favoriteIds.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'Mis Favoritos (CU-08)',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FavoritesScreen()),
              );
              if (mounted) _loadInitialData();
            },
          ),
          IconButton(
            icon: AppSvg.raw(AppSvg.refresh, size: 19, color: AppColors.ink),
            onPressed: _loadInitialData,
            tooltip: 'Actualizar catálogo',
          ),
          Consumer<PushNotificationService>(
            builder: (context, pushService, _) {
              final unread = pushService.unreadCount;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_outlined, size: 24, color: AppColors.ink),
                    tooltip: 'Notificaciones Atelier',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                    ),
                  ),
                  if (unread > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.gold,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          unread > 9 ? '9+' : '$unread',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.ink,
        backgroundColor: AppColors.lime,
        onRefresh: _loadInitialData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. EDITORIAL HERO HEADING
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'COLECCIÓN DRAPEMIND',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                        color: AppColors.textMutedStrong,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Catálogo de Moda.',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                        color: AppColors.ink,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Prendas seleccionadas con trazabilidad de stock en tiempo real y asistencia inteligente de estilo.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              // 2. AI STYLING CONCIERGE ACCESS BAR (Clean & Breathable)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFD6EBA5),
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0610110F),
                      blurRadius: 14,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: const BoxDecoration(
                        color: AppColors.ink,
                        shape: BoxShape.circle,
                      ),
                      child: AppSvg.raw(
                        AppSvg.sparkle,
                        size: 16,
                        color: AppColors.lime,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Personal Stylist IA',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.lime,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'ALTAIR',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _activeOccasion != 'TODOS' ||
                                    _aiQueryController.text.isNotEmpty
                                ? 'Filtro activo: ${_getOccasionDisplayName(_activeOccasion)}'
                                : 'Explora por ocasión, estilo o pide un look a medida',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.ink,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        elevation: 0,
                      ),
                      onPressed: _showAiStylistSidebar,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Explorar',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 10,
                            color: AppColors.lime,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Active AI Filter Notification (if selected)
              if (_activeOccasion != 'TODOS' ||
                  _aiQueryController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7FCE8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD6EBA5)),
                    ),
                    child: Row(
                      children: [
                        AppSvg.raw(
                          AppSvg.sparkle,
                          size: 13,
                          color: AppColors.ink,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Filtrado por: ${_getOccasionDisplayName(_activeOccasion)}${_aiQueryController.text.isNotEmpty ? ' ("${_aiQueryController.text}")' : ""}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => _filterByCollection('TODOS'),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.ink,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 12,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 3. TOOLBAR / SEARCH & FILTERS
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Search bar
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText:
                              'Buscar por polera, camisa, jeans, color...',
                          hintStyle: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textMuted,
                          ),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(12),
                            child: AppSvg.raw(
                              AppSvg.search,
                              size: 16,
                              color: AppColors.ink,
                            ),
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: AppSvg.raw(
                                    AppSvg.close,
                                    size: 14,
                                    color: AppColors.textMuted,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    _applyFilters();
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (_) => _applyFilters(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Gender chips row (TODOS, HOMBRE, MUJER, UNISEX)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final g in [
                            'TODOS',
                            'HOMBRE',
                            'MUJER',
                            'UNISEX',
                          ])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(g),
                                selected: _selectedGender == g,
                                selectedColor: AppColors.ink,
                                backgroundColor: AppColors.white,
                                showCheckmark: false,
                                labelStyle: TextStyle(
                                  color: _selectedGender == g
                                      ? AppColors.white
                                      : AppColors.ink,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11.5,
                                  letterSpacing: 0.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                  side: BorderSide(
                                    color: _selectedGender == g
                                        ? AppColors.ink
                                        : AppColors.line,
                                  ),
                                ),
                                onSelected: (sel) {
                                  if (sel) {
                                    setState(() => _selectedGender = g);
                                    _applyFilters();
                                  }
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Category tabs row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildCategoryTab(
                            title: 'Todas las Categorías',
                            isSelected: _selectedCategoryId == null,
                            onTap: () {
                              setState(() => _selectedCategoryId = null);
                              _applyFilters();
                            },
                          ),
                          for (final cat in _categories)
                            _buildCategoryTab(
                              title: cat.nombre,
                              isSelected: _selectedCategoryId == cat.id,
                              onTap: () {
                                setState(() {
                                  _selectedCategoryId =
                                      _selectedCategoryId == cat.id
                                      ? null
                                      : cat.id;
                                });
                                _applyFilters();
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Price Budget filter row (Cualquier precio, Hasta Bs 200, 400, 750)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const Text(
                            'Presupuesto: ',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMutedStrong,
                            ),
                          ),
                          _buildPriceChip('Cualquier precio', null),
                          _buildPriceChip('Hasta Bs 200', 200.0),
                          _buildPriceChip('Hasta Bs 400', 400.0),
                          _buildPriceChip('Hasta Bs 750', 750.0),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 4. PRODUCTS SECTION
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: AppColors.ink),
                        SizedBox(height: 16),
                        Text(
                          'Consultando el perchero y stock...',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 40,
                    horizontal: 20,
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        AppSvg.raw(
                          AppSvg.close,
                          size: 44,
                          color: AppColors.danger,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.ink,
                            foregroundColor: AppColors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          onPressed: _loadInitialData,
                          child: const Text('Reintentar conexión'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_filteredProducts.isEmpty)
                _buildEmptyState()
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.58,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 14,
                        ),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, idx) {
                      return _buildProductCard(_filteredProducts[idx]);
                    },
                  ),
                ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTab({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.lime : AppColors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected ? AppColors.lime : AppColors.line,
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriceChip(String label, double? price) {
    final isSelected = _maxPriceFilter == price;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () {
          setState(() => _maxPriceFilter = price);
          _applyFilters();
        },
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.ink : AppColors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected ? AppColors.ink : AppColors.line,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? AppColors.white : AppColors.textMutedStrong,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product) => DmProductCard(
    product: product,
    isFavorite: _favoriteIds.contains(product.id),
    onOpen: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(productId: product.id),
      ),
    ),
    onFavorite: () => _toggleFavorite(product),
    onQuickAdd: () => _quickAddToCart(product),
  );
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 24),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.limeSoft.withAlpha(150),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: AppSvg.raw(
                  AppSvg.sparkle,
                  size: 34,
                  color: AppColors.ink,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '0 PRENDAS ENCONTRADAS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: AppColors.textMutedStrong,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No encontramos prendas con los filtros seleccionados.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onPressed: () => _filterByCollection('TODOS'),
              child: const Text(
                'Restablecer filtros',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SIDEBAR / SHEET DE ESTILO IA (ALTAIR PERSONAL STYLIST)
// -----------------------------------------------------------------------------
class _AiStylistDrawerSheet extends StatelessWidget {
  final String activeOccasion;
  final TextEditingController aiQueryController;
  final ValueChanged<String> onSelectOccasion;
  final VoidCallback onSearchQuery;
  final VoidCallback onOpenAiStudio;

  const _AiStylistDrawerSheet({
    required this.activeOccasion,
    required this.aiQueryController,
    required this.onSelectOccasion,
    required this.onSearchQuery,
    required this.onOpenAiStudio,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.lineStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: const BoxDecoration(
                    color: AppColors.ink,
                    shape: BoxShape.circle,
                  ),
                  child: AppSvg.raw(
                    AppSvg.sparkle,
                    size: 16,
                    color: AppColors.lime,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PERSONAL STYLIST IA',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        'Explora el catálogo según ocasión y estilo',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: AppColors.ink),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'OCASIONES DE USO ATELIER',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildOccasionCard(
                    context: context,
                    keyName: 'CENA',
                    title: 'Cena & Noche Elegante',
                    description:
                        'Prendas de seda, cortes depurados, vestidos y tonos nocturnos.',
                    badge: 'Sartorial',
                    icon: Icons.nightlife,
                  ),
                  const SizedBox(height: 10),
                  _buildOccasionCard(
                    context: context,
                    keyName: 'POLERAS_TOP',
                    title: 'Poleras de Alta Gama',
                    description:
                        'Básicos de lujo en algodón pima peruano, siluetas contemporáneas.',
                    badge: 'Esenciales',
                    icon: Icons.checkroom,
                  ),
                  const SizedBox(height: 10),
                  _buildOccasionCard(
                    context: context,
                    keyName: 'CASUAL_ECONOMICO',
                    title: 'Casual por menos de Bs 300',
                    description:
                        'Opciones versátiles de uso diario con diseño editorial.',
                    badge: 'Presupuesto',
                    icon: Icons.local_offer_outlined,
                  ),
                  const SizedBox(height: 10),
                  _buildOccasionCard(
                    context: context,
                    keyName: 'TODOS',
                    title: 'Todo el Catálogo',
                    description:
                        'Mostrar todas las prendas y colecciones activas sin filtro.',
                    badge: 'Completo',
                    icon: Icons.grid_view,
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'BÚSQUEDA ASISTIDA POR PALABRA CLAVE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.line),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: aiQueryController,
                            decoration: const InputDecoration(
                              hintText:
                                  "Ej: 'lino', 'seda', 'negro', 'blazer'...",
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                              border: InputBorder.none,
                            ),
                            onSubmitted: (_) {
                              onSearchQuery();
                              Navigator.pop(context);
                            },
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.ink,
                            foregroundColor: AppColors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                          ),
                          onPressed: () {
                            onSearchQuery();
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Aplicar',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  // Button to jump to AI Studio
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.forest,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        onOpenAiStudio();
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AppSvg.raw(
                            AppSvg.sparkle,
                            size: 16,
                            color: AppColors.acid,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Consultar a Altair en Stylist IA →',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
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

  Widget _buildOccasionCard({
    required BuildContext context,
    required String keyName,
    required String title,
    required String description,
    required String badge,
    required IconData icon,
  }) {
    final isSelected = activeOccasion == keyName;

    return InkWell(
      onTap: () {
        onSelectOccasion(keyName);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.white : AppColors.paperLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.ink : AppColors.line,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x0C10110F),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.lime : AppColors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.line),
              ),
              child: Icon(icon, size: 20, color: AppColors.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.paperDark,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMutedStrong,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.ink,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 12, color: AppColors.lime),
              ),
          ],
        ),
      ),
    );
  }
}
