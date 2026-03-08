import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/client.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/url_service.dart';
import '../config/api_config.dart';
import 'chat_screen.dart';
import 'mi_balance_screen.dart';
import 'login_screen.dart';

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
  String? _profilePictureUrl;
  File? _localImageFile; // Nueva variable para previsualización local

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.client.firstName);
    _paternalController = TextEditingController(text: widget.client.lastNamePaternal);
    _maternalController = TextEditingController(text: widget.client.lastNameMaternal);
    _emailController = TextEditingController(text: widget.client.email);
    _weightController = TextEditingController(text: widget.client.weight.toStringAsFixed(1));
    _heightController = TextEditingController(text: widget.client.height.toStringAsFixed(1));
    _selectedConditions = widget.client.medicalConditions
        ?.where((c) => c != 'Ninguna')
        .toList() ?? [];
    _activityLevel = widget.client.activityLevel;
    _goal = widget.client.goal;
    _birthDate = widget.client.birthDate;
    _profilePictureUrl = widget.client.profilePictureUrl;
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

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _localImageFile = File(image.path);
      });
    }
  }

  void _viewFullScreenImage() {
    if (_localImageFile == null && (_profilePictureUrl == null || _profilePictureUrl!.isEmpty)) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(
          imageFile: _localImageFile,
          imageUrl: UrlService.formatImageUrl(_profilePictureUrl),
        ),
      ),
    );
  }

  // Centralized URL formatting now handled by UrlService.formatImageUrl

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
      
      // 1. Subir foto si hay una nueva previsualizada
      if (_localImageFile != null) {
        final imageUrl = await _apiService.uploadProfilePicture(
          authProvider.token!, 
          _localImageFile!.path, 
          false
        );
        _profilePictureUrl = imageUrl;
      }

      // 2. Guardar el resto de cambios del perfil
      List<String> finalConditions = List<String>.from(_selectedConditions);
      finalConditions.remove('Ninguna');

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
        profilePictureUrl: _profilePictureUrl,
        medicalConditions: finalConditions,
      );

      await _apiService.updateClient(
          widget.client.id,
          updatedClient,
          authProvider.token!
      );

      // ✅ IMPORTANTE: Sincronizar el estado global con la nueva foto para que el Dashboard se entere
      if (_profilePictureUrl != null && _profilePictureUrl!.isNotEmpty) {
        await authProvider.updateProfilePictureUrl(_profilePictureUrl!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Perfil actualizado correctamente'),
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
      backgroundColor: const Color(0xFFF8F9FE),
      body: CustomScrollView(
        slivers: [
          // Header Moderno con Gradiente (Indigo-Blue-Cyan)
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Fondo Gradiente
                Container(
                  height: 280,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1A237E), Color(0xFF1E88E5), Color(0xFF00ACC1)],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(50),
                      bottomRight: Radius.circular(50),
                    ),
                  ),
                ),
                // Título
                const Positioned(
                  top: 50,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      'Mi Perfil',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
                // Avatar y Nombre
                Positioned(
                  top: 100,
                  left: 24,
                  right: 24,
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              child: CircleAvatar(
                                radius: 45,
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage: _localImageFile != null 
                                    ? FileImage(_localImageFile!) as ImageProvider
                                    : (_profilePictureUrl != null && _profilePictureUrl!.isNotEmpty
                                        ? NetworkImage(UrlService.formatImageUrl(_profilePictureUrl))
                                        : null),
                                child: (_localImageFile == null && (_profilePictureUrl == null || _profilePictureUrl!.isEmpty))
                                    ? Text(
                                        (widget.client.firstName).substring(0, 1).toUpperCase(),
                                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
                                      )
                                    : null,
                              ),
                            ),
                            // Botón de Cámara (Editar)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1E88E5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                            // Botón de Ojo (Ver)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _viewFullScreenImage,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Colors.indigo,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.remove_red_eye_rounded, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${widget.client.firstName} ${widget.client.lastNamePaternal}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22, 
                          fontWeight: FontWeight.w900, 
                          color: Colors.white,
                          letterSpacing: -0.5
                        ),
                      ),
                      Text(
                        'CLIENTE PREMIUM',
                        style: TextStyle(
                          fontSize: 11, 
                          fontWeight: FontWeight.w700, 
                          color: Colors.white.withAlpha(230),
                          letterSpacing: 2.0
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // Contenido de los Formularios
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
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
                        _buildSectionHeader('INFORMACIÓN PERSONAL'),
                        const SizedBox(height: 12),
                        _buildInfoCardV2([
                          _buildProfileInputTile(Icons.person_rounded, 'Nombre(s)', _firstNameController),
                          _buildProfileInputTile(Icons.badge_rounded, 'Apellido Paterno', _paternalController),
                          _buildProfileInputTile(Icons.badge_outlined, 'Apellido Materno', _maternalController),
                          _buildProfileInputTile(Icons.email_rounded, 'Correo Electrónico', _emailController, enabled: false),
                          _buildBirthDateTileV2(),
                        ]),

                        const SizedBox(height: 24),
                        _buildSectionHeader('DATOS FÍSICOS'),
                        const SizedBox(height: 12),
                        _buildInfoCardV2([
                          Row(
                            children: [
                              Expanded(child: _buildProfileInputTile(Icons.monitor_weight_rounded, 'Peso (kg)', _weightController, keyboardType: TextInputType.number, onChanged: (v) => setState(() {}))),
                              const SizedBox(width: 8),
                              Expanded(child: _buildProfileInputTile(Icons.height_rounded, 'Altura (cm)', _heightController, keyboardType: TextInputType.number, onChanged: (v) => setState(() {}))),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: _buildIMCPillV2(),
                          ),
                        ]),

                        const SizedBox(height: 24),
                        _buildSectionHeader('ESTILO DE VIDA'),
                        const SizedBox(height: 12),
                        _buildInfoCardV2([
                          _buildDropdownTile(
                            Icons.fitness_center_rounded, 
                            'Nivel de Actividad', 
                            _activityLevel, 
                            [
                              'Sedentario (Sin entrenar)',
                              'Ligero (2 a 3 veces por semana)',
                              'Moderado (3 a 5 veces por semana)',
                              'Activo (5 a 6 veces por semana)',
                              'Muy activo (Atleta o trabajo pesado)'
                            ],
                            (val) => setState(() => _activityLevel = val!)
                          ),
                          _buildDropdownTile(
                            Icons.flag_rounded, 
                            'Objetivo', 
                            _goal, 
                            ['Perder peso (Agresivo)', 'Perder peso (Definición)', 'Mantener peso', 'Ganar masa (Limpio)', 'Ganar masa (Volumen)'],
                            (val) => setState(() => _goal = val!)
                          ),
                        ]),

                        const SizedBox(height: 24),
                        _buildSectionHeader('CONDICIONES MÉDICAS'),
                        const SizedBox(height: 12),
                        _buildConditionsCardV2(),

                        const SizedBox(height: 32),
                        
                        // Botón de Guardar Premium
                        Container(
                          width: double.infinity,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1A237E), Color(0xFF1E88E5)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1E88E5).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              )
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveChanges,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            child: const Text(
                              'GUARDAR CAMBIOS',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),
                        
                        // Botón de Cerrar Sesión
                        Container(
                          width: double.infinity,
                          height: 60,
                          margin: const EdgeInsets.only(bottom: 40),
                          child: OutlinedButton(
                            onPressed: () {
                              final authProvider = Provider.of<AuthProvider>(context, listen: false);
                              _showLogoutDialog(context, authProvider);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Color(0xFFFFEBEE), width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              backgroundColor: Colors.white,
                            ),
                            child: const Text(
                              'CERRAR SESIÓN',
                              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2),
                            ),
                          ),
                        ),
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

  // --- WIDGETS DE REDISEÑO PREMIUM ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13, 
          fontWeight: FontWeight.w800, 
          color: Color(0xFF3949AB), 
          letterSpacing: 1.2
        ),
      ),
    );
  }

  Widget _buildInfoCardV2(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(children: children),
    );
  }

  Widget _buildProfileInputTile(IconData icon, String label, TextEditingController controller, {bool enabled = true, TextInputType? keyboardType, Function(String)? onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F4FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF3949AB), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w700)),
                TextFormField(
                  controller: controller,
                  enabled: enabled,
                  keyboardType: keyboardType,
                  onChanged: onChanged,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBirthDateTileV2() {
    return InkWell(
      onTap: _selectBirthDate,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F4FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.cake_rounded, color: Color(0xFF3949AB), size: 20),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fecha de Nacimiento', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  _birthDate != null
                      ? '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year} (${_calculateAge(_birthDate!)} años)'
                      : 'Seleccionar...',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.calendar_today_rounded, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownTile(IconData icon, String label, String value, List<String> items, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F4FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF3949AB), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w700)),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: items.contains(value) ? value : items.first,
                    isDense: true,
                    isExpanded: true,
                    onChanged: onChanged,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                    items: items.map((String item) {
                      return DropdownMenuItem<String>(value: item, child: Text(item, overflow: TextOverflow.ellipsis));
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIMCPillV2() {
    double weight = double.tryParse(_weightController.text) ?? 0;
    double height = double.tryParse(_heightController.text) ?? 0;
    if (weight == 0 || height == 0) return const SizedBox();
    double imc = weight / ((height / 100) * (height / 100));
    Color color = imc < 18.5 ? Colors.blue : imc < 25 ? Colors.green : imc < 30 ? Colors.orange : Colors.red;
    String status = imc < 18.5 ? 'Bajo peso' : imc < 25 ? 'Normal' : imc < 30 ? 'Sobrepeso' : 'Obesidad';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.monitor_weight_outlined, color: color, size: 18),
          const SizedBox(width: 8),
          Text('IMC: ${imc.toStringAsFixed(1)} ', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
            child: Text(status, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionsCardV2() {
    return _buildInfoCardV2([
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text('Selecciona lo que aplique:', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
      ),
      ...['Diabetes', 'Hipertensión', 'Celíaco', 'Vegetariano', 'Vegano'].map((c) {
        return CheckboxListTile(
          title: Text(c, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          value: _selectedConditions.contains(c),
          onChanged: (v) => setState(() => v! ? _selectedConditions.add(c) : _selectedConditions.remove(c)),
          activeColor: const Color(0xFF3949AB),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          dense: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        );
      }),
      const Divider(indent: 16, endIndent: 16),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customConditionController,
                decoration: InputDecoration(
                  hintText: 'Ej: Alergia al maní',
                  hintStyle: const TextStyle(fontSize: 13),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF8F9FE),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                if (_customConditionController.text.isNotEmpty) {
                  setState(() {
                    _selectedConditions.add(_customConditionController.text);
                    _customConditionController.clear();
                  });
                }
              },
              icon: const Icon(Icons.add_circle),
              color: const Color(0xFF3949AB),
            ),
          ],
        ),
      ),
      if (_selectedConditions.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _selectedConditions.map((c) => Chip(
              label: Text(c, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF3949AB))),
              backgroundColor: const Color(0xFFF1F4FF),
              deleteIcon: const Icon(Icons.cancel, size: 14, color: Color(0xFF3949AB)),
              onDeleted: () => setState(() => _selectedConditions.remove(c)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
            )).toList(),
          ),
        ),
    ]);
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('¿Cerrar Sesión?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Se cerrará tu sesión y volverás a la pantalla de acceso.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCELAR', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold))),
          ElevatedButton(
            onPressed: () async {
              await authProvider.logout();
              if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('SALIR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
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
}

class FullScreenImageViewer extends StatelessWidget {
  final File? imageFile;
  final String? imageUrl;

  const FullScreenImageViewer({super.key, this.imageFile, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: imageFile != null
                  ? Image.file(imageFile!)
                  : (imageUrl != null
                      ? Image.network(
                          imageUrl!,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(child: CircularProgressIndicator(color: Colors.white));
                          },
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, color: Colors.white, size: 50),
                        )
                      : const Icon(Icons.person, color: Colors.white, size: 100)),
            ),
          ),
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
