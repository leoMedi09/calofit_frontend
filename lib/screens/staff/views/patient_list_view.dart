import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../services/url_service.dart';
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
  bool _showPending = false; // 🆕 Filtro para ocultar nuevos registros hasta que se completen

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
        final patients =
            await _apiService.getNutricionistaClientes(authProvider.token!);
        setState(() {
          _patients = patients;
          _isLoading = false;
          _filterPatients(_searchQuery); // Aplicar filtros actuales
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar clientes: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterPatients(String query) {
    setState(() {
      _searchQuery = query;
      _filteredPatients = _patients.where((p) {
        final fullName = p['full_name']?.toString().toLowerCase() ?? '';
        final email = p['email']?.toString().toLowerCase() ?? '';
        final matchesQuery = fullName.contains(query.toLowerCase()) || email.contains(query.toLowerCase());
        
        // El backend ahora envía is_profile_complete
        final bool isComplete = p['is_profile_complete'] == true;
        
        if (_showPending) {
          return matchesQuery && !isComplete;
        } else {
          return matchesQuery && isComplete;
        }
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
    final authProvider = Provider.of<AuthProvider>(context);
    final String role = authProvider.userRole?.toLowerCase() ?? '';
    final bool canCreateClient = role.contains('nutri') || role.contains('admin');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
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
      ),
      floatingActionButton: canCreateClient
          ? FloatingActionButton.extended(
              onPressed: () => _showExpressCreationModal(context),
              backgroundColor: const Color(0xFF1E88E5), // Azul premium
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Inscribir Cliente',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Future<void> _showExpressCreationModal(BuildContext context) async {
    // Pre-carga entrenadores antes de abrir el sheet
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    List<Map<String, dynamic>> coaches = [];
    try {
      coaches = await _apiService.getCoachesList(authProvider.token!);
    } catch (_) {}

    if (!context.mounted) return;

    final emailController = TextEditingController();
    final dniController = TextEditingController();
    bool isSubmitting = false;
    int? selectedCoachId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final bottomInsets = MediaQuery.of(context).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.only(bottom: bottomInsets),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                        width: 45,
                        height: 5,
                        decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(10))),
                  ),
                  const SizedBox(height: 24),

                  // Encabezado
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.flash_on_rounded,
                            color: Color(0xFF1E88E5)),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Creación Express',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1A237E),
                            letterSpacing: -0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Registra un cliente con su DNI y Correo. El DNI será su contraseña inicial.',
                    style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.4),
                  ),
                  const SizedBox(height: 24),

                  // Campo Email
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Correo Electrónico',
                      labelStyle:
                          TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      prefixIcon: const Icon(Icons.email_outlined,
                          size: 20, color: Color(0xFF1E88E5)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade200)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: Color(0xFF1E88E5), width: 2)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Campo DNI
                  TextField(
                    controller: dniController,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Número de DNI (8 dígitos)',
                      labelStyle:
                          TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      prefixIcon: const Icon(Icons.badge_outlined,
                          size: 20, color: Color(0xFF1E88E5)),
                      counterText: '',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade200)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: Color(0xFF1E88E5), width: 2)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Sección: Asignar Entrenador ──────────────────────────
                  Row(
                    children: [
                      const Icon(Icons.fitness_center_rounded,
                          size: 16, color: Color(0xFF1E88E5)),
                      const SizedBox(width: 8),
                      const Text(
                        'ASIGNAR ENTRENADOR',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: Color(0xFF1E88E5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Opcional',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (coaches.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 16, color: Colors.grey.shade400),
                          const SizedBox(width: 10),
                          Text(
                            'No hay entrenadores registrados aún',
                            style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 160),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: coaches.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final coach = coaches[i];
                          final isSelected =
                              selectedCoachId == coach['id'];
                          final initials = (coach['full_name'] as String)
                              .trim()
                              .split(' ')
                              .where((w) => w.isNotEmpty)
                              .take(2)
                              .map((w) => w[0].toUpperCase())
                              .join();

                          return GestureDetector(
                            onTap: () => setModalState(() {
                              selectedCoachId = isSelected
                                  ? null
                                  : coach['id'] as int;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF1E88E5)
                                        .withValues(alpha: 0.06)
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF1E88E5)
                                      : Colors.grey.shade200,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: isSelected
                                        ? const Color(0xFF1E88E5)
                                        : Colors.grey.shade200,
                                    child: Text(
                                      initials.isEmpty ? 'E' : initials,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          coach['full_name'] as String,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: isSelected
                                                ? const Color(0xFF1565C0)
                                                : const Color(0xFF263238),
                                          ),
                                        ),
                                        Text(
                                          coach['email'] as String,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFF1E88E5),
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Botón crear
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final email = emailController.text.trim();
                              final dni = dniController.text.trim();

                              if (email.isEmpty || dni.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Por favor llena DNI y Correo'),
                                        backgroundColor: Colors.orange));
                                return;
                              }
                              final emailRegex =
                                  RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                              if (!emailRegex.hasMatch(email)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Ingresa un correo electrónico válido'),
                                        backgroundColor: Colors.orange));
                                return;
                              }
                              if (dni.length != 8 ||
                                  !RegExp(r'^\d{8}$').hasMatch(dni)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'El DNI debe tener exactamente 8 dígitos'),
                                        backgroundColor: Colors.orange));
                                return;
                              }

                              setModalState(() => isSubmitting = true);
                              try {
                                await _apiService.createExpressClient(
                                  email,
                                  dni,
                                  authProvider.token!,
                                  assignedCoachId: selectedCoachId,
                                );
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(
                                    content:
                                        Text('¡Cliente registrado exitosamente!'),
                                    backgroundColor: Color(0xFF2E7D32),
                                    behavior: SnackBarBehavior.floating,
                                  ));
                                  _loadPatients();
                                }
                              } catch (e) {
                                setModalState(() => isSubmitting = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Text(e.toString()),
                                    backgroundColor: const Color(0xFFC62828),
                                    behavior: SnackBarBehavior.floating,
                                  ));
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Crear Cliente',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16)),
                                const SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded,
                                    size: 20,
                                    color: Colors.white.withValues(alpha: 0.9)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchHeader() {
    final int pendingCount = _patients.where((p) => p['is_profile_complete'] == false).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[100]!, width: 1)),
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: TextField(
              onChanged: _filterPatients,
              decoration: const InputDecoration(
                hintText: 'Buscar cliente por nombre...',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                prefixIcon:
                    Icon(Icons.search_rounded, color: Color(0xFF1A237E), size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildFilterChip(
                label: 'Clientes Activos',
                isSelected: !_showPending,
                onTap: () {
                  setState(() => _showPending = false);
                  _filterPatients(_searchQuery);
                },
                icon: Icons.people_alt_rounded,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Pendientes',
                count: pendingCount,
                isSelected: _showPending,
                onTap: () {
                  setState(() => _showPending = true);
                  _filterPatients(_searchQuery);
                },
                icon: Icons.pending_actions_rounded,
                activeColor: Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required IconData icon,
    int? count,
    Color activeColor = const Color(0xFF1E88E5),
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor.withValues(alpha: 0.2) : Colors.grey.shade200,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? activeColor : Colors.grey.shade500,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? activeColor : Colors.grey.shade600,
              ),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? activeColor : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPatientList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics:
          const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      itemCount: _filteredPatients.length,
      itemBuilder: (context, index) {
        final patient = _filteredPatients[index];
        final double adherence =
            double.tryParse(patient['adherencia']?.toString() ?? '0') ?? 0;
        final bool isMale = patient['gender']?.toString().toLowerCase() == 'm';
        final bool isValidated = patient['is_validated'] == true;

        final String status = patient['semana_status'] ?? 'falta_checkin';
        final bool isProfileComplete = patient['is_profile_complete'] ?? true;
        
        // Formatear objetivo (quitar guiones y capitalizar)
        String rawGoal = patient['goal']?.toString().replaceAll('_', ' ') ?? 'Mantener peso';
        String formattedGoal = rawGoal.isNotEmpty 
            ? rawGoal[0].toUpperCase() + rawGoal.substring(1) 
            : rawGoal;
        
        Color statusColor = const Color(0xFFD32F2F); // Rojo suave profesional
        IconData statusIcon = Icons.error_outline_rounded;
        String statusLabel = "FALTA CHECK-IN";
        
        if (!isProfileComplete) {
          statusColor = const Color(0xFF9C27B0); // Púrpura para Onboarding
          statusIcon = Icons.app_registration_rounded;
          statusLabel = "PERFIL INCOMPLETO";
        } else if (status == "validado") {
          statusColor = const Color(0xFF388E3C); // Verde Nutri
          statusIcon = Icons.task_alt_rounded;
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
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isProfileComplete ? () => _showPatientDetails(patient) : null,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Fila Superior: Badge en la esquina sin tapar nada
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Badge secundario: sin peso mensual
                        if (status == "validado" &&
                            patient['hizo_checkin_peso'] == false) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: const Color(0xFFFFB300)
                                      .withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.scale_rounded,
                                    color: Color(0xFFF57F17), size: 12),
                                SizedBox(width: 4),
                                Text(
                                  'SIN PESO',
                                  style: TextStyle(
                                    color: Color(0xFFF57F17),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 9,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        // Badge principal de estado
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: statusColor.withValues(alpha: 0.15)),
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
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: (isMale
                              ? const Color(0xFFE3F2FD)
                              : const Color(0xFFFCE4EC)),
                          backgroundImage:
                              patient['profile_picture_url'] != null &&
                                      patient['profile_picture_url']
                                          .toString()
                                          .isNotEmpty
                                  ? NetworkImage(UrlService.formatImageUrl(
                                      patient['profile_picture_url']))
                                  : null,
                          child: patient['profile_picture_url'] == null ||
                                  patient['profile_picture_url']
                                      .toString()
                                      .isEmpty
                              ? Text(
                                  ((isProfileComplete && (patient['full_name']?.toString().trim().isNotEmpty ?? false))
                                          ? patient['full_name']
                                          : (patient['email'] ?? 'U'))
                                      .toString()
                                      .trim()
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: TextStyle(
                                    color: (isMale
                                        ? const Color(0xFF1E88E5)
                                        : const Color(0xFFD81B60)),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),

                        // Información
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isProfileComplete && (patient['full_name']?.toString().trim().isNotEmpty ?? false)
                                    ? patient['full_name']
                                    : (patient['email'] ?? "Nuevo Paciente"),
                                style: TextStyle(
                                  fontWeight: isProfileComplete ? FontWeight.w800 : FontWeight.w600,
                                  fontSize: 16,
                                  color: isProfileComplete ? const Color(0xFF263238) : Colors.purple[800],
                                  letterSpacing: -0.4,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                !isProfileComplete 
                                    ? "Esperando primer acceso..."
                                    : formattedGoal,
                                style: TextStyle(
                                  color: !isProfileComplete ? Colors.purple[300] : Colors.grey[500],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Métricas solo si el perfil está completo
                              if (isProfileComplete) ...[
                                const SizedBox(height: 12),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('ADHERENCIA',
                                                  style: TextStyle(
                                                      fontSize: 8,
                                                      fontWeight: FontWeight.w800,
                                                      color: Colors.grey[400])),
                                              Text('${adherence.toInt()}%',
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w800,
                                                      color: _getAdherenceColor(
                                                          adherence))),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(2),
                                            child: LinearProgressIndicator(
                                              value: adherence / 100,
                                              backgroundColor: Colors.grey[100],
                                              valueColor: AlwaysStoppedAnimation<
                                                      Color>(
                                                  _getAdherenceColor(adherence)),
                                              minHeight: 4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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

  Widget _buildInfoTag(IconData icon, String value, Color color, Color bgColor,
      {String? label}) {
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
            _searchQuery.isEmpty
                ? (_showPending ? 'No hay registros express pendientes' : 'No tienes clientes asignados')
                : 'No se encontraron resultados para "$_searchQuery"',
            style: const TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500),
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
      builder: (context) => PatientPreviewModal(
        patient: patient,
        apiService: _apiService,
        onAssignNutri: () =>
            _showAssignmentDialog(context, patient, roleToAssign: 'nutri'),
        onAssignCoach: () =>
            _showAssignmentDialog(context, patient, roleToAssign: 'coach'),
        onValidated: _loadPatients,
      ),
    );
  }

  void _showAssignmentDialog(BuildContext context, Map<String, dynamic> patient,
      {required String roleToAssign}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bool isNutri = roleToAssign == 'nutri';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final staff = await _apiService.getStaffList(authProvider.token!);
      final filteredStaff = staff.where((s) {
        final r = s['role_name']?.toString().toLowerCase() ?? '';
        return isNutri ? r.contains('nutri') : r.contains('coach');
      }).toList();

      if (context.mounted) Navigator.pop(context);

      if (context.mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                      width: 45,
                      height: 5,
                      decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10))),
                ),
                const SizedBox(height: 24),
                Text(
                  isNutri ? 'Asignar Nutricionista' : 'Asignar Coach / Trainer',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF263238),
                      letterSpacing: -0.5),
                ),
                Text(
                  'Elige un especialista para gestionar este perfil.',
                  style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredStaff.length,
                    itemBuilder: (context, index) {
                      final member = filteredStaff[index];
                      final bool isCurrentlyAssigned = isNutri
                          ? member['id'] == patient['nutri_id']
                          : member['id'] == patient['coach_id'];

                      final Color roleColor = isNutri
                          ? const Color(0xFF1E88E5)
                          : Colors.orange.shade700;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isCurrentlyAssigned
                              ? roleColor.withValues(alpha: 0.05)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isCurrentlyAssigned
                                ? roleColor
                                : Colors.grey[100]!,
                            width: isCurrentlyAssigned ? 2 : 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: roleColor.withValues(alpha: 0.1),
                            backgroundImage:
                                member['profile_picture_url'] != null
                                    ? NetworkImage(UrlService.formatImageUrl(
                                        member['profile_picture_url']))
                                    : null,
                            child: member['profile_picture_url'] == null
                                ? Icon(Icons.person_outline_rounded,
                                    color: roleColor)
                                : null,
                          ),
                          title: Text(
                            '${member['first_name']} ${member['last_name_paternal']}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          subtitle: Text(
                              '${member['pacientes_count'] ?? 0} atletas bajo su cargo',
                              style: const TextStyle(fontSize: 12)),
                          trailing: isCurrentlyAssigned
                              ? Icon(Icons.check_circle_rounded,
                                  color: roleColor)
                              : const Icon(Icons.chevron_right_rounded,
                                  color: Colors.grey),
                          onTap: isCurrentlyAssigned
                              ? null
                              : () async {
                                  try {
                                    await _apiService.assignEspecialista(
                                        patient['id'],
                                        nutriId: isNutri ? member['id'] : null,
                                        trainerId:
                                            !isNutri ? member['id'] : null,
                                        token: authProvider.token!);
                                    if (context.mounted) {
                                      Navigator.pop(context); // Cerrar lista
                                      Navigator.pop(context); // Cerrar preview
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              '${isNutri ? "Nutricionista" : "Coach"} asignado con éxito'),
                                          backgroundColor: Colors.green,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                      _loadPatients();
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text('Error: $e'),
                                            backgroundColor: Colors.red),
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
          SnackBar(content: Text('Error al obtener staff: $e')),
        );
      }
    }
  }
}

