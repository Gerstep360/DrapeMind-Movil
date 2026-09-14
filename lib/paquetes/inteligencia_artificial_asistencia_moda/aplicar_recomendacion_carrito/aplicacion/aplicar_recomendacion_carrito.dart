import 'package:drapemind_mobile/paquetes/carrito_pedidos_pagos/datos/servicios/cart_service.dart';
import 'package:drapemind_mobile/paquetes/carrito_pedidos_pagos/dominio/modelos/cart_models.dart';
import 'package:drapemind_mobile/paquetes/inteligencia_artificial_asistencia_moda/dominio/modelos/ai_models.dart';

enum RecommendationCartChange { added, removed, replaced, ignored }

class RecommendationCartResult {
  final RecommendationCartChange change;
  final String message;

  const RecommendationCartResult(this.change, this.message);
}

/// CU: Aplicar recomendación de IA al carrito.
///
/// Centraliza la traducción de acciones Altair al contrato real del carrito.
/// La presentación sólo informa el resultado y no conoce endpoints ni lotes.
class AplicarRecomendacionCarrito {
  final CartService _cart;

  const AplicarRecomendacionCarrito(this._cart);

  Future<RecommendationCartResult> execute(AiActionItem item) async {
    switch (item.accion) {
      case AiActionType.agregar:
        final variantId = item.varianteId;
        if (variantId == null) {
          return const RecommendationCartResult(
            RecommendationCartChange.ignored,
            'Esta recomendación no tiene una variante seleccionable.',
          );
        }
        await _cart.addItem(variantId);
        return RecommendationCartResult(
          RecommendationCartChange.added,
          '${item.nombre} se añadió a tu perchero.',
        );
      case AiActionType.quitar:
        final itemId = item.itemId;
        if (itemId == null) {
          return const RecommendationCartResult(
            RecommendationCartChange.ignored,
            'No encontramos el artículo del perchero que quieres quitar.',
          );
        }
        await _cart.removeItem(itemId);
        return RecommendationCartResult(
          RecommendationCartChange.removed,
          '${item.nombre} se quitó de tu perchero.',
        );
      default:
        return const RecommendationCartResult(
          RecommendationCartChange.ignored,
          'Esta acción no modifica el perchero.',
        );
    }
  }

  Future<RecommendationCartResult> replaceOutfit(
    Iterable<AiActionItem> items,
  ) async {
    final batch = items
        .where((item) => item.varianteId != null)
        .map(
          (item) =>
              BatchCartItemRequest(varianteId: item.varianteId!, cantidad: 1),
        )
        .toList(growable: false);
    if (batch.isEmpty) {
      return const RecommendationCartResult(
        RecommendationCartChange.ignored,
        'El outfit no contiene variantes disponibles.',
      );
    }
    await _cart.replaceCartWithBatch(batch);
    return RecommendationCartResult(
      RecommendationCartChange.replaced,
      'Perchero actualizado con ${batch.length} prendas del outfit.',
    );
  }
}
