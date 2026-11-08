import '../compartido/gestion_resource.dart';

const prendas = ResourceSpec(
  'Prendas',
  '/admin/products',
  'catalog.manage',
  [
    EntryField('nombre', 'Nombre de la prenda'),
    EntryField('categoria_id', 'Categoría', lookup: '/admin/categories'),
    EntryField('precio', 'Precio en Bs', number: true),
    EntryField('descripcion', 'Descripción', required: false),
    EntryField('marca', 'Marca', required: false),
    EntryField('material', 'Material', required: false),
    EntryField(
      'genero_objetivo',
      'Colección',
      options: ['MUJER', 'HOMBRE', 'UNISEX'],
    ),
  ],
  defaults: {'genero_objetivo': 'UNISEX'},
  preserve: [
    'imagenes',
    'costo_referencia',
    'calidad_nivel',
    'descripcion_ai',
    'tags_ai',
  ],
);
const categorias =
    ResourceSpec('Categorías', '/admin/categories', 'catalog.manage', [
      EntryField('nombre', 'Nombre'),
      EntryField(
        'slug',
        'Identificador (se genera si lo dejas vacío)',
        required: false,
      ),
      EntryField('descripcion', 'Descripción', required: false),
    ]);