class PatientPreviewModal extends StatelessWidget {
  final Map<String, dynamic> patient;
  final ApiService apiService;
  final VoidCallback onAssignNutri;
  final VoidCallback onAssignCoach;
  final VoidCallback onValidated;

  const PatientPreviewModal({
    super.key,
    required this.patient,
    required this.apiService,
    required this.onAssignNutri,
    required this.onAssignCoach,
    required this.onValidated,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bool isAdmin =
        authProvider.userRole?.toUpperCase().contains('ADMIN') ?? false;
    final bool isMale = patient['gender']?.toString().toLowerCase() == 'm';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10))),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: (isMale
                    ? const Color(0xFFE3F2FD)
                    : const Color(0xFFFCE4EC)),
                backgroundImage: patient['profile_picture_url'] != null &&
                        patient['profile_picture_url'].toString().isNotEmpty
                    ? NetworkImage(UrlService.formatImageUrl(
                        patient['profile_picture_url']))
                    : null,
                child: patient['profile_picture_url'] == null ||
                        patient['profile_picture_url'].toString().isEmpty
                    ? Text(
                        patient['full_name']
                                ?.toString()
                                .substring(0, 1)
                                .toUpperCase() ??
                            'U',
                        style: TextStyle(
                            fontSize: 32,
                            color: (isMale
                                ? const Color(0xFF1E88E5)
                                : const Color(0xFFD81B60)),
                            fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient['full_name'],
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF263238),
                          letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 2),
                    Text(patient['email'] ?? 'Sin correo',
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'ANÁLISIS DE ADHERENCIA (IA)',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                fontSize: 10,
                color: Color(0xFF1E88E5)),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.05)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome,
                    color: Color(0xFF1E88E5), size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    patient['alerta'] ?? 'Analizando actividad reciente...',
                    style: const TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          if (isAdmin) ...[
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: onAssignNutri,
                icon: const Icon(Icons.restaurant_menu_rounded,
                    color: Colors.white, size: 20),
                label: Text(
                    patient['nutri_id'] != null
                        ? 'Cambiar Nutricionista'
                        : 'Asignar Nutricionista',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: onAssignCoach,
                icon: const Icon(Icons.fitness_center_rounded,
                    color: Colors.white, size: 20),
                label: Text(
                    patient['coach_id'] != null
                        ? 'Cambiar Coach'
                        : 'Asignar Coach / Trainer',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
          if (!isAdmin) ...[
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final wasDeleted = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PatientRecordView(patientData: patient),
                    ),
                  );
                  if (wasDeleted == true) {
                    onValidated();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Ver Expediente Completo',
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
