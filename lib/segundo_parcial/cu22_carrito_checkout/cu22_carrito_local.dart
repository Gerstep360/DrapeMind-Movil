import 'dart:async';
import 'package:drapemind_mobile/core/config/api_config.dart';
import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/core/network/api_exception.dart';
import '../cu13_catalogo_offline/cu13_offline_service.dart';
import '../cu13_catalogo_offline/cu13_catalogo_descargado.dart';
import '../cu23_pagos/cu23_deferred_store.dart';
import 'cu22_cart_models.dart';

class LocalCart {
  final OfflineService offline;
  final ApiClient api;
  final DeferredStore store;
  final void Function(Cart?) changed;
  String? owner;
  Cart? current;
  bool dirty = false;
  String? issue;
  List<Map<String, dynamic>> base = [];
  Future<void> _ready = Future.value();
  Future<Cart?>? _sync;
  Future<Cart>? _edit;
  LocalCart({
    required this.offline,
    required this.api,
    required this.changed,
    DeferredStore? store,
  }) : store = store ?? DeferredStore(store: offline.store);
  String get key => '${ApiConfig.apiV1Url}|${owner!.replaceFirst('_', ':')}';
  Future<void> get ready => _ready;
  bool get active => !offline.online || dirty;
  Future<void> keepSelection() async {
    await _sync;
    await _edit;
    await ready;
    final scope = owner,
        remote = Cart.fromJson(
          Map<String, dynamic>.from(await api.get('/cart')),
        );
    if (scope != owner || current == null) return;
    base = lines(remote);
    await persist(current!, true);
    dirty = true;
    await synchronize();
    changed(current);
  }

  List<Map<String, dynamic>> lines(Cart cart) => cart.items
      .map((i) => {'variante_id': i.varianteId, 'cantidad': i.cantidad})
      .toList();
  void bind(String? next) {
    if (owner == next) return;
    owner = next;
    current = null;
    dirty = false;
    issue = null;
    base = [];
    _ready = next == null ? Future.value() : restore(next);
  }

  Future<void> restore(String scope) async {
    try {
      final saved = await store.context('$key|cart-draft');
      final context = saved == null ? await store.context(key) : null;
      if (owner != scope) return;
      if (saved != null) {
        current = Cart.fromJson(Map<String, dynamic>.from(saved['cart']));
        base = (saved['base'] as List)
            .map((v) => Map<String, dynamic>.from(v))
            .toList();
        dirty = saved['dirty'] == true;
      } else if (context?['cart'] != null) {
        current = Cart.fromJson(Map<String, dynamic>.from(context!['cart']));
        base = lines(current!);
      }
      changed(current);
    } catch (_) {
      /* An online cart remains usable when storage is unavailable. */
    }
  }

  Future<void> persist(Cart cart, bool pending) => store.saveContext(
    '$key|cart-draft',
    {'cart': cart.toJson(), 'base': base, 'dirty': pending},
  );
  Future<void> accept(
    Cart cart,
    String? scope, {
    bool waitForEdit = true,
  }) async {
    final pending = _edit;
    if (waitForEdit && pending != null) {
      try {
        await pending;
      } catch (_) {}
    }
    await ready;
    if (scope == null || scope != owner || dirty) return;
    current = cart;
    base = lines(cart);
    issue = null;
    changed(cart);
    try {
      await persist(cart, false);
    } catch (_) {
      /* Online success is already durable on the server. */
    }
  }

  /// Explicit download requires a successful server read AND a durable copy.
  Future<Cart> prepareDownload() async {
    await ready;
    await _edit;
    await synchronize();
    final scope = owner;
    if (scope == null || dirty || !offline.online) {
      throw ApiException(
        issue ??
            'Recupera conexión para guardar el carrito. Tu selección sigue conservada.',
      );
    }
    final remote = Cart.fromJson(
      Map<String, dynamic>.from(await api.get('/cart')),
    );
    if (scope != owner) {
      throw ApiException('La tienda cambió. Abre nuevamente la descarga.');
    }
    await accept(remote, scope);
    if (scope != owner || dirty || current == null) {
      throw ApiException('El carrito cambió. Vuelve a actualizar la descarga.');
    }
    await persist(current!, false);
    return current!;
  }

  Future<Cart> edit(
    String action, {
    List<Map<String, dynamic>> items = const [],
    int? id,
    int? quantity,
  }) {
    final scope = owner, priorEdit = _edit, priorSync = _sync;
    final targetVariant = current?.items
        .where((i) => i.id == id)
        .firstOrNull
        ?.varianteId;
    final work = () async {
      if (priorEdit != null) {
        try {
          await priorEdit;
        } catch (_) {}
      }
      if (priorSync != null) await priorSync;
      await ready;
      await offline.ready;
      if (owner == null || scope != owner) {
        throw ApiException('La tienda cambió. Vuelve a abrir el carrito.');
      }
      if (!offline.usable) {
        throw ApiException(
          'Descarga esta tienda con conexión para seguir comprando sin Internet.',
        );
      }
      final prior = current ?? Cart(id: 0);
      final selected = action == 'replace'
          ? <Map<String, dynamic>>[]
          : prior.items.map((i) => i.toJson()).toList();
      if (action == 'remove') {
        selected.removeWhere(
          (i) => targetVariant != null
              ? i['variante_id'] == targetVariant
              : i['id'] == id,
        );
      }
      if (action == 'quantity') {
        for (final i in selected) {
          if (targetVariant != null
              ? i['variante_id'] == targetVariant
              : i['id'] == id) {
            i['cantidad'] = quantity;
          }
        }
      }
      final products = downloadedCatalog(offline.bundle!);
      for (final line in items) {
        final existing = selected
            .where((i) => i['variante_id'] == line['variante_id'])
            .firstOrNull;
        if (existing != null) {
          existing['cantidad'] =
              (existing['cantidad'] as int) + (line['cantidad'] as int);
          continue;
        }
        final product = products
            .where(
              (p) => (p['variantes'] as List).any(
                (v) => v['id'] == line['variante_id'],
              ),
            )
            .firstOrNull;
        if (product == null) {
          throw ApiException('Esta variante no forma parte de tu descarga.');
        }
        final variant = (product['variantes'] as List).firstWhere(
          (v) => v['id'] == line['variante_id'],
        );
        selected.add({
          'id': -(variant['id'] as int),
          'variante_id': variant['id'],
          'producto_id': product['id'],
          'nombre': product['nombre'],
          'sku': variant['sku'],
          'color': variant['color'],
          'talla': variant['talla'],
          'cantidad': line['cantidad'],
          'precio_unitario': double.parse(product['precio'].toString()),
          'stock_disponible': variant['stock_disponible'],
          'imagen': (product['imagenes'] as List).firstOrNull,
        });
      }
      if (selected.length > 50) {
        throw ApiException('Puedes llevar hasta 50 variantes en una compra.');
      }
      for (final item in selected) {
        final quantity = item['cantidad'] as int;
        if (quantity < 1 || quantity > 20) {
          throw ApiException('Elige de 1 a 20 unidades de cada variante.');
        }
        if (quantity > (item['stock_disponible'] as int)) {
          throw ApiException(
            'La cantidad supera la disponibilidad de la descarga.',
          );
        }
        item['subtotal'] = double.parse(
          ((item['precio_unitario'] as num) * quantity).toStringAsFixed(2),
        );
      }
      final cart = Cart.fromJson({
        ...prior.toJson(),
        'items': selected,
        'total_items': selected.fold<int>(
          0,
          (n, i) => n + (i['cantidad'] as int),
        ),
        'subtotal': double.parse(
          selected
              .fold<double>(0, (n, i) => n + (i['subtotal'] as num).toDouble())
              .toStringAsFixed(2),
        ),
      });
      await persist(cart, true);
      if (owner != scope) {
        throw ApiException('La tienda cambió. Vuelve a abrir el carrito.');
      }
      current = cart;
      dirty = true;
      issue = null;
      changed(cart);
      return cart;
    }();
    _edit = work;
    return work
        .whenComplete(() {
          if (identical(_edit, work)) _edit = null;
        })
        .then((cart) {
          if (offline.online) unawaited(synchronize());
          return cart;
        });
  }

  Future<Cart?> synchronize() {
    if (_sync != null) return _sync!;
    final priorEdit = _edit;
    final work = () async {
      if (priorEdit != null) {
        try {
          await priorEdit;
        } catch (_) {}
      }
      await ready;
      final scope = owner, cart = current;
      if (scope == null || cart == null || !dirty || !offline.online) {
        return cart;
      }
      try {
        final result = Cart.fromJson(
          Map<String, dynamic>.from(
            await api.put(
              '/cart/draft',
              body: {'base_items': base, 'items': lines(cart)},
            ),
          ),
        );
        if (owner != scope) return null;
        dirty = false;
        await accept(result, scope, waitForEdit: false);
        return result;
      } on ApiException catch (error) {
        if (owner == scope) {
          if (error is NetworkException) {
            offline.useDownloadedData();
          } else {
            issue = error.message;
          }
        }
        return cart;
      }
    }();
    _sync = work;
    return work.whenComplete(() {
      if (identical(_sync, work)) _sync = null;
    });
  }
}
