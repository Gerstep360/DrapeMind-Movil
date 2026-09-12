import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/core.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_svg.dart';
import 'product_detail_screen.dart';

class CatalogScreen extends StatefulWidget {
  final VoidCallback? onOpenAiStudio;
  const CatalogScreen({super.key, this.onOpenAiStudio});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _catalogService = CatalogService();
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
    final searchTxt = _searchController.text.trim().toLowerCase();
    final aiTxt = _aiQueryController.text.trim().toLowerCase();

    setState(() {
      _filteredProducts = _allProducts.where((p) {
        // Category filter
        if (_selectedCategoryId != null && p.categoriaId != _selectedCategoryId) {
          return false;
        }

        // Gender filter
        if (_selectedGender != 'TODOS') {
          final g = p.generoObjetivo.toUpperCase();
          if (g != _selectedGender && g != 'UNISEX') {
            return false;
          }
        }

        // Price filter
        if (_maxPriceFilter != null && p.precio > _maxPriceFilter!) {
          return false;
        }

        // Search text filter
        if (searchTxt.isNotEmpty) {
          final name = p.nombre.toLowerCase();
          final desc = (p.descripcion ?? '').toLowerCase();
          final brand = (p.marca ?? '').toLowerCase();
          final mat = (p.material ?? '').toLowerCase();
          if (!name.contains(searchTxt) &&
              !desc.contains(searchTxt) &&
              !brand.contains(searchTxt) &&
              !mat.contains(searchTxt)) {
            return false;
          }
        }

        // AI Concierge query filter
        if (aiTxt.isNotEmpty) {
          final name = p.nombre.toLowerCase();
          final desc = (p.descripcion ?? '').toLowerCase();
          final mat = (p.material ?? '').toLowerCase();
          final cat = _categories
              .firstWhere(
                (c) => c.id == p.categoriaId,
                orElse: () => Category(id: 0, nombre: '', slug: ''),
              )
              .nombre
              .toLowerCase();
          if (!name.contains(aiTxt) &&
              !desc.contains(aiTxt) &&
              !mat.contains(aiTxt) &&
              !cat.contains(aiTxt)) {
            return false;
          }
        }

        return true;
      }).toList();
    });
  }

  void _filterByCollection(String occasion) {
    setState(() {
      _activeOccasion = occasion;
      if (occasion == 'TODOS') {
        _selectedCategoryId = null;
        _selectedGender = 'TODOS';
        _maxPriceFilter = null;
        _aiQueryController.clear();
        _searchController.clear();
      } else if (occasion == 'CENA') {
        _aiQueryController.text = 'seda';
        _maxPriceFilter = null;
      } else if (occasion == 'POLERAS_TOP') {
        _aiQueryController.text = 'polera';
        _maxPriceFilter = null;
      } else if (occasion == 'CASUAL_ECONOMICO') {
        _maxPriceFilter = 300.0;
        _aiQueryController.clear();
      }
    });
    _applyFilters();
  }

  String _getOccasionDisplayName(String occasion) {
    switch (occasion) {
      case 'CENA':
        return 'Cena & Noche Elegante';
      case 'POLERAS_TOP':
        return 'Poleras de Alta Gama';
      case 'CASUAL_ECONOMICO':
        return 'Casual < Bs 300';
      case 'TODOS':
      default:
        return 'Catálogo Completo';
    }
  }

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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.lime,
                    shape: BoxShape.circle,
                  ),
                  child: AppSvg.raw(AppSvg.check, size: 14, color: AppColors.ink),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: const Text(
              'No se pudo agregar al perchero.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
            icon: AppSvg.raw(AppSvg.refresh, size: 19, color: AppColors.ink),
            onPressed: _loadInitialData,
            tooltip: 'Actualizar catálogo',
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFD6EBA5), width: 1.5),
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
                      child: AppSvg.raw(AppSvg.sparkle, size: 16, color: AppColors.lime),
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
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
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
                            _activeOccasion != 'TODOS' || _aiQueryController.text.isNotEmpty
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
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        elevation: 0,
                      ),
                      onPressed: _showAiStylistSidebar,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Explorar',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.lime),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Active AI Filter Notification (if selected)
              if (_activeOccasion != 'TODOS' || _aiQueryController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7FCE8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD6EBA5)),
                    ),
                    child: Row(
                      children: [
                        AppSvg.raw(AppSvg.sparkle, size: 13, color: AppColors.ink),
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
                            child: const Icon(Icons.close, size: 12, color: AppColors.white),
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
                          hintText: 'Buscar por polera, camisa, jeans, color...',
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
                          for (final g in ['TODOS', 'HOMBRE', 'MUJER', 'UNISEX'])
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
                                      _selectedCategoryId == cat.id ? null : cat.id;
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
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  child: Center(
                    child: Column(
                      children: [
                        AppSvg.raw(AppSvg.close, size: 44, color: AppColors.danger),
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
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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

  Widget _buildProductCard(Product product) {
    final isFavorite = _favoriteIds.contains(product.id);
    final hasStock = (product.stockDisponible) > 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0810110F),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(productId: product.id),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // IMAGE CONTAINER (Aspect Ratio ~ 4:5)
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: const Color(0xFFF7F8F2),
                    child: product.mainImageUrl.isNotEmpty
                        ? Image.network(
                            product.mainImageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholderGraphic(product),
                          )
                        : _buildPlaceholderGraphic(product),
                  ),

                  // FAVORITE TOGGLE (Top Right)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: InkWell(
                      onTap: () => _toggleFavorite(product),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.white.withAlpha(235),
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1410110F),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                          color: isFavorite ? AppColors.danger : AppColors.ink,
                        ),
                      ),
                    ),
                  ),

                  // QUALITY & GENDER BADGES (Bottom Left)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.ink,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Q${product.calidadNivel}',
                            style: const TextStyle(
                              color: AppColors.lime,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (product.generoObjetivo.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.white.withAlpha(230),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Text(
                              product.generoObjetivo,
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // PRODUCT DETAILS (Bottom)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand
                  Text(
                    (product.marca ?? 'DRAPEMIND STUDIO').toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 3),

                  // Title
                  Text(
                    product.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Price & Stock
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Bs ${product.precio.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          color: AppColors.ink,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: hasStock ? const Color(0xFFEAF8ED) : const Color(0xFFFDE8E8),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          hasStock ? '${product.stockDisponible} stock' : 'Agotado',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: hasStock ? AppColors.success : AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Quick Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.ink,
                            foregroundColor: AppColors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProductDetailScreen(productId: product.id),
                              ),
                            );
                          },
                          child: const Text(
                            'Ver Prenda',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => _quickAddToCart(product),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: const BoxDecoration(
                            color: AppColors.lime,
                            shape: BoxShape.circle,
                          ),
                          child: AppSvg.raw(
                            AppSvg.bag,
                            size: 14,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderGraphic(Product product) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.limeSoft.withAlpha(120),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: AppSvg.raw(
                AppSvg.tshirt,
                size: 26,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Muestra Showroom',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

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
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                  child: AppSvg.raw(AppSvg.sparkle, size: 16, color: AppColors.lime),
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
                        style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
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
                    description: 'Prendas de seda, cortes depurados, vestidos y tonos nocturnos.',
                    badge: 'Sartorial',
                    icon: Icons.nightlife,
                  ),
                  const SizedBox(height: 10),
                  _buildOccasionCard(
                    context: context,
                    keyName: 'POLERAS_TOP',
                    title: 'Poleras de Alta Gama',
                    description: 'Básicos de lujo en algodón pima peruano, siluetas contemporáneas.',
                    badge: 'Esenciales',
                    icon: Icons.checkroom,
                  ),
                  const SizedBox(height: 10),
                  _buildOccasionCard(
                    context: context,
                    keyName: 'CASUAL_ECONOMICO',
                    title: 'Casual por menos de Bs 300',
                    description: 'Opciones versátiles de uso diario con diseño editorial.',
                    badge: 'Presupuesto',
                    icon: Icons.local_offer_outlined,
                  ),
                  const SizedBox(height: 10),
                  _buildOccasionCard(
                    context: context,
                    keyName: 'TODOS',
                    title: 'Todo el Catálogo',
                    description: 'Mostrar todas las prendas y colecciones activas sin filtro.',
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: aiQueryController,
                            decoration: const InputDecoration(
                              hintText: "Ej: 'lino', 'seda', 'negro', 'blazer'...",
                              hintStyle: TextStyle(fontSize: 13, color: AppColors.textMuted),
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
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          onPressed: () {
                            onSearchQuery();
                            Navigator.pop(context);
                          },
                          child: const Text('Aplicar', style: TextStyle(fontWeight: FontWeight.w800)),
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
                          AppSvg.raw(AppSvg.sparkle, size: 16, color: AppColors.acid),
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
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
