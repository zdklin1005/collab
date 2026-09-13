import 'package:flutter/material.dart';
import '../core/localquest_theme.dart';
import '../core/localquest_widgets.dart';
import '../models/localquest_models.dart';
import '../services/ai_tourist_guide_service.dart';
import '../services/localquest_services.dart';

class AiAssistantSheet extends StatefulWidget {
  const AiAssistantSheet({
    super.key,
    required this.user,
    this.currentLat = 5.4141, // Default George Town, Penang
    this.currentLng = 100.3288,
  });

  final AppUser user;
  final double currentLat;
  final double currentLng;

  @override
  State<AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiChatMessage {
  const _AiChatMessage({
    required this.isUser,
    required this.text,
    required this.time,
  });

  final bool isUser;
  final String text;
  final DateTime time;
}

class _AiAssistantSheetState extends State<AiAssistantSheet> {
  final _aiService =
      AiTouristGuideService(apiKey: AiTouristGuideService.defaultApiKey);
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_AiChatMessage> _messages = [];
  bool _isLoading = false;

  List<Business> _cachedBusinesses = [];
  List<Campaign> _cachedVouchers = [];

  List<String> _getDynamicLocationPrompts() {
    final prompts = <String>[
      '🎁 Where can I get Welcome Vouchers?',
      '🍜 Authentic Penang Laksa & Cendol',
    ];

    // 1. Context from verified merchants in Firestore:
    if (_cachedBusinesses.isNotEmpty) {
      // Businesses with welcome vouchers
      final welcomeBiz = _cachedBusinesses.where((b) {
        return _cachedVouchers.any((v) => v.businessId == b.id && v.isWelcomeVoucher);
      }).toList();

      if (welcomeBiz.isNotEmpty) {
        prompts.add('🎁 How to claim ${welcomeBiz.first.name}\'s Welcome Voucher?');
      }

      // Cafes or dining spots
      final diningBiz = _cachedBusinesses.where((b) {
        final cat = b.category.toLowerCase();
        return cat.contains('cafe') || cat.contains('dining') || cat.contains('food') || cat.contains('bakery');
      }).toList();

      if (diningBiz.isNotEmpty) {
        prompts.add('☕ What\'s popular at ${diningBiz.first.name}?');
      }

      // Location area of registered shop
      final areaBiz = _cachedBusinesses.where((b) => b.area.isNotEmpty).toList();
      if (areaBiz.isNotEmpty) {
        prompts.add('📍 Must-visit spots around ${areaBiz.first.area}');
      }
    }

    // 2. Dynamic coordinate-based Penang recommendations:
    if (widget.currentLat >= 5.41 && widget.currentLat <= 5.43) {
      prompts.add('🏛️ George Town UNESCO Heritage Walk');
      prompts.add('🍜 Authentic Penang Laksa & Cendol');
    } else if (widget.currentLat >= 5.39 && widget.currentLat < 5.41) {
      prompts.add('🏯 Kek Lok Si Temple & Air Itam Laksa');
      prompts.add('🚡 Penang Hill funicular & nature trails');
    } else if (widget.currentLat >= 5.43 && widget.currentLat <= 5.46) {
      prompts.add('🌊 Gurney Drive seaside dining & hawker stalls');
    } else {
      prompts.add('🍜 Authentic Penang Laksa & Cendol');
      prompts.add('🎨 Street Art Murals along Armenian Street');
    }

    // 3. Time-of-day dynamic prompt:
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 11) {
      prompts.add('🍳 Authentic Penang breakfast & kopitiam nearby');
    } else if (hour >= 11 && hour < 15) {
      prompts.add('🍧 Teochew Chendul & lunch spots near me');
    } else if (hour >= 15 && hour < 18) {
      prompts.add('☕ Best artisan coffee & tea-time cakes nearby');
    } else {
      prompts.add('🌙 Famous night markets & supper tonight');
    }

    // 4. Voucher discovery prompts:
    prompts.add('🎁 Where can I get Welcome Vouchers?');
    prompts.add('🏷️ What vouchers can I claim right now?');

    return prompts.toSet().toList();
  }

  @override
  void initState() {
    super.initState();
    _loadLocalContext();
    _messages.add(
      _AiChatMessage(
        isUser: false,
        text:
            'Hello ${widget.user.displayName}! 👋 I am your LocalQuest Penang AI Travel Guide. '
            'Ask me for authentic street food recommendations, cultural heritage walks, or '
            'discover shops offering 1-time Welcome Vouchers & Seasonal promotions in Penang!',
        time: DateTime.now(),
      ),
    );
  }

