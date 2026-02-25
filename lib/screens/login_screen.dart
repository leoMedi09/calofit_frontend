import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Controladores para Cliente
  final _clientEmailController = TextEditingController();
  final _clientPasswordController = TextEditingController();
  bool _clientRememberMe = false;
  
  // Controladores para Personal
  final _staffEmailController = TextEditingController();
  final _staffPasswordController = TextEditingController();
  bool _staffRememberMe = false;
  
  bool _isLoading = false;
  String? _errorMessage;
  bool _isClientPasswordVisible = false;
  bool _isStaffPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _errorMessage = null; // Limpiar errores al cambiar de tab
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _clientEmailController.dispose();
    _clientPasswordController.dispose();
    _staffEmailController.dispose();
    _staffPasswordController.dispose();
    super.dispose();
  }

  Future<void> _login(bool isClient) async {
    String email = (isClient ? _clientEmailController.text : _staffEmailController.text).trim();
    final password = isClient ? _clientPasswordController.text : _staffPasswordController.text;
    final rememberMe = isClient ? _clientRememberMe : _staffRememberMe;

    
    debugPrint('🔐 Iniciando login en TAB: ${isClient ? "CLIENTE" : "PERSONAL"}');
    debugPrint('📧 Email: $email');
    debugPrint('🔄 isStaff será: ${!isClient}');
    
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Por favor, ingresa tu email y contraseña');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Provider.of<AuthProvider>(context, listen: false)
          .login(email, password, rememberMe, isStaff: isClient ? false : true);

      if (!mounted) return;

      final auth = Provider.of<AuthProvider>(context, listen: false);

      if (auth.isAuthenticated) {
          final String finalType = auth.userType?.toLowerCase() ?? '';
          debugPrint('🚀 Login exitoso. Rol detectado: $finalType');
          
          String route = (finalType == 'staff' || finalType == 'admin') 
              ? '/staff-main' 
              : '/dashboard';
          
          debugPrint('🎯 Navegando a ruta: $route');
          Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
      } else {
        setState(() => _errorMessage = 'No se pudo validar la sesión.');
      }

    } catch (e) {
      debugPrint('❌ Error capturado en UI: $e');
      if (!mounted) return;
      
      String message;
      if (e.toString().contains('SocketException') || e.toString().contains('connection errored') || e.toString().contains('No route to host')) {
        message = 'No se pudo conectar al servidor. Revisa tu conexión Wi-Fi y el Firewall.';
      } else {
        message = isClient 
            ? 'Credenciales incorrectas. Verifica tu email y contraseña.'
            : 'Acceso denegado. Verifica tus credenciales o contacta al administrador.';
      }

      setState(() {
        _errorMessage = message;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('CaloFit', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue[700],
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue[700],
          indicatorWeight: 3,
          tabs: const [
            Tab(
              icon: Icon(Icons.fitness_center),
              text: 'Cliente',
            ),
            Tab(
              icon: Icon(Icons.groups),
              text: 'Personal',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildClientLoginForm(),
          _buildStaffLoginForm(),
        ],
      ),
    );
  }

  // ==================== FORMULARIO CLIENTE ====================
  Widget _buildClientLoginForm() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_circle, size: 80, color: Colors.blue[600]),
              const SizedBox(height: 8),
              const Text(
                'Bienvenido de nuevo',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Inicia sesión para continuar',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _clientEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Correo Electrónico',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.email),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _clientPasswordController,
                obscureText: !_isClientPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isClientPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: Colors.grey,
                    ),
                    onPressed: () => setState(() => _isClientPasswordVisible = !_isClientPasswordVisible),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              
              Row(
                children: [
                  Checkbox(
                    value: _clientRememberMe,
                    onChanged: (value) {
                      setState(() {
                        _clientRememberMe = value ?? false;
                      });
                    },
                    activeColor: Colors.blue,
                  ),
                  const Text('Recordar sesión'),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
                    child: const Text('¿Olvidaste tu contraseña?'),
                  ),
                ],
              ),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
                
              const SizedBox(height: 16),
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: () => _login(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Ingresar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
              const SizedBox(height: 24),
              
              // SOLO PARA CLIENTES: Link de registro
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('¿No tienes cuenta?'),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/register'),
                    child: const Text('Regístrate', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== FORMULARIO PERSONAL ====================
  Widget _buildStaffLoginForm() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.badge, size: 80, color: Colors.blue[600]),
              const SizedBox(height: 8),
              const Text(
                'Acceso de Personal',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Solo personal autorizado',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _staffEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Correo Electrónico',
                  hintText: 'ejemplo@correo.com',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.email_outlined),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _staffPasswordController,
                obscureText: !_isStaffPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isStaffPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: Colors.grey,
                    ),
                    onPressed: () => setState(() => _isStaffPasswordVisible = !_isStaffPasswordVisible),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              
              Row(
                children: [
                  Checkbox(
                    value: _staffRememberMe,
                    onChanged: (value) {
                      setState(() {
                        _staffRememberMe = value ?? false;
                      });
                    },
                    activeColor: Colors.blue,
                  ),
                  const Text('Recordar sesión'),
                ],
              ),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
                
              const SizedBox(height: 16),
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: () => _login(false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Ingresar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
              const SizedBox(height: 24),
              
              // ADVERTENCIA PARA STAFF: No hay registro
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Si eres nutricionista o entrenador, contacta al administrador para obtener tu acceso.',
                        style: TextStyle(color: Colors.orange[900], fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
