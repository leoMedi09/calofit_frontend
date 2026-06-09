import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../app_theme.dart';
import 'chat_screen.dart';
import 'mi_balance_screen.dart';
import 'edit_profile_screen.dart';

class SeguimientoScreen extends StatefulWidget {
  const SeguimientoScreen({Key? key}) : super(key: key);

  @override
  State<SeguimientoScreen> createState() => _SeguimientoScreenState();
}

class _SeguimientoScreenState extends State<SeguimientoScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  Map<String, dynamic>? _semanaData;
  bool _loadingSemana = true;
  String? _errorSemana;
  int _semanaOffset = 0;

  Map<String, dynamic>? _historicoData;
  bool _loadingHistorico = false;
  String? _errorHistorico;
  int _diasSeleccionados = 30;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabController.index == 1) {
        if (_historicoData == null && !_loadingHistorico) _loadHistorico();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSemana());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _token =>
      Provider.of<AuthProvider>(context, listen: false).token ?? '';

  Future<void> _loadSemana() async {
    setState(() {
      _loadingSemana = true;
      _errorSemana = null;
    });
    try {
      final data = await _api.getSeguimientoSemanal(_token, semanaOffset: _semanaOffset);
      if (mounted) setState(() => _semanaData = data);
    } catch (e) {
      if (mounted) setState(() => _errorSemana = e.toString());
    } finally {
      if (mounted) setState(() => _loadingSemana = false);
    }
  }

  void _cambiarSemana(int delta) {
    final nuevo = _semanaOffset + delta;
    if (nuevo > 0 || nuevo < -12) return;
    setState(() {
      _semanaOffset = nuevo;
      _semanaData = null;
    });
    _loadSemana();
  }

  String _formatearRango() {
    if (_semanaData == null) return '';
    final rango = _semanaData!['rango'] as Map<String, dynamic>?;
    if (rango == null) return '';
    final ini = rango['fecha_inicio'] as String;
    final fin = rango['fecha_fin'] as String;
    String _fmt(String iso) {
      final p = iso.split('-');
      return '${p[2]}/${p[1]}';
    }
    final esActual = rango['es_semana_actual'] as bool? ?? false;
    return esActual ? 'Esta semana (${_fmt(ini)} – ${_fmt(fin)})' : '${_fmt(ini)} – ${_fmt(fin)}';
  }

  Future<void> _loadHistorico() async {
    setState(() {
      _loadingHistorico = true;
      _errorHistorico = null;
    });
    try {
      final data = await _api.getSeguimientoHistorico(_token, dias: _diasSeleccionados);
      if (mounted) setState(() => _historicoData = data);
    } catch (e) {
      if (mounted) setState(() => _errorHistorico = e.toString());
    } finally {
      if (mounted) setState(() => _loadingHistorico = false);
    }
  }

  void _cambiarRango(int dias) {
    if (_diasSeleccionados == dias) return;
    setState(() {
      _diasSeleccionados = dias;
      _historicoData = null;
    });
    _loadHistorico();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: _buildBottomNav(),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.primaryDark,
                unselectedLabelColor: Colors.grey.shade400,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                tabs: const [
                  Tab(text: 'Esta Semana'),
                  Tab(text: 'Progreso'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildSemanaTab(),
            _buildProgresoTab(),
          ],
        ),
      ),
    );
  }

  // ─── HEADER ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final resumen = _semanaData?['resumen'];
    final adherencia = (resumen?['adherencia_promedio_pct'] ?? 0.0) as num;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.trending_up_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Mi Seguimiento',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildHeaderStat(
                  'Adherencia',
                  '${adherencia.toStringAsFixed(0)}%',
                  Icons.track_changes_rounded,
                ),
                _buildVDivider(),
                _buildHeaderStat(
                  'Días registrados',
                  '${resumen?['dias_con_registro'] ?? 0}/7',
                  Icons.calendar_today_rounded,
                ),
                _buildVDivider(),
                _buildHeaderStat(
                  'Con ejercicio',
                  '${resumen?['dias_con_ejercicio'] ?? 0} días',
                  Icons.fitness_center_rounded,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white60, size: 16),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildVDivider() =>
      Container(width: 1, height: 40, color: Colors.white24);

  // ─── TAB SEMANA ───────────────────────────────────────────────────────────

  Widget _buildSemanaTab() {
    if (_loadingSemana) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorSemana != null) {
      return _buildError(_errorSemana!, _loadSemana);
    }
    if (_semanaData == null) {
      return const Center(child: Text('Sin datos'));
    }

    final dias = List<Map<String, dynamic>>.from(_semanaData!['dias'] ?? []);
    final resumen = _semanaData!['resumen'] as Map<String, dynamic>;

    return RefreshIndicator(
      onRefresh: _loadSemana,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildWeekNav(),
          const SizedBox(height: 12),
          _buildResumenCard(resumen),
          const SizedBox(height: 16),
          _buildWeeklyChart(dias),
          const SizedBox(height: 16),
          _buildDayCardsRow(dias),
        ],
      ),
    );
  }

  Widget _buildWeekNav() {
    final label = _formatearRango();
    final esActual = _semanaOffset == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => _cambiarSemana(-1),
            icon: const Icon(Icons.chevron_left_rounded),
            color: AppColors.primary,
            iconSize: 28,
            tooltip: 'Semana anterior',
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: esActual ? AppColors.primary : AppColors.textDark,
              ),
            ),
          ),
          IconButton(
            onPressed: esActual ? null : () => _cambiarSemana(1),
            icon: const Icon(Icons.chevron_right_rounded),
            color: esActual ? Colors.grey.shade300 : AppColors.primary,
            iconSize: 28,
            tooltip: 'Semana siguiente',
          ),
        ],
      ),
    );
  }

  Widget _buildResumenCard(Map<String, dynamic> resumen) {
    final adherencia = (resumen['adherencia_promedio_pct'] as num).toDouble();
    final color = adherencia >= 80
        ? Colors.green.shade600
        : adherencia >= 50
            ? Colors.orange.shade600
            : Colors.red.shade500;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, color: color, size: 20),
              const SizedBox(width: 8),
              Text('Resumen de la semana',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildResumenItem(
                  'Promedio diario',
                  '${(resumen['kcal_promedio_consumidas'] as num).toStringAsFixed(0)} kcal',
                  Icons.restaurant_rounded,
                  AppColors.macroCarbs,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildResumenItem(
                  'Meta promedio',
                  '${(resumen['objetivo_promedio'] as num).toStringAsFixed(0)} kcal',
                  Icons.flag_rounded,
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildResumenItem(
                  'Mejor día',
                  resumen['mejor_dia'] as String,
                  Icons.star_rounded,
                  Colors.amber.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Adherencia semanal',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600)),
              Text('${adherencia.toStringAsFixed(1)}%',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: color)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: adherencia / 100.0,
              backgroundColor: color.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center),
          Text(label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ─── GRÁFICO DE BARRAS SEMANAL ─────────────────────────────────────────────

  Widget _buildWeeklyChart(List<Map<String, dynamic>> dias) {
    if (dias.isEmpty) return const SizedBox.shrink();

    // maxY = max(objetivo) × 1.5, pero también incluye consumidas reales
    // con un techo de 2× el objetivo para que outliers no distorsionen la escala.
    final maxObjetivo = dias
        .map((d) => (d['kcal_objetivo'] as num).toDouble())
        .fold(0.0, (a, b) => a > b ? a : b);
    final maxConsumidas = dias
        .where((d) => d['hay_registro'] as bool)
        .map((d) => (d['kcal_consumidas'] as num).toDouble())
        .fold(0.0, (a, b) => a > b ? a : b);
    // Techo: evitar que un día con dato extremo comprima toda la escala
    final maxConsumidasCap = maxConsumidas.clamp(0.0, maxObjetivo * 2.0);
    final maxY = (maxConsumidasCap > maxObjetivo ? maxConsumidasCap : maxObjetivo) * 1.25;

    final groups = <BarChartGroupData>[];
    for (int i = 0; i < dias.length; i++) {
      final d = dias[i];
      final objetivo = (d['kcal_objetivo'] as num).toDouble();
      final consumidas = (d['kcal_consumidas'] as num).toDouble();
      final hayRegistro = d['hay_registro'] as bool;
      // Capear al 75% del maxY: garantiza 25% de espacio libre para el tooltip
      final consumidasDisplay = consumidas.clamp(0.0, maxY * 0.75);
      final esOutlier = hayRegistro && consumidas > maxY * 0.75;

      final colorConsumidas = !hayRegistro
          ? Colors.grey.shade200
          : esOutlier
              ? Colors.red.shade400
              : consumidas <= objetivo * 1.1
                  ? const Color(0xFF43A047)
                  : Colors.orange.shade500;

      groups.add(BarChartGroupData(
        x: i,
        barsSpace: 4,
        barRods: [
          BarChartRodData(
            toY: objetivo,
            color: AppColors.primary.withOpacity(0.22),
            width: 14,
            borderRadius: BorderRadius.circular(5),
          ),
          BarChartRodData(
            toY: hayRegistro ? consumidasDisplay : 0,
            color: colorConsumidas,
            width: 14,
            borderRadius: BorderRadius.circular(5),
          ),
        ],
      ));
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Kcal: Meta vs Consumidas',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark),
              ),
              Row(
                children: [
                  _buildLegendDot(AppColors.primary.withOpacity(0.35), 'Meta'),
                  const SizedBox(width: 12),
                  _buildLegendDot(const Color(0xFF43A047), 'Real'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
                BarChartData(
                  maxY: maxY > 0 ? maxY : 2500,
                  minY: 0,
                  barGroups: groups,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        interval: maxY / 4,
                        getTitlesWidget: (val, meta) {
                          if (val == 0 || val == maxY) return const SizedBox.shrink();
                          return Text(
                            val >= 1000
                                ? '${(val / 1000).toStringAsFixed(1)}k'
                                : val.toStringAsFixed(0),
                            style: TextStyle(fontSize: 9, color: Colors.grey.shade400),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (val, meta) {
                          final idx = val.toInt();
                          if (idx < 0 || idx >= dias.length) return const SizedBox.shrink();
                          final esHoy = dias[idx]['es_hoy'] as bool;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              dias[idx]['dia_etiqueta'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: esHoy ? FontWeight.w900 : FontWeight.w600,
                                color: esHoy ? AppColors.primary : Colors.grey.shade500,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      fitInsideVertically: false,
                      fitInsideHorizontally: true,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final d = dias[group.x];
                        final diaLabel = d['dia_etiqueta'] as String;
                        if (rodIndex == 0) {
                          final obj = (d['kcal_objetivo'] as num).toStringAsFixed(0);
                          return BarTooltipItem(
                            '$diaLabel · Meta\n$obj kcal',
                            const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          );
                        }
                        // Consumidas: mostrar valor real aunque la barra esté capeada
                        final real = (d['kcal_consumidas'] as num).toStringAsFixed(0);
                        final esOutlierTip = (d['kcal_consumidas'] as num) > maxY * 0.98;
                        return BarTooltipItem(
                          esOutlierTip
                              ? '$diaLabel · Consumidas\n$real kcal ⚠️'
                              : '$diaLabel · Consumidas\n$real kcal',
                          const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                        );
                      },
                    ),
                  ),
                ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ─── CARDS DE 7 DÍAS ──────────────────────────────────────────────────────

  Widget _buildDayCardsRow(List<Map<String, dynamic>> dias) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(
            'Detalle por día',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark),
          ),
        ),
        ...dias.map((d) => _buildDayCard(d)),
      ],
    );
  }

  Widget _buildMacroMiniBar({
    required String label,
    required Color color,
    required double value,
    required double meta,
  }) {
    final pct = meta > 0 ? (value / meta).clamp(0.0, 1.0) : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 10,
          child: Text(
            label,
            style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: color),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(
                pct >= 1.0 ? color : color.withValues(alpha: 0.65),
              ),
              minHeight: 4,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '${value.toStringAsFixed(0)}g',
          style: TextStyle(fontSize: 8, color: Colors.grey.shade400, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildDayCard(Map<String, dynamic> d) {
    final hayRegistro = d['hay_registro'] as bool;
    final hayEjercicio = d['hay_ejercicio'] as bool;
    final adherencia = (d['adherencia_pct'] as num).toDouble();
    final esHoy = d['es_hoy'] as bool;
    final kcalObj = (d['kcal_objetivo'] as num).toDouble();
    final kcalCons = (d['kcal_consumidas'] as num).toDouble();
    final protG = (d['proteinas_g'] as num? ?? 0).toDouble();
    final carbG = (d['carbohidratos_g'] as num? ?? 0).toDouble();
    final grasG = (d['grasas_g'] as num? ?? 0).toDouble();
    final protMeta = (d['proteinas_meta_g'] as num? ?? 0).toDouble();
    final carbMeta = (d['carbohidratos_meta_g'] as num? ?? 0).toDouble();
    final grasMeta = (d['grasas_meta_g'] as num? ?? 0).toDouble();

    final Color statusColor = !hayRegistro
        ? Colors.grey.shade300
        : adherencia >= 80
            ? const Color(0xFF43A047)
            : adherencia >= 50
                ? Colors.orange.shade400
                : Colors.red.shade400;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: esHoy ? Border.all(color: AppColors.primary, width: 1.5) : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          // Día + indicador hoy
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Text(
                  d['dia_etiqueta'] as String,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: esHoy ? AppColors.primary : AppColors.textDark,
                  ),
                ),
                if (esHoy)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Hoy',
                        style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Barra de progreso + kcal
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      hayRegistro
                          ? '${kcalCons.toStringAsFixed(0)} / ${kcalObj.toStringAsFixed(0)} kcal'
                          : 'Sin registro',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: hayRegistro ? AppColors.textDark : Colors.grey.shade400),
                    ),
                    if (hayRegistro)
                      Text(
                        '${adherencia.toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: statusColor),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: hayRegistro && kcalObj > 0
                        ? (kcalCons / kcalObj).clamp(0.0, 1.3)
                        : 0.0,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    minHeight: 5,
                  ),
                ),
                if (hayRegistro) ...[
                  const SizedBox(height: 6),
                  _buildMacroMiniBar(label: 'P', color: AppColors.macroProtein, value: protG, meta: protMeta),
                  const SizedBox(height: 3),
                  _buildMacroMiniBar(label: 'C', color: AppColors.macroCarbs,   value: carbG, meta: carbMeta),
                  const SizedBox(height: 3),
                  _buildMacroMiniBar(label: 'G', color: AppColors.macroFat,     value: grasG, meta: grasMeta),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Icono ejercicio
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: hayEjercicio ? Colors.blue.shade50 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.fitness_center_rounded,
              size: 16,
              color: hayEjercicio ? Colors.blue.shade600 : Colors.grey.shade300,
            ),
          ),
        ],
      ),
    );
  }

  // ─── TAB PROGRESO HISTÓRICO ───────────────────────────────────────────────

  Widget _buildProgresoTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _buildRangeSelector(),
        const SizedBox(height: 16),
        if (_loadingHistorico)
          const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
        else if (_errorHistorico != null)
          _buildError(_errorHistorico!, _loadHistorico)
        else if (_historicoData != null) ...[
          _buildKcalHistoricoChart(),
          const SizedBox(height: 16),
          _buildPesoChart(),
          const SizedBox(height: 16),
          _buildResumenHistorico(),
        ] else
          const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
      ],
    );
  }

  Widget _buildRangeSelector() {
    return Row(
      children: [
        const Text('Período:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        const SizedBox(width: 10),
        for (final dias in [7, 30, 90]) ...[
          GestureDetector(
            onTap: () => _cambiarRango(dias),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: _diasSeleccionados == dias ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _diasSeleccionados == dias ? AppColors.primary : Colors.grey.shade200,
                ),
              ),
              child: Text(
                dias == 7 ? '7 días' : dias == 30 ? '30 días' : '90 días',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _diasSeleccionados == dias ? Colors.white : Colors.grey.shade600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildKcalHistoricoChart() {
    final calorias = List<Map<String, dynamic>>.from(_historicoData!['calorias'] ?? []);
    if (calorias.isEmpty) return const SizedBox.shrink();

    final metaKcal = (_historicoData!['meta_kcal'] as num).toDouble();

    // Para más de 30 días, muestrear cada N días para no saturar el eje X
    final step = _diasSeleccionados > 30 ? 3 : 1;
    final spots = <FlSpot>[];
    for (int i = 0; i < calorias.length; i += step) {
      final d = calorias[i];
      if (d['hay_registro'] as bool) {
        spots.add(FlSpot(i.toDouble(), (d['kcal_consumidas'] as num).toDouble()));
      }
    }

    if (spots.isEmpty) {
      return _buildEmptyChart('Sin registros calóricos en este período');
    }

    final maxY = ([metaKcal, ...spots.map((s) => s.y)].reduce((a, b) => a > b ? a : b)) * 1.2;

    // Etiquetas del eje X: cada 7 días o en puntos clave
    final xLabels = <int, String>{};
    for (int i = 0; i < calorias.length; i += (_diasSeleccionados > 30 ? 14 : 7)) {
      final fecha = calorias[i]['fecha'] as String;
      final parts = fecha.split('-');
      if (parts.length == 3) xLabels[i] = '${parts[2]}/${parts[1]}';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Calorías consumidas',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              Row(
                children: [
                  _buildLegendDot(AppColors.primary.withOpacity(0.3), 'Meta ${metaKcal.toStringAsFixed(0)}'),
                  const SizedBox(width: 10),
                  _buildLegendDot(Colors.orange.shade400, 'Real'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  // Línea de meta (horizontal dashed)
                  LineChartBarData(
                    spots: [
                      FlSpot(0, metaKcal),
                      FlSpot((calorias.length - 1).toDouble(), metaKcal),
                    ],
                    isCurved: false,
                    color: AppColors.primary.withOpacity(0.4),
                    barWidth: 1.5,
                    dotData: const FlDotData(show: false),
                    dashArray: [6, 4],
                    belowBarData: BarAreaData(show: false),
                  ),
                  // Línea de consumidas
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: Colors.orange.shade500,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: spots.length <= 15,
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                        color: Colors.orange.shade500,
                        radius: 3,
                        strokeColor: Colors.white,
                        strokeWidth: 1.5,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.orange.withOpacity(0.08),
                    ),
                  ),
                ],
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (val, meta) {
                        if (val == 0) return const SizedBox.shrink();
                        return Text('${val.toInt()}',
                            style: TextStyle(fontSize: 9, color: Colors.grey.shade400));
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        final label = xLabels[idx];
                        if (label == null) return const SizedBox.shrink();
                        return Text(label,
                            style: TextStyle(fontSize: 9, color: Colors.grey.shade500));
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots.map((s) {
                      if (s.barIndex == 0) return null;
                      final idx = s.x.toInt();
                      final fecha = idx < calorias.length
                          ? (calorias[idx]['fecha'] as String).substring(5)
                          : '';
                      return LineTooltipItem(
                        '$fecha\n${s.y.toStringAsFixed(0)} kcal',
                        const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPesoChart() {
    final pesos = List<Map<String, dynamic>>.from(_historicoData!['peso'] ?? []);
    if (pesos.length < 2) {
      return _buildEmptyChart('Sin suficientes registros de peso\n(mínimo 2 para mostrar gráfico)');
    }

    final spots = pesos
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), (e.value['peso_kg'] as num).toDouble()))
        .toList();

    final allY = spots.map((s) => s.y).toList();
    final minY = allY.reduce((a, b) => a < b ? a : b) - 1.5;
    final maxY = allY.reduce((a, b) => a > b ? a : b) + 1.5;

    final xLabels = <int, String>{};
    final step = (pesos.length / 4).ceil();
    for (int i = 0; i < pesos.length; i += step) {
      final fecha = pesos[i]['fecha'] as String;
      final parts = fecha.split('-');
      if (parts.length == 3) xLabels[i] = '${parts[2]}/${parts[1]}';
    }
    xLabels[pesos.length - 1] = (() {
      final fecha = pesos.last['fecha'] as String;
      final parts = fecha.split('-');
      return parts.length == 3 ? '${parts[2]}/${parts[1]}' : '';
    })();

    final resumen = _historicoData!['resumen'] as Map<String, dynamic>;
    final num? cambio = resumen['cambio_peso'] as num?;
    final cambioStr = cambio != null
        ? '${cambio >= 0 ? '+' : ''}${cambio.toStringAsFixed(1)} kg'
        : null;
    final cambioColor = cambio == null
        ? Colors.grey
        : cambio <= 0
            ? Colors.green.shade600
            : Colors.orange.shade600;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Evolución de peso',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              if (cambioStr != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cambioColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(cambioStr,
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800, color: cambioColor)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.4,
                    color: AppColors.primary,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: pesos.length <= 15,
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                        color: AppColors.primary,
                        radius: 3,
                        strokeColor: Colors.white,
                        strokeWidth: 1.5,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withOpacity(0.08),
                    ),
                  ),
                ],
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 38,
                      getTitlesWidget: (val, meta) => Text(
                        '${val.toStringAsFixed(1)}',
                        style: TextStyle(fontSize: 9, color: Colors.grey.shade400),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (val, meta) {
                        final label = xLabels[val.toInt()];
                        if (label == null) return const SizedBox.shrink();
                        return Text(label,
                            style: TextStyle(fontSize: 9, color: Colors.grey.shade500));
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots.map((s) {
                      final idx = s.x.toInt();
                      final fecha = idx < pesos.length
                          ? (pesos[idx]['fecha'] as String).substring(5)
                          : '';
                      return LineTooltipItem(
                        '$fecha\n${s.y.toStringAsFixed(1)} kg',
                        const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenHistorico() {
    final resumen = _historicoData!['resumen'] as Map<String, dynamic>;
    final diasConReg = resumen['dias_con_registro'] as int;
    final kcalProm = (resumen['kcal_promedio'] as num?)?.toStringAsFixed(0) ?? '—';
    final pesoInicial = resumen['peso_inicial'];
    final pesoActual = resumen['peso_actual'];
    final num? cambio = resumen['cambio_peso'] as num?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resumen del período',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 12),
          _buildResumenRow(Icons.calendar_today_rounded, 'Días con registro', '$diasConReg de $_diasSeleccionados', Colors.blue),
          _buildResumenRow(Icons.local_fire_department_rounded, 'Promedio calórico diario', '$kcalProm kcal', Colors.orange),
          if (pesoInicial != null)
            _buildResumenRow(Icons.monitor_weight_outlined, 'Peso inicial', '$pesoInicial kg', Colors.purple),
          if (pesoActual != null)
            _buildResumenRow(Icons.monitor_weight_rounded, 'Peso actual', '$pesoActual kg', AppColors.primary),
          if (cambio != null) ...[
            const SizedBox(height: 4),
            _buildResumenRow(
              cambio <= 0 ? Icons.trending_down_rounded : Icons.trending_up_rounded,
              'Cambio total',
              '${cambio >= 0 ? '+' : ''}${cambio.toStringAsFixed(1)} kg',
              cambio <= 0 ? Colors.green.shade600 : Colors.orange.shade600,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResumenRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          ),
          Text(value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textDark)),
        ],
      ),
    );
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────────

  Widget _buildEmptyChart(String msg) {
    return Container(
      height: 100,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(msg,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
    );
  }

  Widget _buildError(String error, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('Error de conexión', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── BOTTOM NAV ───────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return NavigationBar(
      selectedIndex: 3,
      onDestinationSelected: (index) async {
        if (index == 0) {
          Navigator.popUntil(context, (route) => route.isFirst);
        } else if (index == 1) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
        } else if (index == 2) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MiBalanceScreen()));
        } else if (index == 4) {
          final auth = Provider.of<AuthProvider>(context, listen: false);
          if (auth.userId == null || auth.token == null) return;
          try {
            final client = await _api.getClientProfile(auth.userId!, auth.token!);
            if (mounted) {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => EditProfileScreen(client: client)));
            }
          } catch (_) {}
        }
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
        NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Asistente'),
        NavigationDestination(icon: Icon(Icons.assessment_outlined), selectedIcon: Icon(Icons.assessment), label: 'Balance'),
        NavigationDestination(icon: Icon(Icons.trending_up_rounded), selectedIcon: Icon(Icons.trending_up), label: 'Seguimiento'),
        NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
      ],
    );
  }
}
