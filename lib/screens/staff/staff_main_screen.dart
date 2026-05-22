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
import 'views/trainer_clients_view.dart'; // ✅ Restaurado

class StaffMainScreen extends StatefulWidget {
  const StaffMainScreen({super.key});

  @override
  State<StaffMainScreen> createState() => _StaffMainScreenState();
}

class _StaffMainScreenState extends State<StaffMainScreen> {
  int _selectedIndex = 0;

  bool _isEntrenador(String role) =>
      role.contains('COACH') || role.contains('ENTRENADOR');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.showWelcomeMessage) {
        _showToast(context, "¡Bienvenido Staff, ${authProvider.userName}! 🛠️",
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
          padding: const EdgeInsets.only(
              bottom: 100), // Flotando sobre el contenido inferior
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
                  const Icon(Icons.stars_rounded,
                      color: Colors.white, size: 22),
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
        'view': DashboardView(
            onNavigate: (index) => setState(() => _selectedIndex = index)),
        'item': const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard'),
      },
      'patients': {
        'view': _isEntrenador(userRole) ? const TrainerClientsView() : const PatientListView(),
        'item': BottomNavigationBarItem(
          icon: Icon(_isEntrenador(userRole) ? Icons.fitness_center_outlined : Icons.assignment_ind_outlined),
          activeIcon: Icon(_isEntrenador(userRole) ? Icons.fitness_center_rounded : Icons.assignment_ind_rounded),
          label: _isEntrenador(userRole) ? 'Mis Atletas' : 'Clientes'
        ),
      },
      'assistant': {
        'view': const AssistantCopilotView(),
        'item': const BottomNavigationBarItem(
            icon: Icon(Icons.psychology_outlined),
            activeIcon: Icon(Icons.psychology_rounded),
            label: 'Asistente'),
      },
      'menu': {
        'view': const StaffMenuView(),
        'item': const BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_outlined),
            activeIcon: Icon(Icons.grid_view_rounded),
            label: 'Menú'),
      },
      'team': {
        'view': const TeamListView(),
        'item': const BottomNavigationBarItem(
            icon: Icon(Icons.people_alt_outlined),
            activeIcon: Icon(Icons.people_alt_rounded),
            label: 'Equipo'),
      },
      'audit': {
        'view': const AuditView(),
        'item': const BottomNavigationBarItem(
            icon: Icon(Icons.history_toggle_off_outlined),
            activeIcon: Icon(Icons.history_toggle_off_rounded),
            label: 'Auditoría'),
      },
      'profile': {
        'view': const StaffProfileView(showBackButton: false),
        'item': const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Perfil'),
      },
    };

    // Filtrar secciones por rol
    List<String> activeSectionKeys;
    if (userRole.contains('ADMIN')) {
      activeSectionKeys = ['dashboard', 'team', 'patients', 'profile'];
    } else if (userRole.contains('NUTRI')) {
      activeSectionKeys = ['dashboard', 'patients', 'profile']; // ✅ Quitamos 'team' para evitar 403
    } else if (_isEntrenador(userRole)) {
      activeSectionKeys = ['dashboard', 'patients', 'profile']; // ✅ Acceso para el Entrenador
    } else {
      activeSectionKeys = ['dashboard', 'profile'];
    }

    final List<Widget> filteredViews = activeSectionKeys
        .map((k) => allSections[k]!['view'] as Widget)
        .toList();
    final List<BottomNavigationBarItem> filteredItems = activeSectionKeys
        .map((k) => allSections[k]!['item'] as BottomNavigationBarItem)
        .toList();

    // Asegurar que el índice no se desborde si el rol cambia
    if (_selectedIndex >= filteredViews.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: null,
      body: filteredViews[_selectedIndex],
      floatingActionButton: (activeSectionKeys.contains('assistant') &&
              activeSectionKeys[_selectedIndex] != 'assistant')
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
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
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

}
