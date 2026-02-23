import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../models/user.dart';

class TeamListView extends StatefulWidget {
  const TeamListView({super.key});

  @override
  State<TeamListView> createState() => _TeamListViewState();
}

class _TeamListViewState extends State<TeamListView> {
  final ApiService _apiService = ApiService();
  late Future<List<User>> _teamFuture;
  List<User> _allMembers = [];
  List<User> _filteredMembers = [];
  String _searchQuery = "";
  String _selectedRole = "all"; // all, nutritionist, coach, admin

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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Mi Equipo', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A237E),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshTeam(),
        child: Column(
          children: [
            _buildStatsSummary(),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: TextField(
          onChanged: (value) {
            _searchQuery = value;
            _applyFilters();
          },
          decoration: InputDecoration(
            hintText: 'Buscar por nombre o correo...',
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade600),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
      child: Row(
        children: [
          _buildFilterChip('Todos', 'all', Icons.group_rounded),
          const SizedBox(width: 10),
          _buildFilterChip('Nutricionistas', 'nutritionist', Icons.restaurant_menu_rounded),
          const SizedBox(width: 10),
          _buildFilterChip('Coaches', 'coach', Icons.fitness_center_rounded),
          const SizedBox(width: 10),
          _buildFilterChip('Administradores', 'admin', Icons.admin_panel_settings_rounded),
        ],
      ),
    );
  }

  Widget _buildStatsSummary() {
    int total = _allMembers.length;
    int nutris = _allMembers.where((m) => m.roleName.toLowerCase().contains('nutri')).length;
    int coaches = _allMembers.where((m) => m.roleName.toLowerCase().contains('coach') || m.roleName.toLowerCase().contains('train')).length;
    int admins = _allMembers.where((m) => m.roleName.toLowerCase().contains('admin')).length;
    int suspended = _allMembers.where((m) => !m.isActive).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 5),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildStatCard('Total', total.toString(), Colors.grey.shade800, Icons.groups_rounded),
            _buildStatCard('Nutris', nutris.toString(), Colors.green.shade600, Icons.restaurant_rounded),
            _buildStatCard('Coaches', coaches.toString(), const Color(0xFF1E88E5), Icons.fitness_center_rounded),
            _buildStatCard('Admins', admins.toString(), Colors.indigo.shade700, Icons.admin_panel_settings_rounded),
            _buildStatCard('Bajas', suspended.toString(), Colors.red.shade600, Icons.person_off_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5)),
              Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            ],
          ),
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
          Text(
            'Intenta con otros términos o filtros.',
            style: TextStyle(color: Colors.grey.shade500),
          ),
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
    } else if (member.roleName.toLowerCase().contains('coach') || member.roleName.toLowerCase().contains('train')) {
      roleColor = const Color(0xFF1E88E5);
      roleIcon = Icons.fitness_center_rounded;
    } else if (member.roleName.toLowerCase().contains('admin')) {
      roleColor = Colors.indigo.shade700;
      roleIcon = Icons.admin_panel_settings_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: member.isActive ? roleColor : Colors.red.shade400, 
                width: 5
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: roleColor.withOpacity(0.1),
                      child: Text(
                        member.firstName.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: roleColor, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 20
                        ),
                      ),
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
                      Text(
                        member.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900, 
                          fontSize: 16,
                          letterSpacing: -0.5,
                          color: Color(0xFF1A237E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        member.email,
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: roleColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(roleIcon, size: 12, color: roleColor),
                                const SizedBox(width: 4),
                                Text(
                                  member.roleName.toUpperCase(),
                                  style: TextStyle(
                                    color: roleColor, 
                                    fontSize: 10, 
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (member.pacientesCount != null && member.pacientesCount! > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: roleColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.people_outline, size: 12, color: roleColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${member.pacientesCount} PACIENTES',
                                    style: TextStyle(
                                      color: roleColor, 
                                      fontSize: 10, 
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (!member.isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'SUSPENDIDO',
                                style: TextStyle(
                                  color: Colors.red, 
                                  fontSize: 10, 
                                  fontWeight: FontWeight.bold
                                ),
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
                  onSelected: (value) {
                    if (value == 'password') {
                      _showChangePasswordDialog(context, member);
                    } else if (value == 'edit') {
                      _showEditStaffDialog(context, member);
                    } else if (value == 'status') {
                      _showToggleStatusDialog(context, member);
                    }
                  },
                  itemBuilder: (context) => [
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
                          Icon(
                            member.isActive ? Icons.person_off_outlined : Icons.person_add_outlined, 
                            size: 20, 
                            color: member.isActive ? Colors.red : Colors.green
                          ),
                          const SizedBox(width: 12),
                          Text(member.isActive ? 'Dar de Baja' : 'Reactivar'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    ),
  );
  }

  void _showChangePasswordDialog(BuildContext context, User member) {
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();
    bool isPasswordVisible = false;
    bool isConfirmVisible = false;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Nueva Contraseña: ${member.firstName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Establece las nuevas credenciales para este miembro del equipo.'),
              const SizedBox(height: 20),
              TextField(
                controller: passwordController,
                obscureText: !isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Nueva Contraseña',
                  hintText: 'Mínimo 6 caracteres',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      isPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: Colors.grey,
                    ),
                    onPressed: () => setDialogState(() => isPasswordVisible = !isPasswordVisible),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPasswordController,
                obscureText: !isConfirmVisible,
                decoration: InputDecoration(
                  labelText: 'Confirmar Contraseña',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.enhanced_encryption_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      isConfirmVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: Colors.grey,
                    ),
                    onPressed: () => setDialogState(() => isConfirmVisible = !isConfirmVisible),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                final password = passwordController.text.trim();
                final confirm = confirmPasswordController.text.trim();

                if (password.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('La contraseña debe tener al menos 6 caracteres'))
                  );
                  return;
                }

                if (password != confirm) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⚠️ Las contraseñas no coinciden'),
                      backgroundColor: Colors.orange,
                    )
                  );
                  return;
                }

                setDialogState(() => isLoading = true);
                try {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  await _apiService.updateStaffPassword(
                    member.id, 
                    password, 
                    authProvider.token ?? ''
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Contraseña actualizada exitosamente'), backgroundColor: Colors.green)
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red)
                    );
                  }
                } finally {
                  if (mounted) setDialogState(() => isLoading = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Actualizar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditStaffDialog(BuildContext context, User member) {
    final TextEditingController firstNameController = TextEditingController(text: member.firstName);
    final TextEditingController paternalController = TextEditingController(text: member.lastNamePaternal);
    final TextEditingController maternalController = TextEditingController(text: member.lastNameMaternal);
    final TextEditingController emailController = TextEditingController(text: member.email);
    String selectedRole = member.roleName;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: Colors.blue),
              const SizedBox(width: 10),
              Text('Editar: ${member.firstName}'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildEditField(firstNameController, 'Nombre', Icons.person_outline),
                const SizedBox(height: 12),
                _buildEditField(paternalController, 'Apellido Paterno', Icons.person_outline),
                const SizedBox(height: 12),
                _buildEditField(maternalController, 'Apellido Materno', Icons.person_outline),
                const SizedBox(height: 12),
                _buildEditField(emailController, 'Correo Corporativo', Icons.email_outlined),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: ['nutritionist', 'coach', 'trainer', 'admin'].contains(selectedRole.toLowerCase()) ? selectedRole.toLowerCase() : 'coach',
                  decoration: InputDecoration(
                    labelText: 'Rol',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'nutritionist', child: Text('Nutricionista')),
                    DropdownMenuItem(value: 'coach', child: Text('Entrenador / Coach')),
                    DropdownMenuItem(value: 'trainer', child: Text('Instructor')),
                    DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                  ],
                  onChanged: (val) => selectedRole = val ?? selectedRole,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (firstNameController.text.isEmpty || emailController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nombre y Email son obligatorios')));
                  return;
                }

                setDialogState(() => isLoading = true);
                try {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  final updateData = {
                    'first_name': firstNameController.text.trim(),
                    'last_name_paternal': paternalController.text.trim(),
                    'last_name_maternal': maternalController.text.trim(),
                    'email': emailController.text.trim(),
                    'role_name': selectedRole,
                    'role_id': selectedRole == 'nutritionist' ? 2 : 3,
                  };

                  await _apiService.updateStaff(member.id, updateData, authProvider.token ?? '');
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    setState(() => _refreshTeam());
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Datos actualizados exitosamente'), backgroundColor: Colors.green)
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red)
                    );
                  }
                } finally {
                  if (mounted) setDialogState(() => isLoading = false);
                }
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
              ),
              child: isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showToggleStatusDialog(BuildContext context, User member) {
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(member.isActive ? '¿Dar de baja?' : '¿Reactivar cuenta?'),
          content: Text(
            member.isActive 
              ? 'Esta acción suspenderá el acceso de ${member.firstName} al sistema. Podrás reactivarlo más tarde.'
              : 'Se restaurará el acceso de ${member.firstName} al sistema de administración.'
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                setDialogState(() => isLoading = true);
                try {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  await _apiService.updateStaffStatus(member.id, authProvider.token ?? '');
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    setState(() => _refreshTeam());
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(member.isActive ? '✅ Usuario suspendido' : '✅ Usuario reactivado'),
                        backgroundColor: member.isActive ? Colors.red.shade700 : Colors.green.shade700
                      )
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red)
                    );
                  }
                } finally {
                  if (mounted) setDialogState(() => isLoading = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: member.isActive ? Colors.red.shade700 : Colors.green.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(member.isActive ? 'Confirmar Baja' : 'Reactivar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditField(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: Icon(icon),
      ),
    );
  }
}
