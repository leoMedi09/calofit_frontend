import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../services/url_service.dart';

class CoachDashboardView extends StatefulWidget {
  const CoachDashboardView({super.key});

  @override
  State<CoachDashboardView> createState() => _CoachDashboardViewState();
}

class _CoachDashboardViewState extends State<CoachDashboardView> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _alerts = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token != null) {
        final stats = await _apiService.getNutriStats(token);
        final alerts = await _apiService.getMisAlertasClientes(token);
        setState(() {
          _stats = stats;
          _alerts = alerts;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: Colors.orange.shade800,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            _buildSliverHeader(),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_isLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(50), child: CircularProgressIndicator(color: Colors.orange)))
                  else ...[
                    _buildStatsRow(),
                    const SizedBox(height: 24),
                    _buildAlertsSection(),
                    const SizedBox(height: 24),
                    _buildPerformanceChart(),
                    const SizedBox(height: 24),
                    _buildAIPredictionCard(),
                    const SizedBox(height: 40),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverHeader() {
    final auth = Provider.of<AuthProvider>(context);
    return SliverAppBar(
      expandedHeight: 180,
      backgroundColor: Colors.black,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.black, Colors.grey.shade900, Colors.orange.shade900.withOpacity(0.8)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                bottom: -20,
                child: Icon(Icons.fitness_center_rounded, size: 200, color: Colors.white.withOpacity(0.05)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.orange.shade700,
                      backgroundImage: auth.profilePictureUrl != null 
                          ? NetworkImage(UrlService.formatImageUrl(auth.profilePictureUrl!)) 
                          : null,
                      child: auth.profilePictureUrl == null 
                          ? const Icon(Icons.person, color: Colors.white, size: 35)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('HOLA, COACH', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2)),
                          Text(
                            auth.userName?.split(' ')[0] ?? 'Entrenador',
                            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _buildStatItem('ATLETAS', _stats['total_pacientes']?.toString() ?? '0', Icons.groups_rounded, Colors.blue)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatItem('METAS', '85%', Icons.emoji_events_rounded, Colors.amber.shade700)), // Simulado para Coach
        const SizedBox(width: 12),
        Expanded(child: _buildStatItem('ALERTAS', _stats['alertas_criticas']?.toString() ?? '0', Icons.warning_amber_rounded, Colors.red)),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey[400], letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildAlertsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ALERTAS DE RENDIMIENTO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        if (_alerts.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.green),
                const SizedBox(width: 12),
                Text('Todo en orden con tus atletas', style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        else
          ..._alerts.take(2).map((alerta) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.bolt_rounded, color: Colors.red, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alerta['paciente'] ?? 'Atleta', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(alerta['problema'] ?? 'Baja intensidad detectada', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                  child: const Text('FATIGA', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          )),
      ],
    );
  }

  Widget _buildPerformanceChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('INTENSIDAD DEL EQUIPO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              Text('Últimos 7 días', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 30), FlSpot(1, 45), FlSpot(2, 35), FlSpot(3, 60), 
                      FlSpot(4, 55), FlSpot(5, 80), FlSpot(6, 75)
                    ],
                    isCurved: true,
                    color: Colors.orange.shade700,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true, 
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, 
                        end: Alignment.bottomCenter, 
                        colors: [Colors.orange.shade700.withOpacity(0.3), Colors.orange.shade700.withOpacity(0)]
                      )
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

  Widget _buildAIPredictionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.deepPurple.shade900, Colors.black]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.orangeAccent, size: 30),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('COPILOT COACH AI', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Text(
                  '3 atletas están listos para subir cargas de peso esta semana.',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
