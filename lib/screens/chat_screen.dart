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
  String? _speakingMessageId;
  bool _isKeyboardVisible = false;

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
  }

  void _onFocusChange() {
    bool hasFocus = _consultFocusNode.hasFocus || _registerFocusNode.hasFocus;
    if (hasFocus != _isKeyboardVisible) {
      setState(() => _isKeyboardVisible = hasFocus);
    }
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("es-MX"); // Más natural para Latinoamérica
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.1); // Un tono ligeramente más alto para que sea más amigable
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

        // Instrucción de Experto para la IA
        final promptConInstruccion = """
$message 

(IMPORTANTE: Actúa como un experto en nutrición y fitness. 
- Tus recomendaciones deben tener sentido lógico (evita redundancias como 'palta con aguacate').
- Sugiere alimentos variados: proteínas, carbohidratos complejos y grasas saludables.
- Responde usando listas con viñetas de Markdown.
- Usa negritas para resaltar los alimentos o ejercicios clave.
- Sé breve pero motivador).
""";

        final result = await _apiService.consultarAsistente(promptConInstruccion, token, historial: history);
        final response = result['respuesta_ia'] ?? 'No pude procesar la consulta.';
        setState(() {
          _isTyping = false;
          _consultMessages.add({
            'role': 'assistant', 
            'content': response, 
            'type': response.toLowerCase().contains('recomiendo') ? 'recommendation' : 'text'
          });
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
        if (msg['type'] == 'recommendation') return _buildRecommendationCard(msg['content'], index);
        if (msg['type'] == 'registro_exitoso') return _buildRegistrationBadge(msg, index);
        return _buildChatBubble(msg, index);
      },
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> msg, int index) {
    bool isUser = msg['role'] == 'user';
    String messageId = "bubble_$index";
    bool isSpeaking = _speakingMessageId == messageId;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
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
                  if (!isUser)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: InkWell(
                        onTap: () => _speak(msg['content'], messageId),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(isSpeaking ? Icons.stop_circle : Icons.volume_up_rounded, size: 14, color: isSpeaking ? Colors.red : Colors.blue.shade300),
                          const SizedBox(width: 4),
                          Text(isSpeaking ? 'Detener' : 'Escuchar', style: TextStyle(fontSize: 10, color: isSpeaking ? Colors.red : Colors.blue.shade700, fontWeight: FontWeight.bold)),
                        ]),
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

  Widget _buildRecommendationCard(String content, int index) {
    String messageId = "rec_$index";
    bool isSpeaking = _speakingMessageId == messageId;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(height: 80, width: double.infinity, decoration: BoxDecoration(borderRadius: const BorderRadius.vertical(top: Radius.circular(18)), gradient: LinearGradient(colors: [Colors.blue.shade300, Colors.blue.shade600])), child: const Center(child: Icon(Icons.auto_awesome, color: Colors.white, size: 30))),
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
          InkWell(onTap: () => _speak(content, messageId), child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(isSpeaking ? Icons.stop_circle : Icons.volume_up_rounded, size: 16, color: isSpeaking ? Colors.red : Colors.blue.shade600),
            const SizedBox(width: 6),
            Text(isSpeaking ? 'Detener' : 'Escuchar recomendación', style: TextStyle(fontSize: 12, color: isSpeaking ? Colors.red : Colors.blue.shade700, fontWeight: FontWeight.bold)),
          ])),
        ])),
      ]),
    );
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
