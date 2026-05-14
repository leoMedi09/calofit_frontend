import '../utils/assistant_message_format.dart';

class AssistantResponse {
  final String usuario;
  final ScientificData dataCientifica;
  final StructuredResponse respuestaEstructurada;
  final String? intencion; // INFO, RECIPE, POWER, SUCCESS, DANGER, PROGRESS
  final String? tipoPregunta; // ABIERTA, RAPIDA
  final bool? alertaSalud;
  final String? advertencia;

  AssistantResponse({
    required this.usuario,
    required this.dataCientifica,
    required this.respuestaEstructurada,
    this.intencion,
    this.tipoPregunta,
    this.alertaSalud,
    this.advertencia,
  });

  factory AssistantResponse.fromJson(Map<String, dynamic> json) {
    return AssistantResponse(
      usuario: json['usuario'] ?? '',
      dataCientifica: ScientificData.fromJson(json['data_cientifica'] ?? {}),
      respuestaEstructurada:
          StructuredResponse.fromJson(json['respuesta_estructurada'] ?? {}),
      intencion: json['intencion'],
      tipoPregunta: json['tipo_pregunta'],
      alertaSalud: json['alerta_salud'] as bool?,
      advertencia: json['advertencia_nutricional'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'usuario': usuario,
      'intencion': intencion,
      'tipo_pregunta': tipoPregunta,
      'data_cientifica': dataCientifica.progresoDiario,
      'respuesta_estructurada': {
        'texto_conversacional': respuestaEstructurada.textoConversacional,
        if (respuestaEstructurada.schemaVersion != null)
          'schema_version': respuestaEstructurada.schemaVersion,
        'secciones': respuestaEstructurada.secciones.map((s) => s.toMap()).toList(),
      },
      'alerta_salud': alertaSalud,
    };
  }
}

class ScientificData {
  final Map<String, dynamic> progresoDiario;

  ScientificData({required this.progresoDiario});

  factory ScientificData.fromJson(Map<String, dynamic> json) {
    // Si el backend envía el progreso directamente en 'data_cientifica'
    if (json.containsKey('consumido') || json.containsKey('meta')) {
      return ScientificData(progresoDiario: json);
    }
    // Fallback por si viniera anidado
    return ScientificData(progresoDiario: json['progreso_diario'] ?? {});
  }
}

class StructuredResponse {
  final String textoConversacional;
  final List<Section> secciones;
  /// Versión del contrato backend (p. ej. 2 = incluye macros_normalizados por sección).
  final int? schemaVersion;

  StructuredResponse({
    required this.textoConversacional,
    required this.secciones,
    this.schemaVersion,
  });

  factory StructuredResponse.fromJson(Map<String, dynamic> json) {
    var list = json['secciones'] as List? ?? [];
    return StructuredResponse(
      textoConversacional: json['texto_conversacional'] ?? '',
      secciones: list.map((i) => Section.fromJson(i)).toList(),
      schemaVersion: (json['schema_version'] is int)
          ? json['schema_version'] as int
          : int.tryParse('${json['schema_version'] ?? ''}'),
    );
  }
}

/// Valores numéricos de macros (backend `schema_version` ≥ 2, campo `macros_normalizados`).
class MacrosNormalizados {
  final double kcal;
  final double proteinasG;
  final double carbohidratosG;
  final double grasasG;

  const MacrosNormalizados({
    required this.kcal,
    required this.proteinasG,
    required this.carbohidratosG,
    required this.grasasG,
  });

  /// Preferir chips/UI desde este bloque cuando hay kcal confiable.
  bool get hasUsableKcal => kcal > 0;

  /// Al menos un macronutriente o kcal distinto de cero (evita depender solo de parsear el string con emojis del LLM).
  bool get hasUsableMacros =>
      kcal > 0 || proteinasG > 0 || carbohidratosG > 0 || grasasG > 0;

  factory MacrosNormalizados.fromJson(Map<String, dynamic> json) {
    double r(String key) {
      final v = json[key];
      if (v is num) return v.toDouble();
      return double.tryParse('$v') ?? 0;
    }

    return MacrosNormalizados(
      kcal: r('kcal'),
      proteinasG: r('proteinas_g'),
      carbohidratosG: r('carbohidratos_g'),
      grasasG: r('grasas_g'),
    );
  }

