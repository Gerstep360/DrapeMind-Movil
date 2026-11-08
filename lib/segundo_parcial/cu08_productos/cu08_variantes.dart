import 'package:flutter/material.dart';
import '../compartido/gestion_resource.dart';

class VariantsScreen extends StatelessWidget {
  final int productId;
  final String name;
  const VariantsScreen({
    super.key,
    required this.productId,
    required this.name,
  });
  @override
  Widget build(BuildContext context) => ResourceScreen(
    spec: ResourceSpec(
      'Tallas y colores · $name',
      '/admin/products/$productId/variants',
      'catalog.manage',
      const [
        EntryField('sku', 'Código SKU'),
        EntryField('talla', 'Talla'),
        EntryField('color', 'Color'),
        EntryField('codigo_barras', 'Código de barras', required: false),
      ],
      listPath: '/admin/variants?producto_id=$productId',
      updatePath: '/admin/variants',
      preserve: const ['stock_total', 'codigo_color', 'imagen'],
    ),
  );
}
