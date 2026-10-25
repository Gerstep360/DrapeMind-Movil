import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:drapemind_mobile/core/config/api_config.dart';
import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/core/network/api_exception.dart';
import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/datos/servicios/auth_service.dart';

class PlatformScreen extends StatefulWidget {
  final ApiClient? apiClient;
  const PlatformScreen({super.key, this.apiClient});
  @override
  State<PlatformScreen> createState() => _PlatformScreenState();
}

class _PlatformScreenState extends State<PlatformScreen> {
  late final ApiClient _api = widget.apiClient ?? ApiClient();
  List<Map<String, dynamic>>? _companies;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final rows = await _api.get('/saas/tenants');
      if (mounted) {
        setState(
          () => _companies = (rows as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
        );
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No pudimos cargar las empresas. Intenta nuevamente.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.paper,
    appBar: AppBar(
      title: const Text('DrapeMind · Plataforma'),
      actions: [
        IconButton(
          tooltip: 'Actualizar empresas',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          tooltip: 'Cerrar sesión',
          onPressed: () => context.read<AuthService>().logout(),
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  TextButton(onPressed: _load, child: const Text('Reintentar')),
                ],
              ),
            ),
          )
        : _companies == null
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Tus empresas',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '${_companies!.length} empresas · ${_companies!.where((e) => e['access_active'] == true).length} con acceso activo',
                ),
                const SizedBox(height: 20),
                if (_companies!.isEmpty)
                  const Text(
                    'Aún no hay empresas registradas. Puedes crear la primera desde el panel web.',
                  ),
                for (final row in _companies!) ...[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.paperLight,
                      border: Border.all(color: AppColors.lineStrong),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row['tenant']['name'],
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${row['plan']?['name'] ?? 'Sin plan'} · ${row['access_active'] == true ? 'Acceso activo' : 'Acceso pendiente'}',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${row['active_branches'] ?? 0} de ${row['plan']?['max_branches'] ?? 0} sucursales',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse('${ApiConfig.baseUrl}/saas-platform'),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Gestionar en la web'),
                ),
              ],
            ),
          ),
  );
}