  Map<String, dynamic> toMap() => {
        'kcal': kcal,
        'proteinas_g': proteinasG,
        'carbohidratos_g': carbohidratosG,
        'grasas_g': grasasG,
      };
}

class Section {
  final String tipo; // "comida" o "ejercicio"
  final String nombre;
  final String macros;
  final List<String> ingredientes;
  final List<String> preparacion;
  final String nota;
  final String? consultaId; // ID del cache backend para consistencia
  /// URL https de imagen de referencia (p. ej. Wikimedia); opcional.
  final String? imagenReferencia;
  /// Parseo estable del string `macros` (solo comidas; opcional según backend).
  final MacrosNormalizados? macrosNormalizados;

  Section({
    required this.tipo,
    required this.nombre,
    required this.macros,
    required this.ingredientes,
    required this.preparacion,
    required this.nota,
    this.consultaId,
    this.imagenReferencia,
    this.macrosNormalizados,
  });

  factory Section.fromJson(Map<String, dynamic> json) {
    // Para ejercicios, mapear ejercicios→ingredientes e instrucciones/tecnica→preparacion
    // Esto asegura que los widgets puedan leer los datos correctamente
    List<String> items = [];
    List<String> pasos = [];
    
    // Determinar si es ejercicio o comida
    String tipo = json['tipo'] ?? 'general';
    
    if (tipo == 'ejercicio') {
      items = List<String>.from(json['ejercicios'] ?? []);
      final rawInst = json['instrucciones'];
      final rawTec = json['tecnica'];
      if (rawInst is List) {
        pasos = List<String>.from(rawInst);
      } else if (rawTec is List) {
        pasos = List<String>.from(rawTec);
      } else {
        final blob = (rawInst ?? rawTec)?.toString().trim() ?? '';
        if (blob.isNotEmpty) {
          pasos = blob
              .split(RegExp(r'(?:\n\s*)|(?:\.\s+)'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      }
    } else {
      // Para COMIDA: ingredientes e ingredientes, preparacion → preparacion
      items = expandBulletSeparatedLines(
          List<String>.from(json['ingredientes'] ?? []));
      pasos = expandBulletSeparatedLines(
          List<String>.from(json['preparacion'] ?? []));
    }
    
    final rawImg = json['imagen_referencia']?.toString().trim();

    MacrosNormalizados? macrosNorm;
    final rawMn = json['macros_normalizados'];
    if (rawMn is Map<String, dynamic>) {
      macrosNorm = MacrosNormalizados.fromJson(rawMn);
    } else if (rawMn is Map) {
      macrosNorm =
          MacrosNormalizados.fromJson(Map<String, dynamic>.from(rawMn));
    }

    return Section(
      tipo: tipo,
      nombre: json['nombre'] ?? json['plato'] ?? '',
      macros: (json['macros'] ??
              json['gasto_calorico_estimado'] ??
              json['estimacion_calorica'] ??
              '')
          .toString(),
      ingredientes: items,
      preparacion: pasos,
      nota: (json['nota'] ?? '').toString(),
      consultaId: json['consulta_id'],
      imagenReferencia: (rawImg != null && rawImg.isNotEmpty) ? rawImg : null,
      macrosNormalizados: macrosNorm,
    );
  }

  Map<String, dynamic> toMap() {
    final base = <String, dynamic>{
      'tipo': tipo,
      'nombre': nombre,
      'macros': macros,
      'nota': nota,
      'consulta_id': consultaId,
      if (imagenReferencia != null) 'imagen_referencia': imagenReferencia,
      if (macrosNormalizados != null)
        'macros_normalizados': macrosNormalizados!.toMap(),
    };
    // Guardar con las claves que fromJson() espera según el tipo
    if (tipo == 'ejercicio') {
      base['ejercicios'] = ingredientes;
      base['tecnica'] = preparacion;
    } else {
      base['ingredientes'] = ingredientes;
      base['preparacion'] = preparacion;
    }
    return base;
  }
}
