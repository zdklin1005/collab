import 'package:flutter/material.dart';
import '../core/localquest_theme.dart';
import '../core/localquest_widgets.dart';
import '../models/localquest_models.dart';
import '../services/leaderboard_service.dart';

/// LeaderboardScreen displays both Global and Friends leaderboards based on EXP and Level.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    super.key,
    required this.currentUser,
    this.initialTab = 0,
  });

  final AppUser currentUser;
  final int initialTab; // 0 for Global, 1 for Friends

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab.clamp(0, 1);
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: _selectedTab,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _selectedTab != _tabController.index) {
        setState(() => _selectedTab = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LqColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header matching Friends and Location History (VisitedPlacesScreen) style
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LqBackButton(label: 'Back'),
                  SizedBox(height: 8),
                  Text(
                    'Leaderboard',
                    style: TextStyle(
                      fontSize: 32,
                      height: 1.12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                      color: LqColors.ink,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // Capsule Tab Selector
            _buildCapsuleTabBar(),

            const SizedBox(height: 8),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Global Leaderboard
                  _buildLeaderboardStream(
                    stream: LeaderboardService.instance.streamGlobalLeaderboard(
                      currentUserId: widget.currentUser.id,
                    ),
                    isFriendsTab: false,
                  ),

                  // Friends Leaderboard
                  _buildLeaderboardStream(
                    stream: LeaderboardService.instance.streamFriendsLeaderboard(
                      currentUserId: widget.currentUser.id,
                    ),
                    isFriendsTab: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapsuleTabBar() {
    final tabs = [
      (0, 'Global', Icons.public),
      (1, 'Friends', Icons.people_outline),
    ];

    return SizedBox(
      width: double.infinity,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: CustomPaint(
            foregroundPainter: const LqDashedBorderPainter(
              color: LqColors.primary,
              radius: 999,
              strokeWidth: 1.35,
            ),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: tabs.map((tab) {
                  final isSelected = _selectedTab == tab.$1;
                  return InkWell(
                    key: Key('leaderboard_tab_${tab.$2.toLowerCase()}'),
                    borderRadius: BorderRadius.circular(999),
                    onTap: () {
                      setState(() => _selectedTab = tab.$1);
                      _tabController.animateTo(tab.$1);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? LqColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: isSelected
                            ? const [
                                BoxShadow(
                                  color: Color(0x333267D4),
                                  blurRadius: 7,
                                  offset: Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            tab.$3,
                            size: 16,
                            color: isSelected ? Colors.white : LqColors.muted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            tab.$2,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : LqColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardStream({
    required Stream<List<LeaderboardEntry>> stream,
    required bool isFriendsTab,
  }) {
    return StreamBuilder<List<LeaderboardEntry>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: LqColors.primary),
          );
        }

        final entries = snapshot.data ?? [];

        if (entries.isEmpty) {
          return _buildEmptyState(isFriendsTab);
        }

        // Identify current user's entry if present
        final currentUserEntry = entries.firstWhere(
          (e) => e.userId == widget.currentUser.id || e.isCurrentUser,
          orElse: () => LeaderboardEntry.fromAppUser(
            widget.currentUser,
            rank: 0,
            currentUserId: widget.currentUser.id,
          ),
        );

        final top3 = entries.take(3).toList();
        final rest = entries.skip(3).toList();

        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
              children: [
                // Top 3 Podium
                _buildPodium(top3),

                const SizedBox(height: 20),

                if (rest.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'TOP EXPLORERS',
                      style: monoLabel.copyWith(
                        fontSize: 10,
                        letterSpacing: 1.6,
                        color: LqColors.muted,
                      ),
                    ),
                  ),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rest.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final entry = rest[index];
                      return _buildRankRow(entry);
                    },
                  ),
                ],
              ],
            ),

            // Sticky Bottom Rank Bar for Current User
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildStickyUserBar(currentUserEntry),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPodium(List<LeaderboardEntry> top3) {
    if (top3.isEmpty) return const SizedBox.shrink();

    final first = top3.isNotEmpty ? top3[0] : null;
    final second = top3.length > 1 ? top3[1] : null;
    final third = top3.length > 2 ? top3[2] : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: LqColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 2nd Place (Silver)
          if (second != null)
            Expanded(
              child: _buildPodiumItem(
                entry: second,
                rank: 2,
                podiumHeight: 80,
                color: const Color(0xFF94A3B8), // Slate silver
                crownColor: const Color(0xFF64748B),
              ),
            )
          else
            const Expanded(child: SizedBox(height: 80)),

          const SizedBox(width: 8),

          // 1st Place (Gold)
          if (first != null)
            Expanded(
              child: _buildPodiumItem(
                entry: first,
                rank: 1,
                podiumHeight: 108,
                color: const Color(0xFFF59E0B), // Amber gold
                crownColor: const Color(0xFFD97706),
              ),
            ),

          const SizedBox(width: 8),

          // 3rd Place (Bronze)
          if (third != null)
            Expanded(
              child: _buildPodiumItem(
                entry: third,
                rank: 3,
                podiumHeight: 65,
                color: const Color(0xFFB45309), // Bronze
                crownColor: const Color(0xFF92400E),
              ),
            )
          else
            const Expanded(child: SizedBox(height: 65)),
        ],
      ),
    );
  }

  Widget _buildPodiumItem({
    required LeaderboardEntry entry,
    required int rank,
    required double podiumHeight,
    required Color color,
    required Color crownColor,
  }) {
    final isMe = entry.userId == widget.currentUser.id || entry.isCurrentUser;
    final avatarRadius = rank == 1 ? 28.0 : 22.0;
    final frameBorderRadius = BorderRadius.circular(avatarRadius * 0.45 + 3.5);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown or medal indicator
        if (rank == 1)
          const Icon(Icons.workspace_premium, color: Color(0xFFF59E0B), size: 28)
        else
          Icon(Icons.military_tech, color: crownColor, size: 22),

        const SizedBox(height: 4),

            // Avatar with rounded square frame matching pfp
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  padding: const EdgeInsets.all(3.0),
                  decoration: BoxDecoration(
                    borderRadius: frameBorderRadius,
                    border: Border.all(color: color, width: 2.5),
                    color: Colors.white,
                  ),
                  child: LqAvatar(
                    initials: initialsFor(entry.displayName),
                    photoUrl: entry.photoUrl,
                    radius: avatarRadius,
                  ),
                ),
                Positioned(
                  right: -3,
                  bottom: -3,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$rank',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),

        const SizedBox(height: 6),

        // Name
        Text(
          entry.displayName,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: rank == 1 ? 13 : 11,
            color: isMe ? LqColors.primaryDark : LqColors.ink,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),

        // EXP
        Text(
          '${_formatNumber(entry.exp)} XP',
          style: TextStyle(
            fontSize: rank == 1 ? 12 : 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 6),

        // Pillar
        Container(
          height: podiumHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '#$rank',
                style: TextStyle(
                  fontSize: rank == 1 ? 22 : 18,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Lv.${entry.level}',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: LqColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRankRow(LeaderboardEntry entry) {
    final isMe = entry.userId == widget.currentUser.id || entry.isCurrentUser;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? LqColors.primarySoft : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe ? LqColors.primary : LqColors.line,
          width: isMe ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Rank number
          SizedBox(
            width: 28,
            child: Text(
              '#${entry.rank}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isMe ? LqColors.primaryDark : LqColors.muted,
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Avatar
          LqAvatar(
            initials: initialsFor(entry.displayName),
            photoUrl: entry.photoUrl,
            radius: 18,
          ),
          const SizedBox(width: 12),

          // Name and Level
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isMe ? LqColors.primaryDark : LqColors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: LqColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  entry.username,
                  style: const TextStyle(fontSize: 11, color: LqColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Level Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: LqColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: LqColors.line),
            ),
            child: Text(
              'Lv.${entry.level}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: LqColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // EXP
          Text(
            '${_formatNumber(entry.exp)} XP',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: LqColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyUserBar(LeaderboardEntry userEntry) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: LqColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x331D4ED8),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              userEntry.rank > 0 ? '#${userEntry.rank}' : '-',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          LqAvatar(
            initials: initialsFor(widget.currentUser.displayName),
            photoUrl: widget.currentUser.photoUrl,
            radius: 17,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Your Standing',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.currentUser.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Lv.${widget.currentUser.level}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_formatNumber(widget.currentUser.exp)} XP',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isFriendsTab) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isFriendsTab ? Icons.group_off_outlined : Icons.leaderboard_outlined,
              size: 56,
              color: LqColors.muted,
            ),
            const SizedBox(height: 14),
            Text(
              isFriendsTab ? 'No Friends Ranked Yet' : 'No Leaderboard Data',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: LqColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isFriendsTab
                  ? 'Connect with other Penang explorers to compete on the friends leaderboard!'
                  : 'Start exploring and completing quests to earn your place on the global leaderboard!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: LqColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }
    if (number >= 1000) {
      final str = number.toString();
      final buffer = StringBuffer();
      final len = str.length;
      for (var i = 0; i < len; i++) {
        if (i > 0 && (len - i) % 3 == 0) buffer.write(',');
        buffer.write(str[i]);
      }
      return buffer.toString();
    }
    return number.toString();
  }
}
