import 'package:drapemind_mobile/segundo_parcial/cu22_carrito_checkout/cu22_cart_models.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:drapemind_mobile/core/config/api_config.dart';
import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/segundo_parcial/cu05_acceso/cu05_auth_service.dart';
import 'package:drapemind_mobile/segundo_parcial/cu23_pagos/cu23_deferred_store.dart';
import 'package:drapemind_mobile/segundo_parcial/cu22_carrito_checkout/cu22_cart_service.dart';

class DeferredService extends ChangeNotifier with WidgetsBindingObserver {
  final AuthService auth;
  final ApiClient api;
  final DeferredStore store;
  final CartService? cart;
  String? _owner;
  bool _disposed = false;
  bool busy = false;
  bool online = true;
  String? error;
  Map<String, dynamic>? contextData;
  List<Map<String, dynamic>> purchases = [];
  Timer? _timer;
  Future<void> _restoring = Future.value();
  Future<void> get ready => _restoring;
  void _connectionChanged() {
    final connected = cart?.offline?.online;
    if (connected == false) {
      online = false;
      changed();
    } else if (connected == true && !online) {
      online = true;
      unawaited(refresh());
    }
  }

  Future<void> useCart(Cart value) async {
    await ready;
    final scope = _owner, data = contextData;
    if (scope == null || data == null) {
      throw Exception(
        'Descarga los datos de compra de esta tienda con conexión.',
      );
    }
    final next = {...data, 'cart': value.toJson()};
    await store.saveContext(scope, next);
    if (scope == _owner) {
      contextData = next;
      changed();
    }
  }

  DeferredService({
    required this.auth,
    ApiClient? client,
    DeferredStore? local,
    this.cart,
    bool automatic = true,
  }) : api = client ?? ApiClient(),
       store = local ?? DeferredStore() {
    auth.addListener(_accountChanged);
    cart?.addListener(_cartChanged);
    cart?.offline?.addListener(_connectionChanged);
    if (automatic) {
      WidgetsBinding.instance.addObserver(this);
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (purchases.any((r) => !terminal(r))) {
          if (!online && cart?.offline?.online != false) {
            unawaited(refresh());
          } else {
            unawaited(synchronize());
          }
        }
      });
      _accountChanged();
    }
  }
  void changed() {
    if (!_disposed) notifyListeners();
  }

  void _cartChanged() {
    final user = auth.currentUser;
    final owner = _owner;
    final current = cart?.cart;
    if (owner == null ||
        contextData == null ||
        current == null ||
        cart?.owner != '${user?.tenantId}_${user?.id}') {
      return;
    }
    contextData = {...contextData!, 'cart': current.toJson()};
    unawaited(
      store.saveContext(owner, contextData!).catchError((_) {
        error = 'No pudimos actualizar la copia local del carrito.';
        changed();
      }),
    );
    changed();
  }

  String? get owner => _owner;
  void _accountChanged() {
    final u = auth.currentUser;
    final next = auth.isAuthenticated && u?.rol.toServerString() == 'CLIENTE'
        ? '${ApiConfig.apiV1Url}|${u!.tenantId}:${u.id}'
        : null;
    if (next == _owner) return;
    _owner = next;
    contextData = null;
    purchases = [];
    if (next != null) _restoring = restore(next);
    changed();
  }

  Future<void> restore(String owner) async {
    try {
      final data = await store.context(owner);
      final rows = await store.purchases(owner);
      if (_owner != owner) return;
      contextData = data;
      purchases = rows;
      changed();
      unawaited(refresh());
    } catch (_) {
      error =
          'No pudimos abrir el almacenamiento local. No se guardó ninguna compra nueva.';
      changed();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  List<Map<String, dynamic>> rows(String key) =>
      ((contextData?[key] as List?) ?? [])
          .map((v) => Map<String, dynamic>.from(v))
          .toList();
  List<Map<String, dynamic>> get items =>
      ((contextData?['cart']?['items'] as List?) ?? [])
          .map((v) => Map<String, dynamic>.from(v))
          .toList();
  bool terminal(Map<String, dynamic> row) => [
    'PAGADA',
    'RECHAZADA',
    'CANCELADA',
    'VENCIDA',
  ].contains(row['remote']?['estado'] ?? row['localState']);
  String state(Map<String, dynamic> row) =>
      row['cancelRequested'] == true && !terminal(row)
      ? 'CANCELACION_PENDIENTE'
      : row['remote']?['estado'] ?? row['localState'] ?? 'ESPERANDO_CONEXION';
  static String label(String state) =>
      const {
        'PAGADA': 'Compra pagada',
        'RECHAZADA': 'Compra anulada',
        'CANCELADA': 'Compra cancelada',
        'VENCIDA': 'Solicitud vencida',
        'REQUIERE_AUTENTICACION': 'Tu banco pide verificación',
        'REQUIERE_METODO': 'Falta elegir tarjeta',
        'PROCESANDO_PAGO': 'En proceso de pago',
        'PENDIENTE_RESULTADO': 'Verificando con Stripe',
        'ESPERANDO_CONEXION': 'En espera de conexión',
        'CANCELACION_PENDIENTE': 'Cancelación pendiente',
      }[state] ??
      'Pendiente de sincronizar';

  /// Read-only checkout preparation. Never queues or charges a purchase.
  Future<void> prepareDownload() async {
    await ready;
    final scope = _owner;
    if (scope == null) {
      throw Exception('Abre la tienda con tu cuenta de cliente.');
    }
    final data = Map<String, dynamic>.from(
      await api.get('/payments/deferred/context'),
    );
    if (_owner != scope || data['owner'] != scope.split('|').last) {
      throw Exception('La tienda cambió. Vuelve a abrir la descarga.');
    }
    if (cart?.cart != null) data['cart'] = cart!.cart!.toJson();
    await store.saveContext(scope, data);
    if (_owner != scope) {
      throw Exception('La tienda cambió durante la descarga.');
    }
    contextData = data;
    online = true;
    error = null;
    changed();
  }

  Future<void> refresh() async {
    final owner = _owner;
    if (owner == null) return;
    try {
      try {
        await cart?.synchronizeDraft();
      } catch (_) {
        /* The immutable purchase snapshot does not overwrite another device's cart. */
      }
      final data = Map<String, dynamic>.from(
        await api.get('/payments/deferred/context'),
      );
      if (_owner != owner || data['owner'] != owner.split('|').last) return;
      if (cart?.cart != null) data['cart'] = cart!.cart!.toJson();
      await store.saveContext(owner, data);
      contextData = data;
      online = true;
      error = null;
      final server = await api.get('/payments/deferred') as List;
      if (_owner != owner) return;
      final local = await store.purchases(owner);
      for (final raw in server) {
        final result = Map<String, dynamic>.from(raw);
        final operation = result['operacion_id'];
        final prior = local
            .where((r) => r['operation'] == operation)
            .firstOrNull;
        await store.save({
          ...?prior,
          'key': '$owner|$operation',
          'owner': owner,
          'operation': operation,
          'label': prior?['label'] ?? 'Compra de esta tienda',
          'createdAt':
              prior?['createdAt'] ?? DateTime.now().toUtc().toIso8601String(),
          'remote': result,
        });
      }
      await _reload(owner);
      await synchronize();
    } catch (_) {
      if (_owner == owner) {
        online = false;
        error =
            'Usando la copia local. Tus compras quedan guardadas hasta recuperar conexión.';
        changed();
      }
    }
  }

  Future<void> _reload(String owner) async {
    final records = await store.purchases(owner);
    if (_owner == owner) {
      purchases = records;
      changed();
    }
  }

  String uuid() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final value = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-${value.substring(12, 16)}-${value.substring(16, 20)}-${value.substring(20)}';
  }

  Future<String> enqueue({
    required String delivery,
    int? branch,
    int? address,
    int? card,
    required double total,
    required bool consent,
  }) async {
    final owner = _owner;
    if (owner == null || contextData == null || items.isEmpty) {
      throw Exception(
        'Descarga tu carrito con conexión antes de guardar una compra.',
      );
    }
    if (DateTime.parse(contextData!['valid_until']).isBefore(DateTime.now())) {
      throw Exception(
        'Actualiza la copia de tu tienda antes de guardar otra compra.',
      );
    }
    final source =
        items
            .map(
              (i) => <String, dynamic>{
                'variante_id': i['variante_id'],
                'cantidad': i['cantidad'],
              },
            )
            .toList()
          ..sort(
            (a, b) =>
                (a['variante_id'] as int).compareTo(b['variante_id'] as int),
          );
    if (purchases.any(
      (r) =>
          !terminal(r) && jsonEncode(r['body']?['items']) == jsonEncode(source),
    )) {
      throw Exception('Estas prendas ya tienen una compra pendiente.');
    }
    final operation = uuid();
    final created = DateTime.now().toUtc().toIso8601String();
    final body = {
      'operacion_id': operation,
      'items': source,
      'tipo_entrega': delivery,
      'sucursal_id': delivery == 'RECOJO' ? branch : null,
      'direccion_id': delivery == 'DELIVERY' ? address : null,
      'tarjeta_id': card,
      'total_autorizado': total.toStringAsFixed(2),
      'autorizar_cobro_automatico': card != null && consent,
      'creado_en_dispositivo': created,
    };
    await store.save({
      'key': '$owner|$operation',
      'owner': owner,
      'operation': operation,
      'body': body,
      'createdAt': created,
      'label': items.map((i) => '${i['cantidad']} × ${i['nombre']}').join(', '),
      'localState': 'ESPERANDO_CONEXION',
    });
    await _reload(owner);
    unawaited(synchronize());
    return operation;
  }

  Future<void> _saveRemote(Map<String, dynamic> row, dynamic result) async {
    final current = (await store.purchases(
      row['owner'],
    )).where((r) => r['operation'] == row['operation']).firstOrNull;
    await store.save({...row, ...?current, 'remote': result});
    if (result['estado'] == 'PAGADA' &&
        contextData != null &&
        _owner == row['owner']) {
      final basket =
          items
              .map(
                (i) => <String, dynamic>{
                  'variante_id': i['variante_id'],
                  'cantidad': i['cantidad'],
                },
              )
              .toList()
            ..sort(
              (a, b) =>
                  (a['variante_id'] as int).compareTo(b['variante_id'] as int),
            );
      if (jsonEncode(basket) == jsonEncode(row['body']?['items'])) {
        contextData = {
          ...contextData!,
          'cart': {
            ...Map<String, dynamic>.from(contextData!['cart']),
            'items': [],
            'subtotal': 0,
            'total_items': 0,
          },
        };
        await store.saveContext(row['owner'], contextData!);
        if (cart != null) {
          unawaited(cart!.getCart().then<void>((_) {}).catchError((_) {}));
        }
      }
    }
  }

  Future<void> synchronize() async {
    final owner = _owner;
    if (owner == null || busy) return;
    busy = true;
    changed();
    try {
      for (final row in await store.purchases(owner)) {
        if (_owner != owner) return;
        if (terminal(row)) continue;
        String url;
        dynamic body = <String, dynamic>{};
        if (row['cancelRequested'] == true && row['body'] != null) {
          url = '/payments/deferred/cancel-pending';
          body = row['body'];
        } else if (row['cancelRequested'] == true) {
          url = '/payments/deferred/${row['operation']}/cancel';
        } else if (row['remote'] == null && row['body'] != null) {
          url = '/payments/deferred';
          body = row['body'];
        } else {
          url = '/payments/deferred/${row['operation']}/sync';
        }
        try {
          final result = await api.post(url, body: body);
          await _saveRemote(row, result);
          online = true;
        } catch (_) {
          online = false;
          error =
              'La compra sigue guardada. Verificaremos su identificador antes de repetir cualquier cobro.';
          break;
        }
      }
    } finally {
      busy = false;
      await _reload(owner);
      changed();
    }
  }

  Future<void> cancel(Map<String, dynamic> row) async {
    await store.save({...row, 'cancelRequested': true});
    await _reload(row['owner']);
    await synchronize();
  }

  Future<void> chooseCard(Map<String, dynamic> row, int card) async {
    final result = await api.post(
      '/payments/deferred/${row['operation']}/method',
      body: {'tarjeta_id': card, 'autorizar_cobro_automatico': true},
    );
    await _saveRemote(row, result);
    await _reload(row['owner']);
  }

  Future<void> saveCard(bool consent) async {
    if (!consent) {
      throw Exception(
        'Acepta guardar la tarjeta para futuros cobros expresamente autorizados.',
      );
    }
    final setup = await api.post(
      '/payments/cards/setup',
      body: {
        'operacion_id': uuid(),
        'aceptar_guardado_y_cobros_diferidos': true,
      },
    );
    Stripe.publishableKey = setup['publishable_key'];
    await Stripe.instance.applySettings();
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        setupIntentClientSecret: setup['client_secret'],
        merchantDisplayName: auth.currentUser?.tenantName ?? 'DrapeMind',
      ),
    );
    await Stripe.instance.presentPaymentSheet();
    await api.post(
      '/payments/cards/confirm',
      body: {
        'setup_intent_id': setup['setup_intent_id'],
        'aceptar_guardado_y_cobros_diferidos': true,
      },
    );
    await refresh();
  }

  Future<void> authenticate(Map<String, dynamic> row) async {
    final value = await api.post(
      '/payments/deferred/${row['operation']}/authenticate',
      body: {},
    );
    if (value['client_secret'] != null) {
      Stripe.publishableKey = value['publishable_key'];
      await Stripe.instance.applySettings();
      await Stripe.instance.handleNextAction(value['client_secret']);
    }
    final result = await api.get('/payments/deferred/${row['operation']}');
    await _saveRemote(row, result);
    await _reload(row['owner']);
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    auth.removeListener(_accountChanged);
    cart?.removeListener(_cartChanged);
    cart?.offline?.removeListener(_connectionChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
