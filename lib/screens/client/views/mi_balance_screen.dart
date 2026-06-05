import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/api_service.dart';
import '../../../providers/auth_provider.dart';
import 'chat_screen.dart';
import 'seguimiento_screen.dart'; // usado en bottom nav
import '../../../providers/balance_provider.dart';
import 'edit_profile_screen.dart';
import '../../../widgets/app_components.dart';
import '../../../app_theme.dart';

class MiBalanceScreen extends StatefulWidget {
  const MiBalanceScreen({Key? key}) : super(key: key);

  @override
  State<MiBalanceScreen> createState() => _MiBalanceScreenState();
}

class _MiBalanceScreenState extends State<MiBalanceScreen> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  late AnimationController _animController;

  bool isLocalLoading = false;
  String? errorMessage;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final balance = Provider.of<BalanceProvider>(context, listen: false);
    if (auth.token != null) {
      String? dateParam;
      if (_selectedDate != null) {
        dateParam = "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";
      }
      balance.fetchFullBalance(auth.token!, fecha: dateParam).then((_) {
        // Asegúrate que el controller no haga forward si el widget muere
        if (mounted) _animController.forward(from: 0);
      });
      balance.fetchFavoritos(auth.token!);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    setState(() {
      isLocalLoading = true;
      errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      if (token == null) throw Exception('No hay sesión activa');

      String? dateParam;
      if (_selectedDate != null) {
        dateParam = "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";
      }

      await Provider.of<BalanceProvider>(context, listen: false).fetchFullBalance(token, fecha: dateParam);
      _animController.forward(from: 0);
      if (mounted) setState(() => isLocalLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          isLocalLoading = false;
        });
      }
    }
  }

  Future<void> _eliminarRegistro(int id, String tipo, {int cantidad = 1}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final balanceProvider = Provider.of<BalanceProvider>(context, listen: false);

    // Si hay más de 1 registro del mismo alimento, preguntar cuántos borrar
    int nEliminar = 1;
    if (cantidad > 1 && tipo == 'alimento') {
      final resultado = await showDialog<int>(
        context: context,
        builder: (ctx) {
          int seleccionado = 1;
          return StatefulBuilder(
            builder: (ctx, setStateDialog) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.delete_outline_rounded, color: Colors.red.shade600, size: 24),
                  const SizedBox(width: 10),
                  const Text('¿Cuántos eliminar?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Tienes $cantidad registros de este alimento.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: seleccionado > 1 ? () => setStateDialog(() => seleccionado--) : null,
                        icon: Icon(Icons.remove_circle_outline, color: seleccionado > 1 ? Colors.red.shade500 : Colors.grey.shade300, size: 32),
                      ),
                      Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.orange.shade200)),
                        alignment: Alignment.center,
                        child: Text('$seleccionado', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.orange.shade700)),
                      ),
                      IconButton(
                        onPressed: seleccionado < cantidad ? () => setStateDialog(() => seleccionado++) : null,
                        icon: Icon(Icons.add_circle_outline, color: seleccionado < cantidad ? Colors.green.shade500 : Colors.grey.shade300, size: 32),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    seleccionado == cantidad ? 'Se eliminarán todos los registros' : 'Se eliminará $seleccionado de $cantidad',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 0),
                  child: Text('Cancelar', style: TextStyle(color: Colors.grey.shade600)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, seleccionado),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        },
      );
      if (resultado == null || resultado == 0) return;
      nEliminar = resultado;
    } else {
      // 1 solo registro: confirmar simple
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 24),
              const SizedBox(width: 10),
              const Text('Confirmar', style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          content: Text('¿Eliminar este ${tipo == 'alimento' ? 'alimento' : 'ejercicio'} de tu registro?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancelar', style: TextStyle(color: Colors.grey.shade600))),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    final token = authProvider.token;
    final String? dateParam = _selectedDate != null
        ? "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}"
        : null;

    try {
      await _apiService.eliminarRegistro(id, tipo, token!, n: nEliminar);
      await balanceProvider.fetchFullBalance(token, fecha: dateParam);

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('${tipo == 'alimento' ? 'Alimento' : 'Ejercicio'} eliminado'),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ));
      }
    } catch (e) {
      // Si el registro ya no existe (404) refrescamos silenciosamente sin mostrar error
      final is404 = e.toString().contains('404');
      try {
        await balanceProvider.fetchFullBalance(token!, fecha: dateParam);
      } catch (_) {}
      if (!is404 && mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: const Text('No se pudo eliminar. Intenta de nuevo.'),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BalanceProvider>(
      builder: (context, provider, child) {
        final balanceData = provider.fullBalanceData;
        final isLoading = isLocalLoading && balanceData == null;

        return Scaffold(
          backgroundColor: AppColors.surface,
          body: isLoading
              ? _buildLoadingState()
              : errorMessage != null
                  ? _buildErrorView()
                  : balanceData == null
                      ? _buildEmptyDayState()
                      : _buildPremiumBalance(balanceData),
          bottomNavigationBar: _buildBottomNavigation(),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60, height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: 20),
          Text('Cargando tu balance...', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildEmptyDayState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_rounded, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text('Sin datos disponibles', style: TextStyle(color: Colors.grey.shade600, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Registra tu primera comida en el asistente', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadBalance,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Recargar'),
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

  Widget _buildPremiumBalance(Map<String, dynamic> data) {
    final resumen = data['resumen'] ?? {};
    final alimentos = data['alimentos_registrados'] ?? [];
    final ejercicios = data['ejercicios_registrados'] ?? [];

    final consumidas = (resumen['calorias_consumidas'] ?? 0).toDouble();
    final quemadas = (resumen['calorias_quemadas'] ?? 0).toDouble();
    final objetivo = (resumen['objetivo_diario'] ?? 2000).toDouble();
    // Restan = Meta − Consumido + Quemadas
    final restantes = (resumen['calorias_restantes'] ?? (objetivo - consumidas + quemadas)).toDouble();
    final proteinas = (resumen['proteinas_g'] ?? 0.0).toDouble();
    final carbohidratos = (resumen['carbohidratos_g'] ?? 0.0).toDouble();
    final grasas = (resumen['grasas_g'] ?? 0.0).toDouble();
    
    final metaP = (resumen['proteinas_objetivo'] ?? 150.0).toDouble();
    final metaC = (resumen['carbohidratos_objetivo'] ?? 250.0).toDouble();
    final metaG = (resumen['grasas_objetivo'] ?? 60.0).toDouble();

    return RefreshIndicator(
      onRefresh: _loadBalance,
      color: AppColors.primary,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // ── PREMIUM HEADER ──
          SliverToBoxAdapter(
            child: _buildHeroHeader(consumidas, quemadas, objetivo, restantes),
          ),
          // ── MACRO PILLS ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: _buildMacroPills(proteinas, carbohidratos, grasas, metaP, metaC, metaG),
            ),
          ),
        ],
        body: Column(
          children: [
            // ── TABS (sticky) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primaryDark,
                  unselectedLabelColor: Colors.grey.shade400,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  tabs: const [
                    Tab(text: 'Comidas'),
                    Tab(text: 'Ejercicios'),
                  ],
                ),
              ),
            ),
            // ── CONTENT ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAlimentosList(alimentos),
                    _buildEjerciciosList(ejercicios),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader(double consumidas, double quemadas, double objetivo, double restantes) {
    final progreso = objetivo > 0 ? (consumidas / objetivo).clamp(0.0, 1.5) : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 34, 20, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.3, 0.9],
            colors: [
              AppColors.primary,
              AppColors.primaryDark,
            ],
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(35),
            bottomRight: Radius.circular(35),
          ),
        ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Top bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.assessment_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mi Balance',
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5, height: 1.1),
                        ),
                        if (_selectedDate != null && 
                            (_selectedDate!.day != DateTime.now().day || 
                             _selectedDate!.month != DateTime.now().month))
                          Text(
                            'Historial: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                            style: TextStyle(color: Colors.orange.shade200, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 18),
                      ),
                      onPressed: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate ?? DateTime.now(),
                          firstDate: DateTime(2023),
                          lastDate: DateTime.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: AppColors.primaryDark, // header background color
                                  onPrimary: Colors.white, // header text color
                                  onSurface: Colors.black, // body text color
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                          _loadBalance();
                        }
                      },
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                      ),
                      onPressed: _loadBalance,
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Linear Progress (Compact)
            AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              restantes.toStringAsFixed(0),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                                letterSpacing: -1,
                              ),
                            ),
                            Text(
                              'kcal restantes',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${(progreso * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: LinearProgressIndicator(
                          value: progreso * _animController.value,
                          backgroundColor: Colors.white.withOpacity(0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progreso > 1.0 ? Colors.orange.shade300 : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 14),

            // ── Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildHeaderStat('Meta', objetivo.toStringAsFixed(0), Icons.flag_rounded),
                _buildVerticalDivider(),
                _buildHeaderStat('Comido', consumidas.toStringAsFixed(0), Icons.restaurant_rounded),
                _buildVerticalDivider(),
                _buildHeaderStat('Quemado', quemadas.toStringAsFixed(0), Icons.local_fire_department_rounded),
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
        Icon(icon, color: Colors.white.withOpacity(0.6), size: 16),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(width: 1, height: 36, color: Colors.white.withOpacity(0.15));
  }

  // ═══════════════════════════════════════════
  // ██  MACRO PILLS (PREMIUM 2.0)
  // ═══════════════════════════════════════════
  
  Widget _buildMacroPills(double proteinas, double carbohidratos, double grasas, double metaP, double metaC, double metaG) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMacroPill(
                'Proteínas',
                proteinas,
                metaP,
                Icons.restaurant_menu_rounded,
                AppColors.macroProtein,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMacroPill(
                'Carbos',
                carbohidratos,
                metaC,
                Icons.bakery_dining_rounded,
                AppColors.macroCarbs,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMacroPill(
                'Grasas',
                grasas,
                metaG,
                Icons.water_drop_rounded,
                AppColors.macroFat,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMacroPill(String label, double value, double meta, IconData icon, Color color) {
    final double progress = meta > 0 ? (value / meta).clamp(0.0, 1.0) : 0.0;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.12), width: 1),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(height: 6),
          Text(
            '${value.toStringAsFixed(0)}g',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.blueGrey.shade300,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ██  FOOD / EXERCISE LISTS
  // ═══════════════════════════════════════════

  Widget _buildAlimentosList(List alimentos) {
    if (alimentos.isEmpty) {
      return EmptyStateView(
        icon: Icons.restaurant_rounded,
        message: 'Sin alimentos registrados',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: alimentos.length,
      itemBuilder: (context, index) => _buildAlimentoCard(alimentos[index], index),
    );
  }

  Widget _buildEjerciciosList(List ejercicios) {
    if (ejercicios.isEmpty) {
      return EmptyStateView(
        icon: Icons.fitness_center_rounded,
        message: 'Sin ejercicio registrado',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: ejercicios.length,
      itemBuilder: (context, index) => _buildEjercicioCard(ejercicios[index], index),
    );
  }

  // ============ FAVORITOS UI ============

  Widget _buildAlimentoCard(Map<String, dynamic> alimento, int index) {
    final nombre = alimento['nombre'] ?? '';
    final hora = alimento['hora_registro'] ?? '';

    final horaCorta = hora.length >= 5 ? hora.substring(0, 5) : hora;
    final cantidad = (alimento['cantidad'] ?? 1) as int;

    return AnimatedListEntry(
      controller: _animController,
      index: index,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade300, Colors.orange.shade500],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.restaurant_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            nombre,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (cantidad > 1) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade600,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '×$cantidad',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 5,
                      runSpacing: 3,
                      children: [
                        MiniChip(icon: Icons.local_fire_department_rounded, label: '${alimento['macros']?['calorias']?.toStringAsFixed(0) ?? 0} kcal', color: Colors.orange),
                        MiniChip(label: 'P: ${alimento['macros']?['proteinas']?.toStringAsFixed(1) ?? 0}g', color: AppColors.macroProtein),
                        MiniChip(label: 'C: ${alimento['macros']?['carbohidratos']?.toStringAsFixed(1) ?? 0}g', color: AppColors.macroCarbs),
                        MiniChip(label: 'G: ${alimento['macros']?['grasas']?.toStringAsFixed(1) ?? 0}g', color: AppColors.macroFat),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 13, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text(horaCorta, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _eliminarRegistro(alimento['id'], 'alimento', cantidad: (alimento['cantidad'] as num? ?? 1).toInt()),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400, size: 18),
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEjercicioCard(Map<String, dynamic> ejercicio, int index) {
    final nombre = ejercicio['nombre'] ?? '';
    final hora = ejercicio['hora_registro'] ?? '';
    final series = ejercicio['series'] ?? 0;
    final reps = ejercicio['reps'] ?? 0;
    final intensidad = ejercicio['intensidad'] ?? '';
    final horaCorta = hora.length >= 5 ? hora.substring(0, 5) : hora;
    final volumenLabel = (series > 0 && reps > 0) ? '${series}×${reps}' : null;

    return AnimatedListEntry(
      controller: _animController,
      index: index,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade700],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.fitness_center_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        MiniChip(icon: Icons.local_fire_department_rounded, label: '${(ejercicio['calorias_quemadas'] as num?)?.toStringAsFixed(0) ?? '0'} kcal', color: Colors.orange),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time_rounded, size: 13, color: Colors.grey.shade400),
                            const SizedBox(width: 3),
                            Text(horaCorta, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                          ],
                        ),
                        if (volumenLabel != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              volumenLabel,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.blue.shade700),
                            ),
                          ),
                        if (intensidad.isNotEmpty)
                          MiniChip(icon: Icons.speed_rounded, label: intensidad, color: Colors.deepPurple),
                      ],
                    ),
                  ],
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _eliminarRegistro(ejercicio['id'], 'ejercicio'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ██  BOTTOM NAV
  // ═══════════════════════════════════════════

  Widget _buildBottomNavigation() {
    return NavigationBar(
      selectedIndex: 2,
      onDestinationSelected: (index) {
        if (index == 0) {
          Navigator.popUntil(context, (route) => route.isFirst);
        } else if (index == 1) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
        } else if (index == 3) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SeguimientoScreen()));
        } else if (index == 4) {
          _navigateToProfile();
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

  Future<void> _navigateToProfile() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.userId == null || authProvider.token == null) return;

    try {
      final client = await _apiService.getClientProfile(authProvider.userId!, authProvider.token!);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (context) => EditProfileScreen(client: client)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al abrir perfil: $e')));
      }
    }
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_off_rounded, size: 48, color: Colors.red.shade300),
            ),
            const SizedBox(height: 20),
            Text('Error de conexión', style: TextStyle(color: Colors.grey.shade800, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? 'Error desconocido',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadBalance,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
