import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';

class AuditView extends StatefulWidget {
  const AuditView({super.key});

  @override
  State<AuditView> createState() => _AuditViewState();
}

class _AuditViewState extends State<AuditView> {
  final ApiService _apiService = ApiService();
  late Future<List<Map<String, dynamic>>> _auditFuture;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshAudit();
    // ⏱️ Auto-refresco de alertas cada 60 segundos
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() => _refreshAudit());
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _refreshAudit() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.userType?.toUpperCase() == 'ADMIN') {
      _auditFuture = _apiService.getAdminLogs(authProvider.token ?? '');
    } else {
      _auditFuture = _apiService.getMisAlertasClientes(authProvider.token ?? '');
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _refreshAudit());
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            backgroundColor: const Color(0xFF1E88E5),
            elevation: 0,
            pinned: true,
            toolbarHeight: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                  boxShadow: [
                    BoxShadow(color: Color(0x331E88E5), blurRadius: 20, offset: Offset(0, 10)),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 42, 20, 40),
                  child: _buildHeader(),
                ),
              ),
            ),
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _auditFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                return SliverFillRemaining(child: Center(child: _buildErrorState(snapshot.error.toString())));
              }
              final alerts = snapshot.data ?? [];
              if (alerts.isEmpty) {
                return const SliverFillRemaining(child: Center(child: Text('No hay eventos registrados.')));
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final alert = alerts[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: _buildAuditCard(alert),
                      );
                    },
                    childCount: alerts.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_rounded, color: Colors.white, size: 14),
              const SizedBox(width: 6),
              Text(
                'HISTORIAL DEL SISTEMA',
                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Seguridad y Logs',
          style: TextStyle(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.w500, letterSpacing: -0.2),
        ),
        Text(
          'Auditoría General',
          style: TextStyle(
            fontSize: 28, 
            fontWeight: FontWeight.w900, 
            color: Colors.white,
            letterSpacing: -1.0,
            shadows: [
              Shadow(color: Colors.black.withOpacity(0.1), offset: const Offset(0, 4), blurRadius: 8)
            ]
          ),
        ),
      ],
    );
  }

  Widget _buildAuditCard(Map<String, dynamic> log) {
    // Detectar si es un log administrativo o una alerta de salud
    final bool isAdminLog = log.containsKey('accion');
    
    if (isAdminLog) {
      return _buildAdminLogCard(log);
    }

    final bool isAttended = log['estado'] == 'atendida';
    final String severity = log['severidad'] ?? 'bajo';
    
    Color severityColor;
    if (severity == 'alto') severityColor = Colors.red;
    else if (severity == 'medio') severityColor = Colors.orange;
    else severityColor = Colors.blue;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: severityColor.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: severityColor.withOpacity(0.05), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.priority_high_rounded, color: severityColor, size: 10),
                    const SizedBox(width: 4),
                    Text(
                      severity.toUpperCase(),
                      style: TextStyle(color: severityColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
              Text(
                log['fecha_deteccion'] != null 
                    ? log['fecha_deteccion'].toString().substring(0, 10).split('-').reversed.join('/')
                    : '',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            log['tipo'] ?? 'Alerta de Salud',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1A237E), letterSpacing: -0.2),
          ),
          const SizedBox(height: 6),
          Text(
            log['descripcion'] ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.3),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                child: Icon(Icons.person_rounded, size: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(width: 8),
              Text(
                log['cliente_nombre'] ?? 'Paciente',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              _buildAttendanceBadge(isAttended),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceBadge(bool isAttended) {
    final Color color = isAttended ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isAttended ? Icons.check_circle_rounded : Icons.pending_rounded, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            isAttended ? 'ATENDIDA' : 'PENDIENTE',
            style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminLogCard(Map<String, dynamic> log) {
    String accion = log['accion'] ?? 'EVENTO';
    IconData iconData = Icons.info_outline;
    Color color = Colors.blue;

    if (accion.contains('PASSWORD')) {
      iconData = Icons.key_rounded;
      color = Colors.orange;
    } else if (accion.contains('REGISTRO')) {
      iconData = Icons.person_add_rounded;
      color = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(iconData, color: color, size: 26),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        accion.replaceAll('_', ' '),
                        style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                    ),
                    Text(
                      log['fecha'] != null 
                          ? log['fecha'].toString().substring(11, 16)
                          : '',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  log['descripcion'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF1A237E), letterSpacing: -0.2),
                ),
                const SizedBox(height: 4),
                Text(
                  'Responsable: Admin #${log['admin_id']}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.red),
        const SizedBox(height: 16),
        Text('Error al cargar auditoría', style: const TextStyle(fontWeight: FontWeight.bold)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
          child: Text(error, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
        ),
      ],
    );
  }
}
