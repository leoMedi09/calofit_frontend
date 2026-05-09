import 'package:flutter/material.dart';
import 'package:calofit_frontend/services/api_service.dart';

class VerifyCodeScreen extends StatefulWidget {
  final String? email;

  const VerifyCodeScreen({super.key, this.email});

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen>
    with SingleTickerProviderStateMixin {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _apiService = ApiService();

  bool _isVerifyingCode = false;
  bool _codeVerified = false;
  bool _isUpdatingPassword = false;
  bool _obscureText = true;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _animController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode(String email) async {
    final code = _codeController.text.trim();
    if (code.length < 6) {
      _showSnackBar('Ingresa el código completo de 6 dígitos');
      return;
    }

    setState(() => _isVerifyingCode = true);
    try {
      final response = await _apiService.verifyResetCode(email, code);
      if (!mounted) return;

      if (response['success'] == true) {
        setState(() {
          _codeVerified = true;
          _isVerifyingCode = false;
        });
        _animController.forward();
      } else {
        setState(() => _isVerifyingCode = false);
        _showSnackBar(response['message'] ?? 'Código incorrecto o expirado');
      }
    } catch (e) {
      if (mounted) setState(() => _isVerifyingCode = false);
      _showSnackBar('Error de conexión');
    }
  }

  Future<void> _updatePassword(String email) async {
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (password.isEmpty || password.length < 6) {
      _showSnackBar('La contraseña debe tener al menos 6 caracteres');
      return;
    }
    if (password != confirm) {
      _showSnackBar('Las contraseñas no coinciden');
      return;
    }

    setState(() => _isUpdatingPassword = true);
    try {
      final response = await _apiService.resetPassword(
          email, _codeController.text.trim(), password);
      if (!mounted) return;

      if (response['success'] == true) {
        _showSuccessDialog();
      } else {
        _showSnackBar(response['message'] ?? 'Error al actualizar contraseña');
      }
    } catch (e) {
      _showSnackBar('Error de conexión');
    } finally {
      if (mounted) setState(() => _isUpdatingPassword = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.check_circle_outline_rounded,
                color: Colors.green, size: 60),
            SizedBox(height: 16),
            Text('¡Todo listo!',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        content: const Text(
          'Tu contraseña ha sido actualizada exitosamente. Ya puedes ingresar con tu nueva clave.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context, '/login', (route) => false),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('IR AL LOGIN',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String email = widget.email ??
        ModalRoute.of(context)!.settings.arguments as String;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Verificación',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // Ícono con estado visual
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _codeVerified
                      ? const Icon(
                          Icons.verified_rounded,
                          key: ValueKey('verified'),
                          size: 72,
                          color: Colors.green,
                        )
                      : Icon(
                          Icons.shield_rounded,
                          key: const ValueKey('shield'),
                          size: 72,
                          color: Colors.blue[700],
                        ),
                ),
              ),
              const SizedBox(height: 28),

              // Título con estado visual
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _codeVerified ? '¡Código verificado!' : 'Confirma tu identidad',
                  key: ValueKey(_codeVerified),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _codeVerified ? Colors.green[700] : Colors.grey[900],
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                      color: Colors.grey[600], fontSize: 14, height: 1.5),
                  children: [
                    TextSpan(
                      text: _codeVerified
                          ? 'Ahora establece tu nueva contraseña para\n'
                          : 'Ingresa el código de 6 dígitos que enviamos a\n',
                    ),
                    TextSpan(
                      text: email,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Campo de código ──────────────────────────────────────────
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                enabled: !_codeVerified,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 12,
                  color: _codeVerified ? Colors.green[700] : Colors.black87,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '······',
                  hintStyle: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 28,
                      letterSpacing: 12),
                  suffixIcon: _codeVerified
                      ? const Icon(Icons.check_circle_rounded,
                          color: Colors.green)
                      : null,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.blue[700]!, width: 2)),
                  disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Colors.green, width: 2)),
                  filled: true,
                  fillColor: _codeVerified
                      ? Colors.green.shade50
                      : Colors.grey[50],
                ),
              ),

              const SizedBox(height: 24),

              // ── Botón verificar código (solo antes de verificar) ─────────
              if (!_codeVerified)
                SizedBox(
                  height: 52,
                  child: _isVerifyingCode
                      ? const Center(child: CircularProgressIndicator())
                      : FilledButton(
                          onPressed: () => _verifyCode(email),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'VERIFICAR CÓDIGO',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2),
                          ),
                        ),
                ),

              // ── Campos de contraseña (aparecen animados tras verificar) ──
              if (_codeVerified)
                FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Separador
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 8),
                          child: Row(children: [
                            Expanded(
                                child: Divider(color: Colors.grey[200])),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'Nueva contraseña',
                                style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            Expanded(
                                child: Divider(color: Colors.grey[200])),
                          ]),
                        ),
                        const SizedBox(height: 8),

                        // Contraseña
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscureText,
                          decoration: InputDecoration(
                            labelText: 'Nueva Contraseña',
                            prefixIcon:
                                const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureText
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded),
                              onPressed: () => setState(
                                  () => _obscureText = !_obscureText),
                            ),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Confirmar contraseña
                        TextField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureText,
                          decoration: InputDecoration(
                            labelText: 'Confirmar Contraseña',
                            prefixIcon:
                                const Icon(Icons.lock_clock_outlined),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Botón actualizar
                        SizedBox(
                          height: 52,
                          child: _isUpdatingPassword
                              ? const Center(
                                  child: CircularProgressIndicator())
                              : FilledButton(
                                  onPressed: () => _updatePassword(email),
                                  style: FilledButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  child: const Text(
                                    'ACTUALIZAR CONTRASEÑA',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
