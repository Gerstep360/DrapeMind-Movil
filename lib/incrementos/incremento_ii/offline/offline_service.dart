import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/widgets.dart';
import 'package:drapemind_mobile/core/config/api_config.dart';
import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/core/network/api_exception.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/datos/servicios/auth_service.dart';
import 'models.dart';
import 'offline_store.dart';

class OfflineService extends ChangeNotifier with WidgetsBindingObserver {
  final AuthService auth;
  final ApiClient api;
  final OfflineStore store;
  OfflineBundle? bundle;
  List<OfflineRequest> queue = [];
  bool downloading = false, syncing = false, online = true;
  String message = '', phase = '';
  String? _owner;
  bool _restoring = false, _checking = false, _disposed = false;
  Timer? _timer;
  final Map<String, Future<Uint8List?>> _photos = {};
  Future<void> _ready = Future.value();
  Future<void> get ready => _ready;
  OfflineService({
    required this.auth,
    ApiClient? api,
    OfflineStore? store,
    bool monitor = true,
  }) : api = api ?? ApiClient(),
       store = store ?? OfflineStore() {
    auth.addListener(_accountChanged);
    if (monitor) {
      WidgetsBinding.instance.addObserver(this);
      _timer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (bundle != null || queue.isNotEmpty) checkConnection();
      });
    }
    scheduleMicrotask(_accountChanged);
  }
  String? get owner {
    final user = auth.currentUser;
    return user != null &&
            user.rol.toServerString() != 'PROVEEDOR' &&
            user.tenantId != null &&
            auth.isAuthenticated &&
            !auth.isPlatformAdmin
        ? '${ApiConfig.apiV1Url}|${user.tenantId}:${user.id}'
        : null;
  }

  bool get usable =>
      bundle != null &&
      owner?.endsWith('|${bundle!.owner}') == true &&
      bundle!.validUntil.isAfter(DateTime.now()) &&
      auth.hasValidToken;
  bool get canSell => [
    'ADMIN',
    'ENCARGADO',
    'CAJERO',
  ].contains(auth.currentUser?.rol.toServerString());
  int get pending => queue
      .where(
        (r) =>
            ['PENDING', 'SENDING', 'UNCERTAIN', 'CONFLICT'].contains(r.state),
      )
      .length;
  void _publish() {
    if (!_disposed) notifyListeners();
  }

  void _accountChanged() {
    final current = owner;
    if (current == _owner) return;
    _owner = current;
    _photos.clear();
    bundle = null;
    queue = [];
    message = '';
    _publish();
    if (current != null) _ready = restore(current);
  }

  Future<void> restore(String scope) async {
    _restoring = true;
    try {
      final data = await store.readBundle(scope);
      final rows = await store.requests(scope);
      if (owner != scope) return;
      bundle = data;
      queue = rows
          .map((r) => r.state == 'SENDING' ? r.change(state: 'UNCERTAIN') : r)
          .toList();
      _publish();
    } catch (_) {
      if (owner == scope) {
        message = 'No pudimos abrir los datos guardados en este dispositivo.';
        _publish();
      }
    } finally {
      _restoring = false;
    }
    if (owner == scope &&
        queue.any((r) => ['PENDING', 'UNCERTAIN'].contains(r.state))) {
      await checkConnection();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(checkConnection());
  }

  Future<void> checkConnection() async {
    final scope = owner;
    if (_disposed || scope == null || _checking || _restoring) {
      return;
    }
    _checking = true;
    try {
      await api.get('/offline/status', timeout: const Duration(seconds: 4));
      if (owner == scope) {
        online = true;
        _publish();
        await sync();
      }
    } on NetworkException {
      if (owner == scope) {
        online = false;
        _publish();
      }
    } on ApiException catch (e) {
      if (owner == scope) {
        message = e.message;
        _publish();
      }
    } catch (_) {
      if (owner == scope) {
        online = false;
        _publish();
      }
    } finally {
      _checking = false;
    }
  }

  Future<void> download() async {
    final scope = owner;
    if (scope == null || downloading) return;
    downloading = true;
    message = '';
    phase = 'Descargando prendas y disponibilidad…';
    _publish();
    try {
      final result = await api.get(
        '/offline/bundle',
        timeout: const Duration(seconds: 60),
      );
      final data = OfflineBundle.fromJson(Map<String, dynamic>.from(result));
      if (owner != scope || !scope.endsWith('|${data.owner}')) return;
      phase = 'Guardando tu colección…';
      _publish();
      await store.saveBundle(scope, data);
      if (owner == scope) {
        bundle = data;
        online = true;
        await _cachePhotos(scope, data);
        phase = 'Catálogo guardado';
      }
    } on ApiException catch (e) {
      if (owner == scope) {
        message = e.message;
        if (e is NetworkException) online = false;
      }
    } catch (_) {
      if (owner == scope) {
        message =
            'No pudimos guardar la descarga. Revisa el espacio disponible e inténtalo nuevamente.';
      }
    } finally {
      downloading = false;
      _publish();
    }
  }

  Future<void> _cachePhotos(String scope, OfflineBundle data) async {
    final urls = data.products
        .expand((p) => ((p['imagenes'] as List?) ?? []).take(1))
        .map((p) => ApiConfig.resolveMediaUrl(p.toString()))
        .where((url) => url.startsWith('http'))
        .toSet()
        .toList();
    var next = 0, done = 0;
    Future<void> worker() async {
      while (next < urls.length && owner == scope) {
        final url = urls[next++];
        try {
          final response = await http
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 5));
          if (response.statusCode == 200 &&
              (response.headers['content-type'] ?? '').startsWith('image/') &&
              response.bodyBytes.length <= 2000000 &&
              owner == scope) {
            await store.savePhoto(scope, url, response.bodyBytes);
            _photos.remove(url);
          }
        } catch (_) {
          /* The catalog remains usable when an optional photograph cannot be downloaded. */
        }
        done++;
        if (owner == scope) {
          phase = 'Guardando fotos $done de ${urls.length}…';
          _publish();
        }
      }
    }

    await Future.wait(List.generate(min(3, urls.length), (_) => worker()));
  }

  Future<Uint8List?> photo(String image) {
    final scope = owner;
    if (scope == null) return Future.value();
    final url = ApiConfig.resolveMediaUrl(image);
    return _photos.putIfAbsent(url, () async {
      final bytes = await store.photo(scope, url);
      return owner == scope ? bytes : null;
    });
  }

  int available(int variant, int branch) {
    final base =
        bundle?.stock
                .where(
                  (s) =>
                      s['variante_id'] == variant && s['sucursal_id'] == branch,
                )
                .firstOrNull?['disponible']
            as int? ??
        0;
    final pending = queue
        .where(
          (r) =>
              r.kind != 'PICKUP' &&
              (['PENDING', 'SENDING', 'UNCERTAIN'].contains(r.state) ||
                  (r.kind == 'SALE' && r.state == 'CONFLICT') ||
                  (r.state == 'CONFIRMED' &&
                      r.body['snapshot_version'] == bundle?.version &&
                      DateTime.parse(
                        r.body['creado_at'],
                      ).isAfter(bundle!.downloadedAt) &&
                      (r.kind == 'SALE' ||
                          (DateTime.tryParse(
                                r.reservation?['vence_at'] ?? '',
                              )?.isAfter(DateTime.now()) ??
                              false)))) &&
              r.body['sucursal_id'] == branch,
        )
        .fold<int>(
          0,
          (sum, r) =>
              sum +
              (r.body['items'] as List)
                  .where((i) => i['variante_id'] == variant)
                  .fold<int>(0, (a, i) => a + (i['cantidad'] as int)),
        );
    return max(0, base - pending);
  }

  Future<void> reserve(int variantId, int branchId, int quantity) async {
    final scope = owner, data = bundle;
    if (scope == null || data == null || !usable) {
      throw ApiException(
        'Conéctate para actualizar la descarga antes de guardar otra solicitud.',
      );
    }
    final variant = data.variants
        .where((v) => v['id'] == variantId)
        .firstOrNull;
    final branch = data.branches.where((b) => b['id'] == branchId).firstOrNull;
    if (variant == null ||
        branch == null ||
        quantity < 1 ||
        quantity > 100 ||
        quantity > available(variantId, branchId)) {
      throw ApiException(
        'Revisa la talla, sucursal y cantidad disponible en tu copia.',
      );
    }
    final id = _uuid();
    final product = data.products
        .where((p) => p['id'] == variant['producto_id'])
        .first;
    final record = OfflineRequest(
      key: '$scope|$id',
      owner: scope,
      name: '${product['nombre']} · ${variant['talla']} · ${variant['color']}',
      branch: branch['nombre'],
      body: {
        'operacion_id': id,
        'sucursal_id': branchId,
        'snapshot_version': data.version,
        'creado_at': DateTime.now().toUtc().toIso8601String(),
        'items': [
          {'variante_id': variantId, 'cantidad': quantity},
        ],
      },
    );
    await store.saveRequest(record);
    if (owner != scope) return;
    queue = [...queue, record];
    message = 'Solicitud guardada. La tienda confirmará el stock al enviarla.';
    _publish();
    if (online) unawaited(sync());
  }

  Future<void> _save(OfflineRequest record) async {
    await store.saveRequest(record);
    if (owner == record.owner) {
      queue = queue.map((r) => r.key == record.key ? record : r).toList();
      _publish();
    }
  }

  Future<void> cancel(OfflineRequest record) async {
    final current = queue.where((r) => r.key == record.key).firstOrNull;
    if (current == null ||
        syncing ||
        current.owner != owner ||
        current.kind != 'RESERVATION' ||
        !['PENDING', 'CONFLICT'].contains(current.state)) {
      return;
    }
    record = current;
    final token = auth.token;
    if (token == null) return;
    if (record.kind == 'RESERVATION' && record.state == 'CONFLICT') {
      if (!online) {
        message =
            'Conéctate para cancelar una solicitud que ya recibió la tienda.';
        _publish();
        return;
      }
      try {
        await api.post(
          "/offline/operations/${record.body['operacion_id']}/cancel",
          body: {},
          headers: {'Authorization': 'Bearer $token'},
        );
      } on ApiException catch (e) {
        if (record.owner != owner) return;
        if (e.statusCode != 404) {
          message = e.message;
          _publish();
          await sync();
          return;
        }
      }
    }
    if (record.kind != 'RESERVATION' ||
        syncing ||
        record.owner != owner ||
        !['PENDING', 'CONFLICT'].contains(record.state)) {
      return;
    }
    await _save(
      record.change(
        state: 'CANCELLED',
        message: 'Cancelada en este dispositivo.',
      ),
    );
  }

  Future<void> retry(OfflineRequest record) async {
    record = queue.where((r) => r.key == record.key).firstOrNull ?? record;
    if (syncing || record.owner != owner || record.state != 'CONFLICT') return;
    await _save(record.change(state: 'PENDING'));
    await sync();
  }

  Future<void> sync() async {
    final scope = owner;
    final token = auth.token;
    if (scope == null || token == null || !online || syncing || _restoring) {
      return;
    }
    syncing = true;
    _publish();
    try {
      await _pullResults(scope);
      for (final original
          in queue
              .where(
                (r) => ['PENDING', 'SENDING', 'UNCERTAIN'].contains(r.state),
              )
              .toList()) {
        if (scope != owner || !online) break;
        final record = original.change(
          state: 'SENDING',
          attempts: original.attempts + 1,
        );
        await _save(record);
        if (scope != owner) break;
        try {
          final result = await api.post(
            '/offline/operations',
            body: {'tipo': record.kind, 'payload': record.body},
            headers: {'Authorization': 'Bearer $token'},
            timeout: const Duration(seconds: 25),
          );
          await _save(_mergeResult(record, Map<String, dynamic>.from(result)));
        } on ApiException catch (e) {
          final status = e.statusCode ?? 0;
          await _save(
            record.change(
              state: status >= 400 && status < 500 ? 'CONFLICT' : 'UNCERTAIN',
              message: e.message,
            ),
          );
          if (status == 0 ||
              status == 401 ||
              status == 402 ||
              status == 403 ||
              status >= 500) {
            if (status == 0) online = false;
            break;
          }
        } catch (_) {
          await _save(
            record.change(
              state: 'UNCERTAIN',
              message:
                  'No sabemos si la tienda recibió la solicitud. La comprobaremos al conectar.',
            ),
          );
          break;
        }
      }
    } catch (_) {
      if (scope == owner) {
        message =
            'No pudimos actualizar las solicitudes guardadas. Revisa el almacenamiento del dispositivo.';
      }
    } finally {
      syncing = false;
      _publish();
    }
  }

  String _uuid() {
    final random = Random.secure();
    final b = List<int>.generate(16, (_) => random.nextInt(256));
    b[6] = (b[6] & 15) | 64;
    b[8] = (b[8] & 63) | 128;
    final s = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
  }

  OfflineRequest _mergeResult(
    OfflineRequest record,
    Map<String, dynamic> result,
  ) {
    final state = result['estado'];
    if (!['CONFIRMED', 'CONFLICT', 'REJECTED'].contains(state)) {
      throw ServerException(
        'La tienda no confirmó un resultado válido. Comprobaremos la operación nuevamente.',
      );
    }
    final data = result['resultado'] as Map?;
    return record.change(
      state: state,
      serverId: result['id'],
      attempts: result['intentos'] ?? record.attempts,
      reservation: data?['reservation'] == null
          ? null
          : Map<String, dynamic>.from(data!['reservation']),
      sale: data?['sale'] == null
          ? null
          : Map<String, dynamic>.from(data!['sale']),
      message:
          result['error']?['message'] ??
          (state == 'CONFIRMED'
              ? 'Operación confirmada por la tienda.'
              : 'Necesita revisión del encargado.'),
    );
  }

  Future<void> _pullResults(String scope) async {
    try {
      final result = await api.get(
        '/offline/operations',
        timeout: const Duration(seconds: 10),
      );
      final results = List<dynamic>.from(result as List);
      final known = results.map((r) => r['operacion_id']).toSet();
      final missing = queue
          .where(
            (r) =>
                r.attempts > 0 &&
                ['PENDING', 'UNCERTAIN', 'CONFLICT'].contains(r.state) &&
                !known.contains(r.body['operacion_id']),
          )
          .map((r) => r.body['operacion_id'])
          .toList();
      for (var offset = 0; offset < missing.length; offset += 100) {
        if (owner != scope) return;
        final extra = await api.post(
          '/offline/operations/results',
          body: {
            'operaciones': missing.sublist(
              offset,
              min(offset + 100, missing.length),
            ),
          },
        );
        results.addAll(extra as List);
      }
      for (final raw in results) {
        if (owner != scope) return;
        final row = Map<String, dynamic>.from(raw),
            key = "$scope|${raw['operacion_id']}";
        final existing = queue.where((r) => r.key == key).firstOrNull;
        final body = Map<String, dynamic>.from(row['payload']);
        final branch = bundle?.branches
            .where((b) => b['id'] == body['sucursal_id'])
            .firstOrNull;
        final record =
            existing ??
            OfflineRequest(
              key: key,
              owner: scope,
              kind: row['tipo'],
              name: row['tipo'] == 'RESERVATION'
                  ? 'Reserva de prendas'
                  : row['tipo'] == 'PICKUP'
                  ? 'Retiro de reserva'
                  : 'Venta de contado',
              branch: branch?['nombre'] ?? "Sucursal ${body['sucursal_id']}",
              body: body,
            );
        final updated = _mergeResult(record, row);
        await store.saveRequest(updated);
        if (owner != scope) return;
        queue = existing == null
            ? [...queue, updated]
            : queue.map((r) => r.key == key ? updated : r).toList();
        _publish();
      }
    } catch (_) {
      /* Preserve the durable local queue when results cannot be downloaded. */
    }
  }

  String variantName(int id) {
    final variant = bundle?.variants.where((v) => v['id'] == id).firstOrNull;
    final product = bundle?.products
        .where((p) => p['id'] == variant?['producto_id'])
        .firstOrNull;
    return product == null
        ? 'Variante $id'
        : "${product['nombre']} · ${variant?['talla']} · ${variant?['color']}";
  }

  int _cents(Object? value) {
    final n = num.tryParse(value.toString());
    if (n == null || !n.isFinite || n < 0) {
      throw ApiException('Introduce un importe válido.');
    }
    return (n * 100).round();
  }

  Future<void> cashSale(
    List<Map<String, dynamic>> lines,
    int branchId,
    String received,
  ) async {
    final data = bundle;
    if (data == null || !usable || !canSell) {
      throw ApiException(
        'Actualiza el catálogo con tu cuenta de caja antes de cobrar.',
      );
    }
    if (lines.isEmpty ||
        lines.map((l) => l['variante_id']).toSet().length != lines.length) {
      throw ApiException(
        'Añade prendas y agrupa las cantidades de cada talla.',
      );
    }
    final items = lines.map((line) {
      final id = line['variante_id'] as int, q = line['cantidad'] as int;
      final variant = data.variants.where((v) => v['id'] == id).firstOrNull;
      final product = data.products
          .where((p) => p['id'] == variant?['producto_id'])
          .firstOrNull;
      if (product == null || q < 1 || q > 100 || q > available(id, branchId)) {
        throw ApiException('Revisa las cantidades disponibles en la sucursal.');
      }
      return <String, dynamic>{
        ...line,
        'precio_unitario': product['precio'].toString(),
      };
    }).toList();
    final total = items.fold<int>(
      0,
      (n, i) => n + _cents(i['precio_unitario']) * (i['cantidad'] as int),
    );
    if (_cents(received) < total) {
      throw ApiException('El efectivo recibido no cubre el total.');
    }
    await _queueCash('SALE', branchId, items, received);
  }

  Future<void> pickup(Map<String, dynamic> reservation, String received) async {
    if (!usable || !canSell) {
      throw ApiException('Actualiza el catálogo con tu cuenta de caja.');
    }
    if (!DateTime.parse(reservation['vence_at']).isAfter(DateTime.now())) {
      throw ApiException(
        'Esta reserva ya venció. Actualiza la lista antes de cobrar.',
      );
    }
    if (queue.any(
      (r) =>
          r.body['reserva_id'] == reservation['id'] &&
          !['CANCELLED', 'REJECTED'].contains(r.state),
    )) {
      throw ApiException(
        'Esta reserva ya tiene un cobro guardado. Comprueba su resultado.',
      );
    }
    final items = (reservation['items'] as List)
        .map((i) => Map<String, dynamic>.from(i))
        .toList();
    final total = items.fold<int>(
      0,
      (n, i) => n + _cents(i['precio_unitario']) * (i['cantidad'] as int),
    );
    if (_cents(received) < total) {
      throw ApiException(
        'El efectivo recibido no cubre el total de la reserva.',
      );
    }
    await _queueCash(
      'PICKUP',
      reservation['sucursal_id'],
      items,
      received,
      reservationId: reservation['id'],
    );
  }

  Future<void> _queueCash(
    String kind,
    int branchId,
    List<Map<String, dynamic>> items,
    String received, {
    int? reservationId,
  }) async {
    final scope = owner, data = bundle;
    if (scope == null || data == null) {
      throw ApiException('Inicia sesión antes de cobrar.');
    }
    final branch = data.branches.where((b) => b['id'] == branchId).firstOrNull;
    if (branch == null) {
      throw ApiException('Selecciona una sucursal autorizada.');
    }
    final id = _uuid();
    final record = OfflineRequest(
      key: '$scope|$id',
      owner: scope,
      kind: kind,
      name: kind == 'SALE'
          ? 'Venta de contado'
          : 'Retiro de reserva $reservationId',
      branch: branch['nombre'],
      body: {
        'operacion_id': id,
        'sucursal_id': branchId,
        'snapshot_version': data.version,
        'creado_at': DateTime.now().toUtc().toIso8601String(),
        'items': items,
        'efectivo_recibido': (_cents(received) / 100).toStringAsFixed(2),
        if (reservationId != null) 'reserva_id': reservationId,
      },
    );
    await store.saveRequest(record);
    if (owner != scope) return;
    queue = [...queue, record];
    message =
        'Cobro guardado. El comprobante es provisional hasta sincronizar.';
    _publish();
    if (online) unawaited(sync());
  }

  Future<void> refreshReservations() async {
    final scope = owner;
    if (!online || !canSell || scope == null) return;
    final rows = await api.get('/retail/reservations');
    final data = bundle;
    if (owner == scope && data != null) {
      final updated = OfflineBundle({...data.data, 'reservations': rows});
      await store.saveBundle(scope, updated);
      if (owner == scope) {
        bundle = updated;
        _publish();
      }
    }
  }

  Future<void> prepareReservation(int id, String state) async {
    if (!online) {
      throw ApiException('Conéctate para actualizar la preparación.');
    }
    await api.post('/retail/reservations/$id/prepare', body: {'estado': state});
    await refreshReservations();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    auth.removeListener(_accountChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
