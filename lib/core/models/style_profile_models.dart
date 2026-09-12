class StyleProfile {
  final int? id;
  final int? usuarioId;
  final String? genero;
  final List<String> estilosPreferidos;
  final String? tallaSuperior;
  final String? tallaInferior;
  final String? tallaCalzado;
  final List<String> coloresFavoritos;
  final List<String> ocasionesFrecuentes;
  final double? presupuestoHabitual;
  final String? siluetaPreferida;
  final String? adnEstiloIa;
  final Map<String, dynamic>? primerOutfitIa;
  final bool completado;

  StyleProfile({
    this.id,
    this.usuarioId,
    this.genero,
    this.estilosPreferidos = const [],
    this.tallaSuperior,
    this.tallaInferior,
    this.tallaCalzado,
    this.coloresFavoritos = const [],
    this.ocasionesFrecuentes = const [],
    this.presupuestoHabitual,
    this.siluetaPreferida,
    this.adnEstiloIa,
    this.primerOutfitIa,
    this.completado = false,
  });

  factory StyleProfile.fromJson(Map<String, dynamic> json) {
    return StyleProfile(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      usuarioId: json['usuario_id'] is int
          ? json['usuario_id']
          : int.tryParse(json['usuario_id']?.toString() ?? ''),
      genero: json['genero'] as String?,
      estilosPreferidos: (json['estilos_preferidos'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      tallaSuperior: json['talla_superior'] as String?,
      tallaInferior: json['talla_inferior'] as String?,
      tallaCalzado: json['talla_calzado'] as String?,
      coloresFavoritos: (json['colores_favoritos'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      ocasionesFrecuentes: (json['ocasiones_frecuentes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      presupuestoHabitual: json['presupuesto_habitual'] != null
          ? (json['presupuesto_habitual'] is num
              ? (json['presupuesto_habitual'] as num).toDouble()
              : double.tryParse(json['presupuesto_habitual'].toString()))
          : null,
      siluetaPreferida: json['silueta_preferida'] as String?,
      adnEstiloIa: json['adn_estilo_ia'] as String?,
      primerOutfitIa: json['primer_outfit_ia'] is Map<String, dynamic>
          ? json['primer_outfit_ia'] as Map<String, dynamic>
          : null,
      completado: json['completado'] == true,
    );
  }

  Map<String, dynamic> toJson({bool inferOutfit = false}) => {
        if (genero != null && genero!.isNotEmpty) 'genero': genero,
        'estilos_preferidos': estilosPreferidos,
        if (tallaSuperior != null && tallaSuperior!.isNotEmpty)
          'talla_superior': tallaSuperior,
        if (tallaInferior != null && tallaInferior!.isNotEmpty)
          'talla_inferior': tallaInferior,
        if (tallaCalzado != null && tallaCalzado!.isNotEmpty)
          'talla_calzado': tallaCalzado,
        'colores_favoritos': coloresFavoritos,
        'ocasiones_frecuentes': ocasionesFrecuentes,
        if (presupuestoHabitual != null && presupuestoHabitual! > 0)
          'presupuesto_habitual': presupuestoHabitual,
        if (siluetaPreferida != null && siluetaPreferida!.isNotEmpty)
          'silueta_preferida': siluetaPreferida,
        'infer_outfit': inferOutfit,
      };

  StyleProfile copyWith({
    int? id,
    int? usuarioId,
    String? genero,
    List<String>? estilosPreferidos,
    String? tallaSuperior,
    String? tallaInferior,
    String? tallaCalzado,
    List<String>? coloresFavoritos,
    List<String>? ocasionesFrecuentes,
    double? presupuestoHabitual,
    String? siluetaPreferida,
    String? adnEstiloIa,
    Map<String, dynamic>? primerOutfitIa,
    bool? completado,
  }) {
    return StyleProfile(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      genero: genero ?? this.genero,
      estilosPreferidos: estilosPreferidos ?? this.estilosPreferidos,
      tallaSuperior: tallaSuperior ?? this.tallaSuperior,
      tallaInferior: tallaInferior ?? this.tallaInferior,
      tallaCalzado: tallaCalzado ?? this.tallaCalzado,
      coloresFavoritos: coloresFavoritos ?? this.coloresFavoritos,
      ocasionesFrecuentes: ocasionesFrecuentes ?? this.ocasionesFrecuentes,
      presupuestoHabitual: presupuestoHabitual ?? this.presupuestoHabitual,
      siluetaPreferida: siluetaPreferida ?? this.siluetaPreferida,
      adnEstiloIa: adnEstiloIa ?? this.adnEstiloIa,
      primerOutfitIa: primerOutfitIa ?? this.primerOutfitIa,
      completado: completado ?? this.completado,
    );
  }
}
