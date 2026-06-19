// lib/models/dashboard_data.dart

class DailySummary {
  final double calorias;
  final double proteinas;
  final double carbohidratos;
  final double grasas;
  
  // ✨ NUEVOS MICROS (Pueden ser null si no hay info)
  final double? azucares;
  final double? fibra;
  final double? sodio;
  final double? grasasSaturadas;
  final double? calcio;
  final double? hierro;

  final double gastoMetabolicoBasal;
  final double caloriasQuemadas;
  final double imcActual;
  final String aiInsight;
  final PlanNutricional? planObjetivo;
  final String? aiStrategicFocus;
  final String? nutriWeeklyNote;
  final bool isStrategyValidated;
  final List<String> recommendedFoods;
  final List<String> forbiddenFoods;

  DailySummary({
    required this.calorias,
    required this.proteinas,
    required this.carbohidratos,
    required this.grasas,
    this.azucares,
    this.fibra,
    this.sodio,
    this.grasasSaturadas,
    this.calcio,
    this.hierro,
    required this.gastoMetabolicoBasal,
    required this.caloriasQuemadas,
    required this.imcActual,
    required this.aiInsight,
    this.planObjetivo,
    this.aiStrategicFocus,
    this.nutriWeeklyNote,
    this.isStrategyValidated = false,
    this.recommendedFoods = const [],
    this.forbiddenFoods = const [],
  });

