import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/dashboard_data.dart';
import '../models/client.dart';
import '../screens/login_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/chat_screen.dart';


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final ApiService _apiService = ApiService();

  // Estados de carga
  bool _isLoadingSummary = true;
  bool _isLoadingTrend = true;
  bool _isLoadingWeight = true;
  bool _isLoadingIMC = true;
  bool _isLoadingAI = true;

  // Datos reales
  DailySummary? _dailySummary;
  List<CalorieTrend> _caloriesTrend = [];
  List<WeightRecord> _weightHistory = [];
  List<IMCRecord> _imcHistory = [];
  AIAnalysis? _aiAnalysis;

  final List<String> months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Widget _buildAIInsightCard(String insight) {
    return Container(
      margin: const EdgeInsets.only(top: 15, bottom: 5),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Color de advertencia suave
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.orange[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: Colors.orange[800], size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "RECOMENDACIÓN DE IA",
                  style: TextStyle(
                    color: Colors.orange[900],
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  insight,
                  style: TextStyle(
                    color: Colors.orange[900],
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _loadAllData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.token == null) {
      debugPrint("⏳ Esperando token de seguridad...");
      return;
    }

    final token = authProvider.token;
    final clientId = authProvider.userId;

    if (token == null || clientId == null) {
      setState(() {
        _isLoadingSummary = true;
        _isLoadingTrend = true;
        _isLoadingWeight = false;
        _isLoadingIMC = false;
        _isLoadingAI = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se encontró sesión activa')),
      );
      return;
    }

    // Resetear estados si se llama desde el refresh
    setState(() {
      _isLoadingSummary = true;
      _isLoadingTrend = true;
      _isLoadingWeight = true;
      _isLoadingIMC = true;
      _isLoadingAI = true;
    });

    // Cargar datos en paralelo
    await Future.wait([
      _loadDailySummary(clientId, token),
      _loadCaloriesTrend(clientId, token),
      _loadWeightHistory(clientId, token),
      _loadIMCHistory(clientId, token),
      _loadAIAnalysis(clientId, token),
    ]);
  }

  Future<void> _loadDailySummary(int clientId, String token) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final String? uid = authProvider.userIdFirebase;

      if (uid == null) {
        setState(() => _isLoadingSummary = false);
        return;
      }

      final data = await _apiService.getDietaPorUid(uid, token); // ✅ Ahora pasa el token

      if (!mounted) return;

      setState(() {
        final dieta = data['dieta_recomendada'];

        _dailySummary = DailySummary(
          calorias: dieta['calorias_diarias'].toDouble(),
          proteinas: dieta['proteinas_g'].toDouble(),
          carbohidratos: dieta['carbohidratos_g'].toDouble(),
          grasas: dieta['grasas_g']?.toDouble() ?? 0.0,  // 🆕 Campo agregado
          gastoEstimado: dieta['gasto_metabolico_basal'].toDouble(),
          imcActual: dieta['imc']?.toDouble() ?? 0.0,
          // ✅ CAMBIO CLAVE: Extraemos 'notas' de dentro del objeto 'dieta'
          aiInsight: dieta['notas'] ?? "",
        );
        _isLoadingSummary = false;
      });
    } catch (e) {
      debugPrint('Error en carga real de dieta: $e');
      if (mounted) setState(() => _isLoadingSummary = false);
    }
  }

  Future<void> _loadCaloriesTrend(int clientId, String token) async {
    try {
      final data = await _apiService.getCaloriesTrend(clientId, token);
      setState(() {
        _caloriesTrend = data.map((json) => CalorieTrend.fromJson(json)).toList();
        _isLoadingTrend = false;
      });
    } catch (e) {
      debugPrint('Error cargando tendencia de calorías: $e');
      // Datos mock para usuario 2 (más activo)
      setState(() {
        _caloriesTrend = [
          CalorieTrend(day: 'Lun', consumed: 2200, burned: 500),
          CalorieTrend(day: 'Mar', consumed: 2400, burned: 550),
          CalorieTrend(day: 'Mié', consumed: 2300, burned: 600),
          CalorieTrend(day: 'Jue', consumed: 2500, burned: 520),
          CalorieTrend(day: 'Vie', consumed: 2350, burned: 580),
          CalorieTrend(day: 'Sáb', consumed: 2600, burned: 650),
          CalorieTrend(day: 'Dom', consumed: 2250, burned: 500),
        ];
        _isLoadingTrend = false;
      });
    }
  }

  Future<void> _loadWeightHistory(int clientId, String token) async {
    try {
      final data = await _apiService.getWeightHistory(clientId, token);
      setState(() {
        _weightHistory = data.map((json) => WeightRecord.fromJson(json)).toList();
        _isLoadingWeight = false;
      });
    } catch (e) {
      debugPrint('Error cargando historial de peso: $e');
      // Datos mock para usuario 2 (bajando peso)
      setState(() {
        _weightHistory = [
          WeightRecord(month: 1, weight: 85.0),
          WeightRecord(month: 2, weight: 83.5),
          WeightRecord(month: 3, weight: 82.0),
          WeightRecord(month: 4, weight: 80.8),
          WeightRecord(month: 5, weight: 79.5),
          WeightRecord(month: 6, weight: 78.0),
        ];
        _isLoadingWeight = false;
      });
    }
  }

  Future<void> _loadIMCHistory(int clientId, String token) async {
    try {
      final data = await _apiService.getIMCHistory(clientId, token);
      setState(() {
        _imcHistory = data.map((json) => IMCRecord.fromJson(json)).toList();
        _isLoadingIMC = false;
      });
    } catch (e) {
      debugPrint('Error cargando historial de IMC: $e');
      // Datos mock para usuario 2 (mejorando IMC)
      setState(() {
        _imcHistory = [
          IMCRecord(month: 1, imc: 28.5),
          IMCRecord(month: 2, imc: 27.8),
          IMCRecord(month: 3, imc: 27.2),
          IMCRecord(month: 4, imc: 26.5),
          IMCRecord(month: 5, imc: 25.8),
          IMCRecord(month: 6, imc: 25.0),
        ];
        _isLoadingIMC = false;
      });
    }
  }

  Future<void> _loadAIAnalysis(int clientId, String token) async {
    try {
      final data = await _apiService.getAIAnalysis(clientId, token);
      setState(() {
        _aiAnalysis = AIAnalysis.fromJson(data);
        _isLoadingAI = false;
      });
    } catch (e) {
      debugPrint('Error cargando análisis de IA: $e');
      setState(() {
        // Busca esto en tu dashboard_screen.dart
        _aiAnalysis = AIAnalysis(
          gastoEstimado: 2100.0,
          imcActual: 26.5,
          imcCategoria: 'Sobrepeso',
          aiInsight: '',
        );
        _isLoadingAI = false;
      });
    }
  }

  void _goToEditProfile() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Mostrar un diálogo de carga mientras obtenemos el perfil
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1. Obtener datos actuales del cliente desde la API
      Client client = await _apiService.getClientProfile(authProvider.userId!, authProvider.token!);

      if (!mounted) return;
      Navigator.pop(context); // Cerrar diálogo de carga

      // 2. Navegar a la pantalla de edición
      bool? updated = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => EditProfileScreen(client: client)),
      );

      // 3. Si se actualizó, refrescar el dashboard
      if (updated == true) {
        _loadAllData();
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Cerrar diálogo de carga
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar perfil: $e')),
      );
    }
  }

  void _goToChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChatScreen()),
    );
  }

  void _showLogoutDialog(AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cerrar Sesión'),
          content: const Text('¿Estás seguro de que deseas salir de CaloFit?'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Cierra el diálogo
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Cierra el diálogo
                authProvider.logout(); // Limpia la sesión
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[400],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Cerrar Sesión', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.isAuthenticated && _dailySummary == null && _isLoadingSummary == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadAllData());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard CaloFit'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(authProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeSection(authProvider),
              const SizedBox(height: 20),
              _buildDailySummarySection(),
              const SizedBox(height: 20),
              _buildPlanNutricionalSection(),  // 🆕 NUEVA SECCIÓN
              const SizedBox(height: 20),
              _buildAIAnalysisSection(),
              if (_dailySummary != null && _dailySummary!.aiInsight.isNotEmpty)
                _buildAIInsightCard(_dailySummary!.aiInsight),
              const SizedBox(height: 20),
              _buildCaloriesChart(),
              const SizedBox(height: 20),
              _buildWeightChart(),
              const SizedBox(height: 20),
              _buildIMCChart(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildWelcomeSection(AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(25, 158, 158, 158),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¡Hola, ${authProvider.userName ?? "usuario"}! 👋',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tu asistente de CaloFit está aquí para ayudarte. Mantente al día con tu progreso.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailySummarySection() {
    if (_isLoadingSummary) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_dailySummary == null) {
      return _buildErrorCard('No se pudo cargar el resumen diario');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tu Resumen Calórico Diario',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                value: _dailySummary!.calorias.toStringAsFixed(0),
                label: 'Calorías',
                gradient: const LinearGradient(
                  colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
                ),
                textColor: Colors.blue[700]!,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricCard(
                value: _dailySummary!.proteinas.toStringAsFixed(0),
                label: 'Proteínas',
                gradient: const LinearGradient(
                  colors: [Color(0xFFF3E5F5), Color(0xFFE1BEE7)],
                ),
                textColor: Colors.purple[700]!,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricCard(
                value: _dailySummary!.carbohidratos.toStringAsFixed(0),
                label: 'Carbohidratos',
                gradient: const LinearGradient(
                  colors: [Color(0xFFFCE4EC), Color(0xFFF8BBD0)],
                ),
                textColor: Colors.pink[700]!,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String value,
    required String label,
    required LinearGradient gradient,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAIAnalysisSection() {
    if (_isLoadingAI) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_aiAnalysis == null) {
      return _buildErrorCard('No se pudo cargar el análisis de IA');
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(25, 158, 158, 158),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Análisis de Inteligencia Artificial',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          _buildAICard(
            icon: '🔥',
            title: 'Gasto Calórico Estimado',
            value: '${_aiAnalysis!.gastoEstimado.toStringAsFixed(1)} kcal',
            backgroundColor: Colors.orange[50]!,
            valueColor: Colors.orange[700]!,
          ),
          const SizedBox(height: 8),
          _buildAICard(
            icon: '📏',
            title: 'IMC Actual',
            value: '${_aiAnalysis!.imcActual.toStringAsFixed(1)} (${_aiAnalysis!.imcCategoria})',
            backgroundColor: Colors.blue[50]!,
            valueColor: Colors.blue[700]!,
          ),
        ],
      ),
    );
  }

  Widget _buildAICard({
    required String icon,
    required String title,
    required String value,
    required Color backgroundColor,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaloriesChart() {
    if (_isLoadingTrend) {
      return _buildChartLoadingCard('Cargando datos de calorías...');
    }

    if (_caloriesTrend.isEmpty) {
      return _buildErrorCard('No hay datos de calorías disponibles');
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(25, 158, 158, 158),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔥 Calorías: Consumo vs Quema',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _getMaxCalories(),
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < _caloriesTrend.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _caloriesTrend[index].day,
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  _caloriesTrend.length,
                  (index) => BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: _caloriesTrend[index].consumed,
                        color: Colors.blue[500],
                        width: 8,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: _caloriesTrend[index].burned,
                        color: Colors.purple[400],
                        width: 8,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(Colors.blue[500]!, 'Consumidas'),
              const SizedBox(width: 16),
              _buildLegendItem(Colors.purple[400]!, 'Quemadas'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeightChart() {
    if (_isLoadingWeight) {
      return _buildChartLoadingCard('Cargando datos de peso...');
    }

    if (_weightHistory.isEmpty) {
      return _buildErrorCard('No hay datos de peso disponibles');
    }

    final weightSpots = _weightHistory
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.weight))
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(25, 158, 158, 158),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 Evolución de Peso',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: weightSpots,
                    isCurved: true,
                    color: Colors.red[500],
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < _weightHistory.length) {
                          int monthIdx = (_weightHistory[index].month - 1) % 12;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              months[monthIdx],
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) => Text(value.toStringAsFixed(0), style: const TextStyle(fontSize: 10)),
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                minY: _getMinWeight() - 2,
                maxY: _getMaxWeight() + 2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: _buildLegendItem(Colors.red[500]!, 'Peso Real (kg)'),
          ),
        ],
      ),
    );
  }

  Widget _buildIMCChart() {
    if (_isLoadingIMC) {
      return _buildChartLoadingCard('Cargando datos de IMC...');
    }

    if (_imcHistory.isEmpty) {
      return _buildErrorCard('No hay datos de IMC disponibles');
    }

    final imcSpots = _imcHistory
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.imc))
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(25, 158, 158, 158),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📈 Evolución de IMC',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: imcSpots,
                    isCurved: true,
                    color: Colors.green[500],
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < _imcHistory.length) {
                          int monthIdx = (_imcHistory[index].month - 1) % 12;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              months[monthIdx],
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) => Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 10)),
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                minY: _getMinIMC() - 1,
                maxY: _getMaxIMC() + 1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: _buildLegendItem(Colors.green[500]!, 'IMC'),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
      ],
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartLoadingCard(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(25, 158, 158, 158),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Métodos auxiliares para calcular valores dinámicos
  double _getMaxCalories() {
    if (_caloriesTrend.isEmpty) return 2000.0;
    double max = 0;
    for (var trend in _caloriesTrend) {

      if (trend.consumed > max) max = trend.consumed.toDouble();
      if (trend.burned > max) max = trend.burned.toDouble();
    }
    return max == 0 ? 2000.0 : (max * 1.2);
  }

  double _getMinWeight() {
    if (_weightHistory.isEmpty) return 60.0; // ✅ Si la lista está vacía, devuelve un valor base
    return _weightHistory.map((e) => e.weight).reduce((a, b) => a < b ? a : b);
  }

  double _getMaxWeight() {
    if (_weightHistory.isEmpty) return 80;
    return _weightHistory.map((e) => e.weight).reduce((a, b) => a > b ? a : b);
  }

  double _getMinIMC() {
    if (_imcHistory.isEmpty) return 18;
    return _imcHistory.map((e) => e.imc).reduce((a, b) => a < b ? a : b);
  }

  double _getMaxIMC() {
    return _imcHistory.map((e) => e.imc).reduce((a, b) => a > b ? a : b);
  }

  
  Widget _buildPlanNutricionalSection() {
    if (_dailySummary?.planObjetivo == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.amber[900]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Aún no tienes un plan nutricional asignado. ¡Regístrate con más datos o contacta a tu nutricionista!',
                style: TextStyle(color: Colors.amber[900], fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    final plan = _dailySummary!.planObjetivo!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con badge de validación
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tu Plan Nutricional 🎯',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: plan.validado ? Colors.green[100] : Colors.orange[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      plan.validado ? Icons.verified : Icons.pending,
                      size: 14,
                      color: plan.validado ? Colors.green[700] : Colors.orange[700],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      plan.validado ? 'Validado' : 'En revisión',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: plan.validado ? Colors.green[700] : Colors.orange[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Calorías objetivo destacadas
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[400]!, Colors.blue[600]!],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Meta Diaria',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${plan.caloriasObjetivo.toStringAsFixed(0)} kcal',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Icon(Icons.local_fire_department, size: 50, color: Colors.white70),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Macros con porcentajes
          Text(
            'Distribución de Macronutrientes',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMacroChipWithPct(
                'Proteínas',
                plan.proteinasObjetivoG,
                plan.distribucion['proteina_pct']!,
                Colors.red[300]!,
                Icons.restaurant,
              ),
              _buildMacroChipWithPct(
                'Carbos',
                plan.carbohidratosObjetivoG,
                plan.distribucion['carbohidratos_pct']!,
                Colors.orange[300]!,
                Icons.bakery_dining,
              ),
              _buildMacroChipWithPct(
                'Grasas',
                plan.grasasObjetivoG,
                plan.distribucion['grasas_pct']!,
                Colors.yellow[700]!,
                Icons.oil_barrel,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroChipWithPct(
    String label,
    double gramos,
    int porcentaje,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          '${gramos.toStringAsFixed(0)}g',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$porcentaje%',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildBottomNavigation() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: _selectedIndex,
      selectedItemColor: Colors.blue[700],
      unselectedItemColor: Colors.grey,
      onTap: (index) {
        if (index == 1) {
          _goToChat();
        } else if (index == 3) {
          _goToEditProfile();
        } else {
          setState(() {
            _selectedIndex = index;
          });
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
        BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Asistente IA'),
        BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Entrenamiento'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
      ],
    );
  }
}
