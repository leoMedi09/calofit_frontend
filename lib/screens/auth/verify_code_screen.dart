import 'package:flutter/material.dart';
import 'package:calofit_frontend/services/api_service.dart';

class VerifyCodeScreen extends StatefulWidget {
  final String? email; // Opcional aquí para soportar argumentos de ruta

  const VerifyCodeScreen({super.key, this.email});

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _apiService = ApiService();

  bool _isLoading = false;
  bool _obscureText = true;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _verifyAndReset(String email) async {
    final code = _codeController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // Validaciones locales antes de llamar al servidor
    if (code.length < 6) {
      _showSnackBar('❌ Ingresa el código completo de 6 dígitos');
      return;
    }
    if (password.isEmpty || password.length < 6) {
      _showSnackBar('❌ La contraseña debe tener al menos 6 caracteres');
      return;
    }
    if (password != confirmPassword) {
      _showSnackBar('❌ Las contraseñas no coinciden');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Llamada al servicio que creamos en ApiService
      final response = await _apiService.validateResetCode(
        email,
        code,
        password,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        _showSuccessDialog();
      } else {
        _showSnackBar('❌ ${response['message'] ?? 'Código incorrecto'}');
      }
    } catch (e) {
      _showSnackBar('❌ Error de conexión: verifica tu servidor local');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: message.contains('❌') ? Colors.redAccent : Colors.green,
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('✅ ¡Todo listo!'),
        content: const Text('Tu contraseña ha sido actualizada. Ya puedes iniciar sesión con tus nuevas credenciales.'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false),
            child: const Text('IR AL LOGIN'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Intentamos obtener el email del constructor, si no, lo buscamos en los argumentos de la ruta
    final String effectiveEmail = widget.email ?? ModalRoute.of(context)!.settings.arguments as String;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Verificación de Seguridad'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.shield_outlined, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 20),
            const Text(
              'Confirma tu identidad',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(color: Colors.grey, fontSize: 16),
                children: [
                  const TextSpan(text: 'Ingresa el código enviado a\n'),
                  TextSpan(
                    text: effectiveEmail,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 35),

            // Campo del Código
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: 'Código de 6 dígitos',
                hintText: '000000',
                prefixIcon: const Icon(Icons.lock_clock_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
            const SizedBox(height: 15),

            // Campo de Nueva Contraseña
            TextField(
              controller: _passwordController,
              obscureText: _obscureText,
              decoration: InputDecoration(
                labelText: 'Nueva Contraseña',
                prefixIcon: const Icon(Icons.password_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),

            // Campo de Confirmación
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureText,
              decoration: InputDecoration(
                labelText: 'Confirmar Contraseña',
                prefixIcon: const Icon(Icons.check_circle_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 40),

            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () => _verifyAndReset(effectiveEmail),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: const Text(
                  'ACTUALIZAR CONTRASEÑA',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}