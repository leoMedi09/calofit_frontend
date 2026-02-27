import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';

class CheckInWizardScreen extends StatefulWidget {
  final double currentWeight;
  final double currentHeight;

  const CheckInWizardScreen({
    super.key, 
    required this.currentWeight, 
    required this.currentHeight
  });

  @override
  State<CheckInWizardScreen> createState() => _CheckInWizardScreenState();
}

class _CheckInWizardScreenState extends State<CheckInWizardScreen> {
  final PageController _pageController = PageController();
  final ApiService _apiService = ApiService();
  
  late double _weight;
  late double _height;
  bool _isSaving = false;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _weight = widget.currentWeight;
    _height = widget.currentHeight;
  }

  void _nextPage() {
    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300), 
        curve: Curves.easeInOut
      );
      setState(() => _currentStep++);
    } else {
      _saveCheckIn();
    }
  }

  Future<void> _saveCheckIn() async {
    setState(() => _isSaving = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await _apiService.postCheckIn(
        auth.token!,
        {
          "weight": _weight,
          "height": _height,
          "activity_level": "Moderado", // Podría ser dinámico
        }
      );
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ ¡Check-in exitoso! Tu IA ha sido calibrada.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Calibración Semanal', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentStep + 1) / 3,
            backgroundColor: Colors.grey[100],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3F51B5)),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildWeightStep(),
                _buildHeightStep(),
                _buildSummaryStep(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 5,
                ),
                child: _isSaving 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      _currentStep == 2 ? 'FINALIZAR CALIBRACIÓN' : 'CONTINUAR',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightStep() {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.monitor_weight_rounded, size: 80, color: Color(0xFF3F51B5)),
          const SizedBox(height: 20),
          const Text(
            '¿Cuál es tu peso hoy?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1A237E)),
          ),
          const SizedBox(height: 10),
          Text(
            'Dato vital para ajustar tus macros de la próxima semana.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _weight.toStringAsFixed(1),
                style: const TextStyle(fontSize: 60, fontWeight: FontWeight.w900, color: Color(0xFF1A237E)),
              ),
              const SizedBox(width: 8),
              const Text('kg', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey)),
            ],
          ),
          Slider(
            value: _weight,
            min: widget.currentWeight - 15,
            max: widget.currentWeight + 15,
            activeColor: const Color(0xFF3F51B5),
            onChanged: (val) => setState(() => _weight = val),
          ),
          const SizedBox(height: 30),
          TextButton.icon(
            onPressed: () => _showGymReminder(),
            icon: const Icon(Icons.info_outline, size: 18),
            label: const Text('No tengo balanza en casa'),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  void _showGymReminder() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.fitness_center_rounded, color: Colors.orange),
            SizedBox(width: 10),
            Text('¡Misión Gym! 🏋️‍♂️'),
          ],
        ),
        content: const Text(
          '¡No hay excusas! Recuerda que en World Light Gym tenemos básculas y medidores de alta precisión esperándote.\n\nTu plan nutricional depende de estos datos. ¡Aprovecha tu entrenamiento hoy para calibrarlo!',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ENTENDIDO', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeightStep() {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.height_rounded, size: 80, color: Color(0xFF3F51B5)),
          const SizedBox(height: 20),
          const Text(
            '¿Tu talla sigue igual?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1A237E)),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _height.toStringAsFixed(0),
                style: const TextStyle(fontSize: 60, fontWeight: FontWeight.w900, color: Color(0xFF1A237E)),
              ),
              const SizedBox(width: 8),
              const Text('cm', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey)),
            ],
          ),
          Slider(
            value: _height,
            min: 100,
            max: 220,
            activeColor: const Color(0xFF3F51B5),
            onChanged: (val) => setState(() => _height = val),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStep() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 60, color: Colors.amber),
          const SizedBox(height: 30),
          const Text(
            '¡Todo listo para recalibrar!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1A237E)),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                _buildSummaryRow('Nuevo Peso', '${_weight.toStringAsFixed(1)} kg'),
                const Divider(height: 24),
                _buildSummaryRow('Talla', '${_height.toStringAsFixed(0)} cm'),
              ],
            ),
          ),
          const SizedBox(height: 30),
          const Text(
             'Al finalizar, el Asistente IA ajustará tu plan para la próxima semana.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1A237E))),
      ],
    );
  }
}
