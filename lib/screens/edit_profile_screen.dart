import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/client.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';
import 'mi_balance_screen.dart';

class EditProfileScreen extends StatefulWidget {
  final Client client;
  final VoidCallback? onProfileUpdated;

  const EditProfileScreen({super.key, required this.client, this.onProfileUpdated});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  bool _isSaving = false;

  // Controladores
  late TextEditingController _firstNameController;
  late TextEditingController _paternalController;
  late TextEditingController _maternalController;
  late TextEditingController _emailController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;

  final TextEditingController _customConditionController = TextEditingController();
  List<String> _selectedConditions = [];

  String _activityLevel = 'Sedentario';
  String _goal = 'Mantener peso';
  DateTime? _birthDate;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.client.firstName);
    _paternalController = TextEditingController(text: widget.client.lastNamePaternal);
    _maternalController = TextEditingController(text: widget.client.lastNameMaternal);
    _emailController = TextEditingController(text: widget.client.email);
    _weightController = TextEditingController(text: widget.client.weight.toString());
    _heightController = TextEditingController(text: widget.client.height.toString());
    _selectedConditions = widget.client.medicalConditions
        ?.where((c) => c != 'Ninguna')
        .toList() ?? [];
    _activityLevel = widget.client.activityLevel;
    _goal = widget.client.goal;
    _birthDate = widget.client.birthDate;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _paternalController.dispose();
    _maternalController.dispose();
    _emailController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _customConditionController.dispose();
    super.dispose();
  }

  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'ES'),
    );
    if (picked != null && picked != _birthDate) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    if (_birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona tu fecha de nacimiento'))
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Limpieza de condiciones por lógica de negocio
      List<String> finalConditions = List<String>.from(_selectedConditions);
      finalConditions.remove('Ninguna'); // Asegurar que no se envíe "Ninguna" al backend

      final updatedClient = Client(
        id: widget.client.id,
        flutterUid: widget.client.flutterUid,
        firstName: _firstNameController.text.trim(),
        lastNamePaternal: _paternalController.text.trim(),
        lastNameMaternal: _maternalController.text.trim(),
        email: _emailController.text.trim(),
        weight: double.parse(_weightController.text),
        height: double.parse(_heightController.text),
        birthDate: _birthDate!,
        gender: widget.client.gender,
        activityLevel: _activityLevel,
        goal: _goal,
        medicalConditions: finalConditions,
      );

      await _apiService.updateClient(
          widget.client.id,
          updatedClient,
          authProvider.token!
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text('✅ Perfil actualizado correctamente'),
                  ],
                ),
                backgroundColor: Colors.green
            )
        );

        if (widget.onProfileUpdated != null) widget.onProfileUpdated!();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error al guardar: $e'),
                backgroundColor: Colors.red
            )
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // Header moderno con gradiente
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(20, 70, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Mi Perfil',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Actualiza tu información personal',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Contenido
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (_isSaving)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(50.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Información Personal
                        _buildSectionCard(
                          title: '👤 Información Personal',
                          children: [
                            _buildModernTextField(
                              controller: _firstNameController,
                              label: 'Nombre(s)',
                              icon: Icons.person,
                            ),
                            const SizedBox(height: 12),
                            _buildModernTextField(
                              controller: _paternalController,
                              label: 'Apellido Paterno',
                              icon: Icons.badge,
                            ),
                            const SizedBox(height: 12),
                            _buildModernTextField(
                              controller: _maternalController,
                              label: 'Apellido Materno',
                              icon: Icons.badge_outlined,
                            ),
                            const SizedBox(height: 12),
                            _buildModernTextField(
                              controller: _emailController,
                              label: 'Correo',
                              icon: Icons.email,
                              keyboardType: TextInputType.emailAddress,
                              enabled: false,
                            ),
                            const SizedBox(height: 12),
                            _buildBirthDateField(),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Datos Físicos
                        _buildSectionCard(
                          title: '⚖️ Datos Físicos',
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildModernTextField(
                                    controller: _weightController,
                                    label: 'Peso (kg)',
                                    icon: Icons.monitor_weight,
                                    keyboardType: TextInputType.number,
                                    onChanged: (val) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildModernTextField(
                                    controller: _heightController,
                                    label: 'Altura (cm)',
                                    icon: Icons.height,
                                    keyboardType: TextInputType.number,
                                    onChanged: (val) => setState(() {}),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildIMCPill(),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Estilo de Vida
                        _buildSectionCard(
                          title: '🎯 Estilo de Vida',
                          children: [
                            _buildModernDropdown(
                              label: 'Nivel de Actividad',
                              value: ['Sedentario', 'Ligero', 'Moderado', 'Activo', 'Muy activo'].contains(_activityLevel) ? _activityLevel : 'Sedentario',
                              icon: Icons.fitness_center,
                              items: [
                                'Sedentario',
                                'Ligero',
                                'Moderado',
                                'Activo',
                                'Muy activo'
                              ],
                              onChanged: (value) => setState(() => _activityLevel = value!),
                            ),
                            const SizedBox(height: 12),
                            _buildModernDropdown(
                              label: 'Objetivo',
                              value: ['Perder peso (Agresivo)', 'Perder peso (Definición)', 'Mantener peso', 'Ganar masa (Limpio)', 'Ganar masa (Volumen)'].contains(_goal) ? _goal : 'Mantener peso',
                              icon: Icons.flag,
                              items: [
                                'Perder peso (Agresivo)',
                                'Perder peso (Definición)',
                                'Mantener peso',
                                'Ganar masa (Limpio)',
                                'Ganar masa (Volumen)'
                              ],
                              onChanged: (value) => setState(() => _goal = value!),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Condiciones Médicas
                        _buildSectionCard(
                          title: '🏥 Condiciones Médicas',
                          children: [
                            const Text(
                              'Selecciona las condiciones que apliquen:',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...[
                              'Diabetes',
                              'Hipertensión',
                              'Celíaco',
                              'Vegetariano',
                              'Vegano',
                            ].map((condition) {
                              final isSelected = _selectedConditions.contains(condition);
                              return CheckboxListTile(
                                title: Text(condition),
                                value: isSelected,
                                onChanged: (selected) {
                                  setState(() {
                                    if (selected == true) {
                                      _selectedConditions.add(condition);
                                    } else {
                                      _selectedConditions.remove(condition);
                                    }
                                  });
                                },
                                activeColor: const Color(0xFF1E88E5),
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                              );
                            }).toList(),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 12),
                            const Text(
                              'Agregar condición personalizada:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _customConditionController,
                                    decoration: InputDecoration(
                                      hintText: 'Ej: Alergia al maní',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    if (_customConditionController.text.isNotEmpty) {
                                      setState(() {
                                        _selectedConditions.add(_customConditionController.text);
                                        _customConditionController.clear();
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Condición agregada'),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E88E5),
                                    padding: const EdgeInsets.all(16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Icon(Icons.add, color: Colors.white),
                                ),
                              ],
                            ),
                            if (_selectedConditions.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Condiciones seleccionadas:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _selectedConditions.map((condition) {
                                  return Chip(
                                    label: Text(condition),
                                    deleteIcon: const Icon(Icons.close, size: 18),
                                    onDeleted: () {
                                      setState(() {
                                        _selectedConditions.remove(condition);
                                      });
                                    },
                                    backgroundColor: const Color(0xFF1E88E5).withOpacity(0.1),
                                    labelStyle: const TextStyle(
                                      color: Color(0xFF1E88E5),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Botón de guardar
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _saveChanges,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E88E5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'Guardar Cambios',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildBottomNavigation() {
    return NavigationBar(
      selectedIndex: 3,
      onDestinationSelected: (index) {
        if (index == 0) {
          Navigator.popUntil(context, (route) => route.isFirst);
        } else if (index == 1) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ChatScreen()),
          );
        } else if (index == 2) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MiBalanceScreen()),
          );
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Inicio',
        ),
        NavigationDestination(
          icon: Icon(Icons.chat_bubble_outline),
          selectedIcon: Icon(Icons.chat_bubble),
          label: 'Asistente',
        ),
        NavigationDestination(
          icon: Icon(Icons.assessment_outlined),
          selectedIcon: Icon(Icons.assessment),
          label: 'Balance',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Perfil',
        ),
      ],
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool enabled = true,
    Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1E88E5)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 2),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Este campo es requerido';
        }
        return null;
      },
    );
  }

  Widget _buildModernDropdown({
    required String label,
    required String value,
    required IconData icon,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1E88E5)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      items: items.map((item) {
        return DropdownMenuItem(value: item, child: Text(item));
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildBirthDateField() {
    return InkWell(
      onTap: _selectBirthDate,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Row(
          children: [
            const Icon(Icons.cake, color: Color(0xFF1E88E5)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fecha de Nacimiento',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _birthDate != null
                        ? '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year} (${_calculateAge(_birthDate!)} años)'
                        : 'Seleccionar fecha',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const Icon(Icons.calendar_today, color: Colors.grey),
          ],
        ),
      ),
    );
  }
  Widget _buildIMCPill() {
    double weight = double.tryParse(_weightController.text) ?? 0;
    double height = double.tryParse(_heightController.text) ?? 0;
    
    if (weight == 0 || height == 0) return const SizedBox();
    
    double imc = weight / ((height / 100) * (height / 100));
    
    Color color;
    String status;
    
    if (imc < 18.5) {
      color = Colors.blue;
      status = 'Bajo peso';
    } else if (imc < 25) {
      color = Colors.green;
      status = 'Normal';
    } else if (imc < 30) {
      color = Colors.orange;
      status = 'Sobrepeso';
    } else {
      color = Colors.red;
      status = 'Obesidad';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.monitor_weight_outlined, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            'IMC: ${imc.toStringAsFixed(1)} ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