  Future<void> _loadLocalContext() async {
    try {
      final bizSnap = await MerchantRepository.instance.db
          .collection('businesses')
          .limit(20)
          .get();
      _cachedBusinesses = bizSnap.docs.map(Business.fromDoc).toList();

      final campSnap = await MerchantRepository.instance.db
          .collection('campaigns')
          .limit(20)
          .get();
      _cachedVouchers = campSnap.docs.map(Campaign.fromDoc).toList();
      if (mounted) setState(() {});
    } catch (_) {
      // Offline fallback is handled gracefully
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
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

  Future<void> _handleSend([String? presetPrompt]) async {
    final query = (presetPrompt ?? _controller.text).trim();
    if (query.isEmpty || _isLoading) return;

    _controller.clear();
    setState(() {
      _messages.add(
        _AiChatMessage(
          isUser: true,
          text: query,
          time: DateTime.now(),
        ),
      );
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final response = await _aiService.askGuide(
        userPrompt: query,
        userLat: widget.currentLat,
        userLng: widget.currentLng,
        nearbyBusinesses: _cachedBusinesses,
        activeVouchers: _cachedVouchers,
      );

      if (mounted) {
        setState(() {
          _messages.add(
            _AiChatMessage(
              isUser: false,
              text: response,
              time: DateTime.now(),
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            _AiChatMessage(
              isUser: false,
              text:
                  'Unable to fetch recommendation right now. Please explore nearby Penang spots or try again!',
              time: DateTime.now(),
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: LqColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: LqColors.line,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [LqColors.primary, Color(0xFF6C5CE7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: LqColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LocalQuest AI Guide',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: LqColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Authentic Penang insights & voucher discovery',
                        style: TextStyle(
                          fontSize: 12,
                          color: LqColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: LqColors.muted),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: LqColors.line),

          // Message Thread
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                if (msg.isUser) {
                  return _buildUserBubble(msg);
                } else {
                  return _buildAiBubble(msg);
                }
              },
            ),
          ),

          // Loading indicator
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: LqColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'LocalQuest AI is finding recommendations...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: LqColors.muted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

          // Quick Prompt Chips (Placed directly above input box)
          Builder(
            builder: (context) {
              final dynamicPrompts = _getDynamicLocationPrompts();
              return Container(
                height: 44,
                margin: const EdgeInsets.only(bottom: 4),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  scrollDirection: Axis.horizontal,
                  itemCount: dynamicPrompts.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final prompt = dynamicPrompts[index];
                    return CustomPaint(
                      foregroundPainter: const LqDashedBorderPainter(
                        color: LqColors.primary,
                        radius: 18,
                        strokeWidth: 1.2,
                      ),
                      child: ActionChip(
                        label: Text(
                          prompt,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: LqColors.ink,
                          ),
                        ),
                        backgroundColor: LqColors.surface,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        onPressed: () => _handleSend(prompt),
                      ),
                    );
                  },
                ),
              );
            },
          ),

          // Input Bar
          Container(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + bottomInset),
            decoration: BoxDecoration(
              color: LqColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  offset: const Offset(0, -2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _handleSend(),
                    decoration: InputDecoration(
                      hintText: 'Ask about food, heritage, or vouchers in Penang...',
                      hintStyle: const TextStyle(
                        fontSize: 13,
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
                  icon: const Icon(Icons.send_rounded, size: 20),
                  onPressed: _handleSend,
                  tooltip: 'Send',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserBubble(_AiChatMessage msg) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, left: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: LqColors.primary,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(
          msg.text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildAiBubble(_AiChatMessage msg) {
    const bubbleRadius = BorderRadius.only(
      topLeft: Radius.circular(4),
      topRight: Radius.circular(18),
      bottomLeft: Radius.circular(18),
      bottomRight: Radius.circular(18),
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12, right: 36),
        child: CustomPaint(
          foregroundPainter: const LqDashedBorderPainter(
            color: LqColors.primary,
            borderRadius: bubbleRadius,
            strokeWidth: 1.35,
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: LqColors.surface,
              borderRadius: bubbleRadius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: LqColors.primary,
                ),
                const SizedBox(width: 5),
                Text(
                  'LocalQuest Guide',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: LqColors.primaryDark.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
                SelectableText(
                  _cleanAiMarkdown(msg.text),
                  style: const TextStyle(
                    color: LqColors.ink,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _cleanAiMarkdown(String raw) {
    var text = raw;
    // Replace markdown list asterisks (* **, * , - ) with clean bullet character (• )
    text = text.replaceAll(RegExp(r'^\s*[*•-]\s*\*{1,2}', multiLine: true), '• ');
    text = text.replaceAll(RegExp(r'^\s*[*•-]\s+', multiLine: true), '• ');
    // Remove raw bold / italic asterisks
    text = text.replaceAll('***', '');
    text = text.replaceAll('**', '');
    // Remove backticks
    text = text.replaceAll('`', '');
    // Clean up duplicate bullets if any
    text = text.replaceAll('• • ', '• ');
    return text.trim();
  }
}
