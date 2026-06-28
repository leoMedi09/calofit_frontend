import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';

class RoutineBuilderSheet extends StatefulWidget {
  const RoutineBuilderSheet({Key? key}) : super(key: key);

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const RoutineBuilderSheet(),
    );
  }

  @override
  State<RoutineBuilderSheet> createState() => _RoutineBuilderSheetState();
}

class _RoutineBuilderSheetState extends State<RoutineBuilderSheet> {
  final TextEditingController _nameController   = TextEditingController();
  final TextEditingController _seriesController = TextEditingController();
  final TextEditingController _repsController   = TextEditingController();
  final TextEditingController _pesoController   = TextEditingController();
  final TextEditingController _minutosController = TextEditingController();

  bool _isLoading = false;
  bool _isCardio  = false; // false = Fuerza (series/reps/kg), true = Cardio (minutos)
  String? _errorMessage;

  // Lista estática para persistir ejercicios entre rebuilds del sheet
  static final List<Map<String, dynamic>> _exercises = [];

  // ── Agregar ejercicio ────────────────────────────────────────────────────
  Future<void> _addExercise() async {
    final name    = _nameController.text.trim();
    final series  = _isCardio ? 0 : (int.tryParse(_seriesController.text.trim()) ?? 0);
    final reps    = _isCardio ? 0 : (int.tryParse(_repsController.text.trim()) ?? 0);
    final peso    = _isCardio ? 0.0 : (double.tryParse(_pesoController.text.trim().replaceAll(',', '.')) ?? 0.0);
    final minutos = _isCardio ? (double.tryParse(_minutosController.text.trim().replaceAll(',', '.')) ?? 0.0) : 0.0;

    setState(() => _errorMessage = null);

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Escribe el nombre del ejercicio');
      return;
    }
    if (_isCardio) {
      if (minutos <= 0) {
        setState(() => _errorMessage = 'Ingresa los minutos');
        return;
      }
    } else if (series <= 0 || reps <= 0) {
      setState(() => _errorMessage = 'Ingresa series y repeticiones');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.token == null) return;

      final result = await ApiService().calcularEjercicioManual(
        nombre: name,
        series: series,
        reps: reps,
        pesoKg: peso,
        duracionMin: minutos,
        token: auth.token!,
      );

