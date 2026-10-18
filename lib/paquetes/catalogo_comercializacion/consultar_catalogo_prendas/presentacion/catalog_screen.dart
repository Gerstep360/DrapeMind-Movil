import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drapemind_mobile/compartido/componentes/productos/dm_product_card.dart';
import 'package:drapemind_mobile/compartido/componentes/productos/dm_product_image.dart';
import 'package:drapemind_mobile/core/core.dart';
import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/paquetes/catalogo_comercializacion/consultar_detalle_talla_color_variante/presentacion/product_detail_screen.dart';
import 'package:drapemind_mobile/paquetes/catalogo_comercializacion/gestionar_favoritos/presentacion/favorites_screen.dart';

class CatalogScreen extends StatefulWidget {
  final VoidCallback? onOpenAiStudio;
  final CatalogService? catalogService;
  const CatalogScreen({super.key, this.onOpenAiStudio, this.catalogService});
  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  late final CatalogService _service;
  final _search = TextEditingController();
  Timer? _debounce;
  List<Category> _categories = [];
  List<Product> _products = [];
  final Set<int> _favorites = {};
  final Set<int> _savingFavorites = {};
  String _gender = 'TODOS';
  int? _category;
  double? _budget;
  String? _size;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _error;
  int _request = 0;
  static const _pageSize = 24;

  @override
  void initState() {
    super.initState();
    _service = widget.catalogService ?? CatalogService();
    _loadMetadata();
    _loadProducts();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    try {
      final categories = await _service.getCategories();
      if (mounted) setState(() => _categories = categories);
    } catch (_) {}
    try {
      final favorites = await _service.getFavorites();
      if (mounted) {
        setState(() {
          _favorites.clear();
          _favorites.addAll(favorites.map((item) => item.id));
        });
      }
    } catch (_) {}
  }

