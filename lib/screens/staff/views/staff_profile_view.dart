import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../providers/auth_provider.dart';

class StaffProfileView extends StatefulWidget {
  const StaffProfileView({super.key});

  @override
  State<StaffProfileView> createState() => _StaffProfileViewState();
}

class _StaffProfileViewState extends State<StaffProfileView> {
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickAndUploadImage(AuthProvider authProvider) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => _isUploading = true);

      await authProvider.uploadProfilePicture(image.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Foto de perfil actualizada'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al subir imagen: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final String? photoUrl = authProvider.profilePictureUrl;
    final String initials = (authProvider.userName ?? '?').substring(0, 1).toUpperCase();

    // Colores Premium
    const Color vIndigo = Color(0xFF1A237E);
    const Color vBlue = Color(0xFF1E88E5);
    const Color vCyan = Color(0xFF00ACC1);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
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
                      colors: [vIndigo, vBlue, vCyan],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(50),
                      bottomRight: Radius.circular(50),
                    ),
                  ),
                ),
                // Botón Atrás
                Positioned(
                  top: 50, // Ajustado para safe area aproximado
                  left: 20,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                // Botón Atrás (opcional si es necesario)
                
                // Contenido del Perfil (Glassmorphism effect simulated)
                Positioned(
                  top: 70,
                  left: 24,
                  right: 24,
                  child: Column(
                    children: [
                      // Avatar con botón de editar
                      Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: Hero(
                              tag: 'profile_pic',
                              child: CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage: photoUrl != null 
                                  ? NetworkImage(photoUrl) 
                                  : null,
                                child: photoUrl == null 
                                  ? Text(initials, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: vIndigo))
                                  : null,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _isUploading ? null : () => _pickAndUploadImage(authProvider),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: vBlue,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: _isUploading 
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
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
                        (authProvider.userRole ?? 'Especialista').toUpperCase(),
                        style: TextStyle(
                          fontSize: 14, 
                          fontWeight: FontWeight.w600, 
                          color: Colors.white.withOpacity(0.9),
                          letterSpacing: 2.0
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Chips de especialidad (Simulados por ahora para el premium feel)
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
                  _buildProfileTile(Icons.phone_rounded, 'Teléfono', '+51 987 654 321'), // Simulado
                  _buildProfileTile(Icons.work_rounded, 'Departamento', 'Wellness & Nutrition'),
                ]),
                const SizedBox(height: 24),
                _buildSectionTitle('Ajustes y Seguridad'),
                const SizedBox(height: 12),
                _buildInfoCard([
                  if (authProvider.userRole == 'Administrador')
                    _buildActionTile(Icons.lock_reset_rounded, 'Actualizar Contraseña', () {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Próximamente...')));
                    }),
                  _buildActionTile(Icons.language_rounded, 'Idioma', () {}),
                ]),
                const SizedBox(height: 32),
                
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
          color: Color(0xFF3949AB),
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
        child: Icon(icon, color: const Color(0xFF3949AB), size: 22),
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
        child: Icon(icon, color: const Color(0xFF3949AB), size: 22),
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
