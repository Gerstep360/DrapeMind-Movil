class Address {
  final int id;
  final int usuarioId;
  final String alias;
  final String departamento;
  final String ciudad;
  final String? zona;
  final String direccion;
  final String? referencia;
  final String? telefonoContacto;
  final bool esPrincipal;

  Address({
    required this.id,
    required this.usuarioId,
    required this.alias,
    required this.departamento,
    required this.ciudad,
    this.zona,
    required this.direccion,
    this.referencia,
    this.telefonoContacto,
    this.esPrincipal = false,
  });

  String get formattedAddress =>
      '$direccion${zona != null && zona!.isNotEmpty ? ', $zona' : ''}, $ciudad, $departamento';

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      usuarioId: json['usuario_id'] is int
          ? json['usuario_id']
          : int.tryParse(json['usuario_id'].toString()) ?? 0,
      alias: json['alias'] ?? 'Principal',
      departamento: json['departamento'] ?? '',
      ciudad: json['ciudad'] ?? '',
      zona: json['zona'],
      direccion: json['direccion'] ?? '',
      referencia: json['referencia'],
      telefonoContacto: json['telefono_contacto'],
      esPrincipal: json['es_principal'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'usuario_id': usuarioId,
    'alias': alias,
    'departamento': departamento,
    'ciudad': ciudad,
    'zona': zona,
    'direccion': direccion,
    'referencia': referencia,
    'telefono_contacto': telefonoContacto,
    'es_principal': esPrincipal,
  };
}

class AddressInput {
  final String alias;
  final String departamento;
  final String ciudad;
  final String? zona;
  final String direccion;
  final String? referencia;
  final String? telefonoContacto;
  final bool esPrincipal;

  AddressInput({
    required this.alias,
    required this.departamento,
    required this.ciudad,
    this.zona,
    required this.direccion,
    this.referencia,
    this.telefonoContacto,
    this.esPrincipal = false,
  });

  Map<String, dynamic> toJson() => {
    'alias': alias.trim(),
    'departamento': departamento.trim(),
    'ciudad': ciudad.trim(),
    if (zona != null && zona!.isNotEmpty) 'zona': zona!.trim(),
    'direccion': direccion.trim(),
    if (referencia != null && referencia!.isNotEmpty)
      'referencia': referencia!.trim(),
    if (telefonoContacto != null && telefonoContacto!.isNotEmpty)
      'telefono_contacto': telefonoContacto!.trim(),
    'es_principal': esPrincipal,
  };
}