      if (result['ejercicio'] != null) {
        final ex = result['ejercicio'] as Map<String, dynamic>;
        setState(() {
          _exercises.add({
            'name':        ex['nombre']     ?? name,
            'series':      ex['series']     ?? series,
            'reps':        ex['reps']       ?? reps,
            'peso_kg':     ex['peso_kg']    ?? peso,
            'duracion_min': ex['duracion_min'] ?? (minutos > 0 ? minutos : 10.0),
            'kcal':        (ex['calorias']  ?? 0.0).toDouble(),
            'met':         (ex['met']       ?? 5.0).toDouble(),
            'is_cardio':   _isCardio,
          });
        });
        _nameController.clear();
        _seriesController.clear();
        _repsController.clear();
        _pesoController.clear();
        _minutosController.clear();
      } else {
        setState(() => _errorMessage = 'No se encontró ese ejercicio. Prueba otro nombre.');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Registrar rutina completa ────────────────────────────────────────────
  Future<void> _saveRoutine() async {
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.token == null) return;

      final result = await ApiService().registrarRutinaManual(_exercises, auth.token!);

      if (result['success'] == true) {
        if (mounted) {
          final kcalTotal = (result['total_kcal'] ?? 0.0).toStringAsFixed(0);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Rutina registrada — $kcalTotal kcal quemadas'),
              backgroundColor: Colors.green.shade600,
            ),
          );
          setState(() => _exercises.clear());
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['mensaje'] ?? 'Error al registrar')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _seriesController.dispose();
    _repsController.dispose();
    _pesoController.dispose();
    _minutosController.dispose();
    super.dispose();
  }

  double get totalKcal => _exercises.fold(
      0.0, (sum, e) => sum + (e['kcal'] as num).toDouble());

  double get totalMinutes => _exercises.fold(
      0.0, (sum, e) => sum + (e['duracion_min'] as num).toDouble());

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: kToolbarHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: _KeyboardPadding(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  _buildInputSection(),
                  const Divider(height: 1, color: Color(0xFFF0F2F5)),
                  _buildExerciseList(),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 14),
          const Text(
            "Constructor de Rutinas",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            "Añade ejercicios con series, reps y peso",
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Campo de nombre ───────────────────────────────────────
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
              decoration: InputDecoration(
                hintText: 'Nombre del ejercicio (ej: Press Banca)',
                hintStyle: const TextStyle(color: Color(0xFFADB5BD), fontSize: 14),
                prefixIcon: const Icon(
                  Icons.fitness_center_rounded,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: Color(0xFF10B981), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Toggle Fuerza / Cardio ────────────────────────────────
            Row(
              children: [
                Expanded(child: _modeChip('Fuerza', Icons.fitness_center_rounded, !_isCardio, () => setState(() => _isCardio = false))),
                const SizedBox(width: 8),
                Expanded(child: _modeChip('Cardio', Icons.directions_run_rounded, _isCardio, () => setState(() => _isCardio = true))),
              ],
            ),
            const SizedBox(height: 12),

            // ── Campos según modo | Botón + ───────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_isCardio)
                  _numField(_minutosController, 'Minutos', '30', isDecimal: true)
                else ...[
                  _numField(_seriesController, 'Series', '3'),
                  const SizedBox(width: 8),
                  _numField(_repsController, 'Reps', '10'),
                  const SizedBox(width: 8),
                  _numField(_pesoController, 'Kg', '70', isDecimal: true),
                ],
                const SizedBox(width: 10),
                SizedBox(
                  height: 56,
                  width: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _addExercise,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      disabledBackgroundColor: Colors.grey.shade300,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: EdgeInsets.zero,
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : const Icon(Icons.add_rounded,
                            color: Colors.white, size: 28),
                  ),
                ),
              ],
            ),

            // ── Mensaje de error ──────────────────────────────────────
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _modeChip(String label, IconData icon, bool selected, VoidCallback onTap) {
    const accent = Color(0xFF10B981);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? accent : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : Colors.grey.shade500),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: selected ? Colors.white : Colors.grey.shade500,
            )),
          ],
        ),
      ),
    );
  }

  Widget _numField(
    TextEditingController ctrl,
    String label,
    String hint, {
    bool isDecimal = false,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 5),
          TextField(
            controller: ctrl,
            keyboardType: isDecimal
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: Color(0xFF1E293B),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: Color(0xFF10B981), width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseList() {
    if (_exercises.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.directions_run_rounded, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text("Tu rutina está vacía", style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: _exercises.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _exercises[index];
        final int    series  = item['series']  as int;
        final int    reps    = item['reps']    as int;
        final double pesoKg  = (item['peso_kg'] as num).toDouble();
        final double durMin  = (item['duracion_min'] as num).toDouble();
        final double kcal    = (item['kcal'] as num).toDouble();
        final double met     = (item['met'] as num).toDouble();
        final bool   isCardio = item['is_cardio'] == true;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                child: Icon(Icons.fitness_center_rounded, color: Colors.green.shade500, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    // Series × Reps @Peso
                    Row(
                      children: [
                        if (!isCardio)
                          _badge(
                            '$series × $reps${pesoKg > 0 ? " @${pesoKg.toStringAsFixed(pesoKg % 1 == 0 ? 0 : 1)}kg" : ""}',
                            Colors.green,
                          ),
                        if (!isCardio) const SizedBox(width: 6),
                        _badge('~${durMin.toStringAsFixed(0)} min', Colors.blue),
                        const SizedBox(width: 6),
                        _badge('MET $met', Colors.purple),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${kcal.toStringAsFixed(1)} kcal',
                    style: TextStyle(fontWeight: FontWeight.w800, color: Colors.orange.shade700, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => setState(() => _exercises.removeAt(index)),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.close_rounded, size: 16, color: Colors.red.shade400),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _badge(String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.shade50, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color.shade600)),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Total Estimado",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(totalKcal.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87)),
                    const Padding(
                        padding: EdgeInsets.only(bottom: 3, left: 2),
                        child: Text(" kcal",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statCol("Ejercicios", "${_exercises.length}", Colors.purple.shade400),
                _statCol("Duración est.", "${totalMinutes.toStringAsFixed(0)} min", Colors.blue.shade400),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _exercises.isEmpty ? null : _saveRoutine,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: const Text(
                  "Registrar Rutina",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _KeyboardPadding extends StatelessWidget {
  final Widget child;
  const _KeyboardPadding({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: child,
    );
  }
}
