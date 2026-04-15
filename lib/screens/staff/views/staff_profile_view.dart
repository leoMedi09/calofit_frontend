import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import 'team_management_view.dart';
import 'audit_view.dart';

class StaffProfileView extends StatefulWidget {
  final bool showBackButton;
  const StaffProfileView({super.key, this.showBackButton = true});

  @override
  State<StaffProfileView> createState() => _StaffProfileViewState();
}

class _StaffProfileViewState extends State<StaffProfileView> {
  // Colores Originales (Azul Calofit)
  static const Color vNavy = Color(0xFF1E88E5); // Azul Primario
  static const Color vNavyDark = Color(0xFF1565C0); // Azul Secundario

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final String initials = (authProvider.userName ?? '?').substring(0, 1).toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      body: CustomScrollView(
        slivers: [
          // Header con Gradiente y Perfil
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Fondo Gradiente
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
                // Botón Atrás
                if (widget.showBackButton)
                  Positioned(
                    top: 50,
                    left: 20,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                
                // Contenido del Perfil
                Positioned(
                  top: 70,
                  left: 24,
                  right: 24,
                  child: Column(
                    children: [
                      // Avatar Simplificado (Solo Iniciales)
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
                              letterSpacing: -1.0
                            )
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        authProvider.userName ?? 'Usuario',
                        style: const TextStyle(
                          fontSize: 28, 
                          fontWeight: FontWeight.w900, 
                          color: Colors.white,
                          letterSpacing: -0.5
                        ),
                      ),
                      Text(
                        (authProvider.userRole ?? 'Perfil').toUpperCase(),
                        style: TextStyle(
                          fontSize: 14, 
                          fontWeight: FontWeight.w600, 
                          color: Colors.white.withOpacity(0.9),
                          letterSpacing: 2.0
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Chips de especialidad
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildTag('EXPERT'),
                          const SizedBox(width: 8),
                          _buildTag('STAFF'),
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

          // Espaciador para el contenido posicionado
          const SliverToBoxAdapter(child: SizedBox(height: 120)),

          // Secciones de información
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSectionTitle('Información de Contacto'),
                const SizedBox(height: 12),
                _buildInfoCard([
                  _buildProfileTile(Icons.email_rounded, 'Correo Electrónico', authProvider.userEmail ?? ''),
                  _buildProfileTile(Icons.phone_rounded, 'Teléfono', '+51 987 654 321'),
                  _buildProfileTile(Icons.work_rounded, 'Departamento', 'Wellness & Nutrition'),
                ]),
                const SizedBox(height: 24),


                const SizedBox(height: 24),
                
                // Botón Cerrar Sesión
                Container(
                  width: double.infinity,
                  height: 60,
                  margin: const EdgeInsets.only(bottom: 40),
                  child: ElevatedButton(
                    onPressed: () => _showLogoutDialog(context, authProvider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Color(0xFFFFEBEE), width: 1),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text(
                      'CERRAR SESIÓN',
                      style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2),
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
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
      title: Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
    );
  }

  Widget _buildActionTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F4FF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: vNavy, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('¿Cerrar Sesión?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Se cerrará tu sesión administrativa y volverás a la pantalla de acceso.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCELAR', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              await authProvider.logout();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('SALIR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
