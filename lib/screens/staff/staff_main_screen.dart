import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'views/dashboard_view.dart';
import 'views/team_management_view.dart';
import 'views/audit_view.dart';
import 'views/assistant_copilot_view.dart';
import 'views/staff_profile_view.dart';

class StaffMainScreen extends StatefulWidget {
  const StaffMainScreen({super.key});

  @override
  State<StaffMainScreen> createState() => _StaffMainScreenState();
}

class _StaffMainScreenState extends State<StaffMainScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> views = [
      DashboardView(onNavigate: (index) => setState(() => _selectedIndex = index)),
      const TeamManagementView(),
      const AuditView(),
      const AssistantCopilotView(),
      const StaffProfileView(),
    ];
    final authProvider = Provider.of<AuthProvider>(context);
    final String userRole = authProvider.userType?.toUpperCase() ?? 'STAFF';
    final Color primaryBlue = const Color(0xFF1E88E5);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: null,
      body: views[_selectedIndex],
      floatingActionButton: _selectedIndex != 3 
          ? FloatingActionButton(
              onPressed: () => setState(() => _selectedIndex = 3),
              backgroundColor: primaryBlue,
              elevation: 4,
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
            ) 
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          selectedItemColor: primaryBlue,
          unselectedItemColor: Colors.grey.shade400,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded), 
              activeIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard'
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_alt_rounded), 
              activeIcon: Icon(Icons.people_alt_rounded),
              label: 'Equipo'
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_toggle_off_rounded), 
              activeIcon: Icon(Icons.history_toggle_off_rounded),
              label: 'Auditoría'
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.psychology_rounded), 
              activeIcon: Icon(Icons.psychology_rounded),
              label: 'Asistente'
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded), 
              activeIcon: Icon(Icons.person_rounded),
              label: 'Perfil'
            ),
          ],
        ),
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
      case 4: return 'Perfil del Staff';
      default: return 'CaloFit';
    }
  }
}
