// ─────────────────────────────────────────────
// screens/chat_screen.dart
// Offline AI chatbot screen.
// Features:
//   • Text input with keyboard
//   • Voice input (press and hold mic)
//   • Voice output (TTS reads each reply)
//   • Persisted chat history via SQLite
// ─────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/chatbot_service.dart';
import '../services/voice_services.dart';
import '../data/local_db.dart';
import '../models/models.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    STTService.instance.stopListening();
    TTSService.instance.stop();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final history = await LocalDatabase.instance.getChatHistory();
    if (!mounted) return;

    if (history.isNotEmpty) {
      setState(() => _messages.addAll(history));
      _scrollToBottom();
      return;
    }

    _sendWelcome();
  }

  void _sendWelcome() {
    final lang = context.read<AppProvider>().languageCode;
    Future.delayed(const Duration(milliseconds: 400), () async {
      final greeting = await ChatbotService.instance.generateReply(
        'hello',
        languageCode: lang,
      );
      _addMessage(ChatMessage(text: greeting, role: MessageRole.assistant));
      await TTSService.instance.speak(greeting, languageCode: lang);
    });
  }

  // ── Send text message ─────────────────────────
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    final lang = context.read<AppProvider>().languageCode;

    // User message
    final userMsg = ChatMessage(text: text, role: MessageRole.user);
    _addMessage(userMsg);

    // Show typing indicator
    setState(() => _isTyping = true);

    try {
      // Generate reply
      final reply = await ChatbotService.instance.generateReply(
        text,
        languageCode: lang,
      );

      final botMsg = ChatMessage(text: reply, role: MessageRole.assistant);
      _addMessage(botMsg);

      // Speak the reply
      await TTSService.instance.speak(reply, languageCode: lang);
    } catch (e) {
      _addMessage(
        ChatMessage(
          text: 'Sorry, I could not process that. Please try again.',
          role: MessageRole.assistant,
        ),
      );
    } finally {
      if (mounted) setState(() => _isTyping = false);
    }
  }

  void _addMessage(ChatMessage msg) {
    if (!mounted) return;
    setState(() => _messages.add(msg));
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Voice input ───────────────────────────────
  Future<void> _toggleVoiceInput() async {
    if (_isListening) {
      await STTService.instance.stopListening();
      setState(() => _isListening = false);
      return;
    }

    final lang = context.read<AppProvider>().languageCode;

    await STTService.instance.startListening(
      onResult: (String text) {
        if (text.isNotEmpty) {
          _controller.text = text;
          _sendMessage();
        }
      },
      onListeningStart: () => setState(() => _isListening = true),
      onListeningStop: () => setState(() => _isListening = false),
      languageCode: lang,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppProvider>().l10n;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n['chat_assistant']),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await LocalDatabase.instance.clearChatHistory();
              ChatbotService.instance.clearHistory();
              setState(() => _messages.clear());
              _sendWelcome();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Messages list ──────────────────────
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🤖', style: TextStyle(fontSize: 56)),
                        const SizedBox(height: 12),
                        Text(
                          'Ask me anything about farming!',
                          style: TextStyle(
                            color: scheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return const _TypingBubble();
                      }
                      return _MessageBubble(message: _messages[index]);
                    },
                  ),
          ),

          // ── Quick prompts ──────────────────────
          SizedBox(
            height: 44,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              children:
                  [
                        'Crop for sandy soil 🌾',
                        'Tomato disease 🍅',
                        'Best fertilizer 🌱',
                        'Water schedule 💧',
                        'Wheat blight 🌾',
                      ]
                      .map(
                        (q) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(
                              q,
                              style: const TextStyle(fontSize: 12),
                            ),
                            onPressed: () {
                              _controller.text = q;
                              _sendMessage();
                            },
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),

          const SizedBox(height: 4),

          // ── Input row ──────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            decoration: BoxDecoration(
              color: scheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Voice button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening
                        ? Colors.red.withValues(alpha: 0.15)
                        : Colors.transparent,
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none_rounded,
                      color: _isListening ? Colors.red : scheme.primary,
                    ),
                    onPressed: _toggleVoiceInput,
                  ),
                ),

                // Text field
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: l10n['chat_placeholder'],
                      filled: true,
                      fillColor: scheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: scheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: scheme.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),

                const SizedBox(width: 8),

                // Send button
                FloatingActionButton.small(
                  onPressed: _sendMessage,
                  backgroundColor: scheme.primary,
                  child: const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Message bubble ────────────────────────────
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isUser ? Colors.white : scheme.onSurface,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                color: isUser
                    ? Colors.white70
                    : scheme.onSurface.withValues(alpha: 0.45),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── Typing indicator ──────────────────────────
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              3,
              (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withValues(
                    alpha: 0.3 + 0.7 * ((_ctrl.value + i / 3) % 1),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
