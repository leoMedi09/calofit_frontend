import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/client.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../auth/terms_privacy_screen.dart';
import 'client_main_screen.dart';

class OnboardingProfileScreen extends StatefulWidget {
  final Client client;
  const OnboardingProfileScreen({super.key, required this.client});

  @override
  State<OnboardingProfileScreen> createState() => _OnboardingProfileScreenState();
}

class _OnboardingProfileScreenState extends State<OnboardingProfileScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final ApiService _apiService = ApiService();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  int _currentPage = 0;
  bool _isLoading = false;

  // Step 1 - Identidad
  final _firstNameCtrl = TextEditingController();
  final _lastNamePatCtrl = TextEditingController();
  final _lastNameMatCtrl = TextEditingController();
  String _selectedGender = 'M';
  DateTime? _birthDate;

  // Step 2 - Físico
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  String _activityLevel = 'Sedentario';
  String _goal = 'Mantener peso';
  String _workoutType = 'Cardio';        // 🆕 Para ML Random Forest
  double _sessionDuration = 1.0;         // 🆕 Para ML Random Forest

  // Step 3 - Salud
  final List<String> _selectedConditions = [];
  final List<String> _conditionOptions = [
    'Diabetes',
    'Hipertensión',
    'Asma',
    'Enfermedad Cardiovascular',
    'Intolerancia a la Lactosa',
    'Celíaco',
    'Vegano',
    'Vegetariano',
    'Ninguna',
  ];

  // Step 4 - Seguridad
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _acceptedTerms = false;

  static const Color _navy = Color(0xFF1565C0);
  static const Color _navyLight = Color(0xFF1E88E5);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
    _animController.forward();

    // Pre-fill if data already exists (partial profile)
    _firstNameCtrl.text = widget.client.firstName;
    _lastNamePatCtrl.text = widget.client.lastNamePaternal;
    _lastNameMatCtrl.text = widget.client.lastNameMaternal;
    _selectedGender = widget.client.gender;
    _birthDate = widget.client.birthDate;
    if (widget.client.weight > 0) _weightCtrl.text = widget.client.weight.toStringAsFixed(1);
    if (widget.client.height > 0) _heightCtrl.text = widget.client.height.toStringAsFixed(0);
    _activityLevel = widget.client.activityLevel;
    _goal = widget.client.goal;
    _workoutType = widget.client.workoutType;
    _sessionDuration = widget.client.sessionDuration;
    _selectedConditions.addAll(widget.client.medicalConditions);
  }

  @override
  void dispose() {
    _animController.dispose();
    _pageController.dispose();
    _firstNameCtrl.dispose();
    _lastNamePatCtrl.dispose();
    _lastNameMatCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1995),
      firstDate: DateTime(1940),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: _navy)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _finishOnboarding() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Validar contraseñas
    if (_passwordCtrl.text.isEmpty || _passwordCtrl.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La contraseña debe tener al menos 6 caracteres'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseñas no coinciden'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes aceptar los Términos y la Política de Privacidad'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Cambiar contraseña primero
      await _apiService.changePassword(authProvider.token!, _passwordCtrl.text, _confirmPasswordCtrl.text);

      // 2. Actualizar perfil
      final updated = Client(
        id: widget.client.id,
        email: widget.client.email,
        flutterUid: widget.client.flutterUid,
        firstName: _firstNameCtrl.text.trim(),
        lastNamePaternal: _lastNamePatCtrl.text.trim(),
        lastNameMaternal: _lastNameMatCtrl.text.trim(),
        gender: _selectedGender,
        birthDate: _birthDate,
        weight: double.tryParse(_weightCtrl.text) ?? 70.0,
        height: double.tryParse(_heightCtrl.text) ?? 170.0,
        activityLevel: _activityLevel,
        goal: _goal,
        workoutType: _workoutType,
        sessionDuration: _sessionDuration,
        medicalConditions: _selectedConditions.contains('Ninguna') ? [] : _selectedConditions,
        profilePictureUrl: widget.client.profilePictureUrl,
        assignedNutriId: widget.client.assignedNutriId,
        isProfileComplete: true,
        termsAcceptedAt: widget.client.termsAcceptedAt ?? DateTime.now(),
      );

      await _apiService.updateClient(authProvider.userId!, updated, authProvider.token!);
      authProvider.updateUserName(_firstNameCtrl.text.trim());
      await authProvider.markProfileComplete();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ClientMainScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _validateCurrentStep() {
    switch (_currentPage) {
      case 0:
        if (_firstNameCtrl.text.trim().isEmpty) {
          _showValidationError('Por favor ingresa tu nombre.');
          return false;
        }
        if (_lastNamePatCtrl.text.trim().isEmpty) {
          _showValidationError('Por favor ingresa tu apellido paterno.');
          return false;
        }
        if (_lastNameMatCtrl.text.trim().isEmpty) {
          _showValidationError('Por favor ingresa tu apellido materno.');
          return false;
        }
        if (_birthDate == null) {
          _showValidationError('Por favor selecciona tu fecha de nacimiento.');
          return false;
        }
        return true;
      case 1:
        final weight = double.tryParse(_weightCtrl.text);
        if (weight == null || weight <= 0 || weight > 300) {
          _showValidationError('Ingresa un peso válido (ej: 70).');
          return false;
        }
        final height = double.tryParse(_heightCtrl.text);
        if (height == null || height < 100 || height > 230) {
          _showValidationError('Ingresa tu altura en centímetros, sin decimales (ej: 170).');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _nextPage() {
    if (!_validateCurrentStep()) return;
    if (_currentPage < 3) {
      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      setState(() => _currentPage++);
      _animController.reset();
      _animController.forward();
    } else {
      _finishOnboarding();
    }
  }

  void _prevPage() {
    if (_currentPage == 0) return;
    _pageController.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    setState(() => _currentPage--);
    _animController.reset();
    _animController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Column(
        children: [
          _buildUnifiedHeader(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(),
                _buildStep2(),
                _buildStep3(),
                _buildStep4(),
              ],
            ),
          ),
          _buildBottomButton(),
        ],
      ),
    );
  }

  Widget _buildUnifiedHeader() {
    final steps = ['Identidad', 'Medidas', 'Salud', 'Seguridad'];
    final icons = [Icons.person_rounded, Icons.monitor_weight_rounded, Icons.favorite_rounded, Icons.lock_rounded];
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 20, bottom: 25, left: 24, right: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_navy, _navyLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [
          BoxShadow(color: Color(0x331565C0), blurRadius: 15, offset: Offset(0, 5))
        ],
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(35), bottomRight: Radius.circular(35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('¡Bienvenido a CaloFit! 👋', style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Cuéntanos sobre ti', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const SizedBox(height: 25),
          Row(
            children: List.generate(4, (i) {
              final isActive = i == _currentPage;
              final isDone = i < _currentPage;
              
              Color getBgColor() {
                if (isActive) return Colors.white;
                if (isDone) return Colors.greenAccent.withValues(alpha: 0.25);
                return Colors.white.withValues(alpha: 0.15);
              }
              
              Color getTextColor() {
                if (isActive) return _navy;
                if (isDone) return Colors.greenAccent;
                return Colors.white60;
              }

              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.symmetric(vertical: isActive ? 12 : 10, horizontal: 4),
                        decoration: BoxDecoration(
                          color: getBgColor(),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: isActive ? [const BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))] : [],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(isDone ? Icons.check_circle_rounded : icons[i], color: getTextColor(), size: isActive ? 18 : 16),
                            if (isActive || isDone) ...[
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(steps[i], style: TextStyle(color: getTextColor(), fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                              ),
                            ]
                          ],
                        ),
                      ),
                    ),
                    if (i < 3) 
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Container(
                          width: 8,
                          height: 3,
                          decoration: BoxDecoration(
                            color: isDone ? Colors.greenAccent.withValues(alpha: 0.6) : Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _sectionTitle('Datos Personales', Icons.badge_rounded),
            const SizedBox(height: 16),
            _field(_firstNameCtrl, 'Nombre', Icons.person_outline),
            _field(_lastNamePatCtrl, 'Apellido Paterno', Icons.person_outline),
            _field(_lastNameMatCtrl, 'Apellido Materno', Icons.person_outline),
            const SizedBox(height: 8),
            _sectionTitle('Género', Icons.people_alt_outlined),
            const SizedBox(height: 12),
            Row(children: [
              _genderChip('M', '♂ Masculino'),
              const SizedBox(width: 12),
              _genderChip('F', '♀ Femenino'),
            ]),
            const SizedBox(height: 20),
            _sectionTitle('Fecha de Nacimiento', Icons.cake_outlined),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _birthDate != null ? _navy : Colors.grey.shade200, width: 1.5),
                ),
                child: Row(children: [
                  Icon(Icons.calendar_today_rounded, color: _birthDate != null ? _navy : Colors.grey),
                  const SizedBox(width: 12),
                  Text(
                    _birthDate != null
                        ? '${_birthDate!.day.toString().padLeft(2, '0')}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.year}'
                        : 'Seleccionar fecha',
                    style: TextStyle(color: _birthDate != null ? Colors.black87 : Colors.grey, fontWeight: FontWeight.w500),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    // Mapa: Valor Backend -> Texto UI
    final activityLevels = {
      'Sedentario': 'Sedentario (0-1 días)',
      'Ligero': 'Ligero (2-3 días)',
      'Moderado': 'Moderado (3-5 días)',
      'Activo': 'Activo (5-6 días)',
      'Muy activo': 'Muy activo (Atleta/Intenso)'
    };
    
    // Mapa: Valor Backend -> Texto UI
    final goals = {
      'perder peso': 'Perder peso (Agresivo)',
      'perder_leve': 'Perder peso (Definición)',
      'mantener peso': 'Mantener peso',
      'ganar_leve': 'Ganar masa (Limpio)',
      'ganar masa': 'Ganar masa (Volumen)'
    };

    final workoutTypes = {
      'Cardio': '🏃 Cardio (Correr, Bicicleta, Natación)',
      'Strength': '💪 Fuerza (Pesas, Gym)',
      'HIIT': '⚡ HIIT (Alta Intensidad)',
      'Yoga': '🧘 Yoga / Flexibilidad',
    };

    final sessionDurations = {
      0.5: '30 minutos',
      1.0: '1 hora',
      1.5: '1 hora 30 minutos',
      2.0: '2 horas o más',
    };

    return FadeTransition(
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _sectionTitle('Medidas Físicas', Icons.straighten_rounded),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _field(_weightCtrl, 'Peso (kg)', Icons.monitor_weight_outlined, isNumber: true)),
              const SizedBox(width: 16),
              Expanded(child: _field(_heightCtrl, 'Altura (cm)', Icons.height_rounded, isNumber: true, isInteger: true)),
            ]),
            const SizedBox(height: 16),
            _sectionTitle('Objetivo Principal', Icons.flag_rounded),
            const SizedBox(height: 12),
            _dropdownMap('Objetivo', Icons.flag_rounded, _goal, goals, (v) => setState(() => _goal = v!)),
            const SizedBox(height: 16),
            _sectionTitle('Nivel de Actividad', Icons.directions_run_rounded),
            const SizedBox(height: 12),
            _dropdownMap('Nivel de Actividad', Icons.directions_run_rounded, _activityLevel, activityLevels, (v) => setState(() => _activityLevel = v!)),
            const SizedBox(height: 16),
            _sectionTitle('Tipo de Ejercicio Preferido', Icons.fitness_center_rounded),
            const SizedBox(height: 12),
            _dropdownMap('Tipo de Entrenamiento', Icons.fitness_center_rounded, _workoutType, workoutTypes, (v) => setState(() => _workoutType = v!)),
            const SizedBox(height: 16),
            _sectionTitle('Duración de Sesión', Icons.timer_rounded),
            const SizedBox(height: 12),
            DropdownButtonFormField<double>(
              value: _sessionDuration,
              decoration: InputDecoration(
                labelText: '¿Cuánto dura tu sesión?',
                prefixIcon: const Icon(Icons.timer_rounded, color: Color(0xFF1E88E5), size: 20),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 2)),
              ),
              items: sessionDurations.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: (v) => setState(() => _sessionDuration = v!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _sectionTitle('Condiciones y Restricciones', Icons.favorite_rounded),
            const SizedBox(height: 8),
            Text('Selecciona tus condiciones médicas o preferencias alimenticias.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _conditionOptions.map((condition) {
                final isSelected = _selectedConditions.contains(condition);
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: FilterChip(
                    label: Text(condition),
                    selected: isSelected,
                    onSelected: (val) => setState(() {
                      if (condition == 'Ninguna') {
                        _selectedConditions.clear();
                        if (val) _selectedConditions.add('Ninguna');
                      } else {
                        _selectedConditions.remove('Ninguna');
                        val ? _selectedConditions.add(condition) : _selectedConditions.remove(condition);
                      }
                    }),
                    selectedColor: _navyLight.withValues(alpha: 0.15),
                    checkmarkColor: _navy,
                    labelStyle: TextStyle(color: isSelected ? _navy : Colors.grey.shade700, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: isSelected ? _navyLight : Colors.grey.shade300, width: isSelected ? 2 : 1),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(children: [
                const Icon(Icons.verified_rounded, color: Colors.green, size: 28),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('¡Casi listo!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  Text('Al finalizar, tu plan nutricional personalizado estará listo.', style: TextStyle(color: Colors.green.shade800, fontSize: 12)),
                ])),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep4() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _sectionTitle('Seguridad de la Cuenta', Icons.lock_rounded),
            const SizedBox(height: 12),
            Text('Para proteger tu cuenta, por favor establece una contraseña personal. Esta reemplazará a tu DNI.', 
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 24),
            _field(_passwordCtrl, 'Nueva Contraseña', Icons.lock_outline, isPassword: true),
            _field(_confirmPasswordCtrl, 'Confirmar Contraseña', Icons.lock_clock_outlined, isPassword: true),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                Expanded(child: Text('Usa al menos 6 caracteres. Te recomendamos combinar letras y números.',
                  style: TextStyle(color: Colors.blue.shade800, fontSize: 12))),
              ]),
            ),
            const SizedBox(height: 20),
            _buildTermsCheckbox(),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _acceptedTerms,
            onChanged: (val) => setState(() => _acceptedTerms = val ?? false),
            activeColor: _navy,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
            behavior: HitTestBehavior.translucent,
            child: RichText(
              text: TextSpan(
                style: TextStyle(color: Colors.grey.shade800, fontSize: 13, height: 1.4),
                children: [
                  const TextSpan(text: 'Al activar tu cuenta aceptas los '),
                  TextSpan(
                    text: 'Términos y Condiciones · Política de Privacidad',
                    style: TextStyle(color: _navy, fontWeight: FontWeight.w700, decoration: TextDecoration.underline),
                    recognizer: TapGestureRecognizer()..onTap = _openTermsPrivacy,
                  ),
                  const TextSpan(text: ' de CaloFit.'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openTermsPrivacy() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsPrivacyScreen()));
  }

  Widget _buildBottomButton() {
    return Container(
      padding: EdgeInsets.only(left: 24, right: 24, bottom: MediaQuery.of(context).padding.bottom + 20, top: 16),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, -8))]),
      child: Row(
        children: [
          if (_currentPage > 0) ...[
            SizedBox(
              width: 56,
              height: 56,
              child: OutlinedButton(
                onPressed: _isLoading ? null : _prevPage,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(56, 56),
                  maximumSize: const Size(56, 56),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  side: BorderSide(color: _navy.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.arrow_back_rounded, color: _navy, size: 22),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 6,
                  shadowColor: _navy.withValues(alpha: 0.4),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(_currentPage == 3 ? '¡Activar Cuenta!' : 'Continuar', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
                        const SizedBox(width: 8),
                        Icon(_currentPage == 3 ? Icons.verified_user_rounded : Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                      ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(children: [
      Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: _navy.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: _navy, size: 18)),
      const SizedBox(width: 10),
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF37474F))),
    ]);
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, {bool isNumber = false, bool isPassword = false, bool isInteger = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        obscureText: isPassword,
        keyboardType: isNumber
            ? TextInputType.numberWithOptions(decimal: !isInteger)
            : TextInputType.text,
        textCapitalization: isPassword ? TextCapitalization.none : TextCapitalization.words,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _navyLight, size: 20),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _navyLight, width: 2)),
        ),
      ),
    );
  }

  Widget _genderChip(String value, String label) {
    final isSelected = _selectedGender == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedGender = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? _navy : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? _navy : Colors.grey.shade200, width: 2),
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _dropdownMap(String label, IconData icon, String currentVal, Map<String, String> itemsMap, ValueChanged<String?> onChanged) {
    // Si currentVal no es llave conocida, forzamos la primera de fallback
    final safeValue = itemsMap.containsKey(currentVal) ? currentVal : itemsMap.keys.first;

    return DropdownButtonFormField<String>(
      value: safeValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _navyLight, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _navyLight, width: 2)),
      ),
      items: itemsMap.entries
          .map(
            (entry) => DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value, overflow: TextOverflow.ellipsis, maxLines: 1),
            ),
          )
          .toList(),
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
    );
  }
}