  Future<void> _loadProducts({bool more = false}) async {
    if (more && (_loading || _loadingMore || !_hasMore)) return;
    final request = ++_request;
    final offset = more ? _products.length : 0;
    setState(() {
      _error = null;
      if (more) {
        _loadingMore = true;
      } else {
        _loading = true;
        _loadingMore = false;
      }
    });
    try {
      final products = await _service.getProducts(
        query: _search.text.trim(),
        categoriaId: _category,
        genero: _gender == 'TODOS' ? null : _gender,
        maxPrice: _budget,
        talla: _size,
        limit: _pageSize,
        offset: offset,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _products = more ? [..._products, ...products] : products;
        _hasMore = products.length == _pageSize;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = 'No pudimos cargar las prendas. Intenta de nuevo.';
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _reset() {
    _debounce?.cancel();
    _search.clear();
    setState(() {
      _category = null;
      _gender = 'TODOS';
      _budget = null;
      _size = null;
    });
    _loadProducts();
  }

  Future<void> _favorite(Product product) async {
    if (!_savingFavorites.add(product.id)) return;
    final wasFavorite = _favorites.contains(product.id);
    setState(() {
      wasFavorite ? _favorites.remove(product.id) : _favorites.add(product.id);
    });
    try {
      if (wasFavorite) {
        await _service.removeFavorite(product.id);
      } else {
        await _service.addFavorite(product.id);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          wasFavorite
              ? _favorites.add(product.id)
              : _favorites.remove(product.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No pudimos actualizar tus favoritos. Intenta de nuevo.',
            ),
          ),
        );
      }
    } finally {
      _savingFavorites.remove(product.id);
    }
  }

  void _openProduct(Product product) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ProductDetailScreen(productId: product.id),
    ),
  );

  void _chooseVariant(Product product) {
    final detail = _service.getProductDetail(product.id);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.white,
      builder: (sheetContext) => FutureBuilder<Product>(
        future: detail,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No pudimos cargar las tallas de esta prenda.'),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Volver a la tienda'),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(48),
              child: Center(
                heightFactor: 1,
                child: CircularProgressIndicator(),
              ),
            );
          }
          return _VariantPicker(
            product: snapshot.data!,
            onAdded: () {
              if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Prenda agregada al carrito')),
                );
              }
            },
          );
        },
      ),
    );
  }

  void _showFilters() {
    var budget = _budget;
    var size = _size;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.white,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, update) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Encuentra tu prenda',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar filtros',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Presupuesto',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final value in <double?>[null, 200, 400, 750])
                    ChoiceChip(
                      label: Text(
                        value == null
                            ? 'Cualquier precio'
                            : 'Hasta Bs ${value.toInt()}',
                      ),
                      selected: budget == value,
                      onSelected: (_) => update(() => budget = value),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Talla',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final value in <String?>[
                    null,
                    'XS',
                    'S',
                    'M',
                    'L',
                    'XL',
                    'XXL',
                    '36',
                    '38',
                    '40',
                    '42',
                  ])
                    ChoiceChip(
                      label: Text(value ?? 'Todas'),
                      selected: size == value,
                      onSelected: (_) => update(() => size = value),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () {
                    setState(() {
                      _budget = budget;
                      _size = size;
                    });
                    Navigator.pop(context);
                    _loadProducts();
                  },
                  child: const Text('Ver prendas'),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: () => update(() {
                    budget = null;
                    size = null;
                  }),
                  child: const Text('Limpiar filtros'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeFilters = (_budget == null ? 0 : 1) + (_size == null ? 0 : 1);
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        title: const Text(
          'DrapeMind',
          style: TextStyle(
            fontSize: 23,
            letterSpacing: -0.8,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Mis favoritos',
            icon: const Icon(Icons.favorite_border_rounded),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FavoritesScreen()),
              );
              if (mounted) _loadMetadata();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadProducts(),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LA COLECCIÓN',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMutedStrong,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Para todos tus días.',
                      style: TextStyle(
                        fontSize: 29,
                        letterSpacing: -1,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _search,
                      maxLength: 150,
                      onChanged: (_) {
                        _debounce?.cancel();
                        _debounce = Timer(
                          const Duration(milliseconds: 350),
                          () => _loadProducts(),
                        );
                      },
                      onSubmitted: (_) {
                        _debounce?.cancel();
                        _loadProducts();
                      },
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'Buscar una prenda, color o marca',
                        prefixIcon: const Icon(Icons.search_rounded, size: 22),
                        filled: true,
                        fillColor: AppColors.white,
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Borrar búsqueda',
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  _search.clear();
                                  _loadProducts();
                                },
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.line),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        for (final item in const [
                          ('TODOS', 'Todo'),
                          ('MUJER', 'Mujer'),
                          ('HOMBRE', 'Hombre'),
                          ('UNISEX', 'Unisex'),
                        ])
                          Expanded(
                            child: Semantics(
                              selected: _gender == item.$1,
                              child: InkWell(
                                onTap: () {
                                  setState(() => _gender = item.$1);
                                  _loadProducts();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: _gender == item.$1
                                            ? AppColors.ink
                                            : AppColors.line,
                                        width: _gender == item.$1 ? 2 : 1,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    item.$2,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: _gender == item.$1
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                  ),
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
            if (_categories.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 46,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('Todas las prendas'),
                          selected: _category == null,
                          onSelected: (_) {
                            setState(() => _category = null);
                            _loadProducts();
                          },
                        ),
                      ),
                      for (final category in _categories)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(category.nombre),
                            selected: _category == category.id,
                            onSelected: (_) {
                              setState(
                                () => _category = _category == category.id
                                    ? null
                                    : category.id,
                              );
                              _loadProducts();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _loading
                            ? 'Buscando tus próximas prendas…'
                            : '${_products.length} prendas para explorar',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMutedStrong,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _showFilters,
                      icon: const Icon(Icons.tune_rounded, size: 17),
                      label: Text(
                        activeFilters > 0
                            ? 'Filtros ($activeFilters)'
                            : 'Filtros',
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (activeFilters > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      if (_size != null)
                        InputChip(
                          label: Text('Talla $_size'),
                          onDeleted: () {
                            setState(() => _size = null);
                            _loadProducts();
                          },
                        ),
                      if (_budget != null)
                        InputChip(
                          label: Text('Hasta Bs ${_budget!.toInt()}'),
                          onDeleted: () {
                            setState(() => _budget = null);
                            _loadProducts();
                          },
                        ),
                    ],
                  ),
                ),
              ),
            if (_loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(70),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_error != null && _products.isEmpty)
              SliverToBoxAdapter(
                child: _message(
                  Icons.wifi_off_rounded,
                  'La colección no está disponible',
                  _error!,
                  'Reintentar',
                  () => _loadProducts(),
                ),
              )
            else if (_products.isEmpty)
              SliverToBoxAdapter(
                child: _message(
                  Icons.search_off_rounded,
                  'Probemos con otra búsqueda',
                  'Cambia la talla o quita algún filtro para ver más prendas.',
                  'Ver toda la colección',
                  _reset,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.crossAxisExtent >= 700 ? 3 : 2;
                    final tileWidth =
                        (constraints.crossAxisExtent - 12 * (columns - 1)) /
                        columns;
                    return SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisExtent:
                            tileWidth * 1.3 +
                            92 *
                                MediaQuery.textScalerOf(
                                  context,
                                ).scale(1).clamp(1, 2),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 22,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final product = _products[index];
                        return DmProductCard(
                          product: product,
                          isFavorite: _favorites.contains(product.id),
                          onOpen: () => _openProduct(product),
                          onFavorite: () => _favorite(product),
                          onQuickAdd: () => _chooseVariant(product),
                        );
                      }, childCount: _products.length),
                    );
                  },
                ),
              ),
            if (!_loading && _error != null && _products.isNotEmpty)
              SliverToBoxAdapter(
                child: TextButton(
                  onPressed: () => _loadProducts(more: true),
                  child: Text(_error!),
                ),
              ),
            if (!_loading && _hasMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: OutlinedButton(
                    onPressed: _loadingMore
                        ? null
                        : () => _loadProducts(more: true),
                    child: Text(_loadingMore ? 'Cargando…' : 'Ver más prendas'),
                  ),
                ),
              ),
            if (widget.onOpenAiStudio != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                  child: InkWell(
                    onTap: widget.onOpenAiStudio,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome_outlined,
                            color: AppColors.lime,
                            size: 23,
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '¿Lo combinamos?',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 17,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Encuentra tu próximo look con Altair.',
                                  style: TextStyle(
                                    color: Color(0xFFDDDED6),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: AppColors.white,
                            size: 21,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }

  Widget _message(
    IconData icon,
    String title,
    String description,
    String action,
    VoidCallback onTap,
  ) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 30, 28, 40),
    child: Column(
      children: [
        Icon(icon, size: 40, color: AppColors.textMuted),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMutedStrong, height: 1.5),
        ),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: onTap, child: Text(action)),
      ],
    ),
  );
}

