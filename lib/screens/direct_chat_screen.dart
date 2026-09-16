import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/localquest_theme.dart';
import '../core/localquest_widgets.dart';
import '../data/mock_map_data.dart';
import '../models/localquest_models.dart';
import '../services/cloudinary_images.dart';
import '../services/direct_chat_service.dart';
import '../services/in_app_notification_service.dart';
import '../services/localquest_services.dart';
import '../services/social_service.dart';

class DirectChatScreen extends StatefulWidget {
  const DirectChatScreen({
    super.key,
    required this.currentUser,
    required this.targetUserId,
    required this.targetDisplayName,
    required this.targetUsername,
    this.targetPhotoUrl,
    this.initialSelectedImageBytes,
  });

  final AppUser currentUser;
  final String targetUserId;
  final String targetDisplayName;
  final String targetUsername;
  final String? targetPhotoUrl;
  final Uint8List? initialSelectedImageBytes;

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  late final String _chatId;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  Uint8List? _selectedImageBytes;

  @override
  void initState() {
    super.initState();
    _selectedImageBytes = widget.initialSelectedImageBytes;
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
    final imageBytes = _selectedImageBytes;
    if ((text.isEmpty && imageBytes == null) || _isSending) return;

    _controller.clear();
    setState(() {
      _selectedImageBytes = null;
      _isSending = true;
    });

    try {
      if (imageBytes != null) {
        String finalUrl = '';
        try {
          final uploaded = await CloudinaryImages.instance.upload(imageBytes);
          finalUrl = uploaded.url;
        } catch (_) {
          final base64Data = base64Encode(imageBytes);
          finalUrl = 'data:image/jpeg;base64,$base64Data';
        }

        await DirectChatService.instance.sendImageMessage(
          currentUser: widget.currentUser,
          targetUserId: widget.targetUserId,
          targetDisplayName: widget.targetDisplayName,
          targetUsername: widget.targetUsername,
          targetPhotoUrl: widget.targetPhotoUrl,
          imageUrl: finalUrl,
          caption: text.isNotEmpty ? text : null,
        );
      } else {
        await DirectChatService.instance.sendMessage(
          currentUser: widget.currentUser,
          targetUserId: widget.targetUserId,
          targetDisplayName: widget.targetDisplayName,
          targetUsername: widget.targetUsername,
          targetPhotoUrl: widget.targetPhotoUrl,
          text: text,
        );
      }
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
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: StreamBuilder<AppUser>(
            stream: UserRepository.instance.watch(widget.targetUserId),
            builder: (context, userSnap) {
              final user = userSnap.data;
              final level = user?.level ?? 1;
              final exp = user?.exp ?? 0;
              final displayName = user?.displayName ?? widget.targetDisplayName;
              final username = user?.username ?? widget.targetUsername;
              final photoUrl = user?.photoUrl ?? widget.targetPhotoUrl;

              return StreamBuilder<UserNote?>(
                stream: SocialService.instance.streamUserNote(widget.targetUserId),
                builder: (context, noteSnap) {
                  final note = noteSnap.data;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: LqColors.line,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Avatar with Level pill
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.bottomRight,
                        children: [
                          LqAvatar(
                            initials: initialsFor(displayName),
                            photoUrl: photoUrl,
                            radius: 38,
                          ),
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: LqColors.primary,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Text(
                                'Lv.$level',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Display name & @username
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: LqColors.ink,
                        ),
                      ),
                      Text(
                        username.startsWith('@') ? username : '@$username',
                        style: const TextStyle(
                          fontSize: 13,
                          color: LqColors.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Account Tier Badge
                      LqTierBadge(level: level),
                      const SizedBox(height: 16),

                      // Status / 24-hr Note / Spotify Music Status
                      if (note != null && (note.text.isNotEmpty || note.hasMusic))
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F7FD),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFD6E3F8)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 14,
                                    color: LqColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '24-HR STATUS NOTE',
                                    style: monoLabel.copyWith(
                                      fontSize: 9.5,
                                      letterSpacing: 1.0,
                                      color: LqColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              if (note.text.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  '"${note.text}"',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: LqColors.ink,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                              if (note.hasMusic) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      if (note.albumArtUrl != null && note.albumArtUrl!.isNotEmpty)
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: Image.network(
                                            note.albumArtUrl!,
                                            width: 36,
                                            height: 36,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) => Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF1DB954).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Icon(Icons.music_note, color: Color(0xFF1DB954), size: 20),
                                            ),
                                          ),
                                        )
                                      else
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1DB954).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Icon(Icons.music_note, color: Color(0xFF1DB954), size: 20),
                                        ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              note.songTitle ?? '',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: LqColors.ink,
                                              ),
                                            ),
                                            Text(
                                              note.songArtist ?? '',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: LqColors.muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.music_note_rounded,
                                        color: Color(0xFF1DB954),
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Active Penang Explorer',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: LqColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // EXP Progress Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: LqColors.line),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0A000000),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'EXPLORER EXP',
                                  style: monoLabel.copyWith(
                                    fontSize: 10,
                                    letterSpacing: 1.2,
                                    color: LqColors.muted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '$exp XP',
                                  style: monoLabel.copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: LqColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: ((exp % 3000) / 3000.0).clamp(0.05, 1.0),
                                minHeight: 8,
                                backgroundColor: const Color(0xFFE2E8F0),
                                valueColor: const AlwaysStoppedAnimation<Color>(LqColors.primary),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Level $level Explorer • Next tier at ${level * 3000} XP',
                              style: const TextStyle(
                                fontSize: 11,
                                color: LqColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Remove Friend Action Button
                      OutlinedButton.icon(
                        key: const Key('direct_chat_remove_friend_button'),
                        icon: const Icon(
                          Icons.person_remove_outlined,
                          size: 18,
                          color: LqColors.danger,
                        ),
                        label: const Text(
                          'Remove Friend',
                          style: TextStyle(
                            color: LqColors.danger,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          backgroundColor: const Color(0xFFFEF2F2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: ctx,
                            builder: (dialogCtx) => AlertDialog(
                              title: const Text('Remove Friend'),
                              content: Text(
                                'Are you sure you want to remove $displayName from your friends list?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogCtx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogCtx, true),
                                  child: const Text(
                                    'Remove',
                                    style: TextStyle(color: LqColors.danger),
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await SocialService.instance.removeFriend(
                              currentUserId: widget.currentUser.id,
                              friendUserId: widget.targetUserId,
                            );
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text('Removed $displayName from friends'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: LqColors.line),
                      const SizedBox(height: 10),

                      // Privacy footnote
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
                  );
                },
              );
            },
          ),
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
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _showFriendDetails,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: StreamBuilder<AppUser>(
                          stream: UserRepository.instance.watch(widget.targetUserId),
                          builder: (context, snap) {
                            final liveUser = snap.data;
                            final photo = (liveUser?.photoUrl != null && liveUser!.photoUrl!.isNotEmpty)
                                ? liveUser.photoUrl
                                : widget.targetPhotoUrl;
                            final name = (liveUser != null &&
                                    liveUser.displayName.isNotEmpty &&
                                    liveUser.displayName != 'LocalQuest Explorer')
                                ? liveUser.displayName
                                : widget.targetDisplayName;
                            final uname = (liveUser != null &&
                                    liveUser.username.isNotEmpty &&
                                    liveUser.username != '@explorer')
                                ? liveUser.username
                                : widget.targetUsername;

                            return Row(
                              children: [
                                LqAvatar(
                                  initials: initialsFor(name),
                                  photoUrl: photo,
                                  radius: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: LqColors.ink,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        uname,
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
                              ],
                            );
                          },
                        ),
                      ),
                    ),
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
      final isBusinessPlace = msg.locationName != null && msg.locationName!.contains(' • ');
      final placeTitle = isBusinessPlace
          ? msg.locationName!.split(' • ').first
          : 'Shared Location';
      final placeSubtitle = isBusinessPlace
          ? msg.locationName!.split(' • ').last
          : (msg.locationName ??
              '${msg.latitude!.toStringAsFixed(4)}, ${msg.longitude!.toStringAsFixed(4)}');

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
                        : (isBusinessPlace ? const Color(0xFFEBF3FE) : LqColors.primarySoft),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isBusinessPlace ? Icons.storefront_rounded : Icons.location_on_rounded,
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
                        placeTitle,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isMe ? Colors.white : LqColors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        placeSubtitle,
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
                      _showShareLocationSheet();
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

      setState(() {
        _selectedImageBytes = bytes;
      });
    } catch (e) {
      if (mounted) {
        showLqMessage(context, 'Could not select photo. Please try again.', error: true);
      }
    }
  }

  void _showShareLocationSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: LqColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => _ShareLocationModal(
        onShareCurrentLocation: () {
          Navigator.pop(sheetCtx);
          _shareCurrentLocation();
        },
        onSharePlace: (name, area, lat, lng) {
          Navigator.pop(sheetCtx);
          _sendPlaceLocation(
            name: name,
            area: area,
            latitude: lat,
            longitude: lng,
          );
        },
      ),
    );
  }

  Future<void> _sendPlaceLocation({
    required String name,
    required String area,
    required double latitude,
    required double longitude,
  }) async {
    try {
      setState(() => _isSending = true);

      final locationName = '$name • ${area.isNotEmpty ? area : 'Penang'}';

      await DirectChatService.instance.sendLocationMessage(
        currentUser: widget.currentUser,
        targetUserId: widget.targetUserId,
        targetDisplayName: widget.targetDisplayName,
        targetUsername: widget.targetUsername,
        targetPhotoUrl: widget.targetPhotoUrl,
        latitude: latitude,
        longitude: longitude,
        locationName: locationName,
      );

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        showLqMessage(context, 'Could not share location. Please try again.', error: true);
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedImageBytes != null) ...[
              Padding(
                padding: const EdgeInsets.only(left: 46, bottom: 8, top: 4),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: LqColors.line, width: 1.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          _selectedImageBytes!,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: GestureDetector(
                        key: const Key('remove_selected_image_btn'),
                        onTap: () => setState(() => _selectedImageBytes = null),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: LqColors.ink,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Row(
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
                      hintText: _selectedImageBytes != null
                          ? 'Add a caption...'
                          : 'Type a message...',
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
          ],
        ),
      ),
    );
  }
}

class _ShareLocationModal extends StatefulWidget {
  const _ShareLocationModal({
    required this.onShareCurrentLocation,
    required this.onSharePlace,
  });

