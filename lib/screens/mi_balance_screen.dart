import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';

class MiBalanceScreen extends StatefulWidget {
  const MiBalanceScreen({Key? key}) : super(key: key);

  @override
  State<MiBalanceScreen> createState() => _MiBalanceScreenState();
}

class _MiBalanceScreenState extends State<MiBalanceScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  
  Map<String, dynamic>? balanceData;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBalance();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null) {
        throw Exception('No hay sesión activa');
      }

      final data = await _apiService.getMiBalance(token);
      setState(() {
        balanceData = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _eliminarRegistro(int id, String tipo) async {
    // Mostrar confirmación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar'),
        content: Text('¿Eliminar este ${tipo == 'alimento' ? 'alimento' : 'ejercicio'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      await _apiService.eliminarRegistro(id, tipo, token!);
      
      // Mostrar mensaje de éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tipo == 'alimento' ? 'Alimento' : 'Ejercicio'} eliminado'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Recargar balance
      _loadBalance();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Mi Balance Diario'),
        backgroundColor: Colors.teal,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBalance,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? _buildErrorView()
              : _buildBalanceView(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(errorMessage ?? 'Error desconocido'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadBalance,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceView() {
    final resumen = balanceData?['resumen'] ?? {};
    final alimentos = balanceData?['alimentos_registrados'] ?? [];
    final ejercicios = balanceData?['ejercicios_registrados'] ?? [];

    return Column(
      children: [
        // Resumen de calorías
        _buildCaloriasSummaryCard(resumen),
        
        // Tabs para Alimentos y Ejercicios
        TabBar(
          controller: _tabController,
          labelColor: Colors.teal,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.teal,
          tabs: [
            Tab(
              icon: const Icon(Icons.restaurant),
              text: 'Alimentos (${alimentos.length})',
            ),
            Tab(
              icon: const Icon(Icons.fitness_center),
              text: 'Ejercicios (${ejercicios.length})',
            ),
          ],
        ),
        
        // Contenido de tabs
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAlimentosList(alimentos),
              _buildEjerciciosList(ejercicios),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCaloriasSummaryCard(Map<String, dynamic> resumen) {
    final consumidas = resumen['calorias_consumidas'] ?? 0;
    final quemadas = resumen['calorias_quemadas'] ?? 0;
    final restantes = resumen['calorias_restantes'] ?? 0;
    final objetivo = resumen['objetivo_diario'] ?? 2000;

    final progreso = consumidas / objetivo;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00897B), Color(0xFF00695C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Resumen del Día',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(progreso * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Barra de progreso
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progreso.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 20),
          
          // Stats grid
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Consumidas',
                  '$consumidas',
                  'kcal',
                  Icons.restaurant_menu,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Quemadas',
                  '$quemadas',
                  'kcal',
                  Icons.local_fire_department,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Restantes',
                  '${restantes.toStringAsFixed(0)}',
                  'kcal',
                  Icons.trending_down,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, String unit, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          unit,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildAlimentosList(List alimentos) {
    if (alimentos.isEmpty) {
      return _buildEmptyState(
        'No hay alimentos registrados hoy',
        Icons.restaurant,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: alimentos.length,
      itemBuilder: (context, index) {
        final alimento = alimentos[index];
        return _buildAlimentoCard(alimento);
      },
    );
  }

  Widget _buildEjerciciosList(List ejercicios) {
    if (ejercicios.isEmpty) {
      return _buildEmptyState(
        'No hay ejercicios registrados hoy',
        Icons.fitness_center,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: ejercicios.length,
      itemBuilder: (context, index) {
        final ejercicio = ejercicios[index];
        return _buildEjercicioCard(ejercicio);
      },
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildAlimentoCard(Map<String, dynamic> alimento) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.restaurant_menu, color: Colors.orange),
        ),
        title: Text(
          alimento['nombre'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Registrado: ${alimento['hora_registro'] ?? ''}',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (alimento['frecuencia_total'] != null && alimento['frecuencia_total'] > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'x${alimento['frecuencia_total']}',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _eliminarRegistro(alimento['id'], 'alimento'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEjercicioCard(Map<String, dynamic> ejercicio) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.fitness_center, color: Colors.green),
        ),
        title: Text(
          ejercicio['nombre'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Registrado: ${ejercicio['hora_registro'] ?? ''}',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _eliminarRegistro(ejercicio['id'], 'ejercicio'),
        ),
      ),
    );
  }
}
