import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';

class StaffProfileView extends StatefulWidget {
  final bool showBackButton;
  const StaffProfileView({super.key, this.showBackButton = true});

  @override
  State<StaffProfileView> createState() => _StaffProfileViewState();
}

class _StaffProfileViewState extends State<StaffProfileView> {
  static const Color vNavy = Color(0xFF1E88E5);
  static const Color vNavyDark = Color(0xFF1565C0);

  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _profileData;
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null) return;
    try {
      final data = await _apiService.getStaffProfile(auth.token!);
      if (mounted) setState(() { _profileData = data; _loadingProfile = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  String _roleLabel(String? role) {
    switch ((role ?? '').toUpperCase()) {
      case 'NUTRI': return 'Nutricionista';
      case 'COACH': return 'Entrenador';
      case 'ADMIN': return 'Administrador';
      default: return role ?? 'Staff';
    }
  }

  String _roleTag(String? role) {
    switch ((role ?? '').toUpperCase()) {
      case 'NUTRI': return 'NUTRICIÓN';
      case 'COACH': return 'ENTRENAMIENTO';
      case 'ADMIN': return 'ADMINISTRACIÓN';
      default: return 'STAFF';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    final identidad = _profileData?['identidad'] as Map<String, dynamic>?;
    final String firstName = identidad?['nombres'] ?? auth.userName ?? '';
    final String lastPaternal = identidad?['apellido_paterno'] ?? '';
    final String lastMaternal = identidad?['apellido_materno'] ?? '';
    final String fullName = [firstName, lastPaternal, lastMaternal]
        .where((s) => s.isNotEmpty)
        .join(' ')
        .trim();
    final String displayName = fullName.isNotEmpty ? fullName : (auth.userName ?? 'Usuario');
    final String email = identidad?['email'] ?? auth.userEmail ?? '';
    final String role = auth.userRole ?? '';
    final String initials = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 340,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [vNavyDark, vNavy],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(50),
                      bottomRight: Radius.circular(50),
                    ),
                  ),
                ),
                if (widget.showBackButton)
                  Positioned(
                    top: 50,
                    left: 20,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                Positioned(
                  top: 70,
                  left: 24,
                  right: 24,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey.shade100,
                          child: Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              color: vNavy,
                              letterSpacing: -1.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        displayName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _roleLabel(role).toUpperCase(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.85),
                          letterSpacing: 2.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildTag('WORLD LIGHT'),
                          const SizedBox(width: 8),
                          _buildTag(_roleTag(role)),
                          const SizedBox(width: 8),
                          _buildTag('VERIFIED'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSectionTitle('Información Personal'),
                const SizedBox(height: 12),
                _loadingProfile
                    ? const Center(child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ))
                    : _buildInfoCard([
                        _buildProfileTile(Icons.person_rounded, 'Nombres', firstName.isNotEmpty ? firstName : '—'),
                        _buildProfileTile(Icons.badge_rounded, 'Apellido Paterno', lastPaternal.isNotEmpty ? lastPaternal : '—'),
                        _buildProfileTile(Icons.badge_outlined, 'Apellido Materno', lastMaternal.isNotEmpty ? lastMaternal : '—'),
                      ]),

                const SizedBox(height: 24),
                _buildSectionTitle('Información de Contacto'),
                const SizedBox(height: 12),
                _buildInfoCard([
                  _buildProfileTile(Icons.email_rounded, 'Correo Electrónico', email.isNotEmpty ? email : '—'),
                  _buildProfileTile(Icons.work_rounded, 'Rol del Sistema', _roleLabel(role)),
                ]),

                const SizedBox(height: 32),

                Container(
                  width: double.infinity,
                  height: 60,
                  margin: const EdgeInsets.only(bottom: 40),
                  child: ElevatedButton(
                    onPressed: () => _showLogoutDialog(context, auth),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Color(0xFFFFEBEE), width: 1),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text(
                      'CERRAR SESIÓN',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, letterSpacing: 1.2),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: vNavy,
        ),
      ),
    );
  }

  Widget _buildTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(children: children),
    );
  }

  Widget _buildProfileTile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F4FF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: vNavy, size: 22),
      ),
      title: Text(title,
          style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w600)),
      subtitle: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(subtitle,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('¿Cerrar Sesión?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            'Se cerrará tu sesión y volverás a la pantalla de acceso.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCELAR',
                style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              await authProvider.logout();
              if (context.mounted) {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('SALIR',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
