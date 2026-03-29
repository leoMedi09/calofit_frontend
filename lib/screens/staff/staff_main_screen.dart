import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'views/dashboard_view.dart';
import 'views/audit_view.dart';
import 'views/assistant_copilot_view.dart';
import 'views/staff_profile_view.dart';
import 'views/patient_list_view.dart';
import 'views/staff_menu_view.dart';
import 'views/team_list_view.dart';

class StaffMainScreen extends StatefulWidget {
  const StaffMainScreen({super.key});

  @override
  State<StaffMainScreen> createState() => _StaffMainScreenState();
}

class _StaffMainScreenState extends State<StaffMainScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.showWelcomeMessage) {
        _showToast(
          context,
          "¡Bienvenido Staff, ${authProvider.userName}! 🛠️",
          const Color(0xFF2E7D32) // Verde Premium
        );
        authProvider.consumeWelcomeMessage();
      }
    });
  }

  void _showToast(BuildContext context, String message, Color color) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 100), // Flotando sobre el contenido inferior
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.95),
                borderRadius: BorderRadius.circular(30), // Forma de píldora
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min, // Ajuste al contenido
                children: [
                  const Icon(Icons.stars_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white, 
                        fontWeight: FontWeight.w800, 
                        fontSize: 14,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 4), () {
      overlayEntry.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final String userRole = (authProvider.userRole ?? 'STAFF').toUpperCase();
    final Color primaryBlue = const Color(0xFF1E88E5);

    // Definición de todas las posibles vistas
    final Map<String, Map<String, dynamic>> allSections = {
      'dashboard': {
        'view': DashboardView(onNavigate: (index) => setState(() => _selectedIndex = index)),
        'item': const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined), 
          activeIcon: Icon(Icons.dashboard_rounded),
          label: 'Dashboard'
        ),
      },
      'patients': {
        'view': const PatientListView(),
        'item': const BottomNavigationBarItem(
          icon: Icon(Icons.assignment_ind_outlined), 
          activeIcon: Icon(Icons.assignment_ind_rounded),
          label: 'Pacientes'
        ),
      },
      'assistant': {
        'view': const AssistantCopilotView(),
        'item': const BottomNavigationBarItem(
          icon: Icon(Icons.psychology_outlined), 
          activeIcon: Icon(Icons.psychology_rounded),
          label: 'Asistente'
        ),
      },
      'menu': {
        'view': const StaffMenuView(),
        'item': const BottomNavigationBarItem(
          icon: Icon(Icons.grid_view_outlined), 
          activeIcon: Icon(Icons.grid_view_rounded),
          label: 'Menú'
        ),
      },
      'team': {
        'view': const TeamListView(),
        'item': const BottomNavigationBarItem(
          icon: Icon(Icons.people_alt_outlined), 
          activeIcon: Icon(Icons.people_alt_rounded),
          label: 'Equipo'
        ),
      },
      'audit': {
        'view': const AuditView(),
        'item': const BottomNavigationBarItem(
          icon: Icon(Icons.history_toggle_off_outlined), 
          activeIcon: Icon(Icons.history_toggle_off_rounded),
          label: 'Auditoría'
        ),
      },
      'profile': {
        'view': const StaffProfileView(showBackButton: false),
        'item': const BottomNavigationBarItem(
          icon: Icon(Icons.person_outline_rounded), 
          activeIcon: Icon(Icons.person_rounded),
          label: 'Perfil'
        ),
      },
    };

    // Filtrar secciones por rol
    List<String> activeSectionKeys;
    if (userRole.contains('ADMIN')) {
      activeSectionKeys = ['dashboard', 'team', 'patients', 'profile'];
    } else if (userRole.contains('NUTRI')) {
      activeSectionKeys = ['dashboard', 'team', 'patients', 'profile']; 
    } else {
      activeSectionKeys = ['dashboard', 'profile'];
    }

    final List<Widget> filteredViews = activeSectionKeys.map((k) => allSections[k]!['view'] as Widget).toList();
    final List<BottomNavigationBarItem> filteredItems = activeSectionKeys.map((k) => allSections[k]!['item'] as BottomNavigationBarItem).toList();

    // Asegurar que el índice no se desborde si el rol cambia
    if (_selectedIndex >= filteredViews.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: null,
      body: filteredViews[_selectedIndex],
      floatingActionButton: (activeSectionKeys.contains('assistant') && activeSectionKeys[_selectedIndex] != 'assistant')
          ? FloatingActionButton(
              onPressed: () {
                int assistantIndex = activeSectionKeys.indexOf('assistant');
                if (assistantIndex != -1) {
                  setState(() => _selectedIndex = assistantIndex);
                }
              },
              backgroundColor: primaryBlue,
              elevation: 4,
              child: const Icon(Icons.auto_awesome, color: Colors.white),
            ) 
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        backgroundColor: Colors.white,
        destinations: filteredItems.map((item) {
          return NavigationDestination(
            icon: item.icon,
            selectedIcon: item.activeIcon,
            label: item.label ?? '',
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLogoutButton(AuthProvider authProvider) {
    return Container(
      margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: const Icon(Icons.logout_rounded, size: 20, color: Color(0xFF1A237E)),
        onPressed: () async {
          await authProvider.logout();
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/login');
          }
        },
      ),
    );
  }

  Color _getRoleColor(String role) {
    if (role == 'ADMIN' || role == 'STAFF') return const Color(0xFF1E88E5);
    if (role == 'NUTRI') return Colors.green.shade700;
    if (role == 'COACH') return Colors.orange.shade700;
    return const Color(0xFF1E88E5);
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0: return 'Dashboard';
      case 1: return 'Gestión de Equipo';
      case 2: return 'Auditoría del Sistema';
      case 3: return 'Asistente IA';
      case 4: return 'Perfil';
      default: return 'CaloFit';
    }
  }
}
