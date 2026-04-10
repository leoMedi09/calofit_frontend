import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../services/url_service.dart';
import 'patient_record_view.dart';

class TrainerClientsView extends StatefulWidget {
  const TrainerClientsView({super.key});

  @override
  State<TrainerClientsView> createState() => _TrainerClientsViewState();
}

class _TrainerClientsViewState extends State<TrainerClientsView> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _filteredClients = [];
  bool _isLoading = true;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.token != null) {
        // Usamos el mismo endpoint que el nutri por ahora, ya que el backend
        // filtra por asignación automáticamente si el usuario es staff/coach
        final clients =
            await _apiService.getNutricionistaClientes(authProvider.token!);
        setState(() {
          _clients = clients;
          _filteredClients = clients;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar atletas: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterClients(String query) {
    setState(() {
      _searchQuery = query;
      _filteredClients = _clients.where((p) {
        final fullName = p['full_name']?.toString().toLowerCase() ?? '';
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
        onRefresh: _loadClients,
        color: const Color(0xFF1E88E5), // ✅ Azul Corporativo
        child: Column(
          children: [
            // El buscador sube al tope para ganar espacio tal como solicitaste
            _buildSearchBox(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredClients.isEmpty
                      ? _buildEmptyState()
                      : _buildClientList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          20, 20, 20, 10), // Un poco más de padding superior
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: const Color(0xFF1E88E5).withOpacity(0.2)),
        ),
        child: TextField(
          onChanged: _filterClients,
          decoration: const InputDecoration(
            hintText: 'Buscar cualquier atleta por nombre...',
            hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
            prefixIcon:
                Icon(Icons.search_rounded, color: Color(0xFF1E88E5), size: 24),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildClientList() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics:
          const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      itemCount: _filteredClients.length,
      itemBuilder: (context, index) {
        final client = _filteredClients[index];
        final double adherence =
            double.tryParse(client['adherencia']?.toString() ?? '0') ?? 0;
        final bool isMale = client['gender']?.toString().toLowerCase() == 'm';

        // 🏃‍♂️ Verificamos si este atleta está asignado específicamente a este coach
        // Nota: En una fase final, deberíamos tener un 'coach_id' en el cliente.
        // Por ahora lo simulamos o comparamos con nutri_id si se usa el mismo campo.
        final bool isAssignedToMe = client['coach_id'] == authProvider.userId;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isAssignedToMe
                  ? const Color(0xFF1E88E5).withOpacity(0.3)
                  : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showClientDetails(client),
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        _buildProfileAvatar(client, isMale),
                        const SizedBox(width: 16),
                        // Información simplificada (Nombre + Email) como pidió el usuario
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                client['full_name'] ?? 'Sin nombre',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: Color(0xFF263238)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                client['email'] ?? 'Sin correo electrónico',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            color: Colors.grey, size: 14),
                      ],
                    ),
                  ),
                  if (isAssignedToMe)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E88E5), // ✅ Azul Corporativo
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded,
                                color: Colors.white, size: 10),
                            SizedBox(width: 4),
                            Text(
                              'A TU CARGO',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileAvatar(Map<String, dynamic> client, bool isMale) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: (isMale ? Colors.blue.shade50 : Colors.pink.shade50),
        shape: BoxShape.circle,
        image: client['profile_picture_url'] != null &&
                client['profile_picture_url'].toString().isNotEmpty
            ? DecorationImage(
                image: NetworkImage(
                    UrlService.formatImageUrl(client['profile_picture_url'])),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: client['profile_picture_url'] == null ||
              client['profile_picture_url'].toString().isEmpty
          ? Center(
              child: Text(
                client['full_name']?.toString().substring(0, 1).toUpperCase() ??
                    'A',
                style: TextStyle(
                  color: (isMale ? Colors.blue.shade700 : Colors.pink.shade700),
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fitness_center_rounded, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'No hay atletas registrados'
                : 'No se encontraron resultados',
            style: const TextStyle(
                color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _showClientDetails(Map<String, dynamic> client) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 45,
                height: 5,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                _buildProfileAvatar(
                    client, client['gender']?.toString().toLowerCase() == 'm'),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(client['full_name'],
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF263238),
                              letterSpacing: -0.5)),
                      Text(client['email'] ?? '',
                          style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 35),
            const Text('ANÁLISIS DE ADHERENCIA (IA)',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 1.5,
                    color: Color(0xFF1E88E5))),
            const SizedBox(height: 12),

            // 🤖 AI ADHERENCE CARD (Estilo de la imagen)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F7FF),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE3F2FD), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      color: Color(0xFF1E88E5), size: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Riesgo de abandono detectado. Se recomienda contactar al nutricionista.',
                      style: TextStyle(
                          color: const Color(0xFF455A64).withOpacity(0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                          letterSpacing: -0.1),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // 🚀 BASTÓN DE ACCIÓN: VER EXPEDIENTE COMPLETO
            SizedBox(
              width: double.infinity,
              height: 62,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            PatientRecordView(patientData: client)),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: const Color(0xFF1E88E5).withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('Ver Expediente Completo',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: -0.2)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