class _VariantPicker extends StatefulWidget {
  final Product product;
  final VoidCallback onAdded;
  const _VariantPicker({required this.product, required this.onAdded});
  @override
  State<_VariantPicker> createState() => _VariantPickerState();
}

class _VariantPickerState extends State<_VariantPicker> {
  ProductVariant? _selected;
  bool _saving = false;
  String? _error;
  Future<void> _add() async {
    if (_selected == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<CartService>().addItem(_selected!.id);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onAdded();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'No pudimos agregar esta talla. Revisa su disponibilidad e intenta de nuevo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final variants = product.variantes
        .where((item) => item.activo && item.stockDisponible > 0)
        .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 74,
                height: 94,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: DmProductImage(
                    imageUrl: product.mainImageUrl,
                    semanticLabel: product.nombre,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.nombre,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Bs ${product.precio.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Selecciona tu talla y color',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (variants.isEmpty)
            const Text('Esta prenda ya no tiene tallas disponibles.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: variants
                  .map(
                    (variant) => ChoiceChip(
                      label: Text('${variant.talla} · ${variant.color}'),
                      selected: _selected?.id == variant.id,
                      onSelected: _saving
                          ? null
                          : (_) => setState(() => _selected = variant),
                    ),
                  )
                  .toList(),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _selected == null || _saving ? null : _add,
              child: Text(_saving ? 'Agregando…' : 'Agregar al carrito'),
            ),
          ),
        ],
      ),
    );
  }
}
