// lib/models/dashboard_data.dart

class DailySummary {
  final double calorias;
  final double proteinas;
  final double carbohidratos;
  final double grasas;
  final double gastoEstimado;
  final double imcActual;
  final String aiInsight;
  final PlanNutricional? planObjetivo;  // 🆕 Nuevo campo

  DailySummary({
    required this.calorias,
    required this.proteinas,
    required this.carbohidratos,
    required this.grasas,
    required this.gastoEstimado,
    required this.imcActual,
    required this.aiInsight,
    this.planObjetivo,
  });

  factory DailySummary.fromJson(Map<String, dynamic> json) {
    final dieta = json['dieta_recomendada'] ?? json;
    final plan = json['plan_nutricional'];  
    
    return DailySummary(
      calorias: (dieta['calorias_diarias'] ?? dieta['calorias'] ?? 0).toDouble(),
      proteinas: (dieta['proteinas_g'] ?? dieta['proteinas'] ?? 0).toDouble(),
      carbohidratos: (dieta['carbohidratos_g'] ?? dieta['carbohidratos'] ?? 0).toDouble(),
      grasas: (dieta['grasas_g'] ?? dieta['grasas'] ?? 0).toDouble(),
      gastoEstimado: (dieta['gasto_metabolico_basal'] ?? dieta['gasto_estimado'] ?? 0).toDouble(),
      imcActual: (dieta['imc'] ?? dieta['imc_actual'] ?? 0).toDouble(),
      aiInsight: json['ai_insight'] ?? dieta['notes'] ?? dieta['ai_insight'] ?? "",
      planObjetivo: plan != null ? PlanNutricional.fromJson(plan) : null,  
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
    return PlanNutricional(
      caloriasObjetivo: (json['calorias_objetivo'] as num?)?.toDouble() ?? 
                        (json['calorias_diarias'] as num?)?.toDouble() ?? 0.0,
      proteinasObjetivoG: (json['proteinas_objetivo_g'] as num?)?.toDouble() ?? 
                          (json['macros']?['P'] as num?)?.toDouble() ?? 0.0,
      carbohidratosObjetivoG: (json['carbohidratos_objetivo_g'] as num?)?.toDouble() ?? 
                              (json['macros']?['C'] as num?)?.toDouble() ?? 0.0,
      grasasObjetivoG: (json['grasas_objetivo_g'] as num?)?.toDouble() ?? 
                       (json['macros']?['G'] as num?)?.toDouble() ?? 0.0,
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
    return CalorieTrend(
      day: json['dia'] ?? json['day'] ?? '',
      consumed: (json['consumidas'] ?? json['consumed'] ?? 0).toDouble(),
      burned: (json['quemadas'] ?? json['burned'] ?? 0).toDouble(),
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
      weight: (json['peso'] ?? json['weight'] ?? 0).toDouble(),
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
      imc: (json['imc'] ?? 0).toDouble(),
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
      gastoEstimado: (json['gasto_estimado'] ?? 0).toDouble(),
      imcActual: (json['imc_actual'] ?? 0).toDouble(),
      imcCategoria: json['imc_categoria'] ?? 'Normal',
      aiInsight: json['ai_insight'] ?? '',
    );
  }
}
