import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../services/url_service.dart';
import '../../../models/user.dart';

class TeamListView extends StatefulWidget {
  const TeamListView({super.key});

  @override
  State<TeamListView> createState() => _TeamListViewState();
}

class _TeamListViewState extends State<TeamListView> {
  final ApiService _apiService = ApiService();
  List<User> _allMembers = [];
  List<User> _filteredMembers = [];
  String _searchQuery = "";
  String _selectedRole = "all";

  @override
  void initState() {
    super.initState();
    _loadTeam();
  }

  Future<void> _loadTeam() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final List<User> team = await _apiService.getUsers(authProvider.token ?? '');

      // Asegurar que el Admin actual aparezca en la lista
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

      setState(() {
        _allMembers = team;
        _applyFilters();
      });
    } catch (e) {
      debugPrint('Error loading team: $e');
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredMembers = _allMembers.where((member) {
        final matchesSearch = member.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            member.email.toLowerCase().contains(_searchQuery.toLowerCase());

        bool matchesRole = true;
        if (_selectedRole == 'nutritionist') {
          matchesRole = member.roleName.toLowerCase().contains('nutri');
        } else if (_selectedRole == 'coach') {
          matchesRole = member.roleName.toLowerCase().contains('coach') ||
              member.roleName.toLowerCase().contains('train');
        } else if (_selectedRole == 'admin') {
          matchesRole = member.roleName.toLowerCase().contains('admin');
        }

        return matchesSearch && matchesRole;
      }).toList();
    });
  }

  void _refreshTeam() {
    _loadTeam();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => _refreshTeam(),
        child: Column(
          children: [
            _buildSearchBar(),
            _buildRoleFilters(),
            Expanded(
              child: _allMembers.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredMembers.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                          itemCount: _filteredMembers.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildMemberCard(_filteredMembers[index]),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[100]!, width: 1)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: TextField(
          onChanged: (value) {
            _searchQuery = value;
            _applyFilters();
          },
          decoration: InputDecoration(
            hintText: 'Buscar por nombre o correo...',
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF1A237E), size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
      child: Row(
        children: [
          _buildFilterChip('Todos', 'all', Icons.group_rounded),
          const SizedBox(width: 10),
          _buildFilterChip('Nutris', 'nutritionist', Icons.restaurant_menu_rounded),
          const SizedBox(width: 10),
          _buildFilterChip('Coaches', 'coach', Icons.fitness_center_rounded),
          const SizedBox(width: 10),
          _buildFilterChip('Admins', 'admin', Icons.admin_panel_settings_rounded),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    bool isSelected = _selectedRole == value;
    Color activeColor = const Color(0xFF1E88E5);

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedRole = value;
          _applyFilters();
        });
      },
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey.shade600),
      backgroundColor: Colors.grey.shade100,
      selectedColor: activeColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
        fontSize: 13,
        letterSpacing: -0.2,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide.none,
      checkmarkColor: Colors.white,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Sin resultados',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade400),
          ),
          Text('Intenta con otros términos o filtros.', style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildMemberCard(User member) {
    Color roleColor = Colors.grey;
    IconData roleIcon = Icons.help_outline;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (member.roleName.toLowerCase().contains('nutri')) {
      roleColor = Colors.green.shade600;
      roleIcon = Icons.restaurant_menu_rounded;
    } else if (member.roleName.toLowerCase().contains('admin')) {
      roleColor = Colors.indigo.shade700;
      roleIcon = Icons.admin_panel_settings_rounded;
    } else if (member.roleName.toLowerCase().contains('coach') || member.roleName.toLowerCase().contains('train')) {
      roleColor = Colors.orange.shade700;
      roleIcon = Icons.fitness_center_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: roleColor.withOpacity(0.1),
                backgroundImage: member.profilePictureUrl != null && member.profilePictureUrl!.isNotEmpty
                    ? NetworkImage(UrlService.formatImageUrl(member.profilePictureUrl))
                    : null,
                child: member.profilePictureUrl == null || member.profilePictureUrl!.isEmpty
                    ? Text(member.firstName.substring(0, 1).toUpperCase(),
                        style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 20))
                    : null,
              ),
              Container(
                height: 16,
                width: 16,
                decoration: BoxDecoration(
                  color: member.isActive ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1A237E))),
                Text(member.email,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: roleColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(roleIcon, size: 12, color: roleColor),
                          const SizedBox(width: 4),
                          Text(member.roleName.toUpperCase(),
                              style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                    if (member.pacientesCount != null && member.pacientesCount! > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration:
                            BoxDecoration(color: roleColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people_outline, size: 12, color: Colors.blueGrey),
                            const SizedBox(width: 4),
                            Text('${member.pacientesCount} PACIENTES',
                                style: const TextStyle(color: Colors.blueGrey, fontSize: 10, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (authProvider.userId != member.id)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_horiz_rounded, color: Colors.grey.shade400),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              onSelected: (value) => _handleMenuAction(value, member),
              itemBuilder: (context) => _buildMenuItems(member),
            ),
        ],
      ),
    );
  }

  void _handleMenuAction(String value, User member) {
    if (value == 'password') {
      _showChangePasswordDialog(context, member);
    } else if (value == 'edit') {
      _showEditStaffDialog(context, member);
    } else if (value == 'status') {
      _showToggleStatusDialog(context, member);
    } else if (value == 'delete') {
      _showDeleteStaffDialog(context, member);
    }
  }

  List<PopupMenuEntry<String>> _buildMenuItems(User member) {
    return [
      PopupMenuItem(
        value: 'edit',
        child: Row(
          children: [
            Icon(Icons.edit_outlined, size: 20, color: Colors.blue.shade700),
            const SizedBox(width: 12),
            const Text('Editar Perfil'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'password',
        child: Row(
          children: [
            Icon(Icons.key_outlined, size: 20),
            SizedBox(width: 12),
            Text('Nueva Contraseña'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'status',
        child: Row(
          children: [
            Icon(member.isActive ? Icons.person_off_outlined : Icons.person_add_outlined,
                size: 20, color: member.isActive ? Colors.orange : Colors.green),
            const SizedBox(width: 12),
            Text(member.isActive ? 'Dar de Baja' : 'Reactivar'),
          ],
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
            const SizedBox(width: 12),
            const Text('Eliminar Personal', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ];
  }

  void _showChangePasswordDialog(BuildContext context, User member) {
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();
    bool isPasswordVisible = false;
    bool isConfirmVisible = false;
    bool isLoading = false;

    InputDecoration buildInputDecoration(String label, IconData icon, bool isObscure, VoidCallback toggleVisibility) {
      return InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF1E88E5)),
        suffixIcon: IconButton(
          icon: Icon(isObscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.grey.shade500, size: 20),
          onPressed: toggleVisibility,
          splashRadius: 20,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 2)),
      );
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF1E88E5).withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.password_rounded, color: Color(0xFF1E88E5)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Nueva Contraseña:\n${member.firstName}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1A237E), fontSize: 18, height: 1.1, letterSpacing: -0.3)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Establece las nuevas credenciales de acceso para este miembro del equipo.', style: TextStyle(fontSize: 13, color: Colors.grey), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              TextField(
                controller: passwordController,
                obscureText: !isPasswordVisible,
                decoration: buildInputDecoration('Nueva Contraseña', Icons.lock_outline_rounded, !isPasswordVisible, () {
                  setDialogState(() => isPasswordVisible = !isPasswordVisible);
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: !isConfirmVisible,
                decoration: buildInputDecoration('Confirmar Contraseña', Icons.enhanced_encryption_outlined, !isConfirmVisible, () {
                  setDialogState(() => isConfirmVisible = !isConfirmVisible);
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade600,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final password = passwordController.text.trim();
                      final confirm = confirmPasswordController.text.trim();

                      if (password.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mínimo 6 caracteres')));
                        return;
                      }

                      if (password != confirm) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Las contraseñas no coinciden')));
                        return;
                      }

                      setDialogState(() => isLoading = true);
                      try {
                        final authProvider = Provider.of<AuthProvider>(context, listen: false);
                        await _apiService.updateStaffPassword(member.id, password, authProvider.token ?? '');
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contraseña actualizada correctamente'), backgroundColor: Colors.green));
                        }
                      } catch (e) {
                        setDialogState(() => isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5), 
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) 
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Actualizar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(width: 8),
                      Icon(Icons.check_circle_rounded, size: 18, color: Colors.white.withOpacity(0.9)),
                    ],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditStaffDialog(BuildContext context, User member) {
    final TextEditingController firstNameController = TextEditingController(text: member.firstName);
    final TextEditingController lastPaternalController = TextEditingController(text: member.lastNamePaternal);
    final TextEditingController lastMaternalController = TextEditingController(text: member.lastNameMaternal);
    final TextEditingController emailController = TextEditingController(text: member.email);
    
    // Simplificación de rol para el dropdown
    String currentRole = 'Nutricionista';
    if (member.roleName.toLowerCase().contains('admin')) {
      currentRole = 'Administrador';
    } else if (member.roleName.toLowerCase().contains('coach') || member.roleName.toLowerCase().contains('train')) {
      currentRole = 'Entrenador';
    }
    
    String selectedRole = currentRole;
    bool isLoading = false;

    // Decoración base para inputs premium
    InputDecoration buildInputDecoration(String label, IconData icon) {
      return InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF1E88E5)),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 2)),
      );
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF1E88E5).withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.manage_accounts_rounded, color: Color(0xFF1E88E5)),
              ),
              const SizedBox(width: 12),
              const Text('Editar Perfil', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1A237E), fontSize: 22, letterSpacing: -0.5)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Actualiza los datos del personal. Los cambios se reflejarán de inmediato.', style: TextStyle(fontSize: 13, color: Colors.grey), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  TextField(
                    controller: firstNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: buildInputDecoration('Nombres', Icons.person_outline_rounded),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: lastPaternalController,
                          textCapitalization: TextCapitalization.words,
                          decoration: buildInputDecoration('Ap. Paterno', Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: lastMaternalController,
                          textCapitalization: TextCapitalization.words,
                          decoration: buildInputDecoration('Ap. Materno', Icons.badge_outlined),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: buildInputDecoration('Correo Electrónico', Icons.email_outlined),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF1E88E5)),
                    dropdownColor: Colors.white,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A237E), fontSize: 14),
                    decoration: buildInputDecoration('Rol del Sistema', Icons.admin_panel_settings_outlined),
                    items: ['Nutricionista', 'Entrenador', 'Administrador'].map((role) {
                      return DropdownMenuItem(value: role, child: Text(role));
                    }).toList(),
                    onChanged: (value) => setDialogState(() => selectedRole = value!),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade600,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (firstNameController.text.trim().isEmpty || emailController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nombres y Correo son obligatorios')));
                        return;
                      }

                      setDialogState(() => isLoading = true);
                      try {
                        final authProvider = Provider.of<AuthProvider>(context, listen: false);
                        
                        String mappedRole = 'nutricionista';
                        if (selectedRole == 'Administrador') mappedRole = 'admin';
                        if (selectedRole == 'Entrenador') mappedRole = 'entrenador';

                        await _apiService.updateStaff(
                          member.id, 
                          {
                            'first_name': firstNameController.text.trim(),
                            'last_name_paternal': lastPaternalController.text.trim(),
                            'last_name_maternal': lastMaternalController.text.trim(),
                            'email': emailController.text.trim(),
                            'role_name': mappedRole,
                          }, 
                          authProvider.token ?? ''
                        );
                        
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil actualizado con éxito'), backgroundColor: Colors.green));
                          _refreshTeam();
                        }
                      } catch (e) {
                         setDialogState(() => isLoading = false);
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5), 
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) 
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Guardar Cambios', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(width: 8),
                      Icon(Icons.check_circle_rounded, size: 18, color: Colors.white.withOpacity(0.9)),
                    ],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _showToggleStatusDialog(BuildContext context, User member) {
    bool isLoading = false;
    final bool isDisabling = member.isActive;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Icon(isDisabling ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded, 
                   color: isDisabling ? Colors.orange : Colors.green),
              const SizedBox(width: 10),
              Text(isDisabling ? '¿Dar de baja?' : '¿Reactivar?'),
            ],
          ),
          content: Text(isDisabling 
            ? 'Suspenderá el acceso de ${member.firstName} al sistema. Podrás reactivarlo luego.'
            : 'Se restaurará el acceso de ${member.firstName} al sistema con su última contraseña o contraseña temporal.'),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      setDialogState(() => isLoading = true);
                      try {
                        final authProvider = Provider.of<AuthProvider>(context, listen: false);
                        await _apiService.updateStaffStatus(member.id, authProvider.token ?? '');
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(isDisabling ? 'Personal dado de baja' : 'Personal reactivado'), 
                            backgroundColor: isDisabling ? Colors.orange : Colors.green
                          ));
                          _refreshTeam();
                        }
                      } catch (e) {
                         setDialogState(() => isLoading = false);
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                      }
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: isDisabling ? Colors.orange : Colors.green, 
                  foregroundColor: Colors.white),
              child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(isDisabling ? 'Suspender' : 'Reactivar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteStaffDialog(BuildContext context, User member) {
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.delete_forever_rounded, color: Colors.red),
              SizedBox(width: 10),
              Text('Eliminar Personal', style: TextStyle(color: Colors.red)),
            ],
          ),
          content: Text('¿Estás seguro de eliminar permanentemente a ${member.firstName} del sistema? Esta acción no se puede deshacer y desvinculará a los pacientes a su cargo.'),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      setDialogState(() => isLoading = true);
                      try {
                        final authProvider = Provider.of<AuthProvider>(context, listen: false);
                        await _apiService.deleteStaff(member.id, authProvider.token ?? '');
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Personal eliminado permanentemente'), 
                            backgroundColor: Colors.redAccent
                          ));
                          _refreshTeam();
                        }
                      } catch (e) {
                         setDialogState(() => isLoading = false);
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red));
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Eliminar Definitivamente'),
            ),
          ],
        ),
      ),
    );
  }
}
