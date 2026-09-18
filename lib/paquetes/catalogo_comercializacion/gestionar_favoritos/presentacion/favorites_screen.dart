import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/compartido/componentes/productos/dm_product_card.dart';
import 'package:drapemind_mobile/paquetes/carrito_pedidos_pagos/datos/servicios/cart_service.dart';
import 'package:drapemind_mobile/paquetes/catalogo_comercializacion/consultar_detalle_talla_color_variante/presentacion/product_detail_screen.dart';
import 'package:drapemind_mobile/paquetes/catalogo_comercializacion/datos/servicios/catalog_service.dart';
import 'package:drapemind_mobile/paquetes/catalogo_comercializacion/dominio/modelos/catalog_models.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final CatalogService _catalogService = CatalogService();
  List<Product> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    try {
      final list = await _catalogService.getFavorites();
      if (mounted) {
        setState(() {
          _favorites = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudieron cargar tus prendas favoritas.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _removeFavorite(Product product) async {
    try {
      await _catalogService.removeFavorite(product.id);
      if (mounted) {
        setState(() {
          _favorites.removeWhere((p) => p.id == product.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product.nombre} retirada de favoritos.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al quitar de favoritos.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _quickAdd(Product product) async {
    final defaultVariant = product.variantes.isNotEmpty ? product.variantes.first : null;
    if (defaultVariant == null || defaultVariant.stockDisponible <= 0) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(productId: product.id),
        ),
      );
      return;
    }

    try {
      await context.read<CartService>().addItem(defaultVariant.id, cantidad: 1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product.nombre} añadida al perchero.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo añadir al perchero.'),
            backgroundColor: AppColors.danger,
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
        title: const Text('Mis Favoritos'),
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.ink))
          : _favorites.isEmpty
              ? _buildEmptyState()
              : _buildFavoritesGrid(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.paperLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_border,
                size: 34,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Tu lista de favoritos está vacía',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Explora las prendas del catálogo y toca el corazón para guardarlas en tu selección personal.',
              style: TextStyle(fontSize: 14, color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: AppColors.lime,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Explorar Catálogo'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SELECCIÓN PERSONAL (CU-08)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: AppColors.muted,
                ),
              ),
              Text(
                '${_favorites.length} ${_favorites.length == 1 ? 'prenda' : 'prendas'}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.62,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
            ),
            itemCount: _favorites.length,
            itemBuilder: (context, index) {
              final product = _favorites[index];
              return DmProductCard(
                product: product,
                isFavorite: true,
                onOpen: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(productId: product.id),
                    ),
                  );
                },
                onFavorite: () => _removeFavorite(product),
                onQuickAdd: () => _quickAdd(product),
              );
            },
          ),
        ),
      ],
    );
  }
}