  final VoidCallback onShareCurrentLocation;
  final void Function(String name, String area, double lat, double lng) onSharePlace;

  @override
  State<_ShareLocationModal> createState() => _ShareLocationModalState();
}

class _ShareLocationModalState extends State<_ShareLocationModal> {
  final _searchController = TextEditingController();
  String _query = '';
  List<Business> _businesses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPlaces() async {
    final initialList = List<Business>.from(MockMapData.businesses);
    for (final lm in MockMapData.landmarks) {
      initialList.add(
        Business(
          id: lm.id,
          ownerId: 'heritage',
          name: lm.title,
          category: lm.category,
          address: lm.description,
          phone: '',
          area: 'George Town',
          latitude: lm.latitude,
          longitude: lm.longitude,
        ),
      );
    }
    if (mounted) {
      setState(() {
        _businesses = initialList;
        _loading = false;
      });
    }

    try {
      final snap = await MerchantRepository.instance.db
          .collection('businesses')
          .limit(30)
          .get();
      final remoteList = snap.docs.map(Business.fromDoc).toList();
      if (remoteList.isNotEmpty && mounted) {
        final existingIds = initialList.map((b) => b.id).toSet();
        for (final b in remoteList) {
          if (!existingIds.contains(b.id)) {
            initialList.add(b);
          }
        }
        setState(() {
          _businesses = initialList;
        });
      }
    } catch (_) {
      // offline fallback is completely fine
    }
  }

