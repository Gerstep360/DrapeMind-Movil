import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:drapemind_mobile/core/config/api_config.dart';
import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/datos/servicios/auth_service.dart';

/// CU-11 se opera en Web; un proveedor no debe entrar como cliente de la tienda.
class ProveedorWebScreen extends StatelessWidget {
  const ProveedorWebScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.paper,
    appBar: AppBar(
      title: const Text('Tu espacio de proveedor'),
      actions: [
        IconButton(
          tooltip: 'Cerrar sesión',
          icon: const Icon(Icons.logout),
          onPressed: () => context.read<AuthService>().logout(),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.local_shipping_outlined, size: 64),
              const SizedBox(height: 24),
              const Text(
                'Tus ofertas y pedidos, en un solo lugar',
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              const Text(
                'Abre el portal web e inicia sesión con tu cuenta de proveedor para actualizar tus ofertas y confirmar los pedidos de la tienda.',
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: const Text('Abrir portal de proveedores'),
                onPressed: () async {
                  final opened = await launchUrl(
                    Uri.parse('${ApiConfig.baseUrl}/suppliers-admin'),
                    mode: LaunchMode.externalApplication,
                  );
                  if (!opened && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'No pudimos abrir el navegador. Inténtalo nuevamente.',
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
