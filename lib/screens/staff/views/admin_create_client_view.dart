import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';

/// Vista que únicamente el Admin puede ver para provisionar un nuevo cliente:
/// crea la cuenta en Firebase y el registro mínimo en el backend.
/// El cliente luego llena el resto de sus datos en el Onboarding.
class AdminCreateClientView extends StatefulWidget {
  final VoidCallback? onClientCreated;
  const AdminCreateClientView({super.key, this.onClientCreated});

  @override
  State<AdminCreateClientView> createState() => _AdminCreateClientViewState();
}

class _AdminCreateClientViewState extends State<AdminCreateClientView> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  int? _selectedNutriId;
  int? _selectedCoachId;

  static const Color _navy = Color(0xFF1565C0);
  static const Color _navyLight = Color(0xFF1E88E5);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _createClient() async {
    if (!_formKey.currentState!.validate()) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _isLoading = true);

    User? firebaseUser;
    try {
      // 1️⃣ Crear usuario en Firebase (solo el admin puede hacer esto)
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );
      firebaseUser = credential.user!;

      // 2️⃣ Crear registro mínimo en el backend con is_profile_complete = false
      await ApiService().adminCreateClient(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
        flutterUid: firebaseUser.uid,
        assignedNutriId: _selectedNutriId,
        assignedCoachId: _selectedCoachId,
        token: authProvider.token ?? '',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('✅ Cliente creado. Recibirá un onboarding al iniciar sesión.')),
            ]),
            backgroundColor: Colors.green.shade700,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
        widget.onClientCreated?.call();
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Error de autenticación';
      if (e.code == 'email-already-in-use') msg = 'Este correo ya está registrado en Firebase.';
      if (e.code == 'weak-password') msg = 'La contraseña es muy débil (mín. 6 caracteres).';
      if (e.code == 'invalid-email') msg = 'El formato del correo no es válido.';
      _showError(msg);
    } catch (e) {
      // Rollback Firebase si el backend falla
      if (firebaseUser != null) {
        try { await firebaseUser.delete(); } catch (_) {}
      }
      _showError('Error al crear el cliente. Intenta nuevamente.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [_navy, _navyLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Text('Nuevo Cliente', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(height: 8),
                Text('Las credenciales se entregarán directamente al cliente.\nEl perfil se completará en su primer inicio de sesión.',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
              ]),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Credenciales de Acceso', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF37474F))),
                    const SizedBox(height: 16),
                    // Email
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration('Correo Electrónico', Icons.email_outlined),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'El correo es requerido';
                        if (!v.contains('@') || !v.contains('.')) return 'Formato de correo inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    // Contraseña
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: !_isPasswordVisible,
                      decoration: _inputDecoration('Contraseña Temporal', Icons.lock_outlined).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(_isPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.grey),
                          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                        ),
                        helperText: 'Sugerencia: NombreApellido + año (Ej: LeonardoMedina2025)',
                        helperStyle: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                      validator: (v) {
                        if (v == null || v.length < 6) return 'Mínimo 6 caracteres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Info box
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(Icons.info_rounded, color: Colors.amber.shade700, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(
                          'El nutricionista y coach asignados se podrán configurar después desde el expediente del cliente.',
                          style: TextStyle(color: Colors.amber.shade900, fontSize: 12, fontWeight: FontWeight.w500),
                        )),
                      ]),
                    ),
                    const SizedBox(height: 24),

                    // Botones
                    Row(children: [
                      Expanded(
                        child: TextButton(
                          onPressed: _isLoading ? null : () => Navigator.pop(context),
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text('Cancelar', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _createClient,
                          icon: _isLoading
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.person_add_rounded, size: 18),
                          label: Text(_isLoading ? 'Creando...' : 'Crear Cliente',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _navy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 4,
                            shadowColor: _navy.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _navyLight, size: 20),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _navyLight, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.red)),
    );
  }
}
