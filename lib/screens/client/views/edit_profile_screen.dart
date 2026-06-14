import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/client.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/balance_provider.dart';
import '../../../services/api_service.dart';
import 'chat_screen.dart';
import 'mi_balance_screen.dart';
import 'seguimiento_screen.dart';
import '../client_main_screen.dart';

class EditProfileScreen extends StatefulWidget {
  final Client client;
  final VoidCallback? onProfileUpdated;

  const EditProfileScreen({
    super.key,
    required this.client,
    this.onProfileUpdated,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool _isInitialized = false;

  late TextEditingController _weightController;
  late TextEditingController _heightController;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNamePaternalController;
  late TextEditingController _lastNameMaternalController;
  late TextEditingController _emailController;

  final List<String> _selectedConditions = [];
  String? _activityLevel;
  String? _goal;
  String? _workoutType;
  double? _sessionDuration;
  String? _gender;
  DateTime? _birthDate;

  // Grupos separados para mejor UX
  final List<String> _medicalOptions = [
    'Diabetes', 'Hipertensión', 'Asma', 'Enfermedad Cardiovascular', 'Intolerancia a la Lactosa', 'Celíaco',
  ];
  final List<String> _dietaryOptions = [
    'Vegano', 'Vegetariano', 'Ninguna',
  ];
  // Lista combinada para compatibilidad con el backend
  List<String> get _medicalConditionsOptions => [..._medicalOptions, ..._dietaryOptions];

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    _weightController  = TextEditingController(text: widget.client.weight.toStringAsFixed(1));
    _heightController  = TextEditingController(text: widget.client.height.toStringAsFixed(0));
    _firstNameController = TextEditingController(text: widget.client.firstName);
    _lastNamePaternalController = TextEditingController(text: widget.client.lastNamePaternal);
    _lastNameMaternalController = TextEditingController(text: widget.client.lastNameMaternal);
    _emailController = TextEditingController(text: widget.client.email);

    _selectedConditions.clear();
    _selectedConditions.addAll(widget.client.medicalConditions);

    for (var condition in _selectedConditions) {
      if (!_medicalConditionsOptions.contains(condition) && condition != 'Ninguna') {
        _medicalConditionsOptions.insert(_medicalConditionsOptions.length - 1, condition);
      }
    }
    _activityLevel = widget.client.activityLevel;
    _goal = widget.client.goal;
    _workoutType = widget.client.workoutType;
    _sessionDuration = widget.client.sessionDuration;
    _gender = widget.client.gender;
    _birthDate = widget.client.birthDate;
    _isInitialized = true;
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _firstNameController.dispose();
    _lastNamePaternalController.dispose();
    _lastNameMaternalController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFechaNacimiento() async {
    final hoy = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(hoy.year - 25, hoy.month, hoy.day),
      firstDate: DateTime(hoy.year - 100),
      lastDate: DateTime(hoy.year - 10, hoy.month, hoy.day),
      helpText: 'Fecha de nacimiento',
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  /// Diálogo de confirmación: avisa que guardar cambios quita la aprobación del plan.
  Future<bool> _confirmarCambiosPerfil() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 28),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Cambios en tu perfil',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    '⚠️ Si tu plan nutricional fue aprobado por tu nutricionista, '
                    'modificar tus datos (peso, talla, actividad, objetivo o condiciones médicas) '
                    'requiere una nueva aprobación.',
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      height: 1.5,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '¿Deseas guardar los cambios y solicitar nueva aprobación?',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Cancelar',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Guardar cambios'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // Capturar providers ANTES de cualquier await para evitar async-gap BuildContext
    final authProvider    = Provider.of<AuthProvider>(context, listen: false);
    final balanceProvider = Provider.of<BalanceProvider>(context, listen: false);

    // Mostrar confirmación antes de proceder
    final confirmed = await _confirmarCambiosPerfil();
    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      final current = widget.client;
      final updatedClient = Client(
        id: current.id,
        firstName: _firstNameController.text.trim(),
        lastNamePaternal: _lastNamePaternalController.text.trim(),
        lastNameMaternal: _lastNameMaternalController.text.trim(),
        email: _emailController.text.trim(),
        flutterUid: current.flutterUid,
        gender: _gender ?? current.gender,
        birthDate: _birthDate ?? current.birthDate,
        weight: double.tryParse(_weightController.text) ?? current.weight,
        height: double.tryParse(_heightController.text) ?? current.height,
        activityLevel: _activityLevel ?? current.activityLevel,
        goal: _goal ?? current.goal,
        workoutType: _workoutType ?? current.workoutType,
        sessionDuration: _sessionDuration ?? current.sessionDuration,
        medicalConditions: _selectedConditions.contains('Ninguna') ? [] : _selectedConditions,
        profilePictureUrl: current.profilePictureUrl,
        assignedNutriId: current.assignedNutriId,
        isProfileComplete: current.isProfileComplete,
      );

      await _apiService.updateClient(
        authProvider.userId!,
        updatedClient,
        authProvider.token!,
      );

      // Refresh the daily plan so BalanceCard shows recalculated macros
      if (mounted) {
        await balanceProvider.fetchFullBalance(authProvider.token!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil actualizado correctamente.'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onProfileUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showLogoutDialog(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('¿Cerrar Sesión?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Se cerrará tu sesión en el dispositivo y volverás a la pantalla de acceso.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCELAR', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              await authProvider.logout();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('SALIR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      _initControllers();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: _buildBottomNavigation(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -50,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        child: Text(
                          widget.client.firstName.isNotEmpty 
                            ? widget.client.firstName.substring(0, 1).toUpperCase() 
                            : 'U',
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E88E5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 60),
            
            // Cápsula de Nombre
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: Colors.blue.shade50),
                ),
                child: Column(
                  children: [
                    Text(
                      '${widget.client.firstName} ${widget.client.lastNamePaternal}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1565C0),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.client.email,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildMLBadge(),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Información Personal'),
                    _buildTextField(_firstNameController, 'Nombre', Icons.person_outline),
                    _buildTextField(_lastNamePaternalController, 'Apellido Paterno', Icons.person_outline),
                    _buildTextField(_lastNameMaternalController, 'Apellido Materno', Icons.person_outline),
                    _buildTextField(
                      _emailController,
                      'Correo electrónico',
                      Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Requerido';
                        final regex = RegExp(r'^[\w\.\-]+@[\w\-]+\.[\w\.\-]+$');
                        if (!regex.hasMatch(value.trim())) return 'Correo inválido';
                        return null;
                      },
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: DropdownButtonFormField<String>(
                              value: _gender,
                              decoration: InputDecoration(
                                labelText: 'Género',
                                prefixIcon: Icon(Icons.people_alt_outlined, color: Colors.blue.shade300),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 2)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'M', child: Text('Masculino')),
                                DropdownMenuItem(value: 'F', child: Text('Femenino')),
                              ],
                              onChanged: (v) => setState(() => _gender = v),
                              validator: (v) => v == null ? 'Requerido' : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: FormField<DateTime>(
                              validator: (_) => _birthDate == null ? 'Requerido' : null,
                              builder: (state) => InkWell(
                                onTap: () async {
                                  await _seleccionarFechaNacimiento();
                                  state.didChange(_birthDate);
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'Fecha de Nacimiento',
                                    prefixIcon: Icon(Icons.cake_outlined, color: Colors.blue.shade300),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 2)),
                                    errorText: state.errorText,
                                  ),
                                  child: Text(
                                    _birthDate != null
                                        ? '${_birthDate!.day.toString().padLeft(2, '0')}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.year}'
                                        : 'Seleccionar',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    _buildSectionTitle('Objetivo y Estilo de Vida'),
                    _buildDropdownField(
                      'Objetivo Principal', 
                      Icons.flag_rounded, 
                      _goal, 
                      {
                        'perder peso': 'Perder peso (Agresivo)',
                        'perder_leve': 'Perder peso (Definición)',
                        'mantener peso': 'Mantener peso',
                        'ganar_leve': 'Ganar masa (Limpio)',
                        'ganar masa': 'Ganar masa (Volumen)'
                      },
                      (val) => setState(() => _goal = val)
                    ),
                    _buildDropdownField(
                      'Nivel de Actividad', 
                      Icons.directions_run_rounded, 
                      _activityLevel, 
                      {
                        'Sedentario': 'Sedentario (0-1 días)',
                        'Ligero': 'Ligero (2-3 días)',
                        'Moderado': 'Moderado (3-5 días)',
                        'Activo': 'Activo (5-6 días)',
                        'Muy activo': 'Muy activo (Atleta/Intenso)'
                      },
                      (val) => setState(() => _activityLevel = val)
                    ),
                    _buildDropdownField(
                      'Tipo de Entrenamiento',
                      Icons.fitness_center_rounded,
                      _workoutType,
                      {
                        'Cardio': '🏃 Cardio (Correr, Bicicleta, Natación)',
                        'Strength': '💪 Fuerza (Pesas, Gym)',
                        'HIIT': '⚡ HIIT (Alta Intensidad)',
                        'Yoga': '🧘 Yoga / Flexibilidad',
                      },
                      (val) => setState(() => _workoutType = val)
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: DropdownButtonFormField<double>(
                        value: _sessionDuration,
                        decoration: InputDecoration(
                          labelText: 'Duración de Sesión',
                          prefixIcon: Icon(Icons.timer_rounded, color: Colors.blue.shade300),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: const Color(0xFF1E88E5), width: 2)),
                        ),
                        items: {
                          0.5: '30 minutos',
                          1.0: '1 hora',
                          1.5: '1 hora 30 minutos',
                          2.0: '2 horas o más',
                        }.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                        onChanged: (v) => setState(() => _sessionDuration = v),
                      ),
                    ),

                    const SizedBox(height: 20),
                    _buildSectionTitle('Medidas Físicas'),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(_weightController, 'Peso (kg)', Icons.monitor_weight_outlined, isNumber: true)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField(_heightController, 'Altura (cm)', Icons.height_outlined, isNumber: true)),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    _buildSectionTitle('Condiciones y Restricciones'),
                    const SizedBox(height: 12),
                    _buildGroupLabel('Condiciones Médicas', Icons.local_hospital_outlined),
                    const SizedBox(height: 10),
                    _buildChipGroup(_medicalOptions),
                    const SizedBox(height: 24),
                    _buildGroupLabel('Preferencias Alimenticias', Icons.restaurant_outlined),
                    const SizedBox(height: 10),
                    _buildChipGroup(_dietaryOptions),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _updateProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A237E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 8,
                          shadowColor: const Color(0xFF1A237E).withOpacity(0.5),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'GUARDAR CAMBIOS',
                                style: TextStyle(
                                  fontSize: 16, 
                                  fontWeight: FontWeight.bold, 
                                  color: Colors.white,
                                  letterSpacing: 1.5,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: () => _showLogoutDialog(context),
                        icon: const Icon(Icons.logout_rounded, size: 20),
                        label: const Text(
                          'CERRAR SESIÓN',
                          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Color(0xFFFFEBEE), width: 1.5),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF455A64),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isNumber = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType ?? (isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blue.shade300),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 2),
          ),
        ),
        validator: validator ?? (value) => value == null || value.isEmpty ? 'Requerido' : null,
      ),
    );
  }

  Widget _buildDropdownField(String label, IconData icon, String? currentValue, Map<String, String> itemsMap, ValueChanged<String?> onChanged) {
    final String? safeValue = (currentValue != null && itemsMap.containsKey(currentValue)) 
        ? currentValue 
        : (itemsMap.isNotEmpty ? itemsMap.keys.first : null);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: DropdownButtonFormField<String>(
        value: safeValue,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blue.shade300),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 2),
          ),
        ),
        items: itemsMap.entries.map((entry) {
          return DropdownMenuItem<String>(
            value: entry.key,
            child: Text(entry.value, overflow: TextOverflow.ellipsis, maxLines: 1),
          );
        }).toList(),
        selectedItemBuilder: (context) => itemsMap.entries
            .map(
              (e) => Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  e.value,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildGroupLabel(String label, IconData icon) {
    return Row(children: [
      Icon(icon, size: 14, color: Colors.blueGrey.shade400),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.blueGrey.shade500, letterSpacing: 0.5)),
    ]);
  }

  Widget _buildChipGroup(List<String> options) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: options.map((condition) {
        final isSelected = _selectedConditions.contains(condition);
        return FilterChip(
          label: Text(condition, style: const TextStyle(fontSize: 13)),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (condition == 'Ninguna') {
                _selectedConditions.clear();
                if (selected) _selectedConditions.add('Ninguna');
              } else {
                _selectedConditions.remove('Ninguna');
                selected ? _selectedConditions.add(condition) : _selectedConditions.remove(condition);
              }
            });
          },
          selectedColor: Colors.blue.shade100,
          checkmarkColor: Colors.blue.shade700,
          labelStyle: TextStyle(
            color: isSelected ? Colors.blue.shade900 : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          backgroundColor: Colors.grey.shade100,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: isSelected ? Colors.blue.shade300 : Colors.grey.shade300),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      }).toList(),
    );
  }

  Widget _buildBottomNavigation() {
    return NavigationBar(
      selectedIndex: 4,
      onDestinationSelected: (index) {
        if (index == 0) {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const ClientMainScreen()), (route) => false);
        } else if (index == 1) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
        } else if (index == 2) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MiBalanceScreen()));
        } else if (index == 3) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SeguimientoScreen()));
        }
      },
      backgroundColor: Colors.white,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
        NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Asistente'),
        NavigationDestination(icon: Icon(Icons.assessment_outlined), selectedIcon: Icon(Icons.assessment), label: 'Balance'),
        NavigationDestination(icon: Icon(Icons.trending_up_rounded), selectedIcon: Icon(Icons.trending_up), label: 'Seguimiento'),
        NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
      ],
    );
  }

  Widget _buildMLBadge() {
    // Calculamos dinámicamente el perfil base a la actividad para que sea visual.
    // (En un escenario real ideal, este valor vendría de widget.client.mlProfile)
    String perfilML;
    if (_activityLevel == 'Activo' || _activityLevel == 'Muy activo') {
      perfilML = 'PERFIL_A';
    } else if (_activityLevel == 'Moderado') {
      perfilML = 'PERFIL_B';
    } else {
      perfilML = 'PERFIL_C';
    }

    Color bgColor;
    Color textColor;
    Color borderColor;
    String label;
    IconData icon;

    switch (perfilML) {
      case 'PERFIL_A':
        bgColor = Colors.amber.shade50;
        textColor = Colors.orange.shade900;
        borderColor = Colors.amber.shade200;
        label = 'Atleta Disciplinado';
        icon = Icons.emoji_events_rounded;
        break;
      case 'PERFIL_B':
        bgColor = Colors.blue.shade50;
        textColor = Colors.blue.shade900;
        borderColor = Colors.blue.shade200;
        label = 'En Desarrollo';
        icon = Icons.trending_up_rounded;
        break;
      default: // PERFIL_C
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade900;
        borderColor = Colors.green.shade200;
        label = 'Iniciando el Camino';
        icon = Icons.directions_walk_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 18),
          const SizedBox(width: 8),
          Text(
            'Perfil IA: $label',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
