import '../utils/assistant_message_format.dart';

class AssistantResponse {
  final String usuario;
  final ScientificData dataCientifica;
  final StructuredResponse respuestaEstructurada;
  final String? intencion;
  final String? tipoPregunta;
  final bool? alertaSalud;
  final String? advertencia;
  final Map<String, dynamic>? datos;

  AssistantResponse({
    required this.usuario,
    required this.dataCientifica,
    required this.respuestaEstructurada,
    this.intencion,
    this.tipoPregunta,
    this.alertaSalud,
    this.advertencia,
    this.datos,
  });

  factory AssistantResponse.fromJson(Map<String, dynamic> json) {
    final rawDatos = json['datos'];
    return AssistantResponse(
      usuario: json['usuario'] ?? '',
      dataCientifica: ScientificData.fromJson(json['data_cientifica'] ?? {}),
      respuestaEstructurada:
          StructuredResponse.fromJson(json['respuesta_estructurada'] ?? {}),
      intencion: json['intencion'],
      tipoPregunta: json['tipo_pregunta'],
      alertaSalud: json['alerta_salud'] as bool?,
      advertencia: json['advertencia_nutricional'],
      datos: rawDatos is Map ? Map<String, dynamic>.from(rawDatos) : null,
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
      if (datos != null) 'datos': datos,
    };
  }
}

class ScientificData {
  final Map<String, dynamic> progresoDiario;

  ScientificData({required this.progresoDiario});

  factory ScientificData.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('consumido') || json.containsKey('meta')) {
      return ScientificData(progresoDiario: json);
    }
    return ScientificData(progresoDiario: json['progreso_diario'] ?? {});
  }
}

class StructuredResponse {
  final String textoConversacional;
  final List<Section> secciones;
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

  bool get hasUsableKcal => kcal > 0;

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
  final String tipo;
  final String nombre;
  final String justificacion;
  final String macros;
  final List<String> ingredientes;
  final List<String> preparacion;
  final String nota;
  final String? consultaId;
  final String? imagenReferencia;
  final MacrosNormalizados? macrosNormalizados;

  Section({
    required this.tipo,
    required this.nombre,
    this.justificacion = '',
    required this.macros,
    required this.ingredientes,
    required this.preparacion,
    required this.nota,
    this.consultaId,
    this.imagenReferencia,
    this.macrosNormalizados,
  });

  factory Section.fromJson(Map<String, dynamic> json) {
    List<String> items = [];
    List<String> pasos = [];
    
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
      justificacion: (json['justificacion'] ?? '').toString(),
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
