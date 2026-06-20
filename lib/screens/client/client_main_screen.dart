import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/url_service.dart';
import '../../models/dashboard_data.dart';
import '../auth/login_screen.dart';
import 'views/edit_profile_screen.dart';
import 'views/chat_screen.dart';
import 'views/mi_balance_screen.dart';
import 'views/seguimiento_screen.dart';
import '../../widgets/plan_status_badge.dart';
import '../../widgets/plan_alert_card.dart';

import '../../providers/balance_provider.dart';
import '../../widgets/checkin_card.dart';
import 'views/checkin_wizard_screen.dart';
import 'onboarding_profile_screen.dart';

class ClientMainScreen extends StatefulWidget {
  const ClientMainScreen({super.key});

  @override
  State<ClientMainScreen> createState() => _ClientMainScreenState();
}

class _ClientMainScreenState extends State<ClientMainScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  AnimationController? _progressController;
  
  // ✅ Estado de Check-in
  bool _checkInNeeded = false;
  int _precisionScore = 100;
  int _daysUntilCheckin = 0;
  bool _nutriUpdatesPending = false;
  String? _lastUpdateDate;
  double _baselineWeight = 70.0;
  double _baselineHeight = 170.0;
  bool _dialogShown = false; // ✅ Para mostrar el popup solo una vez al entrar
  int? _assignedNutriId; // ✅ Verifica si tiene Nutri asignado
  bool _showAllRecommended = false; // Expande la lista "Prioriza esta semana"
  bool _showAllForbidden = false; // Expande la lista "Evita esta semana"

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    // No hay polling periódico: se recarga al volver de cualquier sub-pantalla
    // (ver .then en cada Navigator.push) y al volver al primer plano (WidgetsBindingObserver)
    
    // Carga inicial de datos a través del Provider
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // 🆕 Verificar si el cliente tiene el perfil completo
      if (authProvider.userId != null && authProvider.token != null) {
        try {
          final client = await _apiService.getClientProfile(authProvider.userId!, authProvider.token!);
          if (!client.isProfileComplete && mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => OnboardingProfileScreen(client: client)),
            );
            return;
          }
        } catch (_) {
          // Si falla la verificación, continuar con el dashboard normal
        }
      }
      
      // ✅ Mostrar Toast de bienvenida si acaba de iniciar sesión
      if (authProvider.showWelcomeMessage) {
        final String name = authProvider.userName ?? 'Usuario';
        _showToast(context, '¡Bienvenido(a), $name!', const Color(0xFF1E88E5));
        authProvider.consumeWelcomeMessage();
      }
      
      _loadDashboardData();
    });
  }

  void _showToast(BuildContext context, String message, Color color) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 100), // Flotando sobre el contenido inferior
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.95),
                borderRadius: BorderRadius.circular(30), // Forma de píldora
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min, // Ajuste al contenido
                children: [
                  const Icon(Icons.stars_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white, 
                        fontWeight: FontWeight.w800, 
                        fontSize: 14,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 4), () {
      overlayEntry.remove();
    });
  }
  
  @override
  void dispose() {
    _progressController?.dispose();
    super.dispose();
  }
  
  Future<void> _loadDashboardData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final balanceProvider = Provider.of<BalanceProvider>(context, listen: false);
    
    if (!authProvider.isAuthenticated) return;
    
    if (ApiService.needsLogout) {
      ApiService.resetLogoutFlag();
      await _handleSessionExpired(authProvider);
      return;
    }
    
    try {
      await balanceProvider.loadDailySummary(
        authProvider.userId!,
        authProvider.token!,
      );
      
      if (!mounted) return;
      
      // Animar el progreso si se cargaron datos
      if (balanceProvider.dailySummary != null) {
        _progressController?.reset();
        _progressController?.forward();
      }
      
      // ✅ Cargar Estado de Check-in
      try {
        final checkInStatus = await _apiService.getCheckInStatus(authProvider.token!);
        setState(() {
          _checkInNeeded = checkInStatus['needed'] ?? false;
          _precisionScore = checkInStatus['precision_score'] ?? 100;
          _daysUntilCheckin = checkInStatus['days_until_checkin'] ?? 0;
          _nutriUpdatesPending = checkInStatus['nutri_updates_pending'] ?? false;
          _lastUpdateDate = checkInStatus['last_update_date'];
        });
      } catch (checkInErr) {
        debugPrint('Error cargando status de check-in: $checkInErr');
      }

      // Buscar el perfil completo si es necesario o para sincronizar datos
      try {
        final profile = await _apiService.getClientProfile(authProvider.userId!, authProvider.token!);
        
        // ✅ Sincronizar foto de perfil si es diferente
        if (profile.profilePictureUrl != null && profile.profilePictureUrl != authProvider.profilePictureUrl) {
          authProvider.updateProfilePictureUrl(profile.profilePictureUrl!);
        }

        setState(() {
          _assignedNutriId = profile.assignedNutriId;
        });

        if (_checkInNeeded) {
          setState(() {
            _baselineWeight = profile.weight;
            _baselineHeight = profile.height;
          });
        }
      } catch (profileErr) {
        debugPrint('Error sincronizando perfil en dashboard: $profileErr');
      }

      // ✅ Mostrar Diálogo de Emergencia si hoy es necesario y no se ha mostrado
      if (_checkInNeeded && !_dialogShown && mounted) {
        _dialogShown = true;
        _showEmergencyCheckInDialog();
      }
      
    } catch (e) {
      debugPrint('Error cargando dashboard via provider: $e');
    }
  }
  
  Future<void> _handleSessionExpired(AuthProvider authProvider) async {
    if (!mounted) return;
    
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
          'Tu sesión ha expirado por seguridad. Por favor, inicia sesión nuevamente.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final balanceProvider = context.watch<BalanceProvider>();
    final dailySummary = balanceProvider.dailySummary;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboardData,
          child: CustomScrollView(
            slivers: [
              // Header personalizado
              _buildCustomHeader(authProvider, dailySummary),
              
              // Contenido principal
              SliverPadding(
                padding: const EdgeInsets.all(20.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (balanceProvider.isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(50.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (balanceProvider.hasError)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.wifi_off_rounded,
                                  size: 56, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(
                                balanceProvider.errorMessage,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 15, color: Colors.grey),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: _loadDashboardData,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Reintentar'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (dailySummary != null) ...[ // Hero Section: Progreso del día
                      
                      // ✅ NUEVO: Bloqueo de Nutricionista
                      if (_assignedNutriId == null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.orange.shade300, width: 2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 28),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '¡Nutricionista Pendiente!',
                                      style: TextStyle(
                                        color: Colors.orange.shade900,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Tu perfil está bajo revisión. Un administrador te asignará un especialista muy pronto para habilitar las funciones analíticas y el Asistente de IA.',
                                style: TextStyle(color: Colors.orange.shade800, height: 1.4),
                              ),
                            ],
                          ),
                        ),

                      // Card de Check-in: solo aparece cuando el check-in ya es HOY
                      if (_checkInNeeded)
                        CheckInCard(
                          precisionScore: _precisionScore,
                          isNeeded: _checkInNeeded,
                          daysUntilCheckin: _daysUntilCheckin,
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CheckInWizardScreen(
                                  currentWeight: _baselineWeight,
                                  currentHeight: _baselineHeight,
                                ),
                              ),
                            );
                            if (result == true) {
                              _loadDashboardData(); // Recargar datos tras completar
                            }
                          },
                        ),
                      
                      // ✨ NUEVO: Alertas rápidas horizontales
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // Badge de cuenta regresiva: siempre que queden días y no sea urgente
                            if (_daysUntilCheckin > 0 && !_checkInNeeded)
                              Container(
                                margin: const EdgeInsets.only(right: 12, bottom: 16, top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.timer_outlined, size: 16, color: Colors.blue.shade700),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Faltan $_daysUntilCheckin días para tu control', 
                                      style: TextStyle(color: Colors.blue.shade800, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            if (_nutriUpdatesPending)
                              Container(
                                margin: const EdgeInsets.only(right: 12, bottom: 16, top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.green.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.update_rounded, size: 16, color: Colors.green.shade700),
                                    const SizedBox(width: 6),
                                    Text(
                                      _lastUpdateDate != null 
                                          ? '¡Novedades de tu Nutricionista! (Actualizado el $_lastUpdateDate)' 
                                          : '¡Novedades de tu Nutricionista!', 
                                      style: TextStyle(color: Colors.green.shade800, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 4),

                      _buildProgressHero(dailySummary),
                      const SizedBox(height: 20),

                      // Macronutrientes en cards horizontales (siempre visibles sin scroll)
                      _buildMacroCards(dailySummary),
                      if ((dailySummary.aiStrategicFocus != null && dailySummary.aiStrategicFocus!.isNotEmpty) ||
                          (dailySummary.nutriWeeklyNote != null && dailySummary.nutriWeeklyNote!.isNotEmpty) ||
                          dailySummary.recommendedFoods.isNotEmpty ||
                          dailySummary.forbiddenFoods.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildStrategicMissionCard(
                          dailySummary.aiStrategicFocus,
                          dailySummary.isStrategyValidated,
                          nutriWeeklyNote: dailySummary.nutriWeeklyNote,
                          recommendedFoods: dailySummary.recommendedFoods,
                          forbiddenFoods: dailySummary.forbiddenFoods,
                        ),
                      ],
                      const SizedBox(height: 20),

                      // ✨ NUEVO: Panel de Micros & Salud (Si hay datos de micros)
                      if ((dailySummary.azucares ?? 0) > 0 || 
                          (dailySummary.fibra ?? 0) > 0 || 
                          (dailySummary.sodio ?? 0) > 0 ||
                          (dailySummary.grasasSaturadas ?? 0) > 0) ...[
                        _buildMicrosPanel(dailySummary),
                        const SizedBox(height: 20),
                      ],
                      
                      // Plan nutricional (si existe)
                      if (dailySummary.planObjetivo != null) ...[
                        // ✨ Card de alerta de estado del plan
                        PlanAlertCard(
                          estadoPlan: dailySummary.planObjetivo!.estadoPlan,
                          esCondicionCritica: dailySummary.planObjetivo!.esCondicionCritica,
                          mensajeCliente: dailySummary.planObjetivo!.mensajeCliente,
                        ),
                        const SizedBox(height: 16),
                        _buildPlanNutricionalCompact(dailySummary),
                        const SizedBox(height: 20),
                      ],
                      
                      // Insight de IA
                      if (dailySummary.aiInsight.isNotEmpty) ...[
                        _buildAIInsightModern(dailySummary),
                        const SizedBox(height: 16),
                      ],

                      // Stats rápidas
                      _buildQuickStats(dailySummary),
                    ] else
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(50.0),
                          child: Text(
                            'No hay datos disponibles',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
      floatingActionButton: _assignedNutriId == null ? null : FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatScreen()),
          );
          if (mounted) _loadDashboardData();
        },
        backgroundColor: const Color(0xFF1E88E5),
        elevation: 4,
        child: const Icon(Icons.auto_awesome, color: Colors.white),
      ),
    );
  }

  // ==================== CUSTOM HEADER ====================
  Widget _buildCustomHeader(AuthProvider authProvider, DailySummary? dailySummary) {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF1565C0),
      title: Text(
        'Hola, ${authProvider.userName ?? "Usuario"}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      centerTitle: false,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.3, 0.9],
              colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                child: Row(
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
                        child: (authProvider.profilePictureUrl == null || authProvider.profilePictureUrl!.isEmpty)
                            ? Text(
                                (authProvider.userName != null && authProvider.userName!.trim().isNotEmpty)
                                    ? authProvider.userName!.trim().substring(0, 1).toUpperCase()
                                    : 'U',
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
                          Row(
                            children: [
                              Flexible(
                                child: Text(
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
                              ),
                              if (dailySummary?.isStrategyValidated == true) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.verified, color: Colors.lightBlueAccent, size: 24),
                              ],
                            ],
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
      actions: const [
        SizedBox(width: 8),
      ],
    );
  }

  // ==================== PROGRESS HERO ====================
  Widget _buildProgressHero(DailySummary dailySummary) {
    final plan = dailySummary.planObjetivo;
    final meta = plan?.caloriasObjetivo ?? 2000.0;
    final consumido = dailySummary.calorias;
    final quemadas = dailySummary.caloriasQuemadas;
    
    // Restan = Meta − Consumido + Quemadas
    final restante = (meta - consumido + quemadas).clamp(0.0, 5000.0);
    final progreso = meta > 0 ? (consumido / meta).clamp(0.0, 1.0) : 0.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E88E5).withOpacity(0.35),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'ENERGÍA DIARIA - ${DateTime.now().day}/${DateTime.now().month}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
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
                      // Track de fondo
                      SizedBox(
                        width: 180,
                        height: 180,
                        child: CircularProgressIndicator(
                          value: 1.0,
                          strokeWidth: 15,
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
                      // Indicador real
                      SizedBox(
                        width: 180,
                        height: 180,
                        child: AnimatedBuilder(
                          animation: _progressController!,
                          builder: (context, child) {
                            return CircularProgressIndicator(
                              value: progreso * _progressController!.value,
                              strokeWidth: 15,
                              color: Colors.white,
                              strokeCap: StrokeCap.round,
                            );
                          },
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${(progreso * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -2,
                            ),
                          ),
                          Text(
                            'logrado',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildHeroIndicator('Meta', meta.toStringAsFixed(0)),
                  _buildHeroIndicator('Hoy', consumido.toStringAsFixed(0)),
                  _buildHeroIndicator('Quemadas', quemadas.toStringAsFixed(0)),
                  _buildHeroIndicator('Restan', restante.toStringAsFixed(0)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroIndicator(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(width: 1, height: 30, color: Colors.white12);
  }

  Widget _buildStrategicMissionCard(
    String? mission,
    bool isValidated, {
    String? nutriWeeklyNote,
    List<String> recommendedFoods = const [],
    List<String> forbiddenFoods = const [],
  }) {
    final hasNote = nutriWeeklyNote != null && nutriWeeklyNote.isNotEmpty;
    final hasMission = mission != null && mission.isNotEmpty;
    final hasRecommended = recommendedFoods.isNotEmpty;
    final hasForbidden = forbiddenFoods.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isValidated ? const Color(0xFFE8F5E9) : const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isValidated ? Colors.green.withValues(alpha: 0.3) : const Color(0xFF1E88E5).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isValidated ? Colors.green : const Color(0xFF1E88E5)).withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isValidated ? Colors.green : const Color(0xFF1E88E5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isValidated ? Icons.verified_rounded : Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'META SEMANAL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: isValidated ? Colors.green.shade800 : const Color(0xFF1565C0),
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              if (isValidated)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'VALIDADO',
                    style: TextStyle(color: Colors.green.shade900, fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                ),
            ],
          ),
          if (hasMission) ...[
            const SizedBox(height: 18),
            Text(
              mission,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF263238),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: isValidated ? Colors.green.shade700 : const Color(0xFF1E88E5),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isValidated
                        ? 'Tu nutricionista aprobó este enfoque.'
                        : 'Tu asistente IA usa esto como norte estratégico.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: (isValidated ? Colors.green.shade700 : const Color(0xFF1E88E5)).withValues(alpha: 0.8),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (hasNote) ...[
            if (hasMission) ...[
              const SizedBox(height: 16),
              Divider(color: Colors.green.withValues(alpha: 0.25), height: 1),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.medical_services_rounded, size: 14, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text(
                  'NOTA DE TU NUTRICIONISTA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.green.shade800,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
              ),
              child: Text(
                nutriWeeklyNote,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade900,
                  height: 1.45,
                ),
              ),
            ),
          ],
          if (hasRecommended || hasForbidden) ...[
            if (hasMission || hasNote) ...[
              const SizedBox(height: 16),
              Divider(color: Colors.green.withValues(alpha: 0.25), height: 1),
            ],
            const SizedBox(height: 16),
            if (hasRecommended) ...[
              Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 14, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'PRIORIZA ESTA SEMANA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.green.shade800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...(_showAllRecommended ? recommendedFoods : recommendedFoods.take(4))
                      .map((food) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      food,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.green.shade900),
                    ),
                  )),
                  if (recommendedFoods.length > 4)
                    GestureDetector(
                      onTap: () => setState(() => _showAllRecommended = !_showAllRecommended),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _showAllRecommended ? 'Ver menos' : '+${recommendedFoods.length - 4} más',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.green.shade800),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _showAllRecommended ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: Colors.green.shade800,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (hasForbidden) ...[
              if (hasRecommended) const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.block_rounded, size: 14, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'EVITA ESTA SEMANA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.red.shade800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...(_showAllForbidden ? forbiddenFoods : forbiddenFoods.take(4))
                      .map((food) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      food,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.red.shade900),
                    ),
                  )),
                  if (forbiddenFoods.length > 4)
                    GestureDetector(
                      onTap: () => setState(() => _showAllForbidden = !_showAllForbidden),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _showAllForbidden ? 'Ver menos' : '+${forbiddenFoods.length - 4} más',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.red.shade800),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _showAllForbidden ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: Colors.red.shade800,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  // ==================== MACRO CARDS ====================
  Widget _buildMacroCards(DailySummary dailySummary) {
    final plan = dailySummary.planObjetivo;
    
    // Obtener valores de macros del plan (si existe)
    final proteinasMeta = plan?.proteinasObjetivoG.toInt() ?? 0;
    final carbohidratosMeta = plan?.carbohidratosObjetivoG.toInt() ?? 0;
    final grasasMeta = plan?.grasasObjetivoG.toInt() ?? 0;
    
    // Valores consumidos — round() para consistencia con Mi Balance
    final proteinasConsumido = dailySummary.proteinas.round();
    final carbosConsumido = dailySummary.carbohidratos.round();
    final grasasConsumido = dailySummary.grasas.round();
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMacroCard(
                'Proteínas', 
                proteinasConsumido,
                proteinasMeta,
                Icons.restaurant_menu_rounded, 
                const Color(0xFFE57373)
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildMacroCard(
                'Carbos', 
                carbosConsumido,
                carbohidratosMeta,
                Icons.bakery_dining_rounded, 
                const Color(0xFFFFB74D)
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildMacroCard(
                'Grasas', 
                grasasConsumido,
                grasasMeta,
                Icons.opacity_rounded, 
                const Color(0xFF64B5F6)
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildMacroCard(String label, int consumido, int meta, IconData icon, Color color) {
    final porcentaje = meta > 0 ? (consumido / meta).clamp(0.0, 1.0) : 0.0;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.1), width: 1),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$consumido / $meta g',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: porcentaje,
              minHeight: 4,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
  // ==================== MICROS PANEL ====================
  Widget _buildMicrosPanel(DailySummary summary) {
    final items = <Widget>[];

    // 1. Azúcares
    if ((summary.azucares ?? 0) > 0) {
      final val = summary.azucares!;
      items.add(_buildMicroGridItem(
        'Azúcar', '${val.toStringAsFixed(1)}g', Icons.icecream_rounded, Colors.purple,
        val > 50 ? 'Alto' : val > 25 ? 'Moderado' : 'Bueno',
        val > 50 ? Colors.red : val > 25 ? Colors.orange : Colors.green
      ));
    }

    // 2. Fibra
    if ((summary.fibra ?? 0) > 0) {
      final val = summary.fibra!;
      items.add(_buildMicroGridItem(
        'Fibra', '${val.toStringAsFixed(1)}g', Icons.eco_rounded, Colors.green,
        val > 25 ? 'Excelente' : val > 15 ? 'Normal' : 'Bajo',
        val > 25 ? Colors.green : val > 15 ? Colors.blue : Colors.orange
      ));
    }

    // 3. Sodio
    if ((summary.sodio ?? 0) > 0) {
      final val = summary.sodio!;
      items.add(_buildMicroGridItem(
        'Sodio', '${val.toStringAsFixed(0)}mg', Icons.grain_rounded, Colors.blueGrey,
        val > 2300 ? 'Excesivo' : val > 1500 ? 'Normal' : 'Bueno',
        val > 2300 ? Colors.red : val > 1500 ? Colors.orange : Colors.green
      ));
    }

    // 4. Grasas Saturadas
    if ((summary.grasasSaturadas ?? 0) > 0) {
      final val = summary.grasasSaturadas!;
      items.add(_buildMicroGridItem(
        'Grasa Sat.', '${val.toStringAsFixed(1)}g', Icons.warning_amber_rounded, Colors.orange,
        val > 20 ? 'Cuidado' : 'Bien',
        val > 20 ? Colors.red : Colors.green
      ));
    }

    // 5. Calcio / Hierro si existen (solo si detectamos valor significativo)
    if ((summary.calcio ?? 0) > 100) {
      items.add(_buildMicroGridItem('Calcio', '${summary.calcio!.toStringAsFixed(0)}mg', Icons.bolt_rounded, Colors.blue, 'Info', Colors.blue));
    }
    if ((summary.hierro ?? 0) > 1) {
      items.add(_buildMicroGridItem('Hierro', '${summary.hierro!.toStringAsFixed(1)}mg', Icons.fitness_center_rounded, Colors.red, 'Info', Colors.red));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '🍭 Salud y Micronutrientes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF37474F)),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.1,
          children: items,
        ),
      ],
    );
  }

  Widget _buildMicroGridItem(String label, String value, IconData icon, Color color, String status, Color statusColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.black87)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(status, style: TextStyle(fontSize: 9, color: statusColor, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Usamos el mismo estilo de tarjeta que en Staff para unificar
  Widget _buildRoleCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1A237E)),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ==================== PLAN NUTRICIONAL COMPACTO ====================
  Widget _buildPlanNutricionalCompact(DailySummary dailySummary) {
    final plan = dailySummary.planObjetivo!;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título completo + badge debajo → nunca se trunca sin importar el texto del badge
          const Text(
            '🎯 Tu Plan Nutricional',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          PlanStatusBadge(
            estadoPlan: plan.estadoPlan,
            esCondicionCritica: plan.esCondicionCritica,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.local_fire_department, size: 30, color: Colors.orange),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Meta Diaria',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    '${plan.caloriasObjetivo.toStringAsFixed(0)} kcal',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          // 🆕 Mensaje informativo si es fallback
          if (plan.esFallback) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[800], size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Este es un cálculo temporal basado en tus datos. Consulta con tu nutricionista para obtener un plan personalizado.',
                      style: TextStyle(fontSize: 11, color: Colors.blue[900]),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // 📋 Mostrar alerta de seguridad si existe
          if (plan.alertaSeguridad.isNotEmpty) ...[ 
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[300]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange[800], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      plan.alertaSeguridad,
                      style: TextStyle(fontSize: 11, color: Colors.orange[900], height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  
  // ==================== AI INSIGHT MODERNO ====================
  Widget _buildAIInsightModern(DailySummary dailySummary) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7B1FA2), Color(0xFF9C27B0)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.lightbulb,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CONSEJO DE TU ASISTENTE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '"${dailySummary.aiInsight}"',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== QUICK STATS ====================
  Widget _buildQuickStats(DailySummary dailySummary) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 Balance Metabólico',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildStatRow('Gasto Energético Total (TDEE)', '${dailySummary.gastoMetabolicoBasal.toStringAsFixed(0)} kcal', Icons.local_fire_department, Colors.orange),
          const Divider(height: 16),
          _buildStatRow('Actividad Física hoy', '${dailySummary.caloriasQuemadas.toStringAsFixed(0)} kcal', Icons.directions_run_rounded, Colors.green),
          const Divider(height: 16),
          _buildStatRow('IMC Actual', dailySummary.imcActual.toStringAsFixed(1), Icons.monitor_weight, Colors.blue),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== LOGOUT DIALOG ====================
  void _showLogoutDialog(AuthProvider authProvider) {
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

  // ==================== BOTTOM NAVIGATION ====================
  Widget _buildBottomNavigation() {
    return NavigationBar(
      selectedIndex: 0,
      onDestinationSelected: (index) async {
        if (index == 1) {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
          if (mounted) _loadDashboardData();
        } else if (index == 2) {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const MiBalanceScreen()));
          if (mounted) _loadDashboardData();
        } else if (index == 3) {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const SeguimientoScreen()));
          if (mounted) _loadDashboardData();
        } else if (index == 4) {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          try {
            final client = await _apiService.getClientProfile(
              authProvider.userId!,
              authProvider.token!,
            );
            if (mounted) {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EditProfileScreen(client: client)),
              );
              if (mounted) _loadDashboardData();
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error cargando perfil: $e')),
              );
            }
          }
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Inicio',
        ),
        NavigationDestination(
          icon: Icon(Icons.chat_bubble_outline),
          selectedIcon: Icon(Icons.chat_bubble),
          label: 'Asistente',
        ),
        NavigationDestination(
          icon: Icon(Icons.assessment_outlined),
          selectedIcon: Icon(Icons.assessment),
          label: 'Balance',
        ),
        NavigationDestination(
          icon: Icon(Icons.trending_up_rounded),
          selectedIcon: Icon(Icons.trending_up),
          label: 'Seguimiento',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Perfil',
        ),
      ],
    );
  }

  Widget _buildValidationBadge() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.white],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade200),
        boxShadow: [
          BoxShadow(color: Colors.green.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_user_rounded, color: Colors.green, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Estrategia Validada',
                  style: TextStyle(fontWeight: FontWeight.w900, color: Colors.green, fontSize: 14),
                ),
                Text(
                  'Tu nutricionista ha revisado y aprobado tu plan estratégico para esta semana.',
                  style: TextStyle(color: Colors.green.shade900, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEmergencyCheckInDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: const Column(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 50),
            SizedBox(height: 10),
            Text(
              'RECALIBRACIÓN REQUERIDA',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w900, color: Colors.blueGrey, fontSize: 14),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🚨 Tu plan nutricional está perdiendo precisión.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ha pasado el sábado y no hemos recibido tus medidas de peso y talla. Sin estos datos, no podemos asegurar que tus macros de esta semana sean los correctos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.fitness_center_rounded, color: Colors.orange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Recuerda: En World Light Gym tienes básculas y medidores listos para ti.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('MÁS TARDE', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CheckInWizardScreen(
                    currentWeight: _baselineWeight,
                    currentHeight: _baselineHeight,
                  ),
                ),
              ).then((value) {
                if (value == true) _loadDashboardData();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('ACTUALIZAR AHORA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ==================== CIRCULAR PROGRESS PAINTER ====================
class CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  CircularProgressPainter({
    required this.progress,
    required this.color,
    this.strokeWidth = 10,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final sweepAngle = 2 * math.pi * progress;
    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
