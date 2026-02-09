import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/client.dart';
import 'edit_profile_screen.dart';
import 'mi_balance_screen.dart';
import 'package:flutter_tts/flutter_tts.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  int _selectedIndex = 1;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ApiService _apiService = ApiService();
  bool _isTyping = false;
  final FlutterTts _flutterTts = FlutterTts();
  String? _speakingMessageId;


  String _chatMode = 'consulta'; // 'consulta' o 'registro'

  final List<Map<String, dynamic>> _messages = [
    {
      'role': 'assistant',
      'content':
          '¡Hola! Soy tu asistente CaloFit con IA adaptativa. 🤖\n\n💬 Modo Consulta: Pregúntame sobre nutrición, objetivos, o tu progreso.\n🎤 Modo Registro: Di qué comiste o qué ejercicio hiciste (ej: "Comí arroz con pollo").',
      'type': 'text',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("es-ES");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    
    _flutterTts.setCompletionHandler(() {
      setState(() {
        _speakingMessageId = null;
      });
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    final userMessage = _messageController.text;
    _messageController.clear();

    setState(() {
      _messages.add({'role': 'user', 'content': userMessage, 'type': 'text'});
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null) {
        throw Exception('No hay sesión activa');
      }

      String response;

      // ✨ NUEVO: Lógica según el modo
      if (_chatMode == 'registro') {
        // 🎤 Modo Registro por Voz con NLP
        print('🎤 Modo Registro: "$userMessage"');
        final result = await _apiService.registrarPorVoz(userMessage, token);
        
        // El backend devuelve confirmación o error
        response = result['mensaje'] ?? 'Registro procesado correctamente';
        
        // Si se detectó alimento/ejercicio, mostrar badge
        if (result['tipo_detectado'] != null) {
          setState(() {
            _isTyping = false;
            _messages.add({
              'role': 'assistant',
              'content': response,
              'type': 'registro_exitoso',
              'badge': result['tipo_detectado'], // 'alimento' o 'ejercicio'
            });
          });
          _scrollToBottom();
          return;
        }
      } else {
        // 💬 Modo Consulta con Fuzzy Logic
        print('💬 Modo Consulta: "$userMessage"');
        final result = await _apiService.consultarAsistente(userMessage, token);
        
        // ✅ CORRECCIÓN: Usar la clave correcta 'respuesta_ia' que viene del backend
        response = result['respuesta_ia'] ?? result['respuesta'] ?? result['mensaje'] ?? 'Lo siento, no pude procesar tu consulta.';
        
        // ✅ NUEVO: Detectar si hubo alerta de salud
        if (result['alerta_salud'] == true) {
          setState(() {
            _messages.add({
              'role': 'assistant',
              'content': '⚠️ ¡ALERTA DE SALUD DETECTADA!',
              'type': 'health_warning',
            });
          });
        }
      }

      setState(() {
        _isTyping = false;
        bool isRecommendation = response.toLowerCase().contains('recomiendo') ||
            response.toLowerCase().contains('calorías') ||
            response.toLowerCase().contains('dieta');

        _messages.add({
          'role': 'assistant',
          'content': response,
          'type': isRecommendation ? 'recommendation' : 'text'
        });
      });
      _scrollToBottom();
    } catch (e) {
      print('❌ Error en chat: $e');
      setState(() {
        _isTyping = false;
        _messages.add({
          'role': 'assistant',
          'content': 'Error de conexión. Intenta de nuevo.',
          'type': 'error'
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chat Inteligente',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 18)),
            Text(
              _chatMode == 'consulta' ? 'Modo: Consulta 💬' : 'Modo: Registro 🎤',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // ✨ NUEVO: Dropdown de modo
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.grey[700]),
            onSelected: (mode) {
              setState(() {
                _chatMode = mode;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    mode == 'consulta'
                        ? '💬 Modo Consulta activado'
                        : '🎤 Modo Registro por Voz activado',
                  ),
                  duration: const Duration(seconds: 2),
                  backgroundColor: mode == 'consulta' ? Colors.blue : Colors.green,
                ),
              );
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'consulta',
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        color: _chatMode == 'consulta' ? Colors.blue : Colors.grey),
                    const SizedBox(width: 10),
                    Text('Modo Consulta',
                        style: TextStyle(
                            fontWeight: _chatMode == 'consulta' ? FontWeight.bold : FontWeight.normal)),
                  ],
                ),
              ),

              PopupMenuItem(
                value: 'registro',
                child: Row(
                  children: [
                    Icon(Icons.mic,
                        color: _chatMode == 'registro' ? Colors.green : Colors.grey),
                    const SizedBox(width: 10),
                    Text('Modo Registro',
                        style: TextStyle(
                            fontWeight: _chatMode == 'registro' ? FontWeight.bold : FontWeight.normal)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ✨ NUEVO: Banner informativo del modo
          if (_chatMode == 'registro')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.green[50],
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, color: Colors.green, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Di qué comiste o qué ejercicio hiciste (ej: "Comí 2 huevos")',
                      style: TextStyle(fontSize: 12, color: Colors.green[800]),
                    ),
                  ),
                ],
              ),
            ),
          
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                
                if (msg['type'] == 'recommendation') {
                  return _buildExtendedRecommendation(msg['content']);
                }
                
                if (msg['type'] == 'registro_exitoso') {
                  return _buildRegistroExitoso(msg);
                }
                
                return _buildChatBubble(msg);
              },
            ),
          ),
          if (_isTyping) _buildTypingIndicator(),
          _buildInputArea(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> msg) {
    bool isUser = msg['role'] == 'user';
    bool isError = msg['type'] == 'error';
    bool isWarning = msg['type'] == 'health_warning';
    final messageId = msg.hashCode.toString();
    final isSpeaking = _speakingMessageId == messageId;
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isError 
                    ? Colors.red[50]
                    : (isWarning 
                        ? Colors.orange[50] 
                        : (isUser ? Colors.blue[600] : Colors.white)),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 0),
                  bottomRight: Radius.circular(isUser ? 0 : 18),
                ),
                border: isWarning ? Border.all(color: Colors.orange[300]!) : null,
                boxShadow: [
                  if (!isUser)
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)
                ],
              ),
              child: Text(
                msg['content'],
                style: TextStyle(
                  color: isError 
                      ? Colors.red[900] 
                      : (isWarning ? Colors.orange[900] : (isUser ? Colors.white : Colors.black87)),
                  fontSize: isWarning ? 14 : 15,
                  fontWeight: isWarning ? FontWeight.bold : FontWeight.normal,
                  height: 1.4,
                ),
              ),
            ),
            // Botón de voz solo para mensajes del asistente
            if (!isUser && !isError)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: TextButton.icon(
                  onPressed: () => _toggleSpeech(messageId, msg['content']),
                  icon: Icon(
                    isSpeaking ? Icons.stop_circle : Icons.volume_up,
                    size: 18,
                    color: Colors.blue[700],
                  ),
                  label: Text(
                    isSpeaking ? 'Detener' : 'Escuchar',
                    style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleSpeech(String messageId, String text) async {
    if (_speakingMessageId == messageId) {
      // Detener si ya está hablando este mensaje
      await _flutterTts.stop();
      setState(() {
        _speakingMessageId = null;
      });
    } else {
      // Detener cualquier mensaje anterior y comenzar este
      await _flutterTts.stop();
      setState(() {
        _speakingMessageId = messageId;
      });
      await _flutterTts.speak(text);
    }
  }

  // ✨ NUEVO: Widget para registro exitoso con badge
  Widget _buildRegistroExitoso(Map<String, dynamic> msg) {
    final badge = msg['badge'] ?? 'registro';
    final isAlimento = badge == 'alimento';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isAlimento ? Colors.orange : Colors.green, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isAlimento ? Icons.restaurant : Icons.fitness_center,
                color: isAlimento ? Colors.orange : Colors.green,
                size: 20,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isAlimento ? Colors.orange[100] : Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isAlimento ? 'ALIMENTO REGISTRADO' : 'EJERCICIO REGISTRADO',
                  style: TextStyle(
                    color: isAlimento ? Colors.orange[900] : Colors.green[900],
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            msg['content'],
            style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildExtendedRecommendation(String content) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Image.network(
              'https://images.unsplash.com/photo-1467003909585-2f8a72700288?q=80&w=600',
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('RECOMENDACIÓN',
                        style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 1.2)),
                    _badge('Saludable', Colors.green),
                  ],
                ),
                const SizedBox(height: 10),
                Text(content,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          style:
              TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildTypingIndicator() {
    return const Padding(
      padding: EdgeInsets.only(left: 20, bottom: 10),
      child: Align(
          alignment: Alignment.centerLeft,
          child: Text('CaloFit está escribiendo...',
              style: TextStyle(
                  fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic))),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE)))),
      child: SafeArea(
        child: Row(
          children: [
            // ✨ Icono dinámico según modo
            IconButton(
              icon: Icon(
                _chatMode == 'registro' ? Icons.mic : Icons.chat_bubble_outline,
                color: _chatMode == 'registro' ? Colors.green : Colors.blue,
                size: 28,
              ),
              onPressed: () {
                // Cambiar modo rápido
                setState(() {
                  _chatMode = _chatMode == 'consulta' ? 'registro' : 'consulta';
                });
              },
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(30)),
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: _chatMode == 'registro'
                        ? 'Ej: Comí arroz con pollo...'
                        : 'Escribe un mensaje...',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: CircleAvatar(
                  backgroundColor: _chatMode == 'registro' ? Colors.green[600] : Colors.blue[600],
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: 1,
      selectedItemColor: Colors.blue[700],
      unselectedItemColor: Colors.grey,
      onTap: (index) async {
        if (index == 0) {
          Navigator.popUntil(context, (route) => route.isFirst);
        } else if (index == 2) {
          // Navegar a Mi Balance
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MiBalanceScreen()),
          );
        } else if (index == 3) {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          if (authProvider.userId == null || authProvider.token == null) return;

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) =>
                const Center(child: CircularProgressIndicator()),
          );

          try {
            Client client = await _apiService.getClientProfile(
                authProvider.userId!, authProvider.token!);

            if (!mounted) return;
            Navigator.pop(context);

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => EditProfileScreen(client: client)),
            );
          } catch (e) {
            if (!mounted) return;
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al abrir perfil: $e')),
            );
          }
        } else {
          setState(() => _selectedIndex = index);
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Inicio',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline),
          activeIcon: Icon(Icons.chat_bubble),
          label: 'Asistente',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.assessment_outlined),
          activeIcon: Icon(Icons.assessment),
          label: 'Balance',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Perfil',
        ),
      ],
    );
  }
}