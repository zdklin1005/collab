import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/localquest_theme.dart';
import '../core/localquest_widgets.dart';
import '../models/localquest_models.dart';
import '../services/cloudinary_images.dart';
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

    Widget content;
    if (msg.isImage && msg.imageUrl != null) {
      content = Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _openFullScreenImage(context, msg.imageUrl!),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 220,
                  maxWidth: 240,
                ),
                child: _buildImageContent(msg.imageUrl!),
              ),
            ),
          ),
          if (msg.text.isNotEmpty && msg.text != '📷 Photo') ...[
            const SizedBox(height: 6),
            Text(
              msg.text,
              style: TextStyle(
                fontSize: 14,
                color: isMe ? Colors.white : LqColors.ink,
                height: 1.35,
              ),
            ),
          ],
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
      );
    } else if (msg.isLocation && msg.latitude != null && msg.longitude != null) {
      content = InkWell(
        onTap: () => _openLocationInMap(msg.latitude!, msg.longitude!),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.2)
                        : LqColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    color: isMe ? Colors.white : LqColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shared Location',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isMe ? Colors.white : LqColors.ink,
                        ),
                      ),
                      Text(
                        msg.locationName ??
                            '${msg.latitude!.toStringAsFixed(4)}, ${msg.longitude!.toStringAsFixed(4)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.85)
                              : LqColors.muted,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.map_outlined,
                  size: 13,
                  color: isMe ? Colors.white70 : LqColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Tap to open map',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isMe ? Colors.white70 : LqColors.primary,
                  ),
                ),
              ],
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
    } else {
      content = Column(
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
      );
    }

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
      child: content,
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

  Widget _buildImageContent(String url) {
    if (url.startsWith('data:image')) {
      try {
        final commaIndex = url.indexOf(',');
        final base64Data = commaIndex != -1 ? url.substring(commaIndex + 1) : url;
        final bytes = base64Decode(base64Data);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _imageFallback(),
        );
      } catch (_) {
        return _imageFallback();
      }
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : Container(
              height: 160,
              color: LqColors.field,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
      errorBuilder: (_, _, _) => _imageFallback(),
    );
  }

  Widget _imageFallback() {
    return Container(
      height: 140,
      color: LqColors.field,
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: LqColors.muted, size: 32),
          SizedBox(height: 4),
          Text(
            'Unable to load photo',
            style: TextStyle(fontSize: 12, color: LqColors.muted),
          ),
        ],
      ),
    );
  }

  void _openFullScreenImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        insetPadding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: _buildImageContent(url),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLocationInMap(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (_) {
      if (mounted) {
        showLqMessage(context, 'Could not open map: $lat, $lng');
      }
    }
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: const BoxDecoration(
          color: LqColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: LqColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Share with friend',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: LqColors.ink,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _attachmentOption(
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    color: const Color(0xFF3267D4),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _pickAndSendImage(ImageSource.gallery);
                    },
                  ),
                  _attachmentOption(
                    icon: Icons.camera_alt_outlined,
                    label: 'Camera',
                    color: const Color(0xFF00B894),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _pickAndSendImage(ImageSource.camera);
                    },
                  ),
                  _attachmentOption(
                    icon: Icons.location_on_outlined,
                    label: 'Location',
                    color: const Color(0xFFE17055),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _shareCurrentLocation();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: LqColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (picked == null || !mounted) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      final captionController = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: LqColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Send Photo', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  bytes,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: captionController,
                decoration: InputDecoration(
                  hintText: 'Add a caption... (optional)',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  filled: true,
                  fillColor: LqColors.field,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: LqColors.primary),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Send'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      setState(() => _isSending = true);

      String finalUrl = '';
      try {
        final uploaded = await CloudinaryImages.instance.upload(bytes);
        finalUrl = uploaded.url;
      } catch (_) {
        final base64Data = base64Encode(bytes);
        finalUrl = 'data:image/jpeg;base64,$base64Data';
      }

      await DirectChatService.instance.sendImageMessage(
        currentUser: widget.currentUser,
        targetUserId: widget.targetUserId,
        targetDisplayName: widget.targetDisplayName,
        targetUsername: widget.targetUsername,
        targetPhotoUrl: widget.targetPhotoUrl,
        imageUrl: finalUrl,
        caption: captionController.text.trim().isNotEmpty
            ? captionController.text.trim()
            : null,
      );

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        showLqMessage(context, 'Could not send photo. Please try again.', error: true);
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _shareCurrentLocation() async {
    try {
      setState(() => _isSending = true);

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          showLqMessage(context, 'Location permission is required to share location.', error: true);
        }
        return;
      }

      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          showLqMessage(context, 'Please turn on Location Services on your device.', error: true);
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (!mounted) return;

      final locationName =
          'George Town, Penang (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';

      await DirectChatService.instance.sendLocationMessage(
        currentUser: widget.currentUser,
        targetUserId: widget.targetUserId,
        targetDisplayName: widget.targetDisplayName,
        targetUsername: widget.targetUsername,
        targetPhotoUrl: widget.targetPhotoUrl,
        latitude: position.latitude,
        longitude: position.longitude,
        locationName: locationName,
      );

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        showLqMessage(context, 'Could not retrieve location. Please try again.', error: true);
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
            IconButton(
              icon: const Icon(
                Icons.add_circle_outline_rounded,
                color: LqColors.primary,
                size: 26,
              ),
              tooltip: 'Share photo or location',
              onPressed: _showAttachmentSheet,
            ),
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
