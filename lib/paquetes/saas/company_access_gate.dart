import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/core/network/api_exception.dart';
import 'package:drapemind_mobile/core/services/offline_catalog.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/datos/servicios/auth_service.dart';
import 'subscription_screen.dart';

class CompanyAccessGate extends StatefulWidget {
  final Widget child;
  final ApiClient? apiClient;
  const CompanyAccessGate({super.key, required this.child, this.apiClient});
  @override
  State<CompanyAccessGate> createState() => _CompanyAccessGateState();
}

class _CompanyAccessGateState extends State<CompanyAccessGate>
    with WidgetsBindingObserver {
  late final ApiClient _api = widget.apiClient ?? ApiClient();
  bool? _allowed;
  String? _error;
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
    try {
      final state = await _api.get('/saas/me');
      if (mounted) setState(() => _allowed = state['access_active'] == true);
    } on NetworkException {
      if (!mounted) return;
      final owner = OfflineCatalog.owner(context.read<AuthService>().token);
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('dm_license_$owner');
      final state = raw == null ? null : jsonDecode(raw);
      final expires = DateTime.tryParse(
        state?['subscription']?['ends_at'] ?? '',
      );
      if (mounted) {
        setState(
          () => _allowed =
              owner != null &&
              state?['access_active'] == true &&
              state?['plan']?['features']?['offline'] == true &&
              expires != null &&
              expires.isAfter(DateTime.now()),
        );
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No pudimos comprobar el acceso de tu empresa. Intenta nuevamente.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!),
              TextButton(
                onPressed: () {
                  setState(() => _error = null);
                  _load();
                },
                child: const Text('Reintentar'),
              ),
              TextButton(
                onPressed: () => context.read<AuthService>().logout(),
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      );
    }
    if (_allowed == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_allowed == false) {
      return SubscriptionScreen(
        apiClient: _api,
        onActivated: () => setState(() => _allowed = true),
      );
    }
    return ValueListenableBuilder<bool>(
      valueListenable: OfflineCatalog.active,
      builder: (context, offline, _) => Column(
        children: [
          if (offline)
            const SafeArea(
              bottom: false,
              child: Material(
                color: Color(0xFFEEFF9D),
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'Sin conexión · catálogo guardado. Confirma precios y stock al reconectar.',
                  ),
                ),
              ),
            ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}
