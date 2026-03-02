import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import 'patient_record_view.dart';

class PatientListView extends StatefulWidget {
  const PatientListView({super.key});

  @override
  State<PatientListView> createState() => _PatientListViewState();
}

class _PatientListViewState extends State<PatientListView> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _filteredPatients = [];
  bool _isLoading = true;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.token != null) {
        final patients = await _apiService.getNutricionistaClientes(authProvider.token!);
        setState(() {
          _patients = patients;
          _filteredPatients = patients;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar pacientes: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterPatients(String query) {
    setState(() {
      _searchQuery = query;
      _filteredPatients = _patients.where((p) {
        final fullName = p['full_name'].toString().toLowerCase();
        return fullName.contains(query.toLowerCase());
      }).toList();
    });
  }

  Color _getAdherenceColor(double? adherence) {
    if (adherence == null) return Colors.grey;
    if (adherence >= 80) return Colors.green;
    if (adherence >= 50) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadPatients,
        child: Column(
          children: [
            _buildSearchHeader(),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _filteredPatients.isEmpty 
                  ? _buildEmptyState()
                  : _buildPatientList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
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
          onChanged: _filterPatients,
          decoration: const InputDecoration(
            hintText: 'Buscar paciente por nombre...',
            hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
            prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF1A237E), size: 20),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildPatientList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      itemCount: _filteredPatients.length,
      itemBuilder: (context, index) {
        final patient = _filteredPatients[index];
        final double adherence = double.tryParse(patient['adherencia']?.toString() ?? '0') ?? 0;
        final bool isMale = patient['gender']?.toString().toLowerCase() == 'm';
        final bool isValidated = patient['is_validated'] == true;
        
        final String status = patient['semana_status'] ?? 'falta_checkin';
        Color statusColor = const Color(0xFFD32F2F); // Rojo suave profesional
        IconData statusIcon = Icons.error_outline_rounded;
        String statusLabel = "FALTA CHECK-IN";

        if (status == "validado") {
          statusColor = const Color(0xFF388E3C); // Verde Nutri (No azul)
          statusIcon = Icons.task_alt_rounded; // Nuevo símbolo de tarea completada
          statusLabel = "PLAN VALIDADO";
        } else if (status == "pendiente") {
          statusColor = const Color(0xFFF57C00); // Ámbar/Naranja
          statusIcon = Icons.history_rounded;
          statusLabel = "PENDIENTE";
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showPatientDetails(patient),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Fila Superior: Badge en la esquina sin tapar nada
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: statusColor.withOpacity(0.15)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, color: statusColor, size: 13),
                              const SizedBox(width: 4),
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 9,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Contenido Principal
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: (isMale ? const Color(0xFFE3F2FD) : const Color(0xFFFCE4EC)),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              patient['full_name']?.toString().substring(0, 1).toUpperCase() ?? 'U',
                              style: TextStyle(
                                color: (isMale ? const Color(0xFF1E88E5) : const Color(0xFFD81B60)),
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        
                        // Información
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                patient['full_name'] ?? 'Sin nombre',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                  color: Color(0xFF263238),
                                  letterSpacing: -0.4,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                patient['goal'] ?? 'General',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              // Métricas
                              Row(
                                children: [
                                    _buildInfoTag(
                                      Icons.monitor_weight_outlined, 
                                      '${double.tryParse(patient['weight']?.toString() ?? '0')?.toStringAsFixed(1) ?? '--'} kg',
                                      Colors.blueGrey[500]!,
                                      Colors.blueGrey[50]!,
                                    ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('ADHERENCIA', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.grey[400])),
                                            Text('${adherence.toInt()}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _getAdherenceColor(adherence))),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(2),
                                          child: LinearProgressIndicator(
                                            value: adherence / 100,
                                            backgroundColor: Colors.grey[100],
                                            valueColor: AlwaysStoppedAnimation<Color>(_getAdherenceColor(adherence)),
                                            minHeight: 4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
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
      },
    );
  }

  Widget _buildInfoTag(IconData icon, String value, Color color, Color bgColor, {String? label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label != null ? '$label: $value' : value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // _buildWeeklyStatusChip removido (integrado en el diseño premium)

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No tienes pacientes asignados' : 'No se encontraron resultados',
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  void _showPatientDetails(Map<String, dynamic> patient) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PatientQuickPreview(
        patient: patient, 
        apiService: _apiService,
        onAssign: () => _showAssignmentDialog(context, patient),
        onValidated: _loadPatients,
      ),
    );
  }

  void _showAssignmentDialog(BuildContext context, Map<String, dynamic> patient) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final staff = await _apiService.getStaffList(authProvider.token!);
      final nutris = staff.where((s) => s['role_name']?.toString().toLowerCase().contains('nutri') ?? false).toList();
      
      if (context.mounted) Navigator.pop(context);

      if (context.mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Asignar Nutricionista',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF263238)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Selecciona un especialista para ${patient['full_name']}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView.builder(
                    itemCount: nutris.length,
                    itemBuilder: (context, index) {
                      final nutri = nutris[index];
                      final bool isCurrentlyAssigned = nutri['id'] == patient['nutri_id'];
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isCurrentlyAssigned ? const Color(0xFFE8F5E9) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isCurrentlyAssigned ? const Color(0xFF4CAF50) : Colors.grey[200]!,
                            width: isCurrentlyAssigned ? 2 : 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: isCurrentlyAssigned ? const Color(0xFF4CAF50) : const Color(0xFF1E88E5).withOpacity(0.1),
                            child: Icon(
                              isCurrentlyAssigned ? Icons.check_rounded : Icons.person_outline_rounded,
                              color: isCurrentlyAssigned ? Colors.white : const Color(0xFF1E88E5),
                            ),
                          ),
                          title: Text(
                            '${nutri['first_name']} ${nutri['last_name_paternal']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('${nutri['pacientes_count'] ?? 0} pacientes asignados'),
                          trailing: isCurrentlyAssigned 
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4CAF50),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'ACTUAL',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              )
                            : const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                          onTap: isCurrentlyAssigned ? null : () async {
                            try {
                              await _apiService.assignEspecialista(
                                patient['id'], 
                                nutriId: nutri['id'], 
                                token: authProvider.token!
                              );
                              if (context.mounted) {
                                Navigator.pop(context); // Cerrar lista
                                Navigator.pop(context); // Cerrar preview
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Nutricionista asignado correctamente'),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                // Opcional: Recargar lista
                                _loadPatients();
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al obtener especialistas: $e')),
        );
      }
    }
  }
}

class _PatientQuickPreview extends StatelessWidget {
  final Map<String, dynamic> patient;
  final ApiService apiService;
  final VoidCallback onAssign;
  final VoidCallback onValidated;

  const _PatientQuickPreview({
    required this.patient, 
    required this.apiService,
    required this.onAssign,
    required this.onValidated,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bool isAdmin = authProvider.userRole?.toUpperCase().contains('ADMIN') ?? false;
    final bool isMale = patient['gender']?.toString().toLowerCase() == 'm';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: (isMale ? const Color(0xFFE3F2FD) : const Color(0xFFFCE4EC)),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    patient['full_name']?.toString().substring(0, 1).toUpperCase() ?? 'U',
                    style: TextStyle(
                      fontSize: 32, 
                      color: (isMale ? const Color(0xFF1E88E5) : const Color(0xFFD81B60)), 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient['full_name'],
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF263238)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      patient['email'] ?? 'Sin correo', 
                      style: TextStyle(color: Colors.grey[600], fontSize: 14)
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'ANÁLISIS DE ADHERENCIA (IA)', 
            style: TextStyle(
              fontWeight: FontWeight.w800, 
              letterSpacing: 1.2, 
              fontSize: 11,
              color: Color(0xFF1E88E5),
            )
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF1E88E5).withOpacity(0.08), const Color(0xFF1E88E5).withOpacity(0.02)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF1E88E5).withOpacity(0.12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF1E88E5), size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    patient['alerta'] ?? 'Analizando actividad reciente...',
                    style: const TextStyle(
                      fontSize: 14, 
                      height: 1.6,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF455A64),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32), // 👈 Incrementamos el espacio aquí (era 0 o implícito)
          if (isAdmin) ...[
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: onAssign,
                icon: Icon(
                  patient['nutri_id'] != null ? Icons.sync_rounded : Icons.person_add_alt_1_outlined,
                  color: Colors.white,
                ),
                label: Text(
                  patient['nutri_id'] != null ? 'Cambiar Nutricionista' : 'Asignar Nutricionista', 
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: patient['nutri_id'] != null 
                      ? const Color(0xFF5C6BC0) // Indigo para "Cambiar"
                      : const Color(0xFF2E7D32), // Verde para "Asignar"
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
          if (!isAdmin) ...[
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Cerrar bottom sheet
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PatientRecordView(patientData: patient),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Ver Expediente Completo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
