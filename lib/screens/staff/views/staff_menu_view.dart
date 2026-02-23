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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Menú Principal', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF263238))),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          _buildUserInfoCard(authProvider),
          const SizedBox(height: 32),
          
          if (isAdmin) ...[
            _buildSectionTitle('ADMINISTRACIÓN'),
            const SizedBox(height: 12),
            _buildMenuItem(
              context,
              'Gestión de Equipo',
              'Registrar y administrar personal del staff.',
              Icons.people_alt_rounded,
              const Color(0xFF1E88E5),
              () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TeamManagementView())),
            ),
            const SizedBox(height: 12),
            _buildMenuItem(
              context,
              'Auditoría del Sistema',
              'Ver historial de acciones administrativas.',
              Icons.history_toggle_off_rounded,
              const Color(0xFF455A64),
              () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AuditView())),
            ),
            const SizedBox(height: 32),
          ],

          _buildSectionTitle('MI CUENTA'),
          const SizedBox(height: 12),
          _buildMenuItem(
            context,
            'Mi Perfil',
            'Configurar datos personales y biografía.',
            Icons.person_outline_rounded,
            const Color(0xFF7B1FA2),
            () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StaffProfileView())),
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            context,
            'Seguridad',
            'Cambiar contraseña y accesos.',
            Icons.lock_outline_rounded,
            const Color(0xFFF57C00),
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Función disponible en el detalle de Mi Perfil'))
              );
            },
          ),
          const SizedBox(height: 48),
          
          ElevatedButton.icon(
            onPressed: () async {
              await authProvider.logout();
              if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Cerrar Sesión', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[50],
              foregroundColor: Colors.red[700],
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildUserInfoCard(AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFF1E88E5).withOpacity(0.1),
            child: Text(
              auth.userName?.substring(0, 1).toUpperCase() ?? 'U',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Color(0xFF1E88E5)),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  auth.userName ?? 'Usuario',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF263238)),
                ),
                Text(
                  auth.userRole ?? 'Staff',
                  style: TextStyle(fontSize: 14, color: Colors.blue[700], fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12, 
        fontWeight: FontWeight.w900, 
        letterSpacing: 1.5, 
        color: Colors.blueGrey
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withOpacity(0.01)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF263238))),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }
}
