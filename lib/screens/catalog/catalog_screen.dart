import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/core.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_svg.dart';
import 'product_detail_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _catalogService = CatalogService();
  final _searchController = TextEditingController();

  List<Category> _categories = [];
  List<Product> _products = [];
  int? _selectedCategoryId;
  String? _selectedGender;
  int? _selectedQuality;
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
      setState(() {
        _categories = cats;
        _products = prods;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'No se pudo conectar al showroom.';
        _isLoading = false;
      });
    }
  }

  Future<void> _filterProducts() async {
    setState(() => _isLoading = true);
    try {
      final prods = await _catalogService.getProducts(
        categoriaId: _selectedCategoryId,
        query: _searchController.text.trim(),
        calidadMin: _selectedQuality,
        genero: (_selectedGender != null && _selectedGender!.isNotEmpty)
            ? _selectedGender
            : null,
      );
      setState(() {
        _products = prods;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al filtrar prendas.';
        _isLoading = false;
      });
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
            backgroundColor: AppColors.forest,
            content: Text('${product.nombre} agregada a tu perchero'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('No se pudo añadir la prenda al perchero.'),
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
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.ink,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'D',
                  style: TextStyle(
                    color: AppColors.lime,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'DRAPEMIND',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
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
            icon: AppSvg.raw(AppSvg.search, size: 20, color: AppColors.ink),
            onPressed: _loadInitialData,
            tooltip: 'Actualizar showroom',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // SEARCH & FILTER BAR
          Container(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            color: AppColors.paper,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Buscar prendas, marcas, telas...',
                            hintStyle: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
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
                                      _filterProducts();
                                    },
                                  )
                                : null,
                            isDense: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => _filterProducts(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(
                        color: AppColors.ink,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: AppSvg.raw(
                          AppSvg.filter,
                          size: 18,
                          color: AppColors.white,
                        ),
                        onPressed: _filterProducts,
                        tooltip: 'Filtrar prendas',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // CATEGORIES CHIPS (DRAPEMIND STYLE: LIME ACTIVE PILL)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        selected: _selectedCategoryId == null,
                        showCheckmark: false,
                        label: const Text('Todos'),
                        selectedColor: AppColors.lime,
                        backgroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                          side: BorderSide(
                            color: _selectedCategoryId == null
                                ? AppColors.lime
                                : AppColors.line,
                          ),
                        ),
                        labelStyle: TextStyle(
                          color: AppColors.ink,
                          fontWeight: _selectedCategoryId == null
                              ? FontWeight.w800
                              : FontWeight.w600,
                          fontSize: 12,
                        ),
                        onSelected: (_) {
                          setState(() => _selectedCategoryId = null);
                          _filterProducts();
                        },
                      ),
                      const SizedBox(width: 6),
                      ..._categories.map((cat) {
                        final isSelected = _selectedCategoryId == cat.id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            selected: isSelected,
                            showCheckmark: false,
                            label: Text(cat.nombre),
                            selectedColor: AppColors.lime,
                            backgroundColor: AppColors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.lime
                                    : AppColors.line,
                              ),
                            ),
                            labelStyle: TextStyle(
                              color: AppColors.ink,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              fontSize: 12,
                            ),
                            onSelected: (_) {
                              setState(
                                () => _selectedCategoryId = isSelected
                                    ? null
                                    : cat.id,
                              );
                              _filterProducts();
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // PRODUCTS GRID / STATE
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.ink),
                  )
                : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppSvg.raw(
                          AppSvg.close,
                          size: 48,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: 12),
                        Text(_errorMessage!),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadInitialData,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  )
                : _products.isEmpty
                ? const Center(
                    child: Text(
                      'No se encontraron prendas con estos filtros.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  )
                : RefreshIndicator(
                    color: AppColors.ink,
                    onRefresh: _filterProducts,
                    child: GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.64,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        return _buildProductCard(product);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0610110F),
            blurRadius: 16,
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
            // IMAGE & BADGES
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: AppColors.paperDark,
                    child: product.mainImageUrl.isNotEmpty
                        ? Image.network(
                            product.mainImageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: AppSvg.raw(
                                AppSvg.tshirt,
                                size: 36,
                                color: AppColors.ink,
                              ),
                            ),
                          )
                        : Center(
                            child: AppSvg.raw(
                              AppSvg.tshirt,
                              size: 36,
                              color: AppColors.ink,
                            ),
                          ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
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
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // DETAILS
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (product.material != null)
                    Text(
                      product.material!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Bs ${product.precio.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                      InkWell(
                        onTap: () => _quickAddToCart(product),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.lime,
                            shape: BoxShape.circle,
                          ),
                          child: AppSvg.raw(
                            AppSvg.bag,
                            size: 15,
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
}
