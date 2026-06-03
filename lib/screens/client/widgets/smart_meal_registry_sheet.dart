import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/balance_provider.dart';
import '../../../services/api_service.dart';

class SmartMealRegistrySheet extends StatefulWidget {
  final void Function(String mensaje)? onRegister;
  final List<Map<String, dynamic>>? initialIngredients;

  const SmartMealRegistrySheet({
    super.key,
    this.onRegister,
    this.initialIngredients,
  });

  static void show(
    BuildContext context, {
    void Function(String)? onRegister,
    List<Map<String, dynamic>>? initialIngredients,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SmartMealRegistrySheet(
        onRegister: onRegister,
        initialIngredients: initialIngredients,
      ),
    );
  }

  @override
  State<SmartMealRegistrySheet> createState() => _SmartMealRegistrySheetState();
}

class _SmartMealRegistrySheetState extends State<SmartMealRegistrySheet> {
  final TextEditingController _qtyController  = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  bool    _isLoading    = false;
  String? _errorMessage;
  static final List<Map<String, dynamic>> _ingredients = [];
  late bool _isPreFilled;

  @override
  void initState() {
    super.initState();
    _isPreFilled = widget.initialIngredients != null && widget.initialIngredients!.isNotEmpty;
    if (_isPreFilled) {
      // Pre-fill desde recetario: reemplaza la lista estática con los ingredientes sugeridos
      _ingredients
        ..clear()
        ..addAll(widget.initialIngredients!);
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  double get totalKcal => _ingredients.fold(0.0, (s, i) => s + (i['kcal'] as num).toDouble());
  double get totalP    => _ingredients.fold(0.0, (s, i) => s + (i['p']   as num).toDouble());
  double get totalC    => _ingredients.fold(0.0, (s, i) => s + (i['c']   as num).toDouble());
  double get totalG    => _ingredients.fold(0.0, (s, i) => s + (i['g']   as num).toDouble());

  Future<void> _addIngredient() async {
    final qtyStrRaw = _qtyController.text.trim();
    final name      = _nameController.text.trim();
    setState(() => _errorMessage = null);

    if (qtyStrRaw.isEmpty || name.isEmpty) {
      setState(() => _errorMessage = 'Ingresa cantidad y alimento');
      return;
    }
    final cleanQtyStr = qtyStrRaw.replaceAll(RegExp(r'[^0-9.]'), '');
    final qty = double.tryParse(cleanQtyStr);
    if (qty == null || qty <= 0) {
      setState(() => _errorMessage = 'La cantidad no es válida');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.token == null) return;
      final result = await ApiService().parseIngredients('${cleanQtyStr}g de $name', auth.token!);
      if (result['ingredientes'] != null) {
        setState(() {
          for (var item in result['ingredientes']) {
            _ingredients.add({
              'name':     item['nombre'],
              'gramos':   item['gramos_totales'],
              'quantity': '${item['gramos_totales']}g',
              'kcal': item['calorias'],
              'p':    item['proteinas_g'],
              'c':    item['carbohidratos_g'],
              'g':    item['grasas_g'],
            });
          }
        });
        _qtyController.clear();
        _nameController.clear();
      } else {
        setState(() => _errorMessage = 'No se encontró información.');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmar() async {
    if (_ingredients.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.token == null) return;

      // Preparar lista con macros exactos del preview
      final alimentos = _ingredients.map((i) => {
        'nombre':          i['name'] as String,
        'gramos':          (i['gramos'] as num).toDouble(),
        'kcal':            (i['kcal']  as num).toDouble(),
        'proteinas_g':     (i['p']     as num).toDouble(),
        'carbohidratos_g': (i['c']     as num).toDouble(),
        'grasas_g':        (i['g']     as num).toDouble(),
      }).toList();

      final partes = _ingredients.map((i) => '${i['gramos']}g de ${i['name']}').join(', ');

      // Registro directo — usa macros del preview (sin re-estimación)
      await ApiService().registrarDirecto(
        alimentos: alimentos,
        token: auth.token!,
        textoOriginal: 'Registro manual: $partes',
      );

      final kcalTotal = alimentos.fold(0.0, (sum, a) => sum + (a['kcal'] as double));
      final nombresResumen = alimentos.length <= 2
          ? alimentos.map((a) => a['nombre']).join(' + ')
          : '${alimentos[0]['nombre']} y ${alimentos.length - 1} más';

      _ingredients.clear();

      if (mounted) {
        // Mostrar confirmación antes de cerrar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '✅ $nombresResumen — ${kcalTotal.toInt()} kcal registradas',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        Navigator.pop(context);

        // Refrescar balance en segundo plano
        final balance = Provider.of<BalanceProvider>(context, listen: false);
        balance.fetchFullBalance(auth.token!).catchError((_) {});
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Error al guardar: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: kToolbarHeight),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHandle(),
                  if (_isPreFilled) _buildPreFillBanner(),
                  _buildHeader(),
                  _buildInputSection(),
                  const Divider(height: 1, color: Color(0xFFF0F2F5)),
                  _buildIngredientList(),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Container(
        width: 40, height: 4,
        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
      ),
    );
  }

  Widget _buildPreFillBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.orange.shade700, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Encontramos un plato en nuestro recetario. Quita los ingredientes que no comiste antes de confirmar.',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade800, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Row(
        children: [
          const Icon(Icons.restaurant_menu_rounded, color: Color(0xFF2563EB), size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Registro Inteligente',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87)),
              Text(
                _isPreFilled ? 'Revisa y elimina lo que no comiste' : 'Añade alimentos con gramos exactos',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    const accent = Color(0xFF2563EB);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Campo gramos ─────────────────────────────────────
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _qtyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: Color(0xFF1E293B),
                    ),
                    decoration: InputDecoration(
                      hintText: '200',
                      hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 15),
                      suffixText: 'g',
                      suffixStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                          fontSize: 13),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: accent, width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // ── Campo nombre ─────────────────────────────────────
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _isLoading ? null : _addIngredient(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                    decoration: InputDecoration(
                      hintText: 'arroz, pollo...',
                      hintStyle: const TextStyle(color: Color(0xFFADB5BD), fontSize: 14),
                      prefixIcon: const Icon(Icons.search_rounded, color: accent, size: 19),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: accent, width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // ── Botón + ──────────────────────────────────────────
                SizedBox(
                  height: 52,
                  width: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _addIngredient,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      disabledBackgroundColor: Colors.grey.shade300,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: EdgeInsets.zero,
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : const Icon(Icons.add_rounded, color: Colors.white, size: 26),
                  ),
                ),
              ],
            ),
            // ── Error ─────────────────────────────────────────────────
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

  Widget _buildIngredientList() {
    if (_ingredients.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(Icons.shopping_basket_outlined, size: 52, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('Tu lista está vacía', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
            Text('Agrega alimentos arriba', style: TextStyle(color: Colors.grey.shade300, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _ingredients.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _ingredients[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                child: Icon(Icons.emoji_food_beverage_rounded, color: Colors.orange.shade400, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                    const SizedBox(height: 3),
                    Text(item['quantity'], style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    const SizedBox(height: 6),
                    Row(children: [
                      _badge('P ${item['p']}g', Colors.red.shade400),
                      const SizedBox(width: 5),
                      _badge('C ${item['c']}g', Colors.orange.shade400),
                      const SizedBox(width: 5),
                      _badge('G ${item['g']}g', Colors.blue.shade400),
                    ]),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${item['kcal']} kcal',
                      style: TextStyle(fontWeight: FontWeight.w800, color: Colors.orange.shade700, fontSize: 13)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setState(() => _ingredients.removeAt(index)),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.close_rounded, size: 15, color: Colors.red.shade300),
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

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Estimado',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(totalKcal.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87)),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 3, left: 3),
                      child: Text(' kcal', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black45)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _counterCol('Alimentos', '${_ingredients.length}', Colors.orange.shade500),
                _counterCol('Prot', '${totalP.toStringAsFixed(1)}g', Colors.red.shade400),
                _counterCol('Carb', '${totalC.toStringAsFixed(1)}g', Colors.amber.shade600),
                _counterCol('Gras', '${totalG.toStringAsFixed(1)}g', Colors.blue.shade400),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _ingredients.isEmpty || _isLoading ? null : _confirmar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  disabledBackgroundColor: Colors.grey.shade200,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isPreFilled ? Icons.check_circle_outline_rounded : Icons.save_outlined,
                            color: _ingredients.isEmpty ? Colors.grey.shade400 : Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isPreFilled ? 'Confirmar Registro' : 'Guardar Registro',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _ingredients.isEmpty ? Colors.grey.shade400 : Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _counterCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
