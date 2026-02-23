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

  @override
  void initState() {
    super.initState();
    _caloriesController = TextEditingController();
    _proteinController = TextEditingController();
    _carbsController = TextEditingController();
    _fatsController = TextEditingController();
    _obsController = TextEditingController();
    _loadData();
  }

  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatsController.dispose();
    _obsController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token!;
      final clientId = widget.patientData['id'];

      // Cargar progreso (historial) y plan actual
      final progressData = await _apiService.getNutricionistaClienteProgreso(clientId, token);
      
      try {
        final planData = await _apiService.getPatientPlan(clientId, token);
        setState(() {
          _currentPlan = planData;
          if (planData['detalles_diarios'] != null && planData['detalles_diarios'].isNotEmpty) {
            final firstDay = planData['detalles_diarios'][0];
            _caloriesController.text = firstDay['calorias_dia'].toString();
            _proteinController.text = firstDay['proteinas_g'].toString();
            _carbsController.text = firstDay['carbohidratos_g'].toString();
            _fatsController.text = firstDay['grasas_g'].toString();
          }
          _obsController.text = planData['observaciones'] ?? '';
        });
      } catch (e) {
        debugPrint("No se encontró plan: $e");
      }

      setState(() {
        _fullData = progressData;
        _isLoading = false;
      });
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
      
      // Preparar data para actualizar (asumiendo que actualizamos todos los días igual por ahora para simplificar)
      final List<Map<String, dynamic>> dailyUpdates = List.generate(7, (index) => {
        "calorias_dia": double.tryParse(_caloriesController.text) ?? 2000,
        "proteinas_g": double.tryParse(_proteinController.text) ?? 150,
        "carbohidratos_g": double.tryParse(_carbsController.text) ?? 200,
        "grasas_g": double.tryParse(_fatsController.text) ?? 60,
        "estado": "oficial"
      });

      await _apiService.updatePatientPlan(
        widget.patientData['id'], 
        {
          "observaciones": _obsController.text,
          "detalles_diarios": dailyUpdates,
          "status": "validado"
        }, 
        authProvider.token!
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expediente actualizado correctamente'), backgroundColor: Colors.green),
        );
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
              _buildProgressCharts(),
              const SizedBox(height: 24),
              _buildNutritionalPlanSection(),
              const SizedBox(height: 24),
              _buildAIInsightsSection(),
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
          _buildEditField('Calorías Diarias', _caloriesController, Icons.local_fire_department_rounded, 'kcal'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildEditField('Proteína', _proteinController, null, 'g')),
              const SizedBox(width: 12),
              Expanded(child: _buildEditField('Carbs', _carbsController, null, 'g')),
              const SizedBox(width: 12),
              Expanded(child: _buildEditField('Grasas', _fatsController, null, 'g')),
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

  Widget _buildEditField(String label, TextEditingController controller, IconData? icon, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            prefixIcon: icon != null ? Icon(icon, size: 18, color: const Color(0xFF1E88E5)) : null,
            suffixText: unit,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildAIInsightsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E88E5).withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1E88E5).withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF1E88E5), size: 18),
              const SizedBox(width: 8),
              const Text('OBSERVACIONES DE IA', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1E88E5))),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.patientData['alerta'] ?? 'Analizando tendencias históricas...',
            style: const TextStyle(height: 1.5, color: Color(0xFF455A64), fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
