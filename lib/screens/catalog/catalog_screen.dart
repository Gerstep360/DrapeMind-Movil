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
        title: const Text('DRAPEMIND ATELIER'),
        actions: [
          IconButton(
            icon: AppSvg.raw(AppSvg.search, size: 18, color: AppColors.white),
            onPressed: _loadInitialData,
            tooltip: 'Actualizar catálogo',
          ),
        ],
      ),
      body: Column(
        children: [
          // SEARCH & FILTER BAR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.paperLight,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar por prenda, tela, color...',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(12),
                            child: AppSvg.raw(
                              AppSvg.search,
                              size: 16,
                              color: AppColors.forest,
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
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (_) => _filterProducts(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                      ),
                      onPressed: _filterProducts,
                      child: AppSvg.raw(
                        AppSvg.filter,
                        size: 18,
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // CATEGORIES CHIPS
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        selected: _selectedCategoryId == null,
                        label: const Text('Todos'),
                        selectedColor: AppColors.forest,
                        labelStyle: TextStyle(
                          color: _selectedCategoryId == null
                              ? AppColors.white
                              : AppColors.textMain,
                          fontWeight: FontWeight.w700,
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
                            label: Text(cat.nombre),
                            selectedColor: AppColors.forest,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? AppColors.white
                                  : AppColors.textMain,
                              fontWeight: FontWeight.w700,
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
                    child: CircularProgressIndicator(color: AppColors.forest),
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
                    color: AppColors.forest,
                    onRefresh: _filterProducts,
                    child: GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.65,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
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
    return Card(
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
                                color: AppColors.forest,
                              ),
                            ),
                          )
                        : Center(
                            child: AppSvg.raw(
                              AppSvg.tshirt,
                              size: 36,
                              color: AppColors.forest,
                            ),
                          ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        'Q${product.calidadNivel}',
                        style: const TextStyle(
                          color: AppColors.acid,
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
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMain,
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
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Bs ${product.precio.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: AppColors.forest,
                        ),
                      ),
                      InkWell(
                        onTap: () => _quickAddToCart(product),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.forest,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: AppSvg.raw(
                            AppSvg.bag,
                            size: 15,
                            color: AppColors.white,
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
