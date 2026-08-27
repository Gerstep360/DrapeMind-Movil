import 'package:flutter_test/flutter_test.dart';
import 'package:drapemind_mobile/core/core.dart';

void main() {
  group('ApiConfig Tests', () {
    test('Host resolution and media URL resolution', () {
      expect(ApiConfig.apiV1Url, contains('/api/v1'));
      expect(ApiConfig.aiWsUrl, contains('/api/v1/ws/ai'));
      expect(ApiConfig.eventsWsUrl, contains('/api/v1/ws/events'));

      final resolved = ApiConfig.resolveMediaUrl('/static/products/sample.jpg');
      expect(resolved, contains('/static/products/sample.jpg'));
    });
  });

  group('Data Models JSON Deserialization', () {
    test('User deserialization', () {
      final json = {
        'id': 1,
        'nombre': 'Carlos Rojas',
        'email': 'carlos@drapemind.com',
        'rol': 'CLIENTE',
        'estado': 'ACTIVO',
        'created_at': '2026-08-27T10:00:00Z',
      };
      final user = User.fromJson(json);
      expect(user.id, 1);
      expect(user.nombre, 'Carlos Rojas');
      expect(user.rol, UserRole.cliente);
      expect(user.estado, 'ACTIVO');
    });

    test('Product and Variant deserialization', () {
      final json = {
        'id': 10,
        'categoria_id': 2,
        'nombre': 'Pantalón Palazzo Sastrero Fluido',
        'precio': 319.0,
        'calidad_nivel': 5,
        'genero_objetivo': 'MUJER',
        'activo': true,
        'imagenes': ['/static/products/sample1.jpg'],
        'variantes': [
          {
            'id': 101,
            'producto_id': 10,
            'sku': 'PALAZZO-NEGRO-S',
            'color': 'Negro Azabache',
            'talla': 'S',
            'stock_total': 15,
            'stock_reservado': 2,
            'stock_disponible': 13,
            'activo': true,
          }
        ],
      };
      final product = Product.fromJson(json);
      expect(product.id, 10);
      expect(product.precio, 319.0);
      expect(product.variantes.length, 1);
      expect(product.variantes.first.stockDisponible, 13);
    });

    test('Cart and CartItem deserialization', () {
      final json = {
        'id': 5,
        'estado': 'ACTIVO',
        'total_items': 2,
        'subtotal': 498.0,
        'items': [
          {
            'id': 1,
            'variante_id': 101,
            'producto_id': 10,
            'nombre': 'Pantalón Palazzo',
            'sku': 'PAL-1',
            'color': 'Negro',
            'talla': 'S',
            'cantidad': 1,
            'precio_unitario': 319.0,
            'subtotal': 319.0,
            'stock_disponible': 10,
          },
          {
            'id': 2,
            'variante_id': 102,
            'producto_id': 11,
            'nombre': 'Polera Gráfica',
            'sku': 'POL-1',
            'color': 'Blanco',
            'talla': 'L',
            'cantidad': 1,
            'precio_unitario': 179.0,
            'subtotal': 179.0,
            'stock_disponible': 8,
          }
        ],
      };
      final cart = Cart.fromJson(json);
      expect(cart.totalItems, 2);
      expect(cart.subtotal, 498.0);
      expect(cart.items.length, 2);
      expect(cart.isNotEmpty, true);
    });

    test('Order and Reservation deserialization', () {
      final orderJson = {
        'id': 20,
        'codigo_publico': 'ORD-987654',
        'estado': 'PAGADO',
        'canal': 'MOBILE',
        'tipo_entrega': 'DELIVERY',
        'subtotal': 498.0,
        'descuento': 0.0,
        'costo_envio': 25.0,
        'total': 523.0,
        'created_at': '2026-08-27T10:30:00Z',
      };
      final order = Order.fromJson(orderJson);
      expect(order.id, 20);
      expect(order.estado, OrderStatus.pagado);
      expect(order.tipoEntrega, DeliveryType.delivery);
      expect(order.total, 523.0);

      final resJson = {
        'id': 8,
        'codigo_publico': 'RES-123456',
        'estado': 'CONFIRMADA',
        'fecha_reserva': '2026-08-27T10:00:00Z',
        'vence_at': '2026-08-29T10:00:00Z',
      };
      final reservation = Reservation.fromJson(resJson);
      expect(reservation.id, 8);
      expect(reservation.estado, ReservationStatus.confirmada);
      expect(reservation.isExpired, false);
    });

    test('AI Action Items and Suggested Actions deserialization', () {
      final actionJson = {
        'id': 10,
        'variante_id': 101,
        'nombre': 'Pantalón Palazzo Sastrero',
        'precio': 319.0,
        'color': 'Negro Azabache',
        'talla': 'S',
        'accion': 'AGREGAR',
        'motivo': 'Sugerencia de estilista',
      };
      final actionItem = AiActionItem.fromJson(actionJson);
      expect(actionItem.id, 10);
      expect(actionItem.accion, AiActionType.agregar);

      final chipJson = {
        'label': '📏 Talla M (Superior)',
        'prompt': 'Ajusta la prenda superior a talla M',
      };
      final chip = AiSuggestedAction.fromJson(chipJson);
      expect(chip.label, '📏 Talla M (Superior)');
      expect(chip.prompt, 'Ajusta la prenda superior a talla M');
    });

    test('AR Config and Size Metrics deserialization', () {
      final arJson = {
        'producto_id': 5,
        'supported': true,
        'mode': '2d-overlay',
        'asset_url': '/media/products/5.png',
        'instructions': 'Alinea hombros y torso',
        'size_metrics': {
          'M': {'chest': 102.0, 'shoulders': 46.0, 'length': 72.0, 'waist': 86.0, 'hip': 102.0, 'foot': 26.5},
          'L': {'chest': 108.0, 'shoulders': 48.0, 'length': 74.0, 'waist': 92.0, 'hip': 108.0, 'foot': 27.5},
        },
        'fabric_elasticity': 0.08,
        'fit_category': 'regular',
        'available_sizes': ['M', 'L'],
        'recommended_size': 'M',
        'material': 'Algodón Pima',
      };
      final arConfig = ArConfigModel.fromJson(arJson);
      expect(arConfig.productoId, 5);
      expect(arConfig.supported, true);
      expect(arConfig.availableSizes, ['M', 'L']);
      expect(arConfig.recommendedSize, 'M');
      expect(arConfig.sizeMetrics['M']?.chest, 102.0);
      expect(arConfig.sizeMetrics['L']?.length, 74.0);
      expect(arConfig.fabricElasticity, 0.08);
    });
  });
}

