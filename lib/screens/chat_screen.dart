import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/client.dart';
import 'edit_profile_screen.dart';
import 'mi_balance_screen.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // Para kIsWeb si fuera necesario

// 🚀 Modelo de Datos Estructurado para el Asistente (Ideal para Tesis)
class AiSection {
  final String tipo;
  final String? nombre;
  final dynamic ingredientes; // Puede ser String o List
  final dynamic preparacion;  // Puede ser String o List
  final String? justificacion;
  final List<String>? ejercicios;
  final String? contenido;

  AiSection({
    required this.tipo,
    this.nombre,
    this.ingredientes,
    this.preparacion,
    this.justificacion,
    this.ejercicios,
    this.contenido,
  });

  factory AiSection.fromJson(Map<String, dynamic> json) {
    return AiSection(
      tipo: json['tipo'] ?? 'general',
      nombre: json['nombre'] ?? json['plato'],
      ingredientes: json['ingredientes'],
      preparacion: json['preparacion'],
      justificacion: json['justificacion'] ?? json['motivacion'] ?? json['descripcion'],
      ejercicios: json['ejercicios'] != null ? List<String>.from(json['ejercicios']) : null,
      contenido: json['contenido'] ?? json['respuesta'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tipo': tipo,
      'nombre': nombre,
      'ingredientes': ingredientes,
      'preparacion': preparacion,
      'justificacion': justificacion,
      'ejercicios': ejercicios,
      'contenido': contenido,
    };
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _consultController = TextEditingController();
  final TextEditingController _registerController = TextEditingController();
  final ScrollController _consultScrollController = ScrollController();
  final ScrollController _registerScrollController = ScrollController();
  
  final FocusNode _consultFocusNode = FocusNode();
  final FocusNode _registerFocusNode = FocusNode();
  
  final ApiService _apiService = ApiService();
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  
  bool _isTyping = false;
  bool _isListening = false;
  bool _isKeyboardVisible = false;
  bool _isMuted = false; 
  String? _speakingMessageId; 
  Client? _clientProfile; // Perfil cargado para personalización

  final List<Map<String, dynamic>> _consultMessages = [
    {
      'role': 'assistant',
      'content': '¡Hola! Soy tu asistente CaloFit. 🤖 Pregúntame lo que quieras sobre tu dieta, ejercicios o progreso.',
      'type': 'text',
    },
  ];

  final List<Map<String, dynamic>> _registerLogs = [
    {
      'role': 'assistant',
      'content': 'Dime qué comiste o qué ejercicio hiciste hoy para registrarlo. 🎤',
      'type': 'text',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initTts();
    _initSpeech();
    
    _consultFocusNode.addListener(_onFocusChange);
    _registerFocusNode.addListener(_onFocusChange);
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
      debugPrint('Error cargando perfil en asistente: $e');
    }
  }

  void _onFocusChange() {
    bool hasFocus = _consultFocusNode.hasFocus || _registerFocusNode.hasFocus;
    if (hasFocus != _isKeyboardVisible) {
      setState(() => _isKeyboardVisible = hasFocus);
    }
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("es-MX");
    await _flutterTts.setSpeechRate(0.6); // Velocidad aumentada a 0.6 para lectura rápida
    await _flutterTts.setPitch(1.0); 
    await _flutterTts.setVolume(1.0);
    _flutterTts.setCompletionHandler(() => setState(() => _speakingMessageId = null));
  }

  Future<void> _initSpeech() async {
    await _speech.initialize();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _consultController.dispose();
    _registerController.dispose();
    _consultFocusNode.dispose();
    _registerFocusNode.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _speak(String content, String messageId) async {
    if (_speakingMessageId == messageId) {
      await _flutterTts.stop();
      setState(() => _speakingMessageId = null);
    } else {
      setState(() => _speakingMessageId = messageId);
      
      // Limpiar Markdown para que no lea "asterisco", "guión", etc.
      String plainText = content
          .replaceAll(RegExp(r'\*+'), '') // Elimina asteriscos de negrita/itálica
          .replaceAll(RegExp(r'#+'), '')  // Elimina hashes de títulos
          .replaceAll(RegExp(r'^- ', multiLine: true), '') // Elimina guiones de listas
          .replaceAll(RegExp(r'^\d+\. ', multiLine: true), '') // Elimina números de listas
          .trim();

      await _flutterTts.speak(plainText);
    }
  }

  Future<void> _listen(bool isConsult) async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            if (isConsult) _consultController.text = val.recognizedWords;
            else _registerController.text = val.recognizedWords;
            
            if (val.finalResult) {
              _isListening = false;
              _sendMessage(isConsult);
            }
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _sendMessage(bool isConsult, {String? quickMessage}) async {
    final controller = isConsult ? _consultController : _registerController;
    final message = quickMessage ?? controller.text;
    if (message.trim().isEmpty) return;
    
    if (quickMessage == null) controller.clear();

    setState(() {
      if (isConsult) _consultMessages.add({'role': 'user', 'content': message, 'type': 'text'});
      else _registerLogs.add({'role': 'user', 'content': message, 'type': 'text'});
      _isTyping = true;
    });
    
    _scrollToBottom(isConsult);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null) {
        setState(() {
          _isTyping = false;
          final list = isConsult ? _consultMessages : _registerLogs;
          list.add({'role': 'assistant', 'content': 'Sesión expirada o inválida. Por favor, inicia sesión de nuevo.', 'type': 'error'});
        });
        return;
      }

      if (isConsult) {
        // Enviar historial (últimos 5 mensajes para contexto)
        // Usamos .map para asegurar que solo enviamos role y content (lo que el back entiende)
        final history = _consultMessages.length > 1 
          ? _consultMessages.sublist(_consultMessages.length > 6 ? _consultMessages.length - 6 : 0, _consultMessages.length - 1)
            .map((m) => {
              'role': m['role'] == 'assistant' ? 'assistant' : 'user', 
              'content': m['content']
            }).toList()
          : null;

        // Construcción del perfil detallado para la justificación
        final perfilStr = _clientProfile != null 
          ? "CLIENTE: ${_clientProfile!.firstName}, Edad: ${_clientProfile!.age} años, Peso: ${_clientProfile!.weight}kg, Altura: ${_clientProfile!.height}cm, Actividad: ${_clientProfile!.activityLevel}, Objetivo: ${_clientProfile!.goal}, Condiciones: ${_clientProfile!.medicalConditions.join(', ')}."
          : "CLIENTE: Desconocido.";

        // Instrucción Maestra de Personalización (Sin ensuciar con JSON legacy)
        final promptConInstruccion = """
$perfilStr

MENSAJE DEL USUARIO: $message 

(Responde de forma cordial y profesional como un coach experto. Si sugieres un plato o rutina, usa las etiquetas Plato: o Rutina: para que pueda procesarlas correctamente.)
""";

        final result = await _apiService.consultarAsistente(promptConInstruccion, token, historial: history);
        
        // 🚀 NUEVA LÓGICA: Soporte para Respuesta Inteligente Estructurada (v23)
        // Extraemos los datos de 'respuesta_estructurada' enviada por el nuevo parser del backend
        final Map<String, dynamic> struct = result['respuesta_estructurada'] ?? {};
        final rawResponse = result['respuesta_ia'] ?? 'No pude procesar la consulta.';
        final List<dynamic>? seccionesIas = struct['secciones'];
        final String? textoIntro = struct['texto_conversacional'];
        final String? advertenciaSalud = struct['advertencia_nutricional'] ?? result['advertencia_nutricional'];

        String cleanMessage = (textoIntro != null && textoIntro.isNotEmpty) ? textoIntro : rawResponse;
        Map<String, dynamic>? recipeData;
        
        // 🛡️ Retrocompatibilidad: Si no hay secciones inteligentes pero sí hay tags de receta legacy
        if ((seccionesIas == null || seccionesIas.isEmpty) && 
            (rawResponse.contains("###RECETA###") || rawResponse.contains("RECETA_DATOS"))) {
          final tag = rawResponse.contains("###RECETA###") ? "###RECETA###" : "RECETA_DATOS";
          final parts = rawResponse.split(tag);
          if (textoIntro == null) cleanMessage = parts[0].trim();
          
          try {
            String jsonPart = parts[1].trim();
            jsonPart = jsonPart.replaceAll("```json", "").replaceAll("```", "").trim();
            if (jsonPart.startsWith(":")) jsonPart = jsonPart.substring(1).trim();
            recipeData = jsonDecode(jsonPart);
          } catch (e) {
            debugPrint("🚨 Error parseando JSON de receta: $e");
          }
        }

        if (cleanMessage.isEmpty) cleanMessage = "¡Tengo una recomendación ideal para tu objetivo!";
        if (cleanMessage.length > 500 && seccionesIas != null && seccionesIas.isNotEmpty) {
           cleanMessage = cleanMessage.substring(0, 300) + "..."; // Recorte de seguridad
        }

        setState(() {
          _isTyping = false;
          _consultMessages.add({
            'role': 'assistant', 
            'content': cleanMessage, 
            'type': seccionesIas != null && seccionesIas.isNotEmpty ? 'smart_response' : (recipeData != null ? 'recipe' : 'text'),
            'recipe': recipeData,
            'secciones': seccionesIas, 
            'advertencia': advertenciaSalud
          });
          
          if (!_isMuted) _speak(cleanMessage, "auto_${_consultMessages.length}");
        });
      } else {
        final result = await _apiService.registrarPorVoz(message, token);
        final response = result['mensaje'] ?? 'Registro completado.';
        setState(() {
          _isTyping = false;
          _registerLogs.add({
            'role': 'assistant', 
            'content': response, 
            'type': 'registro_exitoso',
            'badge': result['tipo_detectado']
          });
        });
      }
      _scrollToBottom(isConsult);
    } catch (e) {
      setState(() {
        _isTyping = false;
        final list = isConsult ? _consultMessages : _registerLogs;
        list.add({'role': 'assistant', 'content': 'Error de conexión.', 'type': 'error'});
      });
    }
  }

  void _scrollToBottom(bool isConsult) {
    final scroll = isConsult ? _consultScrollController : _registerScrollController;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text('Asistente CaloFit', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: Icon(_isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: _isMuted ? Colors.red : Colors.blue),
            onPressed: () {
              setState(() => _isMuted = !_isMuted);
              if (_isMuted) _flutterTts.stop();
            },
            tooltip: _isMuted ? 'Activar sonido' : 'Silenciar asistente',
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1E88E5),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF1E88E5),
          tabs: const [
            Tab(icon: Icon(Icons.auto_awesome_outlined), text: 'Asistente IA'),
            Tab(icon: Icon(Icons.edit_note_rounded), text: 'Registro Diario'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatView(true),
          _buildChatView(false),
        ],
      ),
      bottomNavigationBar: MediaQuery.of(context).viewInsets.bottom > 0 ? null : _buildBottomNavigation(),
    );
  }

  Widget _buildChatView(bool isConsult) {
    return Column(
      children: [
        if (isConsult && !_isKeyboardVisible) _buildQuickActions(),
        Expanded(
          child: _buildMessageList(isConsult),
        ),
        if (_isTyping) _buildTypingIndicator(),
        _buildInputArea(isConsult),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _quickActionChip('🍽️ ¿Qué como hoy?', 'Recomiéndame algo saludable para comer hoy'),
          _quickActionChip('🔥 Calorías hoy', '¿Cuántas calorías llevo consumidas hoy?'),
          _quickActionChip('💪 Ejercicios', 'Sugiéreme una rutina rápida de ejercicios'),
        ],
      ),
    );
  }

  Widget _quickActionChip(String label, String msg) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label),
        onPressed: () => _sendMessage(true, quickMessage: msg),
        backgroundColor: Colors.white,
        side: BorderSide(color: Colors.grey.shade200),
      ),
    );
  }

  Widget _buildMessageList(bool isConsult) {
    final messages = isConsult ? _consultMessages : _registerLogs;
    return ListView.builder(
      controller: isConsult ? _consultScrollController : _registerScrollController,
      padding: const EdgeInsets.all(20),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        
        // 🚀 Nuevo Renderizador Inteligente
        if (msg['type'] == 'smart_response') {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildChatBubble(msg, index, sections: msg['secciones']), // Respuesta corta con botón integrado
              if (msg['advertencia'] != null) _buildHealthWarning(msg['advertencia']),
            ],
          );
        }
        
        if (msg['type'] == 'recipe') return _buildRecommendationCard(msg['content'], index, recipe: msg['recipe']);
        if (msg['type'] == 'recommendation') return _buildRecommendationCard(msg['content'], index);
        if (msg['type'] == 'registro_exitoso') return _buildRegistrationBadge(msg, index);
        return _buildChatBubble(msg, index);
      },
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> msg, int index, {List<dynamic>? sections}) {
    bool isUser = msg['role'] == 'user';
    String messageId = "bubble_$index";
    bool isSpeaking = _speakingMessageId == messageId;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.80),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) const CircleAvatar(radius: 14, backgroundColor: Color(0xFF1E88E5), child: Icon(Icons.auto_awesome, color: Colors.white, size: 14)),
            if (!isUser) const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF1E88E5) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: isUser ? null : Border.all(color: Colors.grey.shade200),
                    ),
                    child: isUser 
                      ? Text(msg['content'], style: const TextStyle(color: Colors.white, fontSize: 15))
                      : MarkdownBody(
                          data: msg['content'],
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(color: Colors.black87, fontSize: 15, height: 1.5),
                            listBullet: TextStyle(color: Colors.blue.shade700, fontSize: 15),
                            listIndent: 20, // Sangría para que se note la lista
                            blockSpacing: 10, // Espacio entre párrafos y listas
                            strong: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isUser) Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: InkWell(
                          onTap: () => _speak(msg['content'], messageId),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(isSpeaking ? Icons.stop_circle : Icons.volume_up_rounded, size: 14, color: isSpeaking ? Colors.red : Colors.blue.shade300),
                            const SizedBox(width: 4),
                            Text(isSpeaking ? 'Detener' : 'Escuchar', style: TextStyle(fontSize: 10, color: isSpeaking ? Colors.red : Colors.blue.shade700, fontWeight: FontWeight.bold)),
                          ]),
                        ),
                      ),
                      if (sections != null && sections.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: () => _showRecipeDetail(sections[0]),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.restaurant_menu, size: 12, color: Colors.orange.shade800),
                                const SizedBox(width: 4),
                                Text("VER DETALLES", style: TextStyle(fontSize: 10, color: Colors.orange.shade900, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationBadge(Map<String, dynamic> msg, int index) {
    final isAlimento = msg['badge'] == 'alimento';
    String messageId = "reg_$index";
    bool isSpeaking = _speakingMessageId == messageId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: (isAlimento ? Colors.orange : Colors.green).withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(isAlimento ? Icons.restaurant : Icons.fitness_center, color: isAlimento ? Colors.orange : Colors.green),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isAlimento ? 'ALIMENTO REGISTRADO' : 'EJERCICIO REGISTRADO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isAlimento ? Colors.orange : Colors.green)),
              const SizedBox(height: 4),
              Text(msg['content'], style: const TextStyle(fontSize: 14)),
            ])),
          ]),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _speak(msg['content'], messageId),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(isSpeaking ? Icons.stop_circle : Icons.volume_up_rounded, size: 14, color: isSpeaking ? Colors.red : Colors.blue.shade300),
              const SizedBox(width: 4),
              Text(isSpeaking ? 'Detener' : 'Escuchar confirmación', style: TextStyle(fontSize: 10, color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(String content, int index, {Map<String, dynamic>? recipe}) {
    String messageId = "rec_$index";
    bool isSpeaking = _speakingMessageId == messageId;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          height: 80, 
          width: double.infinity, 
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)), 
            gradient: LinearGradient(colors: recipe != null ? [Colors.orange.shade300, Colors.orange.shade600] : [Colors.blue.shade300, Colors.blue.shade600])
          ), 
          child: Center(child: Icon(recipe != null ? Icons.restaurant_menu : Icons.auto_awesome, color: Colors.white, size: 30))
        ),
        Padding(
          padding: const EdgeInsets.all(16), 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, 
            children: [
              MarkdownBody(
                data: content,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87, height: 1.4),
                  listBullet: TextStyle(color: Colors.blue.shade700, fontSize: 14),
                  listIndent: 20,
                  blockSpacing: 8,
                  strong: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  InkWell(
                    onTap: () => _speak(content, messageId), 
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(isSpeaking ? Icons.stop_circle : Icons.volume_up_rounded, size: 16, color: isSpeaking ? Colors.red : Colors.blue.shade600),
                      const SizedBox(width: 6),
                      Text(isSpeaking ? 'Detener' : 'Escuchar', style: TextStyle(fontSize: 12, color: isSpeaking ? Colors.red : Colors.blue.shade700, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                  if (recipe != null) ...[
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => _showRecipeDetail(recipe),
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('Ver Receta', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ]),
    );
  }

    void _showRecipeDetail(Map<String, dynamic> data) {
    debugPrint("📂 Abriendo detalle: ${data['nombre']}");
    final bool isComida = (data['tipo'] == 'comida' || data['tipo'] == 'saludable') || (data['ingredientes'] != null && (data['ingredientes'] as List).isNotEmpty);
    
    List<String> toList(dynamic input) {
      if (input == null) return [];
      if (input is List) return input.map((e) => e.toString()).toList();
      if (input is String) {
        if (input.contains('\n')) return input.split('\n').where((s) => s.trim().isNotEmpty).toList();
        return [input];
      }
      return [];
    }

    final List<String> ingredientes = toList(data['ingredientes'] ?? []);
    final List<String> pasos = toList(data['preparacion'] ?? data['pasos'] ?? data['tecnica'] ?? data['instrucciones'] ?? []);
    
    Set<int> ingredientesChequeados = {};
    Set<int> pasosChequeados = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.90,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      image: DecorationImage(
                        image: NetworkImage(isComida 
                          ? "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?q=80&w=800&auto=format&fit=crop"
                          : "https://images.unsplash.com/photo-1517836357463-d25dfeac3438?q=80&w=800&auto=format&fit=crop"),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withOpacity(0.9), Colors.transparent],
                        ),
                      ),
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.bottomLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                            child: Text(isComida ? "NUTRICIÓN" : "FITNESS", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          ),
                          const SizedBox(height: 8),
                          Text(data['nombre'] ?? data['plato'] ?? 'Sugerencia CaloFit', 
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: CircleAvatar(
                      backgroundColor: Colors.white.withOpacity(0.3),
                      child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    if (data['justificacion'] != null && data['justificacion'].toString().isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade50.withOpacity(0.8), Colors.white],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.blue.shade100.withOpacity(0.5)),
                          boxShadow: [
                            BoxShadow(color: Colors.blue.shade900.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 6)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(8)),
                                  child: Icon(Icons.psychology_outlined, color: Colors.blue.shade800, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Text("COMENTARIO DEL COACH", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade800, letterSpacing: 1.1)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              data['justificacion'],
                              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.blue.shade900, height: 1.5, letterSpacing: 0.2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],
                    if (isComida) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.analytics_outlined, size: 16, color: Colors.orange.shade800),
                                const SizedBox(width: 12),
                                Text("APORTE NUTRICIONAL", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade800, letterSpacing: 0.5)),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Center(
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 16,
                                runSpacing: 12,
                                children: [
                                  _macroBadge("CALORÍAS", _parseMacro(data['macros']?.toString() ?? "", 'Cal'), Icons.local_fire_department, Colors.orange),
                                  _macroBadge("PROTEÍNA", _parseMacro(data['macros']?.toString() ?? "", 'P'), Icons.fitness_center, Colors.blue),
                                  _macroBadge("CARBS", _parseMacro(data['macros']?.toString() ?? "", 'C'), Icons.grain, Colors.green),
                                  _macroBadge("GRASAS", _parseMacro(data['macros']?.toString() ?? "", 'G'), Icons.water_drop, Colors.red),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.verified_user_outlined, size: 14, color: Colors.green.shade600),
                                const SizedBox(width: 8),
                                Text("CÁLCULO MATEMÁTICO VERIFICADO POR CALOFIT", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green.shade700, letterSpacing: 0.5)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ] else ...[
                      if (data['macros'] != null) ...[
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(20)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.track_changes, color: Colors.blue.shade700, size: 20),
                                const SizedBox(width: 10),
                                Text("IMPACTO: ${data['macros']}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ],
                    _premiumSectionHeader(isComida ? "Ingredientes" : "Lista de Ejercicios", isComida ? Icons.shopping_basket : Icons.fitness_center),
                    const SizedBox(height: 12),
                    if (ingredientes.isEmpty) const Text("No se especificaron detalles."),
                    ...ingredientes.asMap().entries.map((e) => _premiumItem(e.value, e.key, ingredientesChequeados, (idx) => setModalState(() => ingredientesChequeados.contains(idx) ? ingredientesChequeados.remove(idx) : ingredientesChequeados.add(idx)))),
                    const SizedBox(height: 32),
                    if (data['nota'] != null && data['nota'].toString().isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.orange.shade200),
                          boxShadow: [
                            BoxShadow(color: Colors.orange.shade900.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: Colors.orange.shade100, shape: BoxShape.circle),
                                  child: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade900, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Text("TIPS DE SEGURIDAD Y SALUD", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade900, letterSpacing: 0.8)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              data['nota'],
                              style: TextStyle(fontSize: 14, color: Colors.orange.shade900, height: 1.5, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                    _premiumSectionHeader(isComida ? "Preparación" : "Pasos de Técnica", isComida ? Icons.restaurant_menu : Icons.psychology),
                    const SizedBox(height: 12),
                    if (pasos.isEmpty) const Text("No se especificaron pasos."),
                    ...pasos.asMap().entries.map((e) => _premiumStep(e.value, e.key, pasosChequeados, (idx) => setModalState(() => pasosChequeados.contains(idx) ? pasosChequeados.remove(idx) : pasosChequeados.add(idx)))),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _parseMacro(String macros, String key) {
    if (macros.isEmpty || macros == "null") return "N/D";
    try {
      // Nueva lógica: Buscar el patrón "Key: Valor" en cualquier parte de la cadena
      final String m = macros.replaceAll('**', '').trim();
      final RegExp regExp = RegExp('$key:\\s*([^,;\\n]+)', caseSensitive: false);
      final match = regExp.firstMatch(m);
      
      if (match != null) {
        String valor = match.group(1)?.trim() ?? "N/D";
        // Limpiar unidades duplicadas si existen
        return valor.replaceAll('  ', ' ');
      }
      
      // Fallback a split si el regex falla
      final parts = m.split(',');
      for (var part in parts) {
        final p = part.trim();
        if (p.contains('$key:')) {
          return p.split(':').last.trim();
        }
      }
      return "N/D";
    } catch (e) {
      return "N/D";
    }
  }

  Widget _buildTypingIndicator() {
    return Padding(padding: const EdgeInsets.only(left: 60, bottom: 10), child: Align(alignment: Alignment.centerLeft, child: Text('CaloFit analizando...', style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontStyle: FontStyle.italic))));
  }

  Widget _buildInputArea(bool isConsult) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: SafeArea(top: false, child: Row(children: [
        GestureDetector(onTap: () => _listen(isConsult), child: CircleAvatar(backgroundColor: _isListening ? Colors.red : Colors.grey[100], child: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.white : Colors.black87, size: 20))),
        const SizedBox(width: 12),
        Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(25)), child: TextField(controller: isConsult ? _consultController : _registerController, focusNode: isConsult ? _consultFocusNode : _registerFocusNode, decoration: InputDecoration(hintText: isConsult ? 'Escribe tu consulta...' : 'Registra comida/ejercicio...', border: InputBorder.none)))),
        const SizedBox(width: 8),
        GestureDetector(onTap: () => _sendMessage(isConsult), child: CircleAvatar(backgroundColor: const Color(0xFF1E88E5), child: const Icon(Icons.send, color: Colors.white, size: 18))),
      ])),
    );
  }

  Widget _sectionTitle(String title, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
      ],
    ),
  );

  Widget _buildTextOrList(dynamic content) {
    if (content == null) return const SizedBox();
    
    List<String> items = [];
    if (content is List) {
      items = content.map((e) => e.toString()).toList();
    } else if (content is String) {
      if (content.contains('\n')) {
        items = content.split('\n').where((s) => s.trim().isNotEmpty).toList();
      } else if (content.contains('. ') && content.length > 50) {
        items = content.split('. ').where((s) => s.trim().length > 3).toList();
      } else {
        return Text(content, style: const TextStyle(fontSize: 14));
      }
    }

    if (items.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("• ", style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(child: Text(item, style: const TextStyle(fontSize: 14))),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildExerciseItem(String title) => CheckboxListTile(
    title: Text(title, style: const TextStyle(fontSize: 14)),
    value: false,
    onChanged: (val) {},
    controlAffinity: ListTileControlAffinity.leading,
    contentPadding: EdgeInsets.zero,
    dense: true,
    activeColor: Colors.blue,
  );

  Widget _buildPreviewRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _macroBadge(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade900)),
      ],
    );
  }

  Widget _premiumSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.black87, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  Widget _premiumItem(String text, int index, Set<int> checked, Function(int) onToggle) {
    final isChecked = checked.contains(index);
    return InkWell(
      onTap: () => onToggle(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(isChecked ? Icons.check_circle : Icons.circle_outlined, color: isChecked ? Colors.green : Colors.grey.shade300, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: TextStyle(fontSize: 15, decoration: isChecked ? TextDecoration.lineThrough : null, color: isChecked ? Colors.grey : Colors.black87))),
          ],
        ),
      ),
    );
  }

  Widget _premiumStep(String text, int index, Set<int> checked, Function(int) onToggle) {
    final isChecked = checked.contains(index);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: InkWell(
        onTap: () => onToggle(index),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: isChecked ? Colors.green.shade50 : Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
              child: Text("${index + 1}", style: TextStyle(color: isChecked ? Colors.green : Colors.blue.shade700, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(text, style: TextStyle(fontSize: 15, height: 1.5, color: isChecked ? Colors.grey : Colors.black87, decoration: isChecked ? TextDecoration.lineThrough : null))),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthWarning(String warning) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.health_and_safety, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              warning,
              style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
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
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Inicio',
        ),
        NavigationDestination(
          icon: Icon(Icons.chat_bubble_outline),
          selectedIcon: Icon(Icons.chat_bubble),
          label: 'Asistente',
        ),
        NavigationDestination(
          icon: Icon(Icons.assessment_outlined),
          selectedIcon: Icon(Icons.assessment),
          label: 'Balance',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Perfil',
        ),
      ],
    );
  }
}
