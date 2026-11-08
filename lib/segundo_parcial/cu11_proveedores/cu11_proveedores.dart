import '../compartido/gestion_resource.dart';

const proveedores = ResourceSpec(
  'Proveedores',
  '/supply/suppliers',
  'suppliers.manage',
  [
    EntryField('nombre_empresa', 'Empresa proveedora'),
    EntryField('nit', 'NIT', required: false),
    EntryField('contacto_nombre', 'Persona de contacto', required: false),
    EntryField('telefono', 'Teléfono', required: false),
    EntryField('email', 'Correo electrónico', required: false),
    EntryField('ciudad', 'Ciudad'),
    EntryField('direccion', 'Dirección', required: false),
  ],
  preserve: ['categoria_suministro'],
);
