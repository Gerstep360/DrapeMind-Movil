class OfflineBundle {
  final Map<String, dynamic> data;
  OfflineBundle(this.data);
  factory OfflineBundle.fromJson(Map<String, dynamic> value) {
    if (value['schema_version'] != 1 || value['owner'] is! String) {
      throw const FormatException('Actualiza la descarga de tu tienda.');
    }
    return OfflineBundle(value);
  }
  String get owner => data['owner'];
  String get version => data['version'];
  String get tenantName => data['tenant_name'];
  DateTime get downloadedAt => DateTime.parse(data['downloaded_at']);
  DateTime get validUntil => DateTime.parse(data['valid_until']);
  List<Map<String, dynamic>> rows(String key) => ((data[key] as List?) ?? [])
      .map((row) => Map<String, dynamic>.from(row))
      .toList();
  List<Map<String, dynamic>> get products => rows('products');
  List<Map<String, dynamic>> get variants => rows('variants');
  List<Map<String, dynamic>> get branches => rows('branches');
  List<Map<String, dynamic>> get stock => rows('stock');
  List<Map<String, dynamic>> get reservations => rows('reservations');
}

class OfflineRequest {
  final String kind;
  final int? serverId;
  final Map<String, dynamic>? sale;
  final String key;
  final String owner;
  final String name;
  final String branch;
  final Map<String, dynamic> body;
  final String state;
  final int attempts;
  final String? message;
  final Map<String, dynamic>? reservation;
  const OfflineRequest({
    this.kind = 'RESERVATION',
    this.serverId,
    this.sale,
    required this.key,
    required this.owner,
    required this.name,
    required this.branch,
    required this.body,
    this.state = 'PENDING',
    this.attempts = 0,
    this.message,
    this.reservation,
  });
  factory OfflineRequest.fromJson(Map<String, dynamic> value) => OfflineRequest(
    kind: value['kind'] ?? 'RESERVATION',
    serverId: value['serverId'],
    sale: value['sale'] == null
        ? null
        : Map<String, dynamic>.from(value['sale']),
    key: value['key'],
    owner: value['owner'],
    name: value['name'],
    branch: value['branch'],
    body: Map<String, dynamic>.from(value['body']),
    state: value['state'],
    attempts: value['attempts'] ?? 0,
    message: value['message'],
    reservation: value['reservation'] == null
        ? null
        : Map<String, dynamic>.from(value['reservation']),
  );
  Map<String, dynamic> toJson() => {
    'kind': kind,
    'serverId': serverId,
    'sale': sale,
    'key': key,
    'owner': owner,
    'name': name,
    'branch': branch,
    'body': body,
    'state': state,
    'attempts': attempts,
    'message': message,
    'reservation': reservation,
  };
  OfflineRequest change({
    int? serverId,
    Map<String, dynamic>? sale,
    String? state,
    int? attempts,
    String? message,
    Map<String, dynamic>? reservation,
  }) => OfflineRequest(
    kind: kind,
    serverId: serverId ?? this.serverId,
    sale: sale ?? this.sale,
    key: key,
    owner: owner,
    name: name,
    branch: branch,
    body: body,
    state: state ?? this.state,
    attempts: attempts ?? this.attempts,
    message: message,
    reservation: reservation ?? this.reservation,
  );
  String get label => switch (state) {
    'PENDING' => 'Guardada en el dispositivo',
    'SENDING' => 'Enviando…',
    'UNCERTAIN' => 'Por comprobar al conectar',
    'CONFLICT' => 'Necesita tu atención',
    'CONFIRMED' => 'Recibida por la tienda',
    'REJECTED' => 'Anulada por el encargado',
    _ => 'Cancelada',
  };
}
