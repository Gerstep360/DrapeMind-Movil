enum UserRole {
  cliente,
  admin,
  vendedor;

  static UserRole fromString(String? role) {
    switch (role?.toUpperCase()) {
      case 'ADMIN':
        return UserRole.admin;
      case 'VENDEDOR':
        return UserRole.vendedor;
      default:
        return UserRole.cliente;
    }
  }

  String toServerString() {
    switch (this) {
      case UserRole.admin:
        return 'ADMIN';
      case UserRole.vendedor:
        return 'VENDEDOR';
      case UserRole.cliente:
        return 'CLIENTE';
    }
  }
}

class User {
  final int id;
  final String nombre;
  final String email;
  final String? telefono;
  final UserRole rol;
  final String estado;
  final DateTime createdAt;

  User({
    required this.id,
    required this.nombre,
    required this.email,
    this.telefono,
    required this.rol,
    required this.estado,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      nombre: json['nombre'] ?? '',
      email: json['email'] ?? '',
      telefono: json['telefono'],
      rol: UserRole.fromString(json['rol']),
      estado: json['estado'] ?? 'ACTIVO',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'email': email,
        'telefono': telefono,
        'rol': rol.toServerString(),
        'estado': estado,
        'created_at': createdAt.toIso8601String(),
      };
}

class TokenResponse {
  final String accessToken;
  final String tokenType;
  final int expiresIn;

  TokenResponse({
    required this.accessToken,
    this.tokenType = 'bearer',
    required this.expiresIn,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      accessToken: json['access_token'] ?? '',
      tokenType: json['token_type'] ?? 'bearer',
      expiresIn: json['expires_in'] is int
          ? json['expires_in']
          : int.tryParse(json['expires_in'].toString()) ?? 86400,
    );
  }
}

class LoginRequest {
  final String email;
  final String password;

  LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {
        'email': email.trim(),
        'password': password,
      };
}

class RegisterRequest {
  final String nombre;
  final String email;
  final String password;
  final String? telefono;

  RegisterRequest({
    required this.nombre,
    required this.email,
    required this.password,
    this.telefono,
  });

  Map<String, dynamic> toJson() => {
        'nombre': nombre.trim(),
        'email': email.trim(),
        'password': password,
        if (telefono != null && telefono!.isNotEmpty) 'telefono': telefono!.trim(),
      };
}
