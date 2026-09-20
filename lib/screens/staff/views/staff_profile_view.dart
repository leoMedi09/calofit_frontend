import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../services/staff_cache.dart';
import '../../../widgets/app_loading.dart';

class StaffProfileGuard {
  const StaffProfileGuard._();

  static bool sucio = false;

  static Future<bool> confirmarSalida(BuildContext context) async {
    final descartar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('¿Salir sin guardar?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Modificaste tu perfil y los cambios aún no se guardaron. Si sales, se perderán.'),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Seguir editando', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Descartar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return descartar ?? false;
  }
}

class StaffProfileView extends StatefulWidget {
  final bool showBackButton;
  const StaffProfileView({super.key, this.showBackButton = true});

  @override
  State<StaffProfileView> createState() => _StaffProfileViewState();
}

class _StaffProfileViewState extends State<StaffProfileView> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _profileData;
  bool _isSaving = false;
  bool _cargando = true;
  bool _ultimoSucio = false;
  Map<String, String> _orig = {};

  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNamePaternalController = TextEditingController();
  final _lastNameMaternalController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _profileData = StaffCache.leer<Map<String, dynamic>>('perfil', auth.userId);
    _cargando = _profileData == null;
    _initControllers(auth);
    for (final c in [
      _firstNameController,
      _lastNamePaternalController,
      _lastNameMaternalController,
      _emailController
    ]) {
      c.addListener(_actualizarSucio);
    }
    _loadProfile();
  }

  bool get _sucio =>
      _firstNameController.text.trim() != _orig['n'] ||
      _lastNamePaternalController.text.trim() != _orig['p'] ||
      _lastNameMaternalController.text.trim() != _orig['m'] ||
      _emailController.text.trim() != _orig['e'];

  void _actualizarSucio() {
    final s = _sucio;
    StaffProfileGuard.sucio = s;
    if (s != _ultimoSucio) {
      _ultimoSucio = s;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    StaffProfileGuard.sucio = false;
    _firstNameController.dispose();
    _lastNamePaternalController.dispose();
    _lastNameMaternalController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null) return;
    try {
      final data = await _apiService.getStaffProfile(auth.token!);
      StaffCache.guardar('perfil', auth.userId, data);
      if (!mounted) return;
      setState(() {
        _profileData = data;
        _cargando = false;
        if (!_sucio) _initControllers(auth);
      });
    } catch (_) {
      if (mounted && _cargando) setState(() => _cargando = false);
    }
  }

  void _initControllers(AuthProvider auth) {
    final identidad = _profileData?['identidad'] as Map<String, dynamic>?;
    final n = (identidad?['nombres'] ?? auth.userName ?? '').toString();
    final p = (identidad?['apellido_paterno'] ?? '').toString();
    final m = (identidad?['apellido_materno'] ?? '').toString();
    final e = (identidad?['email'] ?? auth.userEmail ?? '').toString();
    _orig = {'n': n.trim(), 'p': p.trim(), 'm': m.trim(), 'e': e.trim()};
    _firstNameController.text = n;
    _lastNamePaternalController.text = p;
    _lastNameMaternalController.text = m;
    _emailController.text = e;
  }

  Future<void> _guardarPerfil() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null) return;

    setState(() => _isSaving = true);
    try {
      final data = await _apiService.updateMyStaffProfile({
        'first_name': _firstNameController.text.trim(),
        'last_name_paternal': _lastNamePaternalController.text.trim(),
        'last_name_maternal': _lastNameMaternalController.text.trim(),
        'email': _emailController.text.trim(),
      }, auth.token!);

      StaffCache.guardar('perfil', auth.userId, data);
      await auth.updateUserName(_firstNameController.text.trim());
      if (!mounted) return;
      setState(() {
        _profileData = data;
        _isSaving = false;
        _initControllers(auth);
      });
      _actualizarSucio();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado correctamente'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red),
      );
    }
  }

  String _roleLabel(String? role) {
    final r = (role ?? '').toLowerCase();
    if (r.contains('nutri')) return 'Nutricionista';
    if (r.contains('admin')) return 'Administrador';
    if (r.contains('coach') || r.contains('entrenador') || r.contains('train')) return 'Entrenador';
    return role ?? 'Staff';
  }

  String _roleTag(String? role) {
    final r = (role ?? '').toLowerCase();
    if (r.contains('nutri')) return 'NUTRICIÓN';
    if (r.contains('admin')) return 'ADMINISTRACIÓN';
    if (r.contains('coach') || r.contains('entrenador') || r.contains('train')) return 'ENTRENAMIENTO';
    return 'STAFF';
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final identidad = _profileData?['identidad'] as Map<String, dynamic>?;
    final String firstName = identidad?['nombres'] ?? auth.userName ?? '';
    final String lastPaternal = identidad?['apellido_paterno'] ?? '';
    final String fullName = [firstName, lastPaternal].where((s) => s.isNotEmpty).join(' ').trim();
    final String displayName = fullName.isNotEmpty ? fullName : 'Usuario';
    final String email = identidad?['email'] ?? auth.userEmail ?? '';
    final String role = auth.userRole ?? '';
    final String inicial = firstName.isNotEmpty ? firstName.substring(0, 1).toUpperCase() : 'U';

    return PopScope(
      canPop: !_sucio,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final salir = await StaffProfileGuard.confirmarSalida(context);
        if (salir && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            if (widget.showBackButton)
                              IconButton(
                                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                                onPressed: () => Navigator.pop(context),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -50,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: AppSkeleton(
                          loading: _cargando,
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.white,
                            child: Text(
                              inicial,
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 60),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(color: Colors.blue.shade50),
                  ),
                  child: AppSkeleton(
                    loading: _cargando,
                    child: Column(
                      children: [
                        Text(
                          displayName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryDark,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildBadge(_roleLabel(role).toUpperCase()),
                            _buildBadge(_roleTag(role)),
                            _buildBadge('WORLD LIGHT'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: AppSkeleton(
                    loading: _cargando,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Información Personal'),
                        _buildTextField(_firstNameController, 'Nombre', Icons.person_outline),
                        _buildTextField(_lastNamePaternalController, 'Apellido Paterno', Icons.person_outline),
                        _buildTextField(_lastNameMaternalController, 'Apellido Materno', Icons.person_outline),
                        _buildTextField(
                          _emailController,
                          'Correo electrónico',
                          Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Requerido';
                            final regex = RegExp(r'^[\w\.\-]+@[\w\-]+\.[\w\.\-]+$');
                            if (!regex.hasMatch(v.trim())) return 'Correo inválido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildSectionTitle('Cuenta'),
                        _buildReadOnlyField('Rol del sistema', Icons.work_outline, _roleLabel(role)),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: (_isSaving || !_sucio) ? null : _guardarPerfil,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 8,
                              shadowColor: AppColors.primary.withOpacity(0.5),
                            ),
                            child: _isSaving
                                ? const AppButtonLoader()
                                : const Text(
                                    'GUARDAR CAMBIOS',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton.icon(
                            onPressed: () => _showLogoutDialog(context, auth),
                            icon: const Icon(Icons.logout_rounded, size: 20),
                            label: const Text(
                              'CERRAR SESIÓN',
                              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Color(0xFFFFEBEE), width: 1.5),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blue.shade300),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      );

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: _decoration(label, icon),
        validator: validator ?? (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
      ),
    );
  }

  Widget _buildReadOnlyField(String label, IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        key: ValueKey(value),
        initialValue: value,
        readOnly: true,
        enabled: false,
        decoration: _decoration(label, icon),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF455A64)),
      ),
    );
  }

  Widget _buildBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: const TextStyle(color: AppColors.primaryDark, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('¿Cerrar Sesión?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Se cerrará tu sesión y volverás a la pantalla de acceso.'),
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
