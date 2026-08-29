class Branch {
  final int id;
  final int ciudadId;
  final String codigo;
  final String nombre;
  final String direccion;
  final String? telefono;
  final String? ciudad;
  final String? departamento;

  const Branch({
    required this.id,
    required this.ciudadId,
    required this.codigo,
    required this.nombre,
    required this.direccion,
    this.telefono,
    this.ciudad,
    this.departamento,
  });

  factory Branch.fromJson(Map<String, dynamic> json) => Branch(
    id: int.parse(json['id'].toString()),
    ciudadId: int.parse(json['ciudad_id'].toString()),
    codigo: json['codigo']?.toString() ?? '',
    nombre: json['nombre']?.toString() ?? '',
    direccion: json['direccion']?.toString() ?? '',
    telefono: json['telefono']?.toString(),
    ciudad: json['ciudad']?.toString(),
    departamento: json['departamento']?.toString(),
  );
}

class BranchStock {
  final int sucursalId;
  final int varianteId;
  final int productoId;
  final String producto;
  final String sku;
  final String color;
  final String talla;
  final int stockDisponible;

  const BranchStock({
    required this.sucursalId,
    required this.varianteId,
    required this.productoId,
    required this.producto,
    required this.sku,
    required this.color,
    required this.talla,
    required this.stockDisponible,
  });

  factory BranchStock.fromJson(Map<String, dynamic> json) => BranchStock(
    sucursalId: int.parse(json['sucursal_id'].toString()),
    varianteId: int.parse(json['variante_id'].toString()),
    productoId: int.parse(json['producto_id'].toString()),
    producto: json['producto']?.toString() ?? '',
    sku: json['sku']?.toString() ?? '',
    color: json['color']?.toString() ?? '',
    talla: json['talla']?.toString() ?? '',
    stockDisponible: int.tryParse(json['stock_disponible'].toString()) ?? 0,
  );
}
