import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';

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
  
  List<String> _recommendedList = [];
  List<String> _forbiddenList = [];
  List<String> _medicalConditionsList = [];
  bool _isAILoading = false;
  bool _isValidated = false;

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
    _loadData();
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
        
        _recommendedList = List<String>.from(progressData['recommended_foods'] ?? []);
        _forbiddenList = List<String>.from(progressData['forbidden_foods'] ?? []);
        _medicalConditionsList = List<String>.from(progressData['medical_conditions'] ?? []);
        _isValidated = progressData['is_validated'] == true;
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
          }
          _obsController.text = planData['observaciones'] ?? '';
        });
      } catch (e) {
        debugPrint("No se encontró plan: $e");
      }

      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
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
        },
        token
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expediente y Guía IA actualizados'), backgroundColor: Colors.green),
        );
        _loadData(); // Recargar para ver cambios
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.patientData['full_name'] ?? 'Expediente',
          style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF263238)),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF263238)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_rounded, color: Color(0xFF1E88E5)),
            onPressed: _savePlan,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 24),
              _buildMetricsGrid(),
              const SizedBox(height: 24),
              _buildStrategicGuideSection(), // v80.0
              const SizedBox(height: 24),
              _buildAIInsightsSection(), // v80.0: Ahora incluye historial de alertas
              const SizedBox(height: 24),
              _buildProgressCharts(),
              const SizedBox(height: 24),
              _buildNutritionalPlanSection(),
              const SizedBox(height: 80),
            ],
          ),
    );
  }

  Widget _buildHeaderCard() {
    final bool isMale = widget.patientData['gender']?.toString().toLowerCase() == 'm';
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
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isMale ? const Color(0xFFE3F2FD) : const Color(0xFFFCE4EC),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    widget.patientData['full_name']?.toString().substring(0, 1).toUpperCase() ?? 'U',
                    style: TextStyle(
                      fontSize: 24, 
                      fontWeight: FontWeight.w800, 
                      color: isMale ? const Color(0xFF1E88E5) : const Color(0xFFD81B60)
                    ),
                  ),
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
                      widget.patientData['goal'] ?? 'Sin objetivo definido',
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
    final weight = _fullData?['current_weight']?.toString() ?? '--';
    final height = _fullData?['current_height']?.toString() ?? '--';
    
    return Row(
      children: [
        _buildMetricCard('Peso', '$weight kg', Icons.monitor_weight_outlined, Colors.orange),
        const SizedBox(width: 16),
        _buildMetricCard('Altura', '$height cm', Icons.height_rounded, Colors.blue),
        const SizedBox(width: 16),
        _buildMetricCard('IMC', _calculateIMC(weight, height), Icons.analytics_outlined, Colors.purple),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[100]!),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF263238))),
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
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
    final historialPeso = _fullData?['historial_peso'] as List?;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('EVOLUCIÓN DE PESO', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1, color: Colors.blueGrey)),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: historialPeso == null || historialPeso.isEmpty
              ? const Center(child: Text('No hay datos suficientes para graficar'))
              : LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
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
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: const Color(0xFF1E88E5).withOpacity(0.1),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionalPlanSection() {
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
              const Text('CONFIGURACIÓN DEL PLAN', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1, color: Colors.blueGrey)),
              const Icon(Icons.edit_note_rounded, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 24),
          _buildEditField('Calorías Diarias', _caloriesController, Icons.local_fire_department_rounded, 'kcal', isNumber: true),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildEditField('Proteína', _proteinController, null, 'g', isNumber: true)),
              const SizedBox(width: 12),
              Expanded(child: _buildEditField('Carbs', _carbsController, null, 'g', isNumber: true)),
              const SizedBox(width: 12),
              Expanded(child: _buildEditField('Grasas', _fatsController, null, 'g', isNumber: true)),
            ],
          ),
          const SizedBox(height: 24),
          const Text('NOTAS CLÍNICAS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 8),
          TextField(
            controller: _obsController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Añade observaciones sobre el paciente...',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
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
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ El Asistente IA ha completado los campos. ¡Revísalos!'),
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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: Color(0xFF1E88E5), size: 18),
                      const SizedBox(width: 6),
                      const Text(
                        'GUÍA ESTRATÉGICA PARA IA', 
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5, color: Color(0xFF1E88E5)),
                      ),
                    ],
                  ),
                  if (_isValidated)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, color: Colors.green, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'VALIDADO',
                            style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              _isAILoading 
                ? const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3))
                : GestureDetector(
                    onTap: _askAICopilot,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1E88E5).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.psychology_alt_rounded, size: 20, color: Colors.white),
                          const SizedBox(width: 8),
                          const Text(
                            'Preguntar Asistente', 
                            style: TextStyle(
                              color: Colors.white, 
                              fontWeight: FontWeight.w800, 
                              fontSize: 13,
                              letterSpacing: 0.3
                            )
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
          const SizedBox(height: 24),
          
          _buildEditField(
            'Foco Semanal (Misión de la IA)', 
            _strategicFocusController, 
            Icons.center_focus_strong_rounded, 
            '', 
            isNumber: false,
            maxLines: 5,
            hint: 'Ej: Controlar ansiedad por dulces en las tardes...'
          ),
          
          const SizedBox(height: 24),
          _buildReadOnlyMedicalConditions(),
          
          const Divider(height: 48),
          
          _buildChipInput(
            label: 'Alimentos Recomendados',
            items: _recommendedList,
            controller: _recInputController,
            icon: Icons.check_circle_outline_rounded,
            color: Colors.green,
            onAdd: (val) => setState(() => _recommendedList.add(val)),
            onRemove: (idx) => setState(() => _recommendedList.removeAt(idx)),
          ),
          
          const SizedBox(height: 24),
          _buildChipInput(
            label: 'Alimentos Prohibidos',
            items: _forbiddenList,
            controller: _forInputController,
            icon: Icons.block_flipped,
            color: Colors.red,
            onAdd: (val) => setState(() => _forbiddenList.add(val)),
            onRemove: (idx) => setState(() => _forbiddenList.removeAt(idx)),
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

  Widget _buildEditField(String label, TextEditingController controller, IconData? icon, String unit, {bool isNumber = true, int maxLines = 1, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.multiline,
          maxLines: maxLines,
          style: const TextStyle(fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400], fontWeight: FontWeight.normal),
            prefixIcon: icon != null ? Icon(icon, size: 18, color: const Color(0xFF1E88E5)) : null,
            suffixText: unit.isNotEmpty ? unit : null,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
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
