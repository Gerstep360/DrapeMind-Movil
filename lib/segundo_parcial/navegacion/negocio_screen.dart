import 'package:drapemind_mobile/compartido/componentes/notificaciones/notification_bell.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drapemind_mobile/core/core.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/gestionar_cuenta/presentacion/account_screen.dart';
import '../compartido/gestion_resource.dart';
import '../cu06_usuarios_roles/cu06_equipo.dart';
import '../cu07_sucursales/cu07_sucursales.dart';
import '../cu08_productos/cu08_prendas.dart';
import '../cu08_productos/cu08_variantes.dart';
import '../cu10_precios_promociones/cu10_promociones.dart';
import '../cu11_proveedores/cu11_proveedores.dart';
import '../cu09_inventario/cu09_stock_screen.dart';
import '../cu28_machine_learning/cu28_predicciones.dart';
import '../cu15_ventas_contado/cu15_retail_screen.dart';
import '../cu25_reportes_voz/cu25_reports_screen.dart';
import '../cu27_dashboard/cu27_dashboard_screen.dart';
import '../cu04_plan_empresa/cu04_subscription_screen.dart';
import 'package:drapemind_mobile/segundo_parcial/cu22_carrito_checkout/carrito/cu22_cart_screen.dart';

class BusinessHubScreen extends StatelessWidget {
  const BusinessHubScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    void open(Widget screen) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
    Widget destination(
      String title,
      String subtitle,
      IconData icon,
      Widget screen,
    ) => ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => open(screen),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi negocio'),
        actions: const [NotificationBell()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            user?.tenantName ?? 'Tu tienda',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const Text(
            'Administra tu tienda desde el teléfono. Cada acción respeta tus permisos y el plan de la empresa.',
          ),
          const Divider(height: 32),
          if (user?.can('inventory.manage') == true)
            destination(
              'Inventario',
              'Existencias y ajustes por sucursal',
              Icons.inventory_2_outlined,
              const InventoryScreen(),
            ),
          if (user?.rol == UserRole.admin)
            destination(
              'Predicción de demanda',
              'Modelos guardados y planificación de compras',
              Icons.trending_up,
              const PredictionsScreen(),
            ),
          if (user?.can('reports.view') == true)
            destination(
              'Indicadores',
              'Ventas, inventario y prendas más vendidas',
              Icons.bar_chart,
              const BusinessDashboardScreen(),
            ),
          if (user?.can('reports.ai') == true)
            destination(
              'Reportes con Altair',
              'Consulta con texto o voz y descarga el informe',
              Icons.auto_awesome,
              const ReportsScreen(),
            ),
          if (user?.can('sales.manage') == true)
            destination(
              'Caja y reservas',
              'Ventas de contado, preparación y retiros',
              Icons.point_of_sale,
              const RetailScreen(),
            ),
          for (final spec in [
            equipo,
            roles,
            sucursales,
            ciudades,
            prendas,
            categorias,
            promociones,
            proveedores,
          ])
            if (user?.can(spec.permission) == true)
              destination(
                spec.title,
                'Consultar, agregar y actualizar',
                Icons.edit_outlined,
                ResourceScreen(
                  spec: spec,
                  onSecondary: spec == prendas
                      ? (row) => open(
                          VariantsScreen(
                            productId: row['id'],
                            name: row['nombre'],
                          ),
                        )
                      : null,
                ),
              ),
          destination(
            'Mi carrito',
            'Prendas que has elegido en esta tienda',
            Icons.shopping_bag_outlined,
            const CartScreen(),
          ),
          destination(
            'Mi cuenta',
            'Perfil, seguridad y sesión',
            Icons.person_outline,
            const AccountScreen(),
          ),
          if (user?.rol == UserRole.admin)
            destination(
              'Plan de empresa',
              'Suscripción, renovación y facturación',
              Icons.business_outlined,
              const SubscriptionScreen(),
            ),
        ],
      ),
    );
  }
}
