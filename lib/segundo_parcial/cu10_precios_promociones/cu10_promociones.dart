import '../compartido/gestion_resource.dart';

const promociones = ResourceSpec(
  'Promociones',
  '/admin/promotions',
  'pricing.manage',
  [
    EntryField('codigo', 'Código del cupón'),
    EntryField('descripcion', 'Descripción', required: false),
    EntryField(
      'tipo_descuento',
      'Descuento',
      options: ['PORCENTAJE', 'MONTO_FIJO', 'DOS_POR_UNO', 'COMPRA_MINIMA'],
    ),
    EntryField('valor_descuento', 'Valor del descuento', number: true),
    EntryField('monto_minimo_compra', 'Compra mínima (Bs)', number: true),
  ],
  defaults: {'tipo_descuento': 'PORCENTAJE', 'monto_minimo_compra': 0},
  preserve: ['fecha_inicio', 'fecha_fin', 'limite_usos', 'producto_id'],
);
