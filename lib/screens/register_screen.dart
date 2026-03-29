import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/auth.dart';
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  final _auth = FirebaseAuth.instance;

  // Controladores
  final _firstNameController = TextEditingController();
  final _lastNamePaternalController = TextEditingController();
  final _lastNameMaternalController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _medicalConditionsController = TextEditingController();

  // Estados
  String _selectedActivityLevel = 'Sedentario (Sin entrenar)';
  String _selectedGoal = 'Mantener peso';
  String _selectedGender = 'Masculino';
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  final List<String> _activityLevels = [
    'Sedentario (Sin entrenar)',
    'Ligero (2 a 3 veces por semana)',
    'Moderado (3 a 5 veces por semana)',
    'Activo (5 a 6 veces por semana)',
    'Muy activo (Atleta o trabajo pesado)'
  ];

  final List<String> _goals = [
    'Perder peso (Agresivo)',
    'Perder peso (Definición)',
    'Mantener peso',
    'Ganar masa (Limpio)',
    'Ganar masa (Volumen)'
  ];

  final List<String> _genders = ['Masculino', 'Femenino', 'Otro'];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNamePaternalController.dispose();
    _lastNameMaternalController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _birthDateController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _medicalConditionsController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _birthDateController.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar('Las contraseñas no coinciden', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    User? firebaseUser;

    try {
      // 🚀 1️⃣ Crear usuario en Firebase
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      firebaseUser = userCredential.user;
      final String firebaseUid = firebaseUser!.uid;

      // 🛠️ 2️⃣ Registrar en tu backend
      final request = ClientRegisterRequest(
        firstName: _firstNameController.text.trim(),
        lastNamePaternal: _lastNamePaternalController.text.trim(),
        lastNameMaternal: _lastNameMaternalController.text.trim(),
        email: _emailController.text.trim(),

        // 🔐 Backend manda
        password: _passwordController.text.trim(),

        weight: double.parse(_weightController.text),

        // 📏 m → cm
        height: double.parse(_heightController.text) * 100,

        medicalConditionsText: _medicalConditionsController.text.trim(),
        activityLevel: _selectedActivityLevel,
        goal: _selectedGoal,
        birthDate: _birthDateController.text,

        gender: _selectedGender == 'Masculino'
            ? 'M'
            : _selectedGender == 'Femenino'
                ? 'F'
                : 'M',

        flutterUid: firebaseUid,
        assignedCoachId: 1,
        assignedNutriId: 1,
      );

      await _apiService.registerClient(request);

      if (mounted) {
        _showSnackBar('🎉 ¡Registro exitoso! Ya puedes iniciar sesión.');
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String errorMsg = 'Error en Firebase';
      if (e.code == 'email-already-in-use')
        errorMsg = 'Este correo ya está registrado.';
      if (e.code == 'weak-password') errorMsg = 'La contraseña es muy débil.';
      _showSnackBar(errorMsg, isError: true);
    } catch (e) {
      // 🔥 ROLLBACK: borrar usuario de Firebase si backend falla
      if (firebaseUser != null) {
        await firebaseUser.delete();
      }
      _showSnackBar('Error al registrar. Intenta nuevamente.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Registro de Cliente',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // MENSAJE ACLARATORIO PARA STAFF
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '💡 Si eres nutricionista, contacta al administrador para obtener tu acceso.',
                              style: TextStyle(
                                  color: Colors.blue[900], fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                          labelText: 'Nombre',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _lastNamePaternalController,
                            decoration: const InputDecoration(
                                labelText: 'Ap. Paterno',
                                border: OutlineInputBorder()),
                            validator: (v) => v!.isEmpty ? 'Requerido' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _lastNameMaternalController,
                            decoration: const InputDecoration(
                                labelText: 'Ap. Materno',
                                border: OutlineInputBorder()),
                            validator: (v) => v!.isEmpty ? 'Requerido' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                          labelText: 'Correo Electrónico',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder()),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => v!.isEmpty || !v.contains('@')
                          ? 'Correo inválido'
                          : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: Colors.grey,
                            ),
                            onPressed: () => setState(
                                () => _isPasswordVisible = !_isPasswordVisible),
                          ),
                          border: const OutlineInputBorder()),
                      obscureText: !_isPasswordVisible,
                      validator: (v) =>
                          v!.length < 6 ? 'Mínimo 6 caracteres' : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _confirmPasswordController,
                      decoration: InputDecoration(
                          labelText: 'Confirmar Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isConfirmPasswordVisible
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: Colors.grey,
                            ),
                            onPressed: () => setState(() =>
                                _isConfirmPasswordVisible =
                                    !_isConfirmPasswordVisible),
                          ),
                          border: const OutlineInputBorder()),
                      obscureText: !_isConfirmPasswordVisible,
                      validator: (v) =>
                          v!.isEmpty ? 'Confirme su contraseña' : null,
                    ),

                    const Divider(height: 40, thickness: 2),
                    const Text('Información Personal y Física',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 15),

                    // Selector de Fecha de Nacimiento
                    TextFormField(
                      controller: _birthDateController,
                      readOnly: true,
                      onTap: () => _selectDate(context),
                      decoration: const InputDecoration(
                        labelText: 'Fecha de Nacimiento',
                        prefixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v!.isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 15),

                    // Selector de Género
                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: const InputDecoration(
                          labelText: 'Género',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder()),
                      items: _genders
                          .map(
                              (g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedGender = val!),
                    ),
                    const SizedBox(height: 15),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _weightController,
                            decoration: const InputDecoration(
                                labelText: 'Peso (kg)',
                                border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                            validator: (v) => v!.isEmpty ? '?' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _heightController,
                            decoration: const InputDecoration(
                                labelText: 'Altura (m)',
                                border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                            validator: (v) => v!.isEmpty ? '?' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    DropdownButtonFormField<String>(
                      value: _selectedActivityLevel,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Nivel de Actividad Física',
                          border: OutlineInputBorder()),
                      items: _activityLevels
                          .map((lvl) => DropdownMenuItem(
                              value: lvl,
                              child: Text(lvl,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1)))
                          .toList(),
                      selectedItemBuilder: (BuildContext context) {
                        return _activityLevels.map<Widget>((String lvl) {
                          return Text(lvl,
                              overflow: TextOverflow.ellipsis, maxLines: 1);
                        }).toList();
                      },
                      onChanged: (val) =>
                          setState(() => _selectedActivityLevel = val!),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: _selectedGoal,
                      decoration: const InputDecoration(
                          labelText: 'Objetivo Principal',
                          border: OutlineInputBorder()),
                      items: _goals
                          .map(
                              (g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedGoal = val!),
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _medicalConditionsController,
                      decoration: const InputDecoration(
                        labelText: 'Condiciones médicas o alergias',
                        hintText: 'Ej: Diabetes, Asma...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),

                    const SizedBox(height: 30),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _register,
                            style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10))),
                            child: const Text('Registrarse',
                                style: TextStyle(fontSize: 18)),
                          ),
                    const SizedBox(height: 15),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('¿Ya tienes cuenta? Inicia sesión'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
