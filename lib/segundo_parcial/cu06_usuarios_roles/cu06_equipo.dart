import '../compartido/gestion_resource.dart';

const equipo = ResourceSpec(
  'Equipo',
  '/admin/users',
  'team.manage',
  [
    EntryField('nombre', 'Nombre completo'),
    EntryField('email', 'Correo electrónico', createOnly: true),
    EntryField(
      'password',
      'Contraseña inicial',
      secret: true,
      createOnly: true,
    ),
    EntryField('telefono', 'Teléfono', required: false),
    EntryField(
      'rol',
      'Función',
      options: [
        'ADMIN',
        'ENCARGADO',
        'CAJERO',
        'VENDEDOR',
        'PROVEEDOR',
        'CLIENTE',
      ],
    ),
    EntryField('estado', 'Estado', options: ['ACTIVO', 'INACTIVO']),
  ],
  updateMethod: 'PATCH',
  defaults: {'rol': 'CAJERO', 'estado': 'ACTIVO'},
);
const roles = ResourceSpec(
  'Roles de mi empresa',
  '/team/roles',
  'team.manage',
  [
    EntryField('nombre', 'Nombre del rol'),
    EntryField('descripcion', 'Descripción', required: false),
    EntryField(
      'base_role',
      'Puesto base',
      options: ['CAJERO', 'ENCARGADO', 'VENDEDOR', 'PROVEEDOR', 'CLIENTE'],
    ),
    EntryField(
      'permisos',
      'Permisos del rol',
      multiple: true,
      options: [
        'catalog.read',
        'catalog.manage',
        'inventory.manage',
        'branches.manage',
        'pricing.manage',
        'suppliers.manage',
        'sales.manage',
        'orders.manage',
        'reservations.manage',
        'exchanges.manage',
        'sync.review',
        'offline.use',
        'reports.view',
        'reports.ai',
        'notifications.manage',
      ],
    ),
  ],
  defaults: {'base_role': 'CAJERO', 'permisos': <String>[]},
);
