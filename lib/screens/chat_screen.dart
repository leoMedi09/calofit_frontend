import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/client.dart';
import 'edit_profile_screen.dart';
import 'mi_balance_screen.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/assistant_response.dart';
import '../widgets/chat_bubble.dart';
import '../providers/balance_provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  
  final ApiService _apiService = ApiService();
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  
  bool _isTyping = false;
  bool _isListening = false;
  bool _isKeyboardVisible = false;
  bool _isMuted = false; 
  String? _speakingMessageId; 
  Client? _clientProfile; 
  String? _latestFuzzyHint;

  // 🔄 ONE-STREAM: Una sola lista de mensajes
  final List<Map<String, dynamic>> _messages = [
    {
      'role': 'assistant',
      'response': AssistantResponse(
        usuario: '',
        dataCientifica: ScientificData(progresoDiario: {}),
        respuestaEstructurada: StructuredResponse(
          textoConversacional: '¡Hola! Soy CaloFit. 🤖\nPuedes preguntarme sobre nutrición o simplemente decirme "Comí arroz con pollo" para registrarlo.',
          secciones: []
        )
      ),
      'type': 'assistant_v3',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initTts();
    _focusNode.addListener(_onFocusChange);
    _loadClientProfile();
  }

  Future<void> _loadClientProfile() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.userId != null && auth.token != null) {
        final profile = await _apiService.getClientProfile(auth.userId!, auth.token!);
        if (mounted) setState(() => _clientProfile = profile);
      }
    } catch (e) {
      debugPrint('Error cargando perfil: $e');
    }
  }

  void _onFocusChange() {
    setState(() => _isKeyboardVisible = _focusNode.hasFocus);
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("es-MX");
    await _flutterTts.setSpeechRate(0.55);
    await _flutterTts.setPitch(1.0);
    _flutterTts.setCompletionHandler(() => setState(() => _speakingMessageId = null));
  }

  // Se inicia bajo demanda para no molestar con permisos al abrir

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _speak(String content, String messageId) async {
    if (_speakingMessageId == messageId) {
      await _flutterTts.stop();
      setState(() => _speakingMessageId = null);
    } else {
      setState(() => _speakingMessageId = messageId);
      String plainText = content
          .replaceAll(RegExp(r'\*+'), '')
          .replaceAll(RegExp(r'#+'), '')
          .trim();
      await _flutterTts.speak(plainText);
    }
  }

  Future<void> _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) => print('Micro status: $status'),
        onError: (errorNotification) => print('Micro error: $errorNotification'),
      );
      
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          localeId: "es_MX", // Forzar español latino
          onResult: (val) {
            setState(() {
              _inputController.text = val.recognizedWords;
              if (val.finalResult) {
                _isListening = false;
                Future.delayed(const Duration(milliseconds: 500), () {
                   _handleUnifiedSubmit();
                });
              }
            });
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permiso de micrófono denegado. Actívalo en ajustes.')),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  // 🧠 SMART ROUTING SYSTEM
  Future<void> _handleUnifiedSubmit({String? quickMessage}) async {
    final text = quickMessage ?? _inputController.text.trim();
    if (text.isEmpty) return;

    if (quickMessage == null) _inputController.clear();

    setState(() {
      _messages.add({'role': 'user', 'content': text, 'type': 'text'});
      _isTyping = true;
    });
    _scrollToBottom();

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final balance = Provider.of<BalanceProvider>(context, listen: false);
    final token = auth.token;

    if (token == null) return;

    // Detectar Intención Simple (Heurística del lado del cliente para rapidez)
    final lowerText = text.toLowerCase();
    
    // Palabras detonantes de REGISTRO
    final logKeywords = [
      "comí", "comi", "almorzé", "almorcé", "cené", "desayuné", "tomé", "bebí", "ingerí",
      "registra", "anota", "apunta", "hice", "entrené", "corrí", "troté", "agregame", "clavé", "zampé",
      "me clavé", "me zampé", "me comí", "sali", "salí", "fui", "correr", "caminar", "andar", "gym", "gimnasio", "pesas"
    ];
    
    bool isLogIntent = logKeywords.any((k) => lowerText.startsWith(k) || lowerText.contains(" $k "));

    try {
      if (isLogIntent) {
        // 👉 RUTA REGISTRO (/log-inteligente)
        final result = await _apiService.registrarPorVoz(text, token);
        
        if (result['balance_actualizado'] != null) {
          balance.updateFromAssistant(result['balance_actualizado']);
          // Actualización silenciosa de listas para la pantalla de Balance
          balance.fetchFullBalance(token).catchError((e) => print("Silent refresh failed: $e"));
        }

        setState(() {
          _isTyping = false;
          // Agregamos una tarjeta especial de registro
          _messages.add({
            'role': 'assistant',
            'content': result['mensaje'] ?? 'Registrado.',
            'type': 'registro_exitoso', // Esto renderizará la Card Visual
            'badge': result['tipo_detectado'],
            'data': result['datos'] // Pasar macros para mostrar en la card
          });
          
          if (!_isMuted) _speak(result['mensaje'], "reg_${_messages.length}");
        });

      } else {
        // 👉 RUTA CONSULTA (/consultar)
        // Construir historial reducido
        final history = _messages.length > 2 
          ? _messages.sublist(_messages.length > 6 ? _messages.length - 6 : 0, _messages.length - 1)
            .where((m) => m['type'] != 'registro_exitoso') // Filtrar logs puros del historial de chat
            .map((m) {
               String content = "";
               if (m['role'] == 'user') content = m['content'];
               else if (m['response'] is AssistantResponse) content = (m['response'] as AssistantResponse).respuestaEstructurada.textoConversacional;
               else content = m['content'] ?? "";
               return {'role': m['role'] == 'user' ? 'user' : 'assistant', 'content': content};
            }).toList() 
          : null;

        final result = await _apiService.consultarAsistente(text, token, historial: history);
        final responseObj = AssistantResponse.fromJson(result);
        
        // Actualizar datos si la consulta trajo progreso (ej: "¿cuánto me falta?")
        balance.updateFromAssistant(responseObj.dataCientifica.progresoDiario);

        setState(() {
          _isTyping = false;
          _latestFuzzyHint = result['control_adaptativo']?['mensaje_fuzzy'];
          _messages.add({
            'role': 'assistant',
            'response': responseObj,
            'type': 'assistant_v3'
          });

          // v21.1: Speech inteligente corregido
          String ttsText = responseObj.respuestaEstructurada.textoConversacional;
          if (responseObj.respuestaEstructurada.secciones.isNotEmpty) {
            final names = responseObj.respuestaEstructurada.secciones
                .map((s) => s.nombre.replaceAll('**', '').trim())
                .join(", ");
            ttsText = "${ttsText.split('.').first}. Te sugiero: $names";
          }
          
          if (!_isMuted) _speak(ttsText, "answ_${_messages.length}");
        });
      }
    } catch (e) {
      setState(() {
        _isTyping = false;
        _messages.add({'role': 'assistant', 'content': 'Ups, tuve un problema de conexión. 📶', 'type': 'error'});
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5), // Color de fondo más moderno (Gris azulado suave)
      appBar: _buildUnifiedAppBar(),
      body: Column(
        children: [
          
          Expanded(child: _buildMessageList()),
          
          if (_isTyping) _buildTypingIndicator(),
          if (!_isTyping && _messages.length < 3) _buildQuickActions(),
          _buildInputArea(),
          _buildStickyStatusBar(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  PreferredSizeWidget _buildUnifiedAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue.shade50,
            child: const Icon(Icons.smart_toy_rounded, color: Colors.blue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Asistente CaloFit', style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  _latestFuzzyHint ?? 'En línea', 
                  style: TextStyle(color: Colors.green.shade600, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (_speakingMessageId != null)
          IconButton(
            icon: const Icon(Icons.stop_circle_outlined, color: Colors.red),
            tooltip: 'Detener voz',
            onPressed: () async {
              await _flutterTts.stop();
              setState(() => _speakingMessageId = null);
            },
          )
        else
          IconButton(
            icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up, color: Colors.grey.shade600),
            tooltip: _isMuted ? 'Activar voz' : 'Silenciar voz',
            onPressed: () => setState(() => _isMuted = !_isMuted),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: Colors.grey.shade200, height: 1),
      ),
    );
  }

  Widget _buildStickyStatusBar() {
    return Consumer<BalanceProvider>(
      builder: (context, provider, _) {
        final summary = provider.dailySummary;
        if (summary == null) return const SizedBox.shrink();
        
        final meta = summary.planObjetivo?.caloriasObjetivo ?? 2000;
        final restante = (meta - summary.calorias).clamp(0, meta);
        
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: const Color(0xFFE3F2FD),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_fire_department_rounded, size: 14, color: Colors.orange.shade700),
              const SizedBox(width: 6),
              Text(
                "Restan ${restante.toStringAsFixed(0)} kcal hoy",
                style: TextStyle(color: Colors.blue.shade900, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigation() {
    return NavigationBar(
      selectedIndex: 1,
      onDestinationSelected: (index) async {
        if (index == 0) {
          Navigator.popUntil(context, (route) => route.isFirst);
        } else if (index == 2) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MiBalanceScreen()));
        } else if (index == 3) {
          final auth = Provider.of<AuthProvider>(context, listen: false);
          if (auth.userId == null || auth.token == null) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay una sesión activa.')));
            return;
          }
          try {
            final client = await _apiService.getClientProfile(auth.userId!, auth.token!);
            if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => EditProfileScreen(client: client)));
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al obtener perfil: $e')));
          }
        }
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
        NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Asistente'), // Corrección aquí: label corregido de 'Asistente' a 'Chat' si se prefiere o dejarlo 'Asistente'
        NavigationDestination(icon: Icon(Icons.assessment_outlined), selectedIcon: Icon(Icons.assessment), label: 'Balance'),
        NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
      ],
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        
        if (msg['type'] == 'registro_exitoso') {
          return _buildRichLogCard(msg);
        } else if (msg['role'] == 'assistant' && msg['response'] is AssistantResponse) {
          return AssistantMessageBubble(
            response: msg['response'],
            onAction: (text) => _handleUnifiedSubmit(quickMessage: text),
          );
        } else if (msg['role'] == 'user') {
          return _buildUserBubble(msg['content']);
        }
        
        // Bubbles de texto simple (errores, etc)
        return _buildSimpleSystemBubble(msg['content'], isError: msg['type'] == 'error');
      },
    );
  }

  Widget _buildRichLogCard(Map<String, dynamic> msg) {
    // Tarjeta visual impactante para confirmación de registro
    final isFood = msg['badge'] == 'comida' || msg['badge'] == 'alimento'; // Ajustar según backend return
    final data = msg['data'] ?? {};
    final kcal = data['calorias'] ?? 0;
    
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
          border: Border.all(color: isFood ? Colors.orange.shade100 : Colors.green.shade100, width: 2),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isFood ? Colors.orange.shade50 : Colors.green.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Icon(isFood ? Icons.restaurant_menu_rounded : Icons.directions_run_rounded, 
                      color: isFood ? Colors.orange : Colors.green, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(isFood ? "Comida Registrada" : "Ejercicio Registrado", 
                      style: TextStyle(fontWeight: FontWeight.bold, color: isFood ? Colors.orange.shade800 : Colors.green.shade800)),
                  ),
                  if (data['calidad'] != null && isFood)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getQualityColor(data['calidad']),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        data['calidad'].toString().toUpperCase(),
                        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(msg['content'], style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 12),
                  if (kcal > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMiniStat(Icons.flash_on_rounded, "$kcal kcal", Colors.orange, isMain: true),
                        const SizedBox(height: 12),
                        
                        // 🔥 MACROS PRINCIPALES
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (isFood && (data['proteinas_g'] ?? 0) > 0) 
                              _buildMiniStat(Icons.fitness_center_rounded, "${data['proteinas_g']}g Prot", Colors.red.shade400),
                            if (isFood && (data['carbohidratos_g'] ?? 0) > 0)
                              _buildMiniStat(Icons.grain_rounded, "${data['carbohidratos_g']}g Carb", Colors.orange.shade400),
                            if (isFood && (data['grasas_g'] ?? 0) > 0)
                              _buildMiniStat(Icons.water_drop_rounded, "${data['grasas_g']}g Gras", Colors.blue.shade400),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // 🍭 MICROS (Azúcar, Fibra, Sodio) - Diseño más sutil
                        if (isFood) 
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                               if ((data['azucar_g'] ?? 0) > 0) 
                                 _buildMiniStat(Icons.icecream_rounded, "${data['azucar_g']}g Azú", Colors.purple.shade300, isMicro: true),
                               if ((data['fibra_g'] ?? 0) > 0)
                                 _buildMiniStat(Icons.eco_rounded, "${data['fibra_g']}g Fib", Colors.green.shade600, isMicro: true),
                               if ((data['sodio_mg'] ?? 0) > 0)
                                 _buildMiniStat(Icons.opacity_rounded, "${data['sodio_mg']}mg Sod", Colors.blueGrey.shade400, isMicro: true),
                            ],
                          ),
                      ],
                    )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMiniStat(IconData icon, String text, Color color, {bool isMain = false, bool isMicro = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: isMain ? 16 : 14, color: color),
        const SizedBox(width: 4),
        Text(
          text, 
          style: TextStyle(
            fontSize: isMain ? 14 : (isMicro ? 11 : 12), 
            fontWeight: isMain ? FontWeight.bold : FontWeight.w600, 
            color: isMicro ? Colors.grey.shade600 : Colors.grey.shade800
          )
        )
      ],
    );
  }

  Widget _buildUserBubble(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 50),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB), // Azul brillante moderno
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
            topRight: Radius.circular(4),
          ),
          boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 6, offset: const Offset(2, 4))],
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 15)),
      ),
    );
  }

  Widget _buildSimpleSystemBubble(String? text, {bool isError = false}) {
     return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 50),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isError ? Colors.red.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isError ? Colors.red.shade100 : Colors.grey.shade200),
        ),
        child: Text(text ?? '...', style: TextStyle(color: isError ? Colors.red.shade800 : Colors.black87)),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 20),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
            Text('Procesando...', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _quickChip("🥕 Poca caloría", "Dame opciones de cenas bajas en calorías"),
          _quickChip("💪 Rutina Express", "Rutina de 15 min en casa"),
          _quickChip("🍎 Comí una manzana", "Registra que me comí una manzana"),
        ],
      ),
    );
  }

  Widget _quickChip(String label, String message) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        backgroundColor: Colors.white,
        side: BorderSide(color: Colors.grey.shade300),
        shape: StadiumBorder(),
        onPressed: () => _handleUnifiedSubmit(quickMessage: message),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), // Reducido el padding inferior para conectar con el status bar
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          GestureDetector(
            onLongPress: _listen, // Mantener presionado para hablar? No, tap to toggle better UX
            onTap: _listen,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isListening ? Colors.red.shade100 : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(_isListening ? Icons.mic : Icons.mic_none_rounded, 
                color: _isListening ? Colors.red : Colors.grey.shade700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _inputController,
                focusNode: _focusNode,
                decoration: const InputDecoration(
                  hintText: 'Escribe o di "Comí..."',
                  border: InputBorder.none,
                  hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _handleUnifiedSubmit(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _handleUnifiedSubmit(),
            child: CircleAvatar(
              backgroundColor: const Color(0xFF2563EB),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Color _getQualityColor(dynamic quality) {
    if (quality == null) return Colors.grey;
    final q = quality.toString().toLowerCase();
    if (q.contains('alta')) return Colors.green;
    if (q.contains('media')) return Colors.orange;
    if (q.contains('baja')) return Colors.red;
    return Colors.grey;
  }
}
