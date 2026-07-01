import 'package:flutter/material.dart';

import '../../../core/utils/app_snack_bar.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/services/auth_service.dart';
import '../models/chat_message_model.dart';
import '../services/chat_service.dart';

class ChatScreenData {
  final List<ChatMessageModel> messages;
  final int currentUserId;

  ChatScreenData({
    required this.messages,
    required this.currentUserId,
  });
}

class ChatScreen extends StatefulWidget {
  final int eventId;

  const ChatScreen({
    super.key,
    required this.eventId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final chatService = ChatService();
  final authService = AuthService();

  final messageController = TextEditingController();
  final scrollController = ScrollController();

  late Future<ChatScreenData> chatFuture;

  bool isSending = false;

  @override
  void initState() {
    super.initState();

    chatFuture = loadChatData();
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();

    super.dispose();
  }

  Future<ChatScreenData> loadChatData() async {
    final user = await authService.getCurrentUser();
    final messages = await chatService.getMessagesByEvent(widget.eventId);

    return ChatScreenData(
      messages: messages,
      currentUserId: user.id,
    );
  }

  Future<void> refreshChat() async {
    final future = loadChatData();

    setState(() {
      chatFuture = future;
    });

    await future;
  }

  Future<void> sendMessage() async {
    final content = messageController.text.trim();

    if (content.isEmpty) {
      return;
    }

    setState(() {
      isSending = true;
    });

    try {
      await chatService.sendMessage(
        eventId: widget.eventId,
        content: content,
      );

      messageController.clear();

      await refreshChat();

      if (!mounted) return;

      Future.delayed(const Duration(milliseconds: 150), () {
        if (!scrollController.hasClients) return;

        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      });
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.error(
        context,
        e,
        fallback: 'Nie udało się wysłać wiadomości',
      );
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  Widget buildAuthorAvatar(ChatAuthorModel author) {
    final avatarUrl = author.avatarUrl;

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: Colors.blue.shade100,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }

    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
      child: Text(
        author.name.isNotEmpty ? author.name[0].toUpperCase() : '?',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget buildMessageBubble(
    ChatMessageModel message,
    int currentUserId,
  ) {
    final isMine = message.authorId == currentUserId;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: const BoxConstraints(
          maxWidth: 520,
        ),
        child: Row(
          mainAxisAlignment:
              isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMine) ...[
              buildAuthorAvatar(message.author),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isMine ? Colors.blue : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment:
                      isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (!isMine)
                      Text(
                        message.author.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (!isMine) const SizedBox(height: 4),
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isMine ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppFormatters.dateTime(message.createdAt),
                      style: TextStyle(
                        color: isMine ? Colors.white70 : Colors.grey.shade700,
                        fontSize: 11,
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

  Widget buildMessagesList(ChatScreenData data) {
    if (data.messages.isEmpty) {
      return RefreshIndicator(
        onRefresh: refreshChat,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: const [
            SizedBox(height: 120),
            Icon(
              Icons.chat_bubble_outline,
              size: 56,
              color: Colors.blue,
            ),
            SizedBox(height: 16),
            Text(
              'Brak wiadomości',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Napisz pierwszą wiadomość w tym wydarzeniu.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: refreshChat,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          ...data.messages.map(
            (message) => buildMessageBubble(
              message,
              data.currentUserId,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: messageController,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Napisz wiadomość...',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) {
                  if (!isSending) {
                    sendMessage();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: isSending ? null : sendMessage,
              icon: isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildErrorBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 56,
            ),
            const SizedBox(height: 16),
            const Text(
              'Nie udało się pobrać czatu',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: refreshChat,
              child: const Text('Spróbuj ponownie'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ChatScreenData>(
      future: chatFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Czat wydarzenia'),
          ),
          body: Column(
            children: [
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        data == null) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (snapshot.hasError || data == null) {
                      return buildErrorBody();
                    }

                    return buildMessagesList(data);
                  },
                ),
              ),
              buildInputBar(),
            ],
          ),
        );
      },
    );
  }
}