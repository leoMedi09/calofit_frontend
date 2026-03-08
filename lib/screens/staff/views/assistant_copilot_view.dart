import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../services/url_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class AssistantCopilotView extends StatefulWidget {
  const AssistantCopilotView({super.key});

  @override
  State<AssistantCopilotView> createState() => _AssistantCopilotViewState();
}

class _AssistantCopilotViewState extends State<AssistantCopilotView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ApiService _apiService = ApiService();
  bool _isTyping = false;

  final List<Map<String, dynamic>> _messages = [
    {
      'role': 'assistant',
      'content': '¡Hola! Soy tu Copiloto IA para personal de salud. 🩺\n¿En qué caso clínico, análisis de datos o gestión de pacientes puedo ayudarte hoy?',
    },
  ];

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

  Future<void> _handleSendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isTyping = true;
    });
    _scrollToBottom();

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token!;
    
    try {
      // Usamos el endpoint de consulta general con contexto de staff si fuera necesario en el futuro
      
      // El asistente copilot usa una respuesta más simple o estructurada similar al cliente
      final history = _messages.length > 2 
        ? _messages.sublist(_messages.length > 6 ? _messages.length - 6 : 0, _messages.length - 1)
          .map((m) => {'role': m['role'] == 'user' ? 'user' : 'assistant', 'content': m['content']})
          .toList() 
        : null;

      final result = await _apiService.consultarCopiloto(text, token, historial: history);
      
      setState(() {
        _isTyping = false;
        _messages.add({
          'role': 'assistant', 
          'content': result['respuesta_ia'] ?? 'Sin respuesta.'
        });
      });
    } catch (e) {
      setState(() {
        _isTyping = false;
        _messages.add({
          'role': 'assistant',
          'content': 'Lo siento, hubo un error al conectar con el cerebro de la IA. 📶',
        });
      });
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5), // Mismo fondo que el cliente
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _buildChatBubble(msg['content'], msg['role'] == 'user');
                },
              ),
            ),
            if (_isTyping) _buildTypingIndicator(),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF5C6BC0).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.psychology_rounded, color: Color(0xFF5C6BC0), size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cerebro Clínico IA',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF263238), letterSpacing: -0.5),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Soporte Staff en Línea',
                      style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isUser) {
    final authProvider = Provider.of<AuthProvider>(context);
    final String displayHeroText = isUser ? text : _cleanResponseText(text);
    final bool isLongMessage = !isUser && displayHeroText.length > 300;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(color: const Color(0xFF5C6BC0).withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFF5C6BC0),
                child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 12),
          ],
            
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                _ExpandableMessage(
                  text: displayHeroText,
                  isUser: isUser,
                ),
              ],
            ),
          ),
          
          if (isUser) ...[
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[200],
                backgroundImage: authProvider.profilePictureUrl != null && authProvider.profilePictureUrl!.isNotEmpty
                    ? NetworkImage(UrlService.formatImageUrl(authProvider.profilePictureUrl))
                    : null,
                child: authProvider.profilePictureUrl == null || authProvider.profilePictureUrl!.isEmpty
                    ? Icon(Icons.person_rounded, color: Colors.grey[600], size: 20)
                    : null,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _cleanResponseText(String text) {
    return text.replaceAll(RegExp(r'\[/?CALOFIT_(?:HEADER|LIST|ACTION|FOOTER|STATS|INTENT)(?:[:\s].*?)?\]'), '').trim();
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 20),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Color(0xFF5C6BC0))),
            ),
            const SizedBox(width: 8),
            Text(
              'Copiloto analizando...',
              style: TextStyle(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _controller,
                onSubmitted: (_) => _handleSendMessage(),
                decoration: const InputDecoration(
                  hintText: 'Consultar análisis clínico...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _handleSendMessage,
            child: const CircleAvatar(
              backgroundColor: Color(0xFF5C6BC0),
              child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandableMessage extends StatefulWidget {
  final String text;
  final bool isUser;

  const _ExpandableMessage({
    required this.text,
    required this.isUser,
  });

  @override
  State<_ExpandableMessage> createState() => _ExpandableMessageState();
}

class _ExpandableMessageState extends State<_ExpandableMessage> {
  bool _isExpanded = true; // Por defecto expandido para ver el inicio

  @override
  Widget build(BuildContext context) {
    // Intentar extraer el primer título para el Header
    String title = "Reporte de Análisis";
    String content = widget.text;

    if (!widget.isUser) {
      final lines = widget.text.split('\n');
      for (var line in lines) {
        if (line.startsWith('## ') || line.trim().startsWith('Información de')) {
          title = line.replaceAll('## ', '').trim();
          content = lines.where((l) => l != line).join('\n').trim();
          break;
        }
      }
    }

    if (widget.isUser) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF5C6BC0),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Text(
          widget.text,
          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, 5)),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header del Card
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.vertical(top: const Radius.circular(20), bottom: Radius.circular(_isExpanded ? 0 : 20)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              decoration: BoxDecoration(
                color: const Color(0xFF5C6BC0).withOpacity(0.05),
                borderRadius: BorderRadius.vertical(top: const Radius.circular(20), bottom: Radius.circular(_isExpanded ? 0 : 20)),
              ),
              child: Row(
                children: [
                   Icon(Icons.assignment_ind_rounded, size: 20, color: const Color(0xFF5C6BC0).withOpacity(0.7)),
                   const SizedBox(width: 10),
                   Expanded(
                     child: Text(
                       title,
                       style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3F51B5), fontSize: 15),
                     ),
                   ),
                   Icon(
                     _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                     color: const Color(0xFF5C6BC0),
                   ),
                ],
              ),
            ),
          ),
          
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.all(18),
              child: MarkdownBody(
                data: content,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(color: const Color(0xFF263238), fontSize: 14, height: 1.6),
                  strong: const TextStyle(color: Color(0xFF5C6BC0), fontWeight: FontWeight.bold),
                  h2: const TextStyle(color: Color(0xFF3F51B5), fontSize: 16, fontWeight: FontWeight.bold, height: 2.0),
                  listBullet: const TextStyle(color: Color(0xFF5C6BC0)),
                  blockSpacing: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
