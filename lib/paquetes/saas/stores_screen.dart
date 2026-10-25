import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/core/network/api_exception.dart';
import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/datos/servicios/auth_service.dart';

class StoresScreen extends StatefulWidget {
  final ApiClient? apiClient;
  final bool unavailable;
  const StoresScreen({super.key, this.apiClient, this.unavailable = false});
  @override
  State<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  List<Map<String, dynamic>>? _stores;
  String? _error;
  String? _opening;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await (widget.apiClient ?? ApiClient()).get(
        '/saas/companies',
        requiresAuth: false,
      );
      if (mounted) {
        setState(
          () => _stores = (rows as List)
              .map((row) => Map<String, dynamic>.from(row))
              .toList(),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No pudimos cargar las tiendas. Intenta nuevamente.',
        );
      }
    }
  }

  Future<void> _open(String slug) async {
    if (_opening != null) return;
    setState(() {
      _opening = slug;
      _error = null;
    });
    try {
      await context.read<AuthService>().enterStore(slug);
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No pudimos abrir la tienda. Intenta nuevamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.paper,
    appBar: AppBar(title: const Text('Tus tiendas')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (widget.unavailable) ...[
          const Text(
            'Esta tienda no está recibiendo compras por ahora. Puedes visitar otra con tu misma cuenta.',
          ),
          const SizedBox(height: 20),
        ],
        Text(
          'Una cuenta. Muchas formas de vestir.',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        const Text(
          'Elige dónde comprar. Cada tienda conserva sus propios productos, carrito y pedidos.',
        ),
        const SizedBox(height: 24),
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
          TextButton(onPressed: _load, child: const Text('Reintentar')),
        ],
        if (_stores == null && _error == null)
          const Center(child: CircularProgressIndicator()),
        if (_stores?.isEmpty == true)
          const Text('Aún no hay tiendas disponibles.'),
        for (final store in _stores ?? <Map<String, dynamic>>[])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              tileColor: AppColors.white,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: AppColors.ink),
                borderRadius: BorderRadius.circular(4),
              ),
              leading: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                color: AppColors.lime,
                child: Text(
                  (store['name'] as String).substring(0, 1),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              title: Text(store['name']),
              subtitle: Text(
                context.watch<AuthService>().currentUser?.tenantSlug ==
                        store['slug']
                    ? 'Tienda actual'
                    : 'Visitar tienda',
              ),
              trailing: _opening == store['slug']
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward),
              onTap: _opening == null ? () => _open(store['slug']) : null,
            ),
          ),
      ],
    ),
  );
}
