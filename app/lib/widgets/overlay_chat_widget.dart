import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:omi/providers/message_provider.dart';
import 'package:omi/providers/connectivity_provider.dart';
import 'package:omi/ui/atoms/omi_avatar.dart';
import 'package:omi/backend/schema/message.dart';
//import 'package:omi/utils/responsive_helper.dart';

class OverlayChatWidget extends StatefulWidget {
  final VoidCallback onClose;
  
  const OverlayChatWidget({Key? key, required this.onClose}) : super(key: key);

  @override
  State<OverlayChatWidget> createState() => _OverlayChatWidgetState();
}

class _OverlayChatWidgetState extends State<OverlayChatWidget> 
    with TickerProviderStateMixin {
  late TextEditingController _textController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    
    _fadeController.forward();
    
    // Auto-focus the input field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(FocusNode());
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: widget.onClose, // Close when clicking outside
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black.withOpacity(0.3), // Semi-transparent background
            child: Center(
              child: GestureDetector(
                onTap: () {}, // Prevent closing when clicking inside
                child: _buildOverlayContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayContent() {
    return Container(
      width: 600,
      height: 400,
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900]!,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildOverlayHeader(),
          Expanded(child: _buildChatArea()),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildOverlayHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[800]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          OmiAvatar(
            size: 24,
            fallback: Icon(Icons.chat_bubble_outline, color: Colors.deepPurple),
          ),
          const SizedBox(width: 12),
          const Text(
            'Chat with Omi',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: widget.onClose,
            icon: Icon(
              Icons.close,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    return Consumer<MessageProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: provider.messages.isEmpty
              ? _buildEmptyState()
              : _buildMessagesList(provider),
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Consumer2<MessageProvider, ConnectivityProvider>(
      builder: (context, provider, connectivityProvider, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Colors.grey[800]!,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Focus(
                  child: TextField(
                    controller: _textController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Ask Omi anything...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[800]!,
                    ),
                    onSubmitted: (text) => _sendMessage(text),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => _sendMessage(_textController.text),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        );
      },
    );
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    
    // Reuse the same logic as desktop_chat_page.dart
    final provider = context.read<MessageProvider>();
    provider.setSendingMessage(true);
    provider.addMessageLocally(text);
    _textController.clear();
    provider.sendMessageStreamToServer(text);
    provider.setSendingMessage(false);
  }

  // ... other methods for empty state, messages list, etc.

  Widget _buildEmptyState() {
  return const Center(
    child: Text(
      'Start chatting with Omi',
      style: TextStyle(color: Colors.grey),
    ),
  );
}

Widget _buildMessagesList(MessageProvider provider) {
  return ListView.builder(
    itemCount: provider.messages.length,
    itemBuilder: (context, index) {
      final message = provider.messages[index];
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: message.sender == MessageSender.human ? Colors.blue : Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message.text,
          style: const TextStyle(color: Colors.white),
        ),
      );
    },
  );
}

@override
void dispose() {
  _textController.dispose();
  _fadeController.dispose();
  super.dispose();
}
}