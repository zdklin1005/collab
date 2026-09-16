import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/demo_database_seeder.dart';
import '../core/localquest_theme.dart';
import '../core/localquest_widgets.dart';
import '../models/localquest_models.dart';
import 'package:geolocator/geolocator.dart';
import '../services/ai_tourist_guide_service.dart';
import '../services/localquest_services.dart';
import '../services/location_service.dart';

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
    this.modelUsed,
  });

  final bool isUser;
  final String text;
  final DateTime time;
  final String? modelUsed;
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
  List<Map<String, dynamic>> _cachedVisitedPlaces = [];

  double? _liveLat;
  double? _liveLng;

  double get _currentLat => _liveLat ?? widget.currentLat;
  double get _currentLng => _liveLng ?? widget.currentLng;

  List<String> _getDynamicLocationPrompts() {
    final prompts = <String>[
      '🎁 Where can I get Welcome Vouchers?',
      '🍜 Authentic Penang Laksa & Cendol',
      '☕ Best artisan cafes & cakes',
      '🍳 Traditional kopitiam breakfast',
      '🍛 Famous Halal Nasi Kandar',
      '🛍️ Batik & artisan craft souvenirs',
    ];

    // Context from user's visited places:
    if (_cachedVisitedPlaces.isNotEmpty) {
      final lastVisited = _cachedVisitedPlaces.first['name'] as String?;
      if (lastVisited != null && lastVisited.isNotEmpty) {
        prompts.insert(0, '📍 What should I explore after visiting $lastVisited?');
      }
    }

    // Mainland / Seberang Perai region dynamic prompt:
    if (_currentLng >= 100.36 && _currentLat >= 5.10 && _currentLat <= 5.65) {
      prompts.add('📍 Where am I right now?');
      prompts.add('🌉 How to get from Mainland to George Town?');
      prompts.add('🍛 Famous food spots in Seberang Perai & Butterworth');
    }

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
    if (_currentLat >= 5.41 && _currentLat <= 5.43) {
      prompts.add('🏛️ George Town UNESCO Heritage Walk');
    } else if (_currentLat >= 5.39 && _currentLat < 5.41) {
      prompts.add('🏯 Kek Lok Si Temple & Air Itam Laksa');
      prompts.add('🚡 Penang Hill funicular & nature trails');
    } else if (_currentLat >= 5.43 && _currentLat <= 5.46) {
      prompts.add('🌊 Gurney Drive seaside dining & hawker stalls');
    } else {
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
    prompts.add('🏷️ What vouchers can I claim right now?');

    return prompts.toSet().toList();
  }

  @override
  void initState() {
    super.initState();
    _loadLocalContext();
    _resolveLiveLocation();
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

  Future<void> _resolveLiveLocation() async {
    // 1. Check LocationTrackerService last known GPS position
    final trackerPos = LocationTrackerService.instance.lastPosition;
    if (trackerPos != null && trackerPos.latitude.isFinite && trackerPos.longitude.isFinite) {
      if (mounted) {
        setState(() {
          _liveLat = trackerPos.latitude;
          _liveLng = trackerPos.longitude;
        });
      }
    }

    // 2. Query Geolocator for fresh GPS fix
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (enabled) {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          final lastKnown = await Geolocator.getLastKnownPosition();
          if (lastKnown != null && mounted) {
            setState(() {
              _liveLat = lastKnown.latitude;
              _liveLng = lastKnown.longitude;
            });
          }

          final fresh = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 4),
            ),
          );
          if (mounted) {
            setState(() {
              _liveLat = fresh.latitude;
              _liveLng = fresh.longitude;
            });
          }
        }
      }
    } catch (_) {}

    // 3. Fallback: check recent visited places if GPS fix wasn't retrieved
    if (_liveLat == null && _cachedVisitedPlaces.isNotEmpty) {
      for (final place in _cachedVisitedPlaces) {
        final lat = place['latitude'] as num?;
        final lng = place['longitude'] as num?;
        if (lat != null && lng != null && lat.toDouble().isFinite && lng.toDouble().isFinite) {
          if (mounted) {
            setState(() {
              _liveLat = lat.toDouble();
              _liveLng = lng.toDouble();
            });
          }
          break;
        }
      }
    }
  }



  Future<void> _loadLocalContext() async {
    try {
      final bizSnap = await MerchantRepository.instance.db
          .collection('businesses')
          .limit(30)
          .get();
      final firestoreBiz = bizSnap.docs.map(Business.fromDoc).toList();

      final campSnap = await MerchantRepository.instance.db
          .collection('campaigns')
          .limit(50)
          .get();
      final firestoreCamps = campSnap.docs.map(Campaign.fromDoc).toList();

      // Combine authentic Penang partner venues with live Firestore businesses,
      // guaranteeing full coverage of Penang heritage spots and active Welcome Vouchers
      final combinedBiz = <String, Business>{};
      for (final b in DemoDatabaseSeeder.sampleMalaysianBusinesses.map((e) => e.toBusiness())) {
        combinedBiz[b.id] = b;
      }
      for (final b in firestoreBiz) {
        combinedBiz[b.id] = b;
      }
      _cachedBusinesses = combinedBiz.values.toList();

      final combinedCamps = <String, Campaign>{};
      for (final c in DemoDatabaseSeeder.sampleMalaysianBusinesses.expand((b) => b.vouchers.map((v) => v.toCampaign(businessId: b.id)))) {
        combinedCamps[c.id] = c;
      }
      for (final c in firestoreCamps) {
        combinedCamps[c.id] = c;
      }
      _cachedVouchers = combinedCamps.values.toList();

      // Fetch user's recent visited places from Firestore
      try {
        final visitSnap = await UserRepository.instance.db
            .collection('users')
            .doc(widget.user.id)
            .collection('visitedPlaces')
            .orderBy('visitedAt', descending: true)
            .limit(5)
            .get();

        _cachedVisitedPlaces = visitSnap.docs.map((d) {
          final data = d.data();
          final date = (data['visitedAt'] as Timestamp?)?.toDate();
          return {
            'name': data['name'] ?? '',
            'area': data['area'] ?? '',
            'businessId': data['businessId'] ?? '',
            'latitude': data['latitude'],
            'longitude': data['longitude'],
            'time': date != null ? DateFormat('d MMM, HH:mm').format(date) : '',
          };
        }).toList();

        // If GPS wasn't yet acquired, check if recent visited place can supply coordinates
        if (_liveLat == null) {
          _resolveLiveLocation();
        }
      } catch (_) {}
    } catch (_) {
      // Offline fallback
      _cachedBusinesses = DemoDatabaseSeeder.sampleMalaysianBusinesses
          .map((b) => b.toBusiness())
          .toList();
      _cachedVouchers = DemoDatabaseSeeder.sampleMalaysianBusinesses
          .expand((b) => b.vouchers.map((v) => v.toCampaign(businessId: b.id)))
          .toList();
    }

    if (mounted) setState(() {});
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
      final history = _messages
          .where((m) => m.text.isNotEmpty)
          .map((m) => AiChatMessageHistory(
                isUser: m.isUser,
                text: m.text,
                time: m.time,
              ))
          .toList();

      final response = await _aiService.askGuide(
        userPrompt: query,
        userLat: _currentLat,
        userLng: _currentLng,
        nearbyBusinesses: _cachedBusinesses,
        activeVouchers: _cachedVouchers,
        userProfile: widget.user,
        visitedPlacesHistory: _cachedVisitedPlaces,
        conversationHistory: history,
      );

      if (mounted) {
        setState(() {
          _messages.add(
            _AiChatMessage(
              isUser: false,
              text: response,
              time: DateTime.now(),
              modelUsed: _aiService.lastSuccessfulModel,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'LocalQuest AI Guide',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: LqColors.ink,
                        ),
                      ),
                      const Text(
                        'Penang Travel & Heritage Guide',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
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
    var text = AiTouristGuideService.sanitizeTechnicalInformation(raw);
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
