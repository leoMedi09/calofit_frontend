import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import 'team_management_view.dart';
import 'audit_view.dart';
import 'staff_profile_view.dart';

class StaffMenuView extends StatelessWidget {
  const StaffMenuView({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final String userRole = (authProvider.userRole ?? 'STAFF').toUpperCase();
    final bool isAdmin = userRole.contains('ADMIN');

    // Colores Premium
    const Color vIndigo = Color(0xFF1A237E);
    const Color vBlue = Color(0xFF1E88E5);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: CustomScrollView(
        slivers: [
          // Elegant Header
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
              title: const Text(
                'Panel de Control', 
                style: TextStyle(
                  color: Color(0xFF1A237E), 
                  fontWeight: FontWeight.w900, 
                  fontSize: 20,
                  letterSpacing: -0.5
                )
              ),
              background: Container(color: Colors.white),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF1A237E)),
                onPressed: () {},
              ),
              const SizedBox(width: 8),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildUserInfoCard(authProvider),
                const SizedBox(height: 32),
                
                if (isAdmin) ...[
                  _buildSectionHeader('GESTIÓN ADMINISTRATIVA'),
                  const SizedBox(height: 16),
                  _buildMenuCard(
                    context,
                    'Gestión de Equipo',
                    'Administra roles y accesos del personal.',
                    Icons.groups_rounded,
                    vBlue,
                    () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TeamManagementView())),
                  ),
                  const SizedBox(height: 16),
                  _buildMenuCard(
                    context,
                    'Registros de Auditoría',
                    'Monitoreo de actividad del sistema.',
                    Icons.security_rounded,
                    const Color(0xFF455A64),
                    () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AuditView())),
                  ),
                  const SizedBox(height: 32),
                ],

                _buildSectionHeader('CONFIGURACIÓN PERSONAL'),
                const SizedBox(height: 16),
                _buildMenuCard(
                  context,
                  'Mi Cuenta',
                  'Edita tu perfil, foto y biografía.',
                  Icons.account_circle_rounded,
                  vIndigo,
                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StaffProfileView())),
                ),
                const SizedBox(height: 16),
                _buildMenuCard(
                  context,
                  'Seguridad Avanzada',
                  'Cambio de llaves y autenticación.',
                  Icons.vpn_key_rounded,
                  const Color(0xFFF57C00),
                  () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const StaffProfileView()));
                  },
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoCard(AuthProvider auth) {
    final String? photoUrl = auth.profilePictureUrl;
    final String initials = (auth.userName ?? 'U').substring(0, 1).toUpperCase();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A237E).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Hero(
            tag: 'profile_pic',
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white24),
              child: CircleAvatar(
                radius: 35,
                backgroundColor: Colors.white,
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null 
                  ? Text(initials, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 28, color: Color(0xFF1A237E)))
                  : null,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bienvenido de nuevo,',
                  style: TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500),
                ),
                Text(
                  auth.userName ?? 'Usuario',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    (auth.userRole ?? 'Staff').toUpperCase(),
                    style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12, 
          fontWeight: FontWeight.w900, 
          letterSpacing: 1.5, 
          color: Color(0xFF7986CB)
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title, 
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1A237E), letterSpacing: -0.3)
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle, 
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500)
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.withOpacity(0.3), size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
