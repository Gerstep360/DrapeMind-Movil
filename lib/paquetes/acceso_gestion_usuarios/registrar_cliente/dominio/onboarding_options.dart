/// Catálogos de captura del perfil inicial.
///
/// Se mantienen fuera de la pantalla para poder sustituirlos por configuración
/// remota o catálogos del backend sin reescribir el flujo visual.
abstract final class OnboardingOptions {
  static const genders = <Map<String, String>>[
    {
      'id': 'femenino',
      'label': 'Femenino',
      'desc': 'Siluetas y cortes curados para mujer',
    },
    {
      'id': 'masculino',
      'label': 'Masculino',
      'desc': 'Líneas sartoriales y contemporáneas para hombre',
    },
    {
      'id': 'unisex',
      'label': 'Andrógino / Unisex',
      'desc': 'Prendas versátiles fluidas sin distinción',
    },
    {
      'id': 'otro',
      'label': 'Expresión libre',
      'desc': 'Exploración híbrida y vanguardista',
    },
  ];

  static const styles = <Map<String, String>>[
    {
      'id': 'Minimalista Atelier',
      'desc': 'Líneas limpias, cortes depurados y sobriedad',
    },
    {
      'id': 'Casual Sofisticado',
      'desc': 'Elegancia sin esfuerzo para el día a día',
    },
    {
      'id': 'Streetwear Urbano',
      'desc': 'Volúmenes oversize, gráficos sutiles y confort',
    },
    {
      'id': 'Clásico Contemporáneo',
      'desc': 'Estructuras sartoriales adaptadas a la modernidad',
    },
    {
      'id': 'Avant-Garde / Editorial',
      'desc': 'Prendas audaces con carácter de pasarela',
    },
    {
      'id': 'Bohemia Chic',
      'desc': 'Texturas naturales, fluidez y tonalidades botánicas',
    },
  ];

  static const topSizes = <String>[
    'XXS',
    'XS',
    'S',
    'M',
    'L',
    'XL',
    '2XL',
    '3XL',
    '4XL',
  ];
  static const bottomSizes = <String>[
    '24',
    '26',
    '28',
    '30',
    '32',
    '34',
    '36',
    '38',
    '40',
    '42',
    '44',
  ];
  static const shoeSizes = <String>[
    '35',
    '36',
    '37',
    '38',
    '39',
    '40',
    '41',
    '42',
    '43',
    '44',
    '45',
    '46',
  ];
  static const silhouettes = <String>[
    'Oversize',
    'Regular Confort',
    'Slim Estilizado',
    'Fit / Ceñido',
  ];

  static const colors = <Map<String, String>>[
    {
      'id': 'Monocromático',
      'desc': 'Negro atelier, blanco crudo y grafito',
      'colorHex': '#10110F',
    },
    {
      'id': 'Tonos Tierra',
      'desc': 'Terracota, arena, habano y oliva',
      'colorHex': '#8C6239',
    },
    {
      'id': 'Neutros Cálidos',
      'desc': 'Beige, marfil y camel',
      'colorHex': '#D4AF37',
    },
    {
      'id': 'Pasteles Nórdicos',
      'desc': 'Celeste hielo, salvia y rosa empolvado',
      'colorHex': '#C9EEF0',
    },
    {
      'id': 'Acentos Vivos / Neón',
      'desc': 'Drape Lime, cobalto y magenta',
      'colorHex': '#DFFF3F',
    },
  ];

  static const occasions = <Map<String, String>>[
    {
      'id': 'Casual Diario',
      'desc': 'Confort con diseño para café, reuniones o paseo',
    },
    {
      'id': 'Oficina / Sartorial',
      'desc': 'Cortes pulidos y presencia ejecutiva',
    },
    {'id': 'Salidas & Noche', 'desc': 'Impacto visual para cócteles o cenas'},
    {'id': 'Eventos Especiales', 'desc': 'Alta costura y sofisticación formal'},
  ];

  static const budgets = <Map<String, dynamic>>[
    {'value': 300.0, 'label': 'Esencial', 'range': 'Hasta Bs 300'},
    {'value': 600.0, 'label': 'Intermedio', 'range': 'Bs 300 - Bs 600'},
    {
      'value': 1000.0,
      'label': 'Atelier Signature',
      'range': 'Bs 600 - Bs 1,200',
    },
    {
      'value': 2000.0,
      'label': 'Colección Exclusiva',
      'range': 'Más de Bs 1,200',
    },
  ];
}