  factory DailySummary.fromJson(Map<String, dynamic> json) {
    final dieta = json['dieta_recomendada'] ?? json;
    final plan = json['plan_nutricional'];
    final micros = json['micros_dia'] ?? {};

    // Helper para parseo seguro
    double toDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    return DailySummary(
      calorias: toDouble(dieta['calorias_diarias'] ?? dieta['calorias']),
      proteinas: toDouble(dieta['proteinas_g'] ?? dieta['proteinas']),
      carbohidratos: toDouble(dieta['carbohidratos_g'] ?? dieta['carbohidratos']),
      grasas: toDouble(dieta['grasas_g'] ?? dieta['grasas']),
      
      // Micros (pueden ser nulos)
      azucares: (dieta['azucares'] ?? micros['azucares']) != null 
          ? toDouble(dieta['azucares'] ?? micros['azucares']) 
          : null,
      fibra: (dieta['fibra'] ?? micros['fibra']) != null 
          ? toDouble(dieta['fibra'] ?? micros['fibra']) 
          : null,
      sodio: (dieta['sodio'] ?? micros['sodio']) != null 
          ? toDouble(dieta['sodio'] ?? micros['sodio']) 
          : null,
      grasasSaturadas: (dieta['grasas_saturadas'] ?? micros['grasas_saturadas']) != null 
          ? toDouble(dieta['grasas_saturadas'] ?? micros['grasas_saturadas']) 
          : null,
      calcio: (dieta['calcio'] ?? micros['calcio']) != null 
          ? toDouble(dieta['calcio'] ?? micros['calcio']) 
          : null,
      hierro: (dieta['hierro'] ?? micros['hierro']) != null 
          ? toDouble(dieta['hierro'] ?? micros['hierro']) 
          : null,

      gastoMetabolicoBasal: toDouble(dieta['gasto_metabolico_basal'] ?? dieta['gasto_estimado']),
      caloriasQuemadas: toDouble(json['resumen']?['calorias_quemadas'] ?? json['calorias_quemadas']),
      imcActual: toDouble(dieta['imc'] ?? dieta['imc_actual']),
      aiInsight: (json['ai_insight'] ?? dieta['notes'] ?? dieta['ai_insight'] ?? "").toString(),
      planObjetivo: plan != null ? PlanNutricional.fromJson(plan) : null,
      aiStrategicFocus: json['ai_strategic_focus'] as String?,
      nutriWeeklyNote: json['nutri_weekly_note'] as String?,
      isStrategyValidated: json['is_strategy_validated'] as bool? ?? false,
      recommendedFoods: (json['recommended_foods'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      forbiddenFoods: (json['forbidden_foods'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

class PlanNutricional {
  final double caloriasObjetivo;
  final double proteinasObjetivoG;
  final double carbohidratosObjetivoG;
  final double grasasObjetivoG;
  final Map<String, int> distribucion;
  final bool validado;
  final int? planId;
  final bool esFallback;
  
  // ✨ NUEVOS CAMPOS DEL BACKEND
  final String estadoPlan;           // "provisional_ia", "validado", "en_revision", "modificado"
  final bool requiereValidacion;
  final bool esCondicionCritica;
  final String alertaSeguridad;
  final bool generadoAutomaticamente;
  final String? fechaGeneracion;
  final bool validoHastaValidacion;
  final String mensajeCliente;
  final String descripcionEstado;

  PlanNutricional({
    required this.caloriasObjetivo,
    required this.proteinasObjetivoG,
    required this.carbohidratosObjetivoG,
    required this.grasasObjetivoG,
    required this.distribucion,
    required this.validado,
    this.planId,
    this.esFallback = false,
    // ✨ Valores por defecto para nuevos campos
    this.estadoPlan = 'provisional_ia',
    this.requiereValidacion = false,
    this.esCondicionCritica = false,
    this.alertaSeguridad = '',
    this.generadoAutomaticamente = true,
    this.fechaGeneracion,
    this.validoHastaValidacion = true,
    this.mensajeCliente = '',
    this.descripcionEstado = '',
  });

  factory PlanNutricional.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    return PlanNutricional(
      caloriasObjetivo: toDouble(json['calorias_objetivo'] ?? json['calorias_diarias']),
      proteinasObjetivoG: toDouble(json['proteinas_objetivo_g'] ?? json['macros']?['P']),
      carbohidratosObjetivoG: toDouble(json['carbohidratos_objetivo_g'] ?? json['macros']?['C']),
      grasasObjetivoG: toDouble(json['grasas_objetivo_g'] ?? json['macros']?['G']),
      distribucion: {
        'proteina_pct': (json['distribucion']?['proteina_pct'] as num?)?.toInt() ?? 0,
        'carbohidratos_pct': (json['distribucion']?['carbohidratos_pct'] as num?)?.toInt() ?? 0,
        'grasas_pct': (json['distribucion']?['grasas_pct'] as num?)?.toInt() ?? 0,
      },
      validado: json['validado'] as bool? ?? false,
      planId: json['plan_id'] as int?,
      esFallback: json['es_fallback'] as bool? ?? false,
      
      // ✨ PARSEAR NUEVOS CAMPOS
      estadoPlan: json['estado_plan'] as String? ?? 'provisional_ia',
      requiereValidacion: json['requiere_validacion'] as bool? ?? false,
      esCondicionCritica: json['es_condicion_critica'] as bool? ?? false,
      alertaSeguridad: json['alerta_seguridad'] as String? ?? '',
      generadoAutomaticamente: json['generado_automaticamente'] as bool? ?? true,
      fechaGeneracion: json['fecha_generacion'] as String?,
      validoHastaValidacion: json['valido_hasta_validacion'] as bool? ?? true,
      mensajeCliente: json['mensaje_cliente'] as String? ?? 
                      '🤖 Este plan fue generado automáticamente por la IA. Tu nutricionista lo revisará pronto.',
      descripcionEstado: json['descripcion_estado'] as String? ?? 
                         'Plan generado automáticamente - Pendiente de validación',
    );
  }
}

class CalorieTrend {
  final String day;
  final double consumed;
  final double burned;

  CalorieTrend({required this.day, required this.consumed, required this.burned});

  factory CalorieTrend.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return 0.0;
    }
    return CalorieTrend(
      day: json['dia'] ?? json['day'] ?? '',
      consumed: toDouble(json['consumidas'] ?? json['consumed']),
      burned: toDouble(json['quemadas'] ?? json['burned']),
    );
  }
}

class WeightRecord {
  final int month;
  final double weight;

  WeightRecord({required this.month, required this.weight});

  factory WeightRecord.fromJson(Map<String, dynamic> json) {
    return WeightRecord(
      month: json['mes'] ?? json['month'] ?? 0,
      weight: (json['peso'] ?? json['weight'] ?? 0.0).toDouble(),
    );
  }
}

class IMCRecord {
  final int month;
  final double imc;

  IMCRecord({required this.month, required this.imc});

  factory IMCRecord.fromJson(Map<String, dynamic> json) {
    return IMCRecord(
      month: json['mes'] ?? json['month'] ?? 0,
      imc: (json['imc'] ?? 0.0).toDouble(),
    );
  }
}

class AIAnalysis {
  final double gastoEstimado;
  final double imcActual;
  final String imcCategoria;
  final String aiInsight;

  AIAnalysis({
    required this.gastoEstimado,
    required this.imcActual,
    required this.imcCategoria,
    required this.aiInsight,
  });

  factory AIAnalysis.fromJson(Map<String, dynamic> json) {
    return AIAnalysis(
      gastoEstimado: (json['gasto_estimado'] ?? 0.0).toDouble(),
      imcActual: (json['imc_actual'] ?? 0.0).toDouble(),
      imcCategoria: json['imc_categoria'] ?? 'Normal',
      aiInsight: json['ai_insight'] ?? '',
    );
  }
}
