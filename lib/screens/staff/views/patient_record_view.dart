import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../widgets/profile_avatar.dart';

class PatientRecordView extends StatefulWidget {
  final Map<String, dynamic> patientData;

  const PatientRecordView({super.key, required this.patientData});

  @override
  State<PatientRecordView> createState() => _PatientRecordViewState();
}

class _PatientRecordViewState extends State<PatientRecordView> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _fullData;
  Map<String, dynamic>? _currentPlan;
  
  // Controladores para edición
  late TextEditingController _caloriesController;
  late TextEditingController _proteinController;
  late TextEditingController _carbsController;
  late TextEditingController _fatsController;
  late TextEditingController _obsController;
  
  // v80.0: Controladores Estratégicos
  // v80.0: Controladores Estratégicos
  late TextEditingController _strategicFocusController;
  late TextEditingController _recInputController;
  late TextEditingController _forInputController;
  late TextEditingController _weeklyNoteController;
  late TextEditingController _coachNotesController;

  List<String> _recommendedList = [];
  List<String> _forbiddenList = [];
  List<String> _medicalConditionsList = [];
  bool _isAILoading = false;
  bool _isValidated = false;
  String _planStatus = 'pendiente';
  String? _planValidatedAt;
  bool _shouldRefreshList = false;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _caloriesController = TextEditingController();
    _proteinController = TextEditingController();
    _carbsController = TextEditingController();
    _fatsController = TextEditingController();
    _obsController = TextEditingController();
    
    _strategicFocusController = TextEditingController();
    _recInputController = TextEditingController();
    _forInputController = TextEditingController();
    _weeklyNoteController = TextEditingController();
    _coachNotesController = TextEditingController();
    for (final ctrl in [
      _caloriesController, _proteinController, _carbsController, _fatsController,
      _obsController, _strategicFocusController, _weeklyNoteController, _coachNotesController,
    ]) {
      ctrl.addListener(_markDirty);
    }
    _loadData();
  }

  void _markDirty() {
    if (!_isDirty && mounted) setState(() => _isDirty = true);
  }

  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatsController.dispose();
    _obsController.dispose();
    _strategicFocusController.dispose();
    _recInputController.dispose();
    _forInputController.dispose();
    _weeklyNoteController.dispose();
    _coachNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token!;
      final clientId = widget.patientData['id'];

      // Cargar progreso (historial), plan actual y guía estratégica
      final progressData = await _apiService.getNutricionistaClienteProgreso(clientId, token);
      
      setState(() {
        _fullData = progressData;
        _strategicFocusController.text = progressData['ai_strategic_focus'] ?? '';
        _weeklyNoteController.text = progressData['nutri_weekly_note'] ?? '';
        _coachNotesController.text = progressData['coach_notes'] ?? '';
        
        _recommendedList = List<String>.from(progressData['recommended_foods'] ?? []);
        _forbiddenList = List<String>.from(progressData['forbidden_foods'] ?? []);
        _medicalConditionsList = List<String>.from(progressData['medical_conditions'] ?? []);
        _isValidated = progressData['is_validated'] == true;
        _planStatus = progressData['semana_status'] ?? 'pendiente';
        _planValidatedAt = progressData['plan_validated_at']?.toString();
      });

      try {
        final planData = await _apiService.getPatientPlan(clientId, token);
        setState(() {
          _currentPlan = planData;
          if (planData['detalles_diarios'] != null && planData['detalles_diarios'].isNotEmpty) {
            final firstDay = planData['detalles_diarios'][0];
            _caloriesController.text = (firstDay['calorias_dia'] ?? 2000).toString();
            _proteinController.text = (firstDay['proteinas_g'] ?? 150).toString();
            _carbsController.text = (firstDay['carbohidratos_g'] ?? 200).toString();
            _fatsController.text = (firstDay['grasas_g'] ?? 60).toString();
          } else if (progressData['metabolismo_estimado'] != null) {
            // 🆕 FALLBACK IA: Sincronización con lo que ve el cliente (v80.0)
            final est = progressData['metabolismo_estimado'];
            _caloriesController.text = (est['calorias_objetivo'] ?? '').toString();
            _proteinController.text = (est['proteinas_g'] ?? '').toString();
            _carbsController.text = (est['carbohidratos_g'] ?? '').toString();
            _fatsController.text = (est['grasas_g'] ?? '').toString();
          }
          _obsController.text = planData['observaciones'] ?? '';
        });
      } catch (e) {
        debugPrint("No se encontró plan: $e");
        if (progressData['metabolismo_estimado'] != null) {
            final est = progressData['metabolismo_estimado'];
            _caloriesController.text = (est['calorias_objetivo'] ?? '').toString();
            _proteinController.text = (est['proteinas_g'] ?? '').toString();
            _carbsController.text = (est['carbohidratos_g'] ?? '').toString();
            _fatsController.text = (est['grasas_g'] ?? '').toString();
        }
      }

      setState(() { _isLoading = false; _isDirty = false; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _confirmarSalida() async {
    if (!_isDirty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 10),
            Text('¿Salir sin guardar?',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF263238))),
          ],
        ),
        content: const Text(
          'Los cambios que no hayas guardado se perderán.',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF263238),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Salir', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _savePlan() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token!;
      final clientId = widget.patientData['id'];
      
      // 1. Guardar Plan Nutricional
      final List<Map<String, dynamic>> dailyUpdates = List.generate(7, (index) => {
        "calorias_dia": double.tryParse(_caloriesController.text) ?? 2000,
        "proteinas_g": double.tryParse(_proteinController.text) ?? 150,
        "carbohidratos_g": double.tryParse(_carbsController.text) ?? 200,
        "grasas_g": double.tryParse(_fatsController.text) ?? 60,
        "estado": "oficial"
      });

      await _apiService.updatePatientPlan(
        clientId, 
        {
          "observaciones": _obsController.text,
          "detalles_diarios": dailyUpdates,
          "status": "validado"
        }, 
        token
      );

      // 2. Guardar Guía Estratégica IA (v80.0)
      await _apiService.actualizarGuiaEstrategica(
        clientId,
        {
          "ai_strategic_focus": _strategicFocusController.text.trim(),
          "recommended_foods": _recommendedList,
          "forbidden_foods": _forbiddenList,
          "medical_conditions": _medicalConditionsList,
          "nutri_weekly_note": _weeklyNoteController.text.trim().isEmpty
              ? null
              : _weeklyNoteController.text.trim(),  // 🆕 Enviar nota semanal
        },
        token
      );

      if (mounted) {
        _shouldRefreshList = true;
        setState(() => _isDirty = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expediente y Guía IA actualizados'), backgroundColor: Colors.green),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteClient() async {
    final patientName = widget.patientData['full_name'] ?? 'este paciente';
    final clientId   = widget.patientData['id'] as int;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
          SizedBox(width: 10),
          Text('Eliminar Paciente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Estás a punto de eliminar permanentemente a:', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
              child: Row(children: [
                const Icon(Icons.person, color: Colors.red),
                const SizedBox(width: 10),
                Expanded(child: Text(patientName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
              ]),
            ),
            const SizedBox(height: 12),
            const Text('⚠️ Esta acción es IRREVERSIBLE. Se eliminarán todos sus datos, historial y su cuenta de Firebase.', style: TextStyle(fontSize: 12, color: Colors.red)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Sí, ELIMINAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token!;
      await _apiService.deleteClient(clientId, token);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$patientName fue eliminado de la plataforma.'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final nav = Navigator.of(context);
        final salir = await _confirmarSalida();
        if (salir) nav.pop(_shouldRefreshList);
        return false;
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF263238)),
          onPressed: () async {
            final salir = await _confirmarSalida();
            if (salir && context.mounted) Navigator.pop(context, _shouldRefreshList);
          },
        ),
        actions: [
          if (!Provider.of<AuthProvider>(context, listen: false).userRole!.toUpperCase().contains('COACH')) ...[
            Tooltip(
              message: _planStatus == 'validado'
                  ? 'Guarda cambios en kcal/macros y guía estratégica'
                  : 'Guarda y valida el plan nutricional del paciente',
              child: TextButton.icon(
                onPressed: _savePlan,
                icon: Icon(
                  _planStatus == 'validado'
                      ? Icons.save_outlined
                      : Icons.check_circle_outline_rounded,
                  size: 18,
                ),
                label: Text(
                  _planStatus == 'validado' ? 'Guardar Plan' : 'Guardar y Validar',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: _planStatus == 'validado'
                      ? const Color(0xFF1E88E5)
                      : const Color(0xFF2E7D32),
                ),
              ),
            ),
            Tooltip(
              message: 'Da de baja al paciente.\nElimina todos sus datos permanentemente.',
              child: TextButton.icon(
                onPressed: _deleteClient,
                icon: const Icon(Icons.person_remove_outlined, size: 18),
                label: const Text(
                  'Dar de baja',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 24),
              
              // 🍎 SECCIÓN NUEVA: CONSUMO DE HOY (Macro Tracking Diario)
              _buildTodayConsumption(),
              const SizedBox(height: 24),

              _buildMetricsGrid(),
              const SizedBox(height: 24),

              // 🛡️ Guía Estratégica (Solo para Nutris/Admins)
              if (!Provider.of<AuthProvider>(context, listen: false).userRole!.toUpperCase().contains('COACH')) ...[
                _buildValidationCard(),
                const SizedBox(height: 24),
                _buildStrategicGuideSection(),
                const SizedBox(height: 24),
                _buildAIInsightsSection(),
                const SizedBox(height: 24),
              ],

              _buildProgressCharts(),
              const SizedBox(height: 24),
              _buildNutritionalPlanSection(),
              const SizedBox(height: 24),
              
              // 📝 SECCIÓN NUEVA: NOTAS DEL ENTRENADOR
              _buildCoachNotesSection(),

              const SizedBox(height: 80),
            ],
          ),
      ),
    );
  }

  static const _goalLabels = {
    'perder peso':  'Perder peso (Agresivo)',
    'perder_leve':  'Perder peso (Definición)',
    'mantener peso':'Mantener peso',
    'ganar_leve':   'Ganar masa (Limpio)',
    'ganar masa':   'Ganar masa (Volumen)',
  };

  String _formatGoal(String? raw) {
    final key = (raw ?? '').toLowerCase().trim();
    return _goalLabels[key] ?? raw ?? 'Sin objetivo definido';
  }

  Widget _buildHeaderCard() {
    final bool isMale = widget.patientData['gender']?.toString().toLowerCase() == 'm';
    final String? photoUrl = widget.patientData['profile_picture_url'] ?? widget.patientData['profilePictureUrl'];
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              ProfileAvatar(
                photoUrl: photoUrl,
                name: widget.patientData['full_name'] ?? 'U',
                radius: 30,
                backgroundColor: isMale ? const Color(0xFFE3F2FD) : const Color(0xFFFCE4EC),
                textStyle: TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.w800, 
                  color: isMale ? const Color(0xFF1E88E5) : const Color(0xFFD81B60)
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.patientData['full_name'] ?? 'Paciente',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF263238)),
                    ),
                    Text(
                      _formatGoal(widget.patientData['goal']?.toString()),
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_fullData?['medical_conditions'] != null && (_fullData?['medical_conditions'] as List).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 12),
                  const Text('CONDICIONES MÉDICAS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.redAccent)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (_fullData!['medical_conditions'] as List).map<Widget>((c) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.red[100]!),
                      ),
                      child: Text(
                        c.toString(),
                        style: TextStyle(color: Colors.red[800], fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    final weightRaw = _fullData?['current_weight'];
    final weight = weightRaw is num ? weightRaw.toStringAsFixed(1) : '--';
    final height = _fullData?['current_height']?.toString() ?? '--';
    
    // 🆕 Sincronización Metabólica (v80.0)
    final gastoEstimadoRaw = _fullData?['metabolismo_estimado']?['calorias_objetivo'];
    final gastoEstimado = gastoEstimadoRaw != null ? '$gastoEstimadoRaw kcal' : '--';

    return Column(
      children: [
        Row(
          children: [
            _buildMetricCard('Peso actual', '$weight kg', Icons.monitor_weight_outlined, Colors.orange),
            const SizedBox(width: 16),
            _buildMetricCard('Altura', '$height cm', Icons.height_rounded, Colors.blue),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildMetricCard('IMC Actual', _calculateIMC(weight, height), Icons.analytics_outlined, Colors.purple),
            const SizedBox(width: 16),
            _buildMetricCard('Gasto Estimado', gastoEstimado, Icons.bolt_rounded, Colors.teal, isPremium: true),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, {bool isPremium = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isPremium ? color.withOpacity(0.2) : Colors.grey[100]!),
          boxShadow: isPremium ? [
            BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
          ] : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isPremium ? color : const Color(0xFF263238))),
            Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  String _calculateIMC(String weightStr, String heightStr) {
    try {
      double w = double.parse(weightStr);
      double h = double.parse(heightStr) / 100;
      return (w / (h * h)).toStringAsFixed(1);
    } catch (_) { return '--'; }
  }

  Widget _buildProgressCharts() {
    final historialPeso = (_fullData?['historial_peso'] as List?) ?? [];
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'EVOLUCIÓN MENSUAL', 
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2, color: Color(0xFF455A64))
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Peso (kg)',
                  style: TextStyle(color: Colors.blue[800], fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (historialPeso.isEmpty)
            const SizedBox(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.show_chart_rounded, color: Colors.grey, size: 40),
                    SizedBox(height: 8),
                    Text('Aún no hay registros de peso para graficar', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 5,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.withOpacity(0.1),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                        interval: 5,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: TextStyle(color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          int index = value.toInt();
                          if (index >= 0 && index < historialPeso.length) {
                             String fecha = historialPeso[index]['fecha']?.toString() ?? '';
                             if (fecha.isNotEmpty) {
                               // Extract day/month from YYYY-MM-DD
                               try {
                                 DateTime dt = DateTime.parse(fecha);
                                 return Padding(
                                   padding: const EdgeInsets.only(top: 8.0),
                                   child: Text(
                                     '${dt.day}/${dt.month}',
                                     style: TextStyle(color: Colors.grey[500], fontSize: 9, fontWeight: FontWeight.bold),
                                   ),
                                 );
                               } catch (_) {}
                             }
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(historialPeso.length, (i) {
                        return FlSpot(i.toDouble(), (historialPeso[i]['valor'] as num).toDouble());
                      }),
                      isCurved: true,
                      color: const Color(0xFF1E88E5),
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 5,
                          color: Colors.white,
                          strokeWidth: 3,
                          strokeColor: const Color(0xFF1E88E5),
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF1E88E5).withOpacity(0.2),
                            const Color(0xFF1E88E5).withOpacity(0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (touchedSpot) => const Color(0xFF263238),
                      getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                        return touchedBarSpots.map((barSpot) {
                          return LineTooltipItem(
                            '${barSpot.y.toStringAsFixed(1)} kg',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          );
                        }).toList();
                      },
                    ),
                    handleBuiltInTouches: true,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNutritionalPlanSection() {
    final bool isCoach = Provider.of<AuthProvider>(context, listen: false).userRole!.toUpperCase().contains('COACH');

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('CONFIGURACIÓN DEL PLAN', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.2, color: Colors.blueGrey)),
              if (isCoach)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(8)),
                  child: const Text('SOLO LECTURA', style: TextStyle(color: Colors.amber, fontSize: 8, fontWeight: FontWeight.bold)),
                )
              else
                const Icon(Icons.edit_note_rounded, color: Colors.blue),
            ],
          ),
          const SizedBox(height: 24),
          _buildEditField('Calorías Diarias', _caloriesController, Icons.local_fire_department_rounded, 'kcal', isNumber: true, readOnly: isCoach),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildEditField('Proteína', _proteinController, null, 'g', isNumber: true, readOnly: isCoach)),
              const SizedBox(width: 12),
              Expanded(child: _buildEditField('Carbs', _carbsController, null, 'g', isNumber: true, readOnly: isCoach)),
              const SizedBox(width: 12),
              Expanded(child: _buildEditField('Grasas', _fatsController, null, 'g', isNumber: true, readOnly: isCoach)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayConsumption() {
    // 🔋 Datos REALES del día (vienen en _fullData desde el backend)
    final ingesta = _fullData?['today_summary'] ?? {
      'calorias_consumidas': _fullData?['current_day_calories'] ?? 0,
      'proteinas': _fullData?['current_day_protein'] ?? 0,
      'carbos': _fullData?['current_day_carbs'] ?? 0,
      'grasas': _fullData?['current_day_fats'] ?? 0,
      'calorias_quemadas': _fullData?['current_day_burned'] ?? 0,
    };

    final int consumido = (ingesta['calorias_consumidas'] ?? 0).toInt();
    final int quemado = (ingesta['calorias_quemadas'] ?? 0).toInt();
    final int neto = consumido - quemado;
    
    final double objetivoCal = double.tryParse(_caloriesController.text) ?? 2000;
    final double progress = (objetivoCal > 0) ? (consumido / objetivoCal) : 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: const Color(0xFF1E88E5).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('RESUMEN ENERGÉTICO HOY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5)),
              Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
            ],
          ),
          const SizedBox(height: 20),
          
          // Fila de Balance: Consumido vs Quemado vs Neto
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$consumido', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1)),
                  const Text('INGERIDAS', style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(height: 30, width: 1, color: Colors.white24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text('$quemado', style: const TextStyle(color: Color(0xFFFFCC80), fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1)),
                   const Text('QUEMADAS', style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(height: 30, width: 1, color: Colors.white24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$neto', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1)),
                  const Text('BALANCE NETO', style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: Colors.white.withOpacity(0.15),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('${(progress * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
            ],
          ),
          
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMacroSmall('PROTEÍNA', '${ingesta['proteinas']}g'),
              _buildMacroSmall('CARBOS', '${ingesta['carbos']}g'),
              _buildMacroSmall('GRASAS', '${ingesta['grasas']}g'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroSmall(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w900)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildCoachNotesSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blue.shade50),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.assignment_ind_rounded, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                'NOTAS DEL ENTRENADOR',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1,
                    color: Color(0xFF263238)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _coachNotesController,
            maxLines: 4,
            readOnly: true,
            decoration: InputDecoration(
              hintText: 'El entrenador aún no ha registrado notas.',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.lock_outline_rounded, size: 13, color: Colors.blueGrey),
              const SizedBox(width: 6),
              const Text(
                'Solo editable por el entrenador.',
                style: TextStyle(fontSize: 11, color: Colors.blueGrey, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Future<void> _askAICopilot() async {
    setState(() => _isAILoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final token = auth.token!;
      final clientId = widget.patientData['id'];

      final suggestion = await _apiService.getSugerenciaEstrategica(clientId, token);

      setState(() {
        _strategicFocusController.text = suggestion['ai_strategic_focus'] ?? '';
        _recommendedList = List<String>.from(suggestion['recommended_foods'] ?? []);
        _forbiddenList = List<String>.from(suggestion['forbidden_foods'] ?? []);
        _isAILoading = false;
        _isDirty = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: const Text('✨ Guía Mensual IA generada con éxito. ¡Revísala!'),
            backgroundColor: Colors.indigo,
          ),
        );
      }
    } catch (e) {
      setState(() => _isAILoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error del Copiloto: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildValidationCard() {
    final bool isValidado = _planStatus == 'validado';
    String dateStr = '';
    if (_planValidatedAt != null) {
      try {
        final dt = DateTime.parse(_planValidatedAt!);
        dateStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      } catch (_) {}
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isValidado ? Colors.green.withOpacity(0.35) : Colors.orange.withOpacity(0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isValidado ? Colors.green : Colors.orange).withOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isValidado ? Colors.green : Colors.orange).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isValidado ? Icons.verified_rounded : Icons.pending_actions_rounded,
              color: isValidado ? Colors.green.shade700 : Colors.orange.shade800,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isValidado ? 'Plan validado ✅' : 'Falta validar el plan',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: isValidado ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isValidado
                    ? (dateStr.isNotEmpty ? 'Última validación: $dateStr' : 'Plan aprobado')
                    : 'El plan nutricional aún no ha sido validado',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrategicGuideSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1E88E5).withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.blue.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Título e instrucción
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.auto_awesome_rounded, color: Color(0xFF1E88E5), size: 18),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'GUÍA ESTRATÉGICA MENSUAL (IA)',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5, color: Color(0xFF1E88E5)),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Genera automáticamente la misión, alimentos recomendados y restricciones según el perfil del paciente.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Botón a la derecha
              _isAILoading
                  ? const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3))
                  : GestureDetector(
                      onTap: _askAICopilot,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1E88E5).withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.psychology_alt_rounded, size: 18, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'IA Sugerir',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
            ],
          ),
          const SizedBox(height: 24),
          
          _buildEditField(
            'Misión de la Semana (Enfoque IA)', 
            _strategicFocusController, 
            Icons.center_focus_strong_rounded, 
            '', 
            isNumber: false,
            maxLines: 5,
            hint: 'Misión: Priorizar saciedad y control glucémico...'
          ),

          const SizedBox(height: 16),
          
          const SizedBox(height: 24),
          _buildReadOnlyMedicalConditions(),
          
          const Divider(height: 48),
          
          _buildChipInput(
            label: 'Alimentos Recomendados',
            items: _recommendedList,
            controller: _recInputController,
            icon: Icons.check_circle_outline_rounded,
            color: Colors.green,
            onAdd: (val) => setState(() { _recommendedList.add(val); _isDirty = true; }),
            onRemove: (idx) => setState(() { _recommendedList.removeAt(idx); _isDirty = true; }),
          ),
          
          const SizedBox(height: 24),
          _buildChipInput(
            label: 'Alimentos Prohibidos',
            items: _forbiddenList,
            controller: _forInputController,
            icon: Icons.block_flipped,
            color: Colors.red,
            onAdd: (val) => setState(() { _forbiddenList.add(val); _isDirty = true; }),
            onRemove: (idx) => setState(() { _forbiddenList.removeAt(idx); _isDirty = true; }),
          ),
          
          const SizedBox(height: 16),
          const Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.grey),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'La IA bloqueará o sugerirá estos alimentos según tus órdenes.',
                  style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChipInput({
    required String label,
    required List<String> items,
    required TextEditingController controller,
    required IconData icon,
    required Color color,
    required Function(String) onAdd,
    required Function(int) onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('Presiona "+" para añadir alimentos', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                ),
              if (items.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...items.asMap().entries.map((entry) {
                      return Container(
                        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  fontSize: 13, 
                                  fontWeight: FontWeight.bold, 
                                  color: color,
                                  height: 1.2
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => onRemove(entry.key),
                              child: Icon(Icons.cancel_rounded, size: 20, color: color.withOpacity(0.5)),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              if (items.isNotEmpty) const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        hintText: 'Añadir alimento...',
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                        isDense: true,
                        border: InputBorder.none,
                        prefixIcon: Icon(icon, size: 18, color: color),
                        prefixIconConstraints: const BoxConstraints(minWidth: 32),
                      ),
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          onAdd(val.trim());
                          controller.clear();
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add_circle_outline_rounded, color: color, size: 24),
                    onPressed: () {
                      final val = controller.text;
                      if (val.trim().isNotEmpty) {
                        onAdd(val.trim());
                        controller.clear();
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditField(String label, TextEditingController controller, IconData? icon, String unit, {bool isNumber = true, int maxLines = 1, String? hint, bool readOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.multiline,
          maxLines: maxLines,
          readOnly: readOnly,
          style: const TextStyle(fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400], fontWeight: FontWeight.normal),
            prefixIcon: icon != null ? Icon(icon, size: 18, color: const Color(0xFF1E88E5)) : null,
            suffixText: unit.isNotEmpty ? unit : null,
            filled: true,
            fillColor: readOnly ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyMedicalConditions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            const Text(
              'CONDICIONES MÉDICAS (DEL PERFIL)', 
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(8)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_rounded, size: 10, color: Colors.amber),
                  SizedBox(width: 4),
                  Text('SOLO LECTURA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.blueGrey.withOpacity(0.1)),
          ),
          child: _medicalConditionsList.isEmpty
            ? const Text('El cliente no ha registrado condiciones médicas.', style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic))
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._medicalConditionsList.map((c) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blueGrey.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.health_and_safety_rounded, size: 14, color: Colors.redAccent),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            c, 
                            style: const TextStyle(
                              fontSize: 12, 
                              fontWeight: FontWeight.bold, 
                              color: Color(0xFF334155),
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
        ),
        const SizedBox(height: 8),
        const Text(
          '* Estos datos son llenados por el cliente en su perfil inicial.',
          style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _buildAIInsightsSection() {
    final alertas = (_fullData?['alertas_salud'] as List?) ?? [];
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('HISTORIAL DE ALERTAS (IA)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF475569))),
              Icon(Icons.history_toggle_off_rounded, color: Colors.blueGrey[300]),
            ],
          ),
          const SizedBox(height: 16),
          if (alertas.isEmpty)
            const Text('No hay alertas de salud detectadas recientemente.', style: TextStyle(color: Colors.grey, fontSize: 13))
          else
            ...alertas.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(
                    a['severidad'] == 'alto' ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                    color: a['severidad'] == 'alto' ? Colors.red : Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a['descripcion'] ?? 'Sin descripción', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(a['fecha']?.toString().split('T')[0] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                    child: Text(a['tipo']?.toString().toUpperCase() ?? 'SINTOMA', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }
}
