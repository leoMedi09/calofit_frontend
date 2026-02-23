import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import 'staff_registration_form.dart';
import 'team_list_view.dart';
import '../../../models/user.dart';
import '../../../services/api_service.dart';

class TeamManagementView extends StatefulWidget {
  const TeamManagementView({super.key});

  @override
  State<TeamManagementView> createState() => _TeamManagementViewState();
}

class _TeamManagementViewState extends State<TeamManagementView> {
  static const Color primaryBlue = Color(0xFF1E88E5);
  static const Color secondaryBlue = Color(0xFF1565C0);

  final ApiService _apiService = ApiService();
  List<User> _members = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadStats();
    // ⏱️ Sincronización automática de equipo cada 60 segundos
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) => _loadStats(isAutoRefresh: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStats({bool isAutoRefresh = false}) async {
    if (!isAutoRefresh) setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final List<User> team = await _apiService.getUsers(authProvider.token ?? '');
      
      // Asegurar que el Admin actual sea considerado en las estadísticas
      final bool selfFound = team.any((m) => m.id == authProvider.userId);
      if (!selfFound && authProvider.userId != null) {
        team.add(User(
          id: authProvider.userId!,
          firstName: authProvider.userName ?? 'Admin',
          lastNamePaternal: '',
          lastNameMaternal: '',
          email: authProvider.userEmail ?? '',
          roleName: authProvider.userRole ?? 'admin',
          isActive: true,
        ));
      }

      if (mounted) {
        setState(() {
          _members = team;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshStats() async {
    await _loadStats();
  }

  void _openRegistrationForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const StaffRegistrationForm(),
    );
  }

  void _navigateToTeamList(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TeamListView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: _refreshStats,
        color: primaryBlue,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              backgroundColor: primaryBlue,
              elevation: 0,
              pinned: true,
              toolbarHeight: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [primaryBlue, Color(0xFF0D47A1)],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                    boxShadow: [
                      BoxShadow(color: Color(0x331E88E5), blurRadius: 20, offset: Offset(0, 10)),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 42, 20, 40),
                    child: _buildHeader(),
                  ),
                ),
              ),
            ),
            
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildSectionTitle('Estadísticas de Personal', Icons.analytics_outlined),
                  const SizedBox(height: 15),
                  _isLoading 
                    ? const Center(child: LinearProgressIndicator())
                    : Row(
                        children: [
                          Expanded(child: _buildRoleCard(
                            'Nutris', 
                            _members.where((m) => m.roleName.toLowerCase().contains('nutri')).length.toString(), 
                            Icons.restaurant_menu, 
                            const Color(0xFFFF5252)
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: _buildRoleCard(
                            'Coaches', 
                            _members.where((m) => m.roleName.toLowerCase().contains('coach') || m.roleName.toLowerCase().contains('train')).length.toString(), 
                            Icons.fitness_center, 
                            const Color(0xFFFFA000)
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: _buildRoleCard(
                            'Admins', 
                            _members.where((m) => m.roleName.toLowerCase().contains('admin')).length.toString(), 
                            Icons.admin_panel_settings, 
                            primaryBlue
                          )),
                        ],
                      ),
                  const SizedBox(height: 35),
                  _buildSectionTitle('Acciones de Miembros', Icons.settings_accessibility_rounded),
                  const SizedBox(height: 15),
                  _buildActionCard(
                    context,
                    'Registrar Nuevo Personal',
                    'Añade y configura accesos iniciales.',
                    Icons.person_add_alt_1_rounded,
                    primaryBlue,
                    () => _openRegistrationForm(context),
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    context,
                    'Ver Mi Equipo',
                    'Gestión de perfiles y estados de miembros.',
                    Icons.group_work_rounded,
                    secondaryBlue,
                    () => _navigateToTeamList(context),
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    context,
                    'Gestión de Credenciales',
                    'Cambio de contraseñas y reseteo de accesos.',
                    Icons.password_rounded,
                    const Color(0xFF455A64),
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Acción disponible seleccionando al miembro en "Ver Mi Equipo"'))
                      );
                    },
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_alt_rounded, color: Colors.white, size: 14),
              const SizedBox(width: 6),
              Text(
                'RECURSOS HUMANOS',
                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Administración',
          style: TextStyle(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.w500, letterSpacing: -0.2),
        ),
        Text(
          'Gestión de Equipo',
          style: TextStyle(
            fontSize: 28, 
            fontWeight: FontWeight.w900, 
            color: Colors.white,
            letterSpacing: -1.0,
            shadows: [
              Shadow(color: Colors.black.withOpacity(0.1), offset: const Offset(0, 4), blurRadius: 8)
            ]
          ),
        ),
      ],
    );
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

  Widget _buildRoleCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, 8)),
        ],
        border: Border.all(color: color.withOpacity(0.05), width: 1),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1A237E))),
          Text(title.toUpperCase(), style: TextStyle(color: Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
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
}
