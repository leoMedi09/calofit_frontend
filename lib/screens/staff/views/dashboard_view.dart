import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:dio/dio.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../services/url_service.dart';
import '../../../widgets/plan_status_badge.dart';
import '../../auth/login_screen.dart';
import 'staff_registration_form.dart';
import 'team_list_view.dart';

class DashboardView extends StatefulWidget {
  final Function(int)? onNavigate;
  const DashboardView({super.key, this.onNavigate});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  static const Color primaryBlue = Color(0xFF1E88E5);
  static const Color secondaryBlue = Color(0xFF1565C0);
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  int _countNutri = 0;
  int _countCoach = 0;
  int _countAdmin = 0;
  int _countInactive = 0;
  
  // 🏥 Nutri KPIs
  int _countPacientes = 0;
  int _countValidaciones = 0;
  int _countAlertasCriticas = 0;
  double _adherenciaMedia = 0.0;
  List<double> _tendenciaAdherencia = [];
  List<Map<String, dynamic>> _recentAlerts = [];
  bool _showAllAlerts = false;
  
  String _currentAIInsight = 'Generando informe estratégico...';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshData();
    // ⏱️ Refresco automático cada 60 segundos para mantener datos frescos sin saturar el back
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) => _refreshData(isAutoRefresh: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshData({bool isAutoRefresh = false}) async {
    if (!mounted) return;
    if (!isAutoRefresh) setState(() => _isLoading = true);
    
    // 🔐 Verificar si hubo un error 401/403 en alguna petición previa
    if (ApiService.needsLogout) {
      ApiService.resetLogoutFlag();
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await _handleSessionExpired(authProvider);
      return;
    }
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token ?? '';
      
      if (token.isEmpty) {
        _refreshTimer?.cancel();
        return;
      }

      final currentUserRole = authProvider.userRole?.toLowerCase() ?? '';
      final isAdmin = currentUserRole.contains('admin') || currentUserRole.contains('administrador');

      if (isAdmin) {
        // 🏢 Lógica original para Administradores (Gestión de Staff)
        final team = await _apiService.getUsers(token);
        
        int nutris = 0;
        int coaches = 0;
        int admins = 0;
        int inactives = 0;
        bool selfFound = false;
        final currentUserId = authProvider.userId;

        for (var member in team) {
          if (member.id == currentUserId) selfFound = true;
          
          String role = member.roleName.toLowerCase();
          if (role.contains('admin') || role.contains('administrador')) {
            admins++;
          } else if (role.contains('nutri')) {
            nutris++;
          } else if (role.contains('coach') || role.contains('trainer')) {
            coaches++;
          }

          if (!member.isActive) {
            inactives++;
          }
        }

        if (!selfFound) {
          admins++;
        }

        if (mounted) {
          setState(() {
            _countNutri = nutris;
            _countCoach = coaches;
            _countAdmin = admins;
            _countInactive = inactives;
            _isLoading = false;
            
            final total = nutris + coaches + admins;
            if (total == 0) {
              _currentAIInsight = '👋 No hay personal registrado aún.';
            } else if (inactives > total / 2) {
              _currentAIInsight = '⚠️ Alta tasa de staff inactivo.';
            } else {
              _currentAIInsight = '✅ Equipo balanceado. Los logs muestran estabilidad.';
            }
          });
        }
      } else {
        // 🏥 Lógica nueva para Nutricionistas (KPIs Clínicos)
        final stats = await _apiService.getNutriStats(token);
        
        if (mounted) {
          setState(() {
            _countPacientes = stats['total_pacientes'] ?? 0;
            _countValidaciones = stats['validaciones_pendientes'] ?? 0;
            _countAlertasCriticas = stats['alertas_criticas'] ?? 0;
            _adherenciaMedia = (stats['adherencia_media'] ?? 0.0).toDouble();
            _tendenciaAdherencia = (stats['tendencia_adherencia'] as List?)
                ?.map((e) => (e as num).toDouble())
                .toList() ?? [];
            _recentAlerts = (stats['alertas_recientes'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e))
                .toList() ?? [];
            
            _isLoading = false;
            
            // Insight específico para Nutri
            if (_countAlertasCriticas > 0) {
              _currentAIInsight = '🚨 Tienes $_countAlertasCriticas alertas críticas de salud. ¡Revísalas pronto!';
            } else if (_countValidaciones > 0) {
              _currentAIInsight = '📝 Hay $_countValidaciones planes esperando tu validación profesional.';
            } else if (_adherenciaMedia < 50) {
              _currentAIInsight = '📉 La adherencia media es baja. Considera contactar a tus pacientes.';
            } else {
              _currentAIInsight = '🌟 ¡Excelente! Tus pacientes mantienen una adherencia del $_adherenciaMedia%.';
            }
          });
        }
      }
      
      // ✅ Sincronizar Foto de Perfil del Staff
      try {
        final profile = await _apiService.getStaffProfile(token);
        final identity = profile['identidad'];
        if (identity != null && identity['foto_perfil'] != null) {
          final newUrl = identity['foto_perfil'] as String;
          if (newUrl != authProvider.profilePictureUrl) {
            authProvider.updateProfilePictureUrl(newUrl);
          }
        }
      } catch (staffProfileErr) {
        debugPrint('Error sincronizando perfil de staff: $staffProfileErr');
      }
    } on DioException catch (e) {
      // Detectar error de autenticación (token expirado)
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        debugPrint('🔐 Token expirado detectado en Dashboard Staff');
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await _handleSessionExpired(authProvider);
        return;
      }
      
      debugPrint('❌ Error refrescando datos: $e');
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error refrescando datos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _handleSessionExpired(AuthProvider authProvider) async {
    if (!mounted) return;
    
    // Cancelar timer de refresco
    _refreshTimer?.cancel();
    
    // Mostrar diálogo informativo
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.lock_clock, color: Colors.orange.shade700, size: 28),
            const SizedBox(width: 12),
            const Text('Sesión Expirada'),
          ],
        ),
        content: const Text(
          'Tu sesión de staff ha expirado por seguridad. Por favor, inicia sesión nuevamente.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
    
    // Ejecutar logout y redirigir al login
    await authProvider.logout();
    
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }


  void _updateAIInsight() {
    List<String> insights = [
      'IA Copilot: Los logs de auditoría muestran un sistema 100% estable hoy.',
      'IA Insight: El compromiso del staff ha subido un 8% este trimestre.',
      'Sugerencia: Programar una reunión de alineación con los nuevos Nutris.',
      'KPI Alert: El tiempo de respuesta a clientes es excelente actualmente.',
      'Sugerencia: Revisar los accesos de staff que no han tenido actividad reciente.',
      'Análisis: La distribución del equipo es ideal para la carga de usuarios actual.',
    ];
    
    // Consejos dinámicos basados en la data real
    if (_countNutri < 2) {
      insights.insert(0, 'Alerta: Hay pocos Nutricionistas activos. Considera contratar refuerzos.');
    }
    if (_countAdmin > (_countCoach + _countNutri)) {
      insights.insert(0, 'Gestión: Tienes una estructura con muchos administradores. ¿Delegar tareas?');
    }

    setState(() {
      _currentAIInsight = insights[math.Random().nextInt(insights.length)];
    });
  }

  void _navigateToAuditList(BuildContext context) {
    // Usamos el callback para cambiar a la pestaña de Auditoría (Índice 2)
    // Esto mantiene la barra de navegación visible y evita el "pop up"
    widget.onNavigate?.call(2);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    return Scaffold(
      backgroundColor: Colors.grey[50], // Match Scaffold background
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          color: primaryBlue,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverAppBar(
                expandedHeight: 140,
                floating: false,
                elevation: 0,
                backgroundColor: primaryBlue,
                title: Text(
                  'Hola, ${authProvider.userName ?? "Staff"}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                centerTitle: false,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [secondaryBlue, primaryBlue, Color(0xFF1E88E5)],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 60, 24, 10),
                      child: Row(
                        children: [
                          _buildProfileIcon(authProvider),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '¡BIENVENIDO!',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  authProvider.userName ?? 'Staff',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: const [
                  SizedBox(width: 8),
                ],
              ),
              
              SliverPadding(
                padding: const EdgeInsets.all(20.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                  // Lógica de Rol
                  if (!_isAdmin(context)) ...[
                    // SESIÓN 2: ALERTAS DE SALUD (Solo para Nutris/Coaches)
                    _buildSectionTitle('Alertas de Salud (Clientes)', Icons.notification_important_rounded),
                    const SizedBox(height: 15),
                    _buildHealthAlertsSection(),
                    const SizedBox(height: 35),
                  ],

                  // SESIÓN 3: ESTADÍSTICAS DE EQUIPO / GESTIÓN
                  _buildSectionTitle(
                    _isAdmin(context) ? 'Centro de Análisis Corporativo' : 'Gestión de Equipo', 
                    _isAdmin(context) ? Icons.analytics_rounded : Icons.analytics_rounded
                  ),
                  const SizedBox(height: 20),
                  if (_isAdmin(context))
                    _buildAdminModernStats()
                  else
                    _buildNutriKPIs(),

                  const SizedBox(height: 35),



                  // SESIÓN 4: INTELIGENCIA ARTIFICIAL
                  _buildSectionTitle('Asistente IA Copilot', Icons.auto_awesome_outlined),
                  const SizedBox(height: 15),
                  _buildAIInsightCard(),
                  
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    ),
   );
  }

  bool _isAdmin(BuildContext context) {
    final role = Provider.of<AuthProvider>(context, listen: false).userRole?.toLowerCase() ?? '';
    return role == 'admin' || role == 'administrador';
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: secondaryBlue.withOpacity(0.8)),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 13, 
            fontWeight: FontWeight.w800, 
            color: const Color(0xFF1A237E).withOpacity(0.7),
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }


  Widget _buildWelcomeHeader(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            backgroundImage: authProvider.profilePictureUrl != null && authProvider.profilePictureUrl!.isNotEmpty
                ? NetworkImage(UrlService.formatImageUrl(authProvider.profilePictureUrl))
                : null,
            child: authProvider.profilePictureUrl == null || authProvider.profilePictureUrl!.isEmpty
                ? Text(
                    authProvider.userName?.substring(0, 1).toUpperCase() ?? 'U',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E88E5),
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '¡BIENVENIDO!',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                authProvider.userName ?? 'Usuario',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handleLogout(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cerrar Sesión'),
          content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                await authProvider.logout();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              child: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }


  Widget _buildNutriKPIs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 📈 Main KPI Row
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Seguimiento',
                '$_countPacientes',
                'Pacientes',
                Icons.people_alt_rounded,
                primaryBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Pendientes',
                '$_countValidaciones',
                'Validaciones',
                Icons.fact_check_rounded,
                Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 25),
        
        // 📊 Adherence Chart Section
        _buildSectionSubtitle('Adherencia del Equipo (7 días)'),
        const SizedBox(height: 15),
        Container(
          height: 200,
          padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: _buildAdherenceChart(),
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'PROMEDIO ACTUAL: $_adherenciaMedia%',
                style: TextStyle(
                  color: primaryBlue,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, String unit, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: color.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A237E),
              letterSpacing: -0.5,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdherenceChart() {
    if (_tendenciaAdherencia.isEmpty) {
      return const Center(child: Text('Cargando tendencia...'));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withOpacity(0.1),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                const days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
                int idx = value.toInt();
                if (idx < 0 || idx >= days.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    days[idx],
                    style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 50,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}%',
                  style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold, fontSize: 10),
                );
              },
              reservedSize: 35,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 6,
        minY: 0,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(_tendenciaAdherencia.length, (i) {
              return FlSpot(i.toDouble(), _tendenciaAdherencia[i]);
            }),
            isCurved: true,
            gradient: LinearGradient(colors: [primaryBlue, primaryBlue.withOpacity(0.5)]),
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [primaryBlue.withOpacity(0.2), primaryBlue.withOpacity(0)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildRoleCard(
                'Nutricionistas', 
                _countNutri.toString(), 
                Icons.restaurant_menu_rounded, 
                const Color(0xFFE57373)
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildRoleCard(
                'Entrenadores', 
                _countCoach.toString(), 
                Icons.bolt_rounded, 
                const Color(0xFFFFB74D)
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        _buildActionItem(
          'Personal de Baja',
          'Cuentas inactivas o suspendidas.',
          Icons.person_off_rounded,
          Colors.grey.shade600,
          () {},
        ),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, String subtitle, IconData icon, Color color, {bool isFullWidth = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A237E),
                    letterSpacing: -0.8,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade700,
                    letterSpacing: -0.2,
                  ),
                ),
                if (isFullWidth)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade500,
                      letterSpacing: 0.1,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIInsightCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF673AB7), Color(0xFF512DA8)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: const Color(0xFF673AB7).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'IA COPILOT ANALYTICS',
                  style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                ),
                const SizedBox(height: 6),
                Text(
                  _currentAIInsight,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: -0.1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminModernStats() {
    final int totalStaffCount = _countNutri + _countAdmin + _countCoach; // ✅ Incluimos Coaches

    return Column(
      children: [
        // 💎 HERO STATUS CARD (Diseño Sólido Premium)
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1565C0).withOpacity(0.3),
                blurRadius: 25,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.groups_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'DISTRIBUCIÓN DEL EQUIPO',
                          style: TextStyle(
                            fontSize: 12, 
                            fontWeight: FontWeight.w800, 
                            color: Colors.white, 
                            letterSpacing: 1.2
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 35),
                    Center(
                      child: SizedBox(
                        height: 180,
                        width: 180,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            PieChart(
                              PieChartData(
                                sectionsSpace: 4,
                                centerSpaceRadius: 65,
                                startDegreeOffset: -90,
                                sections: [
                                  PieChartSectionData(
                                    value: _countAdmin.toDouble(),
                                    color: Colors.white, 
                                    radius: 14,
                                    showTitle: false,
                                  ),
                                  PieChartSectionData(
                                    value: _countNutri.toDouble(),
                                    color: const Color(0xFFE57373),
                                    radius: 14,
                                    showTitle: false,
                                  ),
                                  PieChartSectionData(
                                    value: _countCoach.toDouble(),
                                    color: const Color(0xFFFFA726), // ✅ Naranja para Coaches
                                    radius: 14,
                                    showTitle: false,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$totalStaffCount',
                                  style: const TextStyle(
                                    fontSize: 52, 
                                    fontWeight: FontWeight.w900, 
                                    color: Colors.white, 
                                    letterSpacing: -2
                                  ),
                                ),
                                const Text(
                                  'total',
                                  style: TextStyle(
                                    fontSize: 16, 
                                    fontWeight: FontWeight.w500, 
                                    color: Colors.white
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 35),
                    // Stats Inferiores (Admin, Nutri)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildHeroIndicator('Administrador', _countAdmin.toString()),
                        _buildHeroIndicator('Nutricionista', _countNutri.toString()),
                        _buildHeroIndicator('Entrenador', _countCoach.toString()),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 35),
        
        // ⚡ ACCIONES RÁPIDAS
        _buildSectionTitle('Operaciones del Sistema', Icons.bolt_rounded),
        const SizedBox(height: 15),
        _buildActionItem(
          'Gestión de Equipo',
          'Añadir personal nuevo y gestionar roles.',
          Icons.group_add_rounded,
          const Color(0xFF1E88E5),
          () {
            // Cambiar pestaña a "Equipo"
            widget.onNavigate?.call(1);
          },
        ),
        const SizedBox(height: 12),
        _buildActionItem(
          'Gestión de Clientes',
          'Inscribir pacientes y asignarlos al personal.',
          Icons.person_add_alt_1_rounded,
          const Color(0xFF43A047), // Verde
          () {
            // Cambiar pestaña a "Pacientes"
            widget.onNavigate?.call(2);
          },
        ),
      ],
    );
  }


  Widget _buildHeroIndicator(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 0.8),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1.0),
        ),
      ],
    );
  }

  Widget _buildRoleCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 15),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1A237E), letterSpacing: -0.8),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w800, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black.withOpacity(0.03)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1A237E), letterSpacing: -0.3),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600, letterSpacing: 0.2),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade300),
          ],
        ),
      ),
    );
  }

  void _openRegistrationForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const StaffRegistrationForm(),
    ).then((_) => _refreshData());
  }

  Widget _buildMiniLegend(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.0)),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1A237E), letterSpacing: -0.5)),
        ),
      ],
    );
  }

  Widget _buildSectionSubtitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey.shade600, letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildExecutiveCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 15),
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF1A237E), letterSpacing: -0.2)),
            Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.8),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
      ],
    );
  }

  Widget _buildModernMiniCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, 8)),
          ],
          border: Border.all(color: color.withOpacity(0.05), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1A237E), letterSpacing: -0.2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
      ],
    );
  }


  Widget _buildHealthAlertsSection() {
    // ── Estado vacío ────────────────────────────────────────────────────────
    if (_recentAlerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.shade100),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green.shade400, size: 20),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Sin alertas pendientes. ¡Todo en orden!',
                style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1A531B), fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    // ── Métricas del resumen ─────────────────────────────────────────────────
    final int totalAlerts = _recentAlerts.length;
    final int alta  = _recentAlerts.where((a) => a['urgency'] == 'Alta').length;
    final int media = _recentAlerts.where((a) => a['urgency'] == 'Media').length;
    final int baja  = _recentAlerts.where((a) => a['urgency'] == 'Baja').length;

    const int previewCount = 3;
    final List<Map<String, dynamic>> visible = _showAllAlerts
        ? _recentAlerts
        : _recentAlerts.take(previewCount).toList();
    final int hidden = totalAlerts - previewCount;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Fila resumen ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: alta > 0 ? Colors.red.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.notification_important_rounded,
                    size: 18,
                    color: alta > 0 ? Colors.red.shade600 : Colors.orange.shade700,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$totalAlerts ${totalAlerts == 1 ? 'alerta activa' : 'alertas activas'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                // Chips de urgencia
                if (alta > 0)  _urgencyChip('Alta', alta, Colors.red),
                if (media > 0) _urgencyChip('Media', media, Colors.orange),
                if (baja > 0)  _urgencyChip('Baja', baja, const Color(0xFFF59E0B)),
              ],
            ),
          ),

          Divider(height: 1, color: Colors.grey.shade100),

          // ── Alertas compactas ───────────────────────────────────────────
          ...visible.asMap().entries.map((entry) {
            final alert = entry.value;
            final bool isLast = entry.key == visible.length - 1 && (!_showAllAlerts || hidden <= 0);
            final Color accent = alert['urgency'] == 'Alta'
                ? Colors.red.shade600
                : alert['urgency'] == 'Media'
                    ? Colors.orange.shade700
                    : const Color(0xFFF59E0B);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Indicador de color lateral
                      Container(
                        width: 3,
                        height: 36,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Ícono pequeño
                      Icon(
                        alert['urgency'] == 'Alta'
                            ? Icons.warning_amber_rounded
                            : Icons.info_outline_rounded,
                        color: accent,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      // Texto
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alert['paciente'] ?? 'Paciente',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              alert['problema'] ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Badge urgencia
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          alert['urgency'] ?? 'Baja',
                          style: TextStyle(
                            color: accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast) Divider(height: 1, indent: 16, endIndent: 16, color: Colors.grey.shade100),
              ],
            );
          }),

          // ── Botón expandir / contraer ───────────────────────────────────
          if (totalAlerts > previewCount)
            InkWell(
              onTap: () => setState(() => _showAllAlerts = !_showAllAlerts),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  border: Border(top: BorderSide(color: Colors.grey.shade100)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _showAllAlerts
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _showAllAlerts
                          ? 'Mostrar menos'
                          : 'Ver $hidden alerta${hidden > 1 ? 's' : ''} más',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade600,
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

  Widget _urgencyChip(String label, int count, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _buildProfileIcon(AuthProvider authProvider) {
    final String initials = (authProvider.userName ?? '?').isNotEmpty 
        ? (authProvider.userName ?? '?').substring(0, 1).toUpperCase() 
        : '?';
    final String? photoUrl = authProvider.profilePictureUrl;
    
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ]
      ),
      child: CircleAvatar(
        radius: 30,
        backgroundColor: Colors.white,
        backgroundImage: photoUrl != null && photoUrl.isNotEmpty
            ? NetworkImage(UrlService.formatImageUrl(photoUrl))
            : null,
        child: (photoUrl == null || photoUrl.isEmpty)
            ? Text(initials, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: primaryBlue))
            : null,
      ),
    );
  }
}