  List<Business> get _filteredPlaces {
    if (_query.trim().isEmpty) return _businesses;
    final q = _query.trim().toLowerCase();
    return _businesses.where((b) {
      return b.name.toLowerCase().contains(q) ||
          b.category.toLowerCase().contains(q) ||
          b.area.toLowerCase().contains(q) ||
          b.address.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final places = _filteredPlaces;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: LqColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Share Location',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: LqColors.ink,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: LqColors.muted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Option 1: Live current GPS location
            InkWell(
              onTap: widget.onShareCurrentLocation,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: LqColors.primarySoft.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: LqColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: LqColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.my_location_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Current Location',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: LqColors.ink,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Share live GPS coordinates in Penang',
                            style: TextStyle(
                              fontSize: 12,
                              color: LqColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: LqColors.primary,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),
            Text(
              'OR SHARE A BUSINESS / PLACE',
              style: monoLabel.copyWith(
                fontSize: 10,
                letterSpacing: 1.2,
                color: LqColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),

            // Search input field
            TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _query = val),
              decoration: InputDecoration(
                hintText: 'Search businesses, cafes, heritage...',
                hintStyle: const TextStyle(fontSize: 13, color: LqColors.muted),
                prefixIcon: const Icon(Icons.search, size: 20, color: LqColors.muted),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16, color: LqColors.muted),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: LqColors.field,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: LqColors.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: LqColors.line),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Places List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: LqColors.primary))
                  : places.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.storefront_outlined, size: 36, color: LqColors.muted),
                                const SizedBox(height: 8),
                                Text(
                                  'No businesses found matching "$_query"',
                                  style: const TextStyle(fontSize: 13, color: LqColors.muted),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: places.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, color: LqColors.line),
                          itemBuilder: (context, idx) {
                            final b = places[idx];
                            final areaText = b.area.isNotEmpty
                                ? b.area
                                : (b.address.isNotEmpty ? b.address : 'Penang');
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              leading: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEBF3FE),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _categoryIcon(b.category),
                                  color: LqColors.primary,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                b.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: LqColors.ink,
                                ),
                              ),
                              subtitle: Text(
                                '${b.category} • $areaText',
                                style: const TextStyle(fontSize: 12, color: LqColors.muted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(
                                Icons.send_rounded,
                                size: 18,
                                color: LqColors.primary,
                              ),
                              onTap: () => widget.onSharePlace(
                                b.name,
                                areaText,
                                b.latitude ?? 5.4164,
                                b.longitude ?? 100.3327,
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    final c = category.toLowerCase();
    if (c.contains('food') || c.contains('beverage') || c.contains('cafe') || c.contains('coffee')) {
      return Icons.restaurant_rounded;
    }
    if (c.contains('heritage') || c.contains('attraction') || c.contains('sight')) {
      return Icons.account_balance_rounded;
    }
    if (c.contains('art') || c.contains('craft')) {
      return Icons.brush_rounded;
    }
    return Icons.storefront_rounded;
  }
}
