import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';

class StaffRegistrationForm extends StatefulWidget {
  final BuildContext parentContext;
  const StaffRegistrationForm({super.key, required this.parentContext});

  @override
  State<StaffRegistrationForm> createState() => _StaffRegistrationFormState();
}

class _StaffRegistrationFormState extends State<StaffRegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  // Mapa estático para persistencia entre sesiones del modal
  static final Map<String, String> _persistedData = {};
  static String _persistedRole = 'NUTRI';
  static int _persistedRoleId = 3;
  static bool _persistedObscure = true;

  late final _firstNameController =
      TextEditingController(text: _persistedData['first_name'] ?? '');
  late final _paternalController =
      TextEditingController(text: _persistedData['paternal'] ?? '');
  late final _maternalController =
      TextEditingController(text: _persistedData['maternal'] ?? '');
  late final _emailController =
      TextEditingController(text: _persistedData['email'] ?? '');
  late final _passwordController =
      TextEditingController(text: _persistedData['password'] ?? '');
  late final _confirmPasswordController =
      TextEditingController(text: _persistedData['confirm'] ?? '');

  bool _isLoading = false;
  String? _apiError;

  final Map<String, int> _roleIds = {
    'ADMIN': 1,
    'NUTRI': 3,
    'COACH': 4,
  };

  @override
  void initState() {
    super.initState();
    _firstNameController.addListener(
        () => _persistedData['first_name'] = _firstNameController.text);
    _paternalController.addListener(
        () => _persistedData['paternal'] = _paternalController.text);
    _maternalController.addListener(
        () => _persistedData['maternal'] = _maternalController.text);
    _emailController
        .addListener(() => _persistedData['email'] = _emailController.text);
    _passwordController.addListener(
        () => _persistedData['password'] = _passwordController.text);
    _confirmPasswordController.addListener(
        () => _persistedData['confirm'] = _confirmPasswordController.text);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _paternalController.dispose();
    _maternalController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra indicadora superior (estética)
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              physics:
                  const ClampingScrollPhysics(), // Más eficiente para formularios
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    const Text(
                      'Nuevo Miembro',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A237E)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Complete los datos para el registro.',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    const SizedBox(height: 24),

                    _buildTextField(
                        _firstNameController, 'Nombres', Icons.person_outline),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: _buildTextField(_paternalController,
                                'A. Paterno', Icons.badge_outlined)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _buildTextField(_maternalController,
                                'A. Materno', Icons.badge_outlined)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(_emailController, 'Correo Electrónico',
                        Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 12),
                    _buildTextField(_passwordController, 'Contraseña Inicial',
                        Icons.lock_outline,
                        isPassword: true),
                    const SizedBox(height: 12),
                    _buildTextField(_confirmPasswordController,
                        'Confirmar Contraseña', Icons.lock_reset_rounded,
                        isPassword: true,
                        extraValidator: (v) => v != _passwordController.text
                            ? 'Las contraseñas no coinciden'
                            : null),
                    const SizedBox(height: 20),

                    const Text('Rol del Sistema',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 10),
                    _buildRoleSelector(),

                    if (_apiError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFEF9A9A)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Color(0xFFC62828), size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _apiError!,
                                style: const TextStyle(color: Color(0xFFC62828), fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _registerStaff,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A237E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text('Registrar Profesional',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    // Espacio final para asegurar que el contenido no quede pegado abajo
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {bool isPassword = false,
      TextInputType keyboardType = TextInputType.text,
      String? Function(String?)? extraValidator}) {
    final bool isMainPassword = label == 'Contraseña Inicial';
    final bool isConfirmPassword = label == 'Confirmar Contraseña';
    final bool isEmail = label == 'Correo Electrónico';
    final bool isPasswordField = isMainPassword || isConfirmPassword;

    return TextFormField(
      controller: controller,
      obscureText: isPasswordField && _persistedObscure,
      keyboardType: keyboardType,
      autofillHints: _getAutofillHints(label),
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF1A237E), size: 20),
        suffixIcon: isPasswordField
            ? IconButton(
                tooltip: 'Ver',
                icon: Icon(
                    _persistedObscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: Colors.grey,
                    size: 18),
                onPressed: () => setState(
                    () => _persistedObscure = !_persistedObscure),
              )
            : null,
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1A237E), width: 1)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Campo requerido';
        return extraValidator?.call(value);
      },
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _persistedRole,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: 'NUTRI', child: Text('Nutricionista')),
            DropdownMenuItem(value: 'COACH', child: Text('Entrenador')),
            DropdownMenuItem(value: 'ADMIN', child: Text('Administrador')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _persistedRole = value;
                _persistedRoleId = _roleIds[value]!;
              });
            }
          },
        ),
      ),
    );
  }

  Future<void> _registerStaff() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _apiError = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token ?? '';

      String email = _emailController.text.trim();
      if (email.isNotEmpty && !email.contains('@')) {
        email = '$email@worldlight.com';
      }

      final staffData = {
        'first_name': _firstNameController.text,
        'last_name_paternal': _paternalController.text,
        'last_name_maternal': _maternalController.text,
        'email': email,
        'password': _passwordController.text,
        'role': _persistedRole,
        'role_id': _persistedRoleId,
      };

      await _apiService.registerStaff(staffData, token);

      if (!mounted) return;

      Navigator.pop(context);
      _showSnackbar('Profesional registrado con éxito', isError: false);
      _clearFields();
    } catch (e) {
      if (mounted) {
        setState(() => _apiError = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message, {required bool isError}) {
    ScaffoldMessenger.of(widget.parentContext).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
        backgroundColor:
            isError ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 8,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Iterable<String>? _getAutofillHints(String label) {
    if (label.contains('Nombre')) return [AutofillHints.givenName];
    if (label.contains('Paterno')) return [AutofillHints.familyName];
    if (label.contains('Correo')) return [AutofillHints.email];
    if (label.contains('Contraseña')) return [AutofillHints.password];
    return null;
  }

  void _clearFields() {
    _firstNameController.clear();
    _paternalController.clear();
    _maternalController.clear();
    _emailController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    _persistedData.clear();
    setState(() {
      _persistedRole = 'NUTRI';
      _persistedRoleId = 3;
      _persistedObscure = true;
    });
  }
}
