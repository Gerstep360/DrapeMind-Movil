import '../compartido/gestion_resource.dart';

const sucursales = ResourceSpec(
  'Sucursales',
  '/branches',
  'branches.manage',
  [
    EntryField('nombre', 'Nombre de la sucursal'),
    EntryField('codigo', 'Código de sucursal'),
    EntryField('ciudad_id', 'Ciudad', lookup: '/branches/cities'),
    EntryField('direccion', 'Dirección'),
    EntryField('telefono', 'Teléfono', required: false),
  ],
  preserve: ['latitud', 'longitud'],
);
const ciudades = ResourceSpec(
  'Ciudades',
  '/branches/cities',
  'branches.manage',
  [EntryField('nombre', 'Ciudad'), EntryField('departamento', 'Departamento')],
);
