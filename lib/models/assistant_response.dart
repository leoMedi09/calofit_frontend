class AssistantResponse {
  final String usuario;
  final ScientificData dataCientifica;
  final StructuredResponse respuestaEstructurada;
  final bool? alertaSalud;
  final String? advertencia;

  AssistantResponse({
    required this.usuario,
    required this.dataCientifica,
    required this.respuestaEstructurada,
    this.alertaSalud,
    this.advertencia,
  });

  factory AssistantResponse.fromJson(Map<String, dynamic> json) {
    return AssistantResponse(
      usuario: json['usuario'] ?? '',
      dataCientifica: ScientificData.fromJson(json['data_cientifica'] ?? {}),
      respuestaEstructurada: StructuredResponse.fromJson(json['respuesta_estructurada'] ?? {}),
      alertaSalud: json['alerta_salud'] as bool?,
      advertencia: json['advertencia_nutricional'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'usuario': usuario,
      'data_cientifica': dataCientifica.progresoDiario,
      'respuesta_estructurada': {
        'texto_conversacional': respuestaEstructurada.textoConversacional,
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

  StructuredResponse({required this.textoConversacional, required this.secciones});

  factory StructuredResponse.fromJson(Map<String, dynamic> json) {
    var list = json['secciones'] as List? ?? [];
    return StructuredResponse(
      textoConversacional: json['texto_conversacional'] ?? '',
      secciones: list.map((i) => Section.fromJson(i)).toList(),
    );
  }
}

class Section {
  final String tipo; // "comida" o "ejercicio"
  final String nombre;
  final String macros;
  final List<String> ingredientes;
  final List<String> preparacion;
  final String nota;

  Section({
    required this.tipo,
    required this.nombre,
    required this.macros,
    required this.ingredientes,
    required this.preparacion,
    required this.nota,
  });

  factory Section.fromJson(Map<String, dynamic> json) {
    // Para ejercicios, mapear ejercicios→ingredientes e instrucciones/tecnica→preparacion
    // Esto asegura que los widgets puedan leer los datos correctamente
    List<String> items = [];
    List<String> pasos = [];
    
    // Determinar si es ejercicio o comida
    String tipo = json['tipo'] ?? 'general';
    
    if (tipo == 'ejercicio') {
      // Para EJERCICIOS: ejercicios → ingredientes (CIRCUITO)
      items = List<String>.from(json['ejercicios'] ?? []);
      // Para INSTRUCCIONES: instrucciones o tecnica → preparacion
      pasos = List<String>.from(json['instrucciones'] ?? json['tecnica'] ?? []);
    } else {
      // Para COMIDA: ingredientes e ingredientes, preparacion → preparacion
      items = List<String>.from(json['ingredientes'] ?? []);
      pasos = List<String>.from(json['preparacion'] ?? []);
    }
    
    return Section(
      tipo: tipo,
      nombre: json['nombre'] ?? json['plato'] ?? '',
      macros: (json['macros'] ?? json['gasto_calorico_estimado'] ?? '').toString(),
      ingredientes: items,
      preparacion: pasos,
      nota: (json['nota'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tipo': tipo,
      'nombre': nombre,
      'macros': macros,
      'ingredientes': ingredientes,
      'preparacion': preparacion,
      'nota': nota,
    };
  }
}
