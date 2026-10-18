import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/core/network/api_exception.dart';
import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/datos/servicios/auth_service.dart';

class SubscriptionScreen extends StatefulWidget {
  final ApiClient? apiClient;
  final VoidCallback? onActivated;
  const SubscriptionScreen({super.key, this.onActivated, this.apiClient});
  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with WidgetsBindingObserver {
  late final _api = widget.apiClient ?? ApiClient();
  Map<String, dynamic>? _state;
  List<dynamic> _plans = [];
  String _interval = 'month';
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (context.read<AuthService>().isAdmin) {
        try { await _api.post('/saas/sync', body: {}); }
        on ApiException catch(e) { if(mounted)setState(()=>_error=e.message); }
      }
      final values = await Future.wait([
        _api.get('/saas/me'),
        _api.get('/saas/plans'),
      ]);
      if (!mounted) return;
      setState(() {
        _state = Map<String, dynamic>.from(values[0]);
        _plans = values[1] as List;
      });
      if (_state?['access_active'] == true) widget.onActivated?.call();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo consultar el plan. Intenta nuevamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stripe(String path, {Map<String, dynamic>? body}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await _api.post(path, body: body ?? {});
      if (response['synchronized'] == true) {
        await _load();
        return;
      }
      final uri = Uri.parse(response['url']);
      if (uri.scheme != 'https' ||
          !['checkout.stripe.com', 'billing.stripe.com'].contains(uri.host)) {
        throw const FormatException();
      }
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw const FormatException();
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo abrir Stripe. Intenta nuevamente.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AuthService>().isAdmin;
    final subscription = _state?['subscription'] as Map?;
    final plan = _state?['plan'] as Map?;
    final portal = _state?['portal_available'] == true;
    final features = {
      'products_sales': 'Productos y ventas',
      'reservations': 'Reservas',
      'offline': 'Acceso offline',
      'reports': 'Reportes normales',
      'ai_reports': 'Reportes con IA',
    };
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('Plan de empresa'),
        actions: [
          IconButton(
            tooltip: 'Actualizar estado',
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () => context.read<AuthService>().logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              _state?['tenant']?['name'] ?? 'Tu empresa',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${plan?['name'] ?? 'Sin plan'} · ${_state?['access_active'] == true ? 'Acceso activo' : 'Pendiente o vencido'}',
            ),
            const SizedBox(height: 8),
            Text(
              'Sucursales: ${_state?['active_branches'] ?? 0} / ${plan?['max_branches'] ?? 0}',
            ),
            if (subscription?['ends_at'] != null)
              Text(
                'Vence: ${subscription!['ends_at'].toString().split('T').first}',
              ),
            if (subscription?['source'] != 'STRIPE')
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Licencia administrativa. No registra un cobro Stripe.',
                ),
              ),
            if (_state?['access_active'] == false)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Activa la suscripción para continuar. Los datos de tu empresa se conservan.',
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger),
                  semanticsLabel: 'Error: $_error',
                ),
              ),
            if (_busy) const LinearProgressIndicator(),
            if (admin && portal)
              FilledButton.icon(
                onPressed: _busy ? null : () => _stripe('/saas/portal'),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Gestionar con Stripe'),
              ),
            const SizedBox(height: 24),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'month', label: Text('Mensual')),
                ButtonSegment(value: 'year', label: Text('Anual')),
              ],
              selected: {_interval},
              onSelectionChanged: (v) => setState(() => _interval = v.first),
            ),
            if (_interval == 'year')
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Dos meses de ahorro respecto al pago mensual.'),
              ),
            const SizedBox(height: 20),
            for (final p in _plans)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: p['code'] == 'PRO'
                        ? AppColors.limeSoft
                        : Colors.white,
                    border: Border.all(color: AppColors.ink, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['name'],
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text('${p['max_branches']} sucursales activas'),
                      const SizedBox(height: 12),
                      Text(
                        '${p['currency'].toString().toUpperCase()} ${((p[_interval == 'month' ? 'monthly_amount_minor' : 'annual_amount_minor'] as num) / 100).toStringAsFixed(2)} / ${_interval == 'month' ? 'mes' : 'año'}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      for (final feature in features.entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                p['features'][feature.key] == true
                                    ? Icons.check
                                    : Icons.remove,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(feature.value)),
                            ],
                          ),
                        ),
                      if (admin)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: FilledButton(
                            onPressed:
                                _busy ||
                                    portal ||
                                    p['active'] != true ||
                                    p[_interval == 'month'
                                            ? 'checkout_available'
                                            : 'annual_checkout_available'] !=
                                        true
                                ? null
                                : () => _stripe(
                                    '/saas/checkout',
                                    body: {
                                      'plan_id': p['id'],
                                      'billing_interval': _interval,
                                    },
                                  ),
                            child: const Text('Contratar con Stripe'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            const Text(
            'Stripe confirma el importe antes de pagar. Al terminar, vuelve a DrapeMind para actualizar el estado. Los cambios de plan y la cancelación se gestionan desde su portal. Para bajar de plan, ajusta primero tus sucursales.',
            ),
          ],
        ),
      ),
    );
  }
}
