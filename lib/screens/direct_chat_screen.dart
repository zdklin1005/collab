import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/localquest_theme.dart';
import '../core/localquest_widgets.dart';
import '../models/localquest_models.dart';
import '../services/direct_chat_service.dart';
import '../services/in_app_notification_service.dart';

class DirectChatScreen extends StatefulWidget {
  const DirectChatScreen({
    super.key,
    required this.currentUser,
    required this.targetUserId,
    required this.targetDisplayName,
    required this.targetUsername,
    this.targetPhotoUrl,
  });

  final AppUser currentUser;
  final String targetUserId;
  final String targetDisplayName;
  final String targetUsername;
  final String? targetPhotoUrl;

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  late final String _chatId;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _chatId = DirectChatService.getChatId(
      widget.currentUser.id,
      widget.targetUserId,
    );
    InAppNotificationService.instance.activeChatId = _chatId;
    _markRead();
  }

  void _markRead() {
    DirectChatService.instance.markChatAsRead(
      chatId: _chatId,
      currentUserId: widget.currentUser.id,
    );
  }

  @override
  void dispose() {
    if (InAppNotificationService.instance.activeChatId == _chatId) {
      InAppNotificationService.instance.activeChatId = null;
    }
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    _controller.clear();
    setState(() => _isSending = true);

    try {
      await DirectChatService.instance.sendMessage(
        currentUser: widget.currentUser,
        targetUserId: widget.targetUserId,
        targetDisplayName: widget.targetDisplayName,
        targetUsername: widget.targetUsername,
        targetPhotoUrl: widget.targetPhotoUrl,
        text: text,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showFriendDetails() {
    showModalBottomSheet(
      context: context,
      backgroundColor: LqColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LqAvatar(
              initials: initialsFor(widget.targetDisplayName),
              photoUrl: widget.targetPhotoUrl,
              radius: 36,
            ),
            const SizedBox(height: 12),
            Text(
              widget.targetDisplayName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: LqColors.ink,
              ),
            ),
            Text(
              widget.targetUsername,
              style: const TextStyle(
                fontSize: 13,
                color: LqColors.muted,
              ),
            ),
            const SizedBox(height: 20),
            const Divider(color: LqColors.line),
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.shield_outlined, size: 18, color: LqColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Direct messages are private between tourists within Penang LocalQuest.',
                    style: TextStyle(fontSize: 12, color: LqColors.muted),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LqColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Seamless transparent header
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: LqColors.ink),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 2),
                  LqAvatar(
                    initials: initialsFor(widget.targetDisplayName),
                    photoUrl: widget.targetPhotoUrl,
                    radius: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.targetDisplayName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: LqColors.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.targetUsername,
                          style: const TextStyle(
                            fontSize: 12,
                            color: LqColors.muted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: LqColors.muted),
                    tooltip: 'Friend Details',
                    onPressed: _showFriendDetails,
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<ChatMessage>>(
              stream: DirectChatService.instance.streamMessages(_chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: LqColors.primary),
                  );
                }

                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: const BoxDecoration(
                              color: LqColors.primarySoft,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 36,
                              color: LqColors.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Say hello to ${widget.targetDisplayName}!',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: LqColors.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Plan your heritage walking tour, share food tips, and explore Penang together!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: LqColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _markRead();
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == widget.currentUser.id;
                    return _buildBubble(msg, isMe);
                  },
                );
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    ),
  );
}

  Widget _buildBubble(ChatMessage msg, bool isMe) {
    final timeStr = DateFormat('h:mm a').format(msg.createdAt);
    final bubbleRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isMe ? 16 : 4),
      bottomRight: Radius.circular(isMe ? 4 : 16),
    );

    final bubbleWidget = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.76,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? LqColors.primary : LqColors.surface,
        borderRadius: bubbleRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            msg.text,
            style: TextStyle(
              fontSize: 14,
              color: isMe ? Colors.white : LqColors.ink,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            timeStr,
            style: TextStyle(
              fontSize: 10,
              color: isMe
                  ? Colors.white.withValues(alpha: 0.75)
                  : LqColors.muted,
            ),
          ),
        ],
      ),
    );

    if (isMe) {
      return Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: bubbleWidget,
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: CustomPaint(
          foregroundPainter: LqDashedBorderPainter(
            color: LqColors.primary,
            borderRadius: bubbleRadius,
            strokeWidth: 1.35,
          ),
          child: bubbleWidget,
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: LqColors.surface,
        border: Border(
          top: BorderSide(color: LqColors.line),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSend(),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: LqColors.muted,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: LqColors.field,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: LqColors.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: LqColors.line),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: LqColors.primary,
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
              ),
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
              onPressed: _handleSend,
            ),
          ],
        ),
      ),
    );
  }
}
