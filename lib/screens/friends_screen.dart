import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/localquest_theme.dart';
import '../core/localquest_widgets.dart';
import '../models/localquest_models.dart';
import '../services/social_service.dart';
import '../services/direct_chat_service.dart';
import '../services/spotify_service.dart';
import 'direct_chat_screen.dart';
import 'leaderboard_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({
    super.key,
    required this.currentUser,
    this.initialTabIndex = 0,
  });

  final AppUser currentUser;
  final int initialTabIndex;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTabIndex;
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _tabController.addListener(() {
      if (_tabController.index != _selectedTab) {
        if (mounted) {
          setState(() => _selectedTab = _tabController.index);
        }
      }
    });
    SpotifyService.instance.setLiveSync(widget.currentUser.id, true);
    SpotifyService.instance.checkLocalBroadcast();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openNoteEditor(UserNote? currentNote) {
    bool isSyncingSpotify = false;
    bool isCheckingLink = true;
    bool isLinked = false;
    bool isStatusEnabled = (currentNote != null && currentNote.hasMusic);
    SpotifyTrack? selectedTrack = (currentNote != null && currentNote.hasMusic)
        ? SpotifyTrack(
            id: 'current',
            title: currentNote.songTitle ?? '',
            artist: currentNote.songArtist ?? '',
            albumArtUrl: currentNote.albumArtUrl,
            spotifyUrl: currentNote.spotifyUrl ?? '',
          )
        : null;

    bool hasAutoFetched = false;
    StreamSubscription<SpotifyTrack>? trackSub;
    Timer? pollTimer;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          if (isCheckingLink) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!ctx.mounted) return;
              final linked =
                  await SpotifyService.instance.isSpotifyLinked(widget.currentUser.id);
              if (ctx.mounted) {
                setModalState(() {
                  isLinked = linked;
                  isCheckingLink = false;
                  if (!linked) {
                    isStatusEnabled = false;
                    selectedTrack = null;
                  }
                });
              }
            });
          }

          if (isLinked && !hasAutoFetched && selectedTrack == null) {
            hasAutoFetched = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!ctx.mounted) return;
              final track = await SpotifyService.instance.fetchCurrentlyPlaying();
              if (track != null && selectedTrack == null && ctx.mounted) {
                setModalState(() {
                  selectedTrack = track;
                  if (isStatusEnabled) {
                    SocialService.instance.updateUserNote(
                      uid: widget.currentUser.id,
                      text: '',
                      songTitle: track.title,
                      songArtist: track.artist,
                      albumArtUrl: track.albumArtUrl,
                      spotifyUrl: track.spotifyUrl,
                    );
                    SpotifyService.instance.setLiveSync(widget.currentUser.id, true);
                  }
                });
              }
            });
          }

          if (isLinked) {
            trackSub ??= SpotifyService.instance.onTrackChanged.listen((newTrack) {
              if (context.mounted) {
                setModalState(() {
                  selectedTrack = newTrack;
                  if (isStatusEnabled) {
                    SocialService.instance.updateUserNote(
                      uid: widget.currentUser.id,
                      text: '',
                      songTitle: newTrack.title,
                      songArtist: newTrack.artist,
                      albumArtUrl: newTrack.albumArtUrl,
                      spotifyUrl: newTrack.spotifyUrl,
                    );
                  }
                });
              }
            });
            pollTimer ??= Timer.periodic(const Duration(seconds: 3), (_) {
              SpotifyService.instance.checkLocalBroadcast();
            });
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: LqColors.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header: Avatar, Name, "Music Note", Close button
                      Row(
                        children: [
                          LqAvatar(
                            initials: initialsFor(widget.currentUser.displayName),
                            photoUrl: widget.currentUser.photoUrl,
                            radius: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.currentUser.displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: LqColors.ink,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Text(
                                  'Music Note',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: LqColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20, color: LqColors.muted),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Toggle Row
                      if (!isLinked)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: LqColors.background,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: LqColors.line),
                          ),
                          child: Row(
                            children: [
                              const LqSpotifyLogo(size: 20),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Share Music Status',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: LqColors.muted,
                                      ),
                                    ),
                                    Text(
                                      'Connect Spotify to share music',
                                      style: TextStyle(fontSize: 11, color: LqColors.muted),
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF1DB954),
                                  side: const BorderSide(color: Color(0xFF1DB954)),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () async {
                                  final success = await SpotifyService.instance
                                      .authenticateWithSpotify(widget.currentUser.id);
                                  if (success && ctx.mounted) {
                                    final track = await SpotifyService.instance.fetchCurrentlyPlaying();
                                    setModalState(() {
                                      isLinked = true;
                                      isStatusEnabled = true;
                                      if (track != null) selectedTrack = track;
                                    });
                                    if (track != null) {
                                      await SocialService.instance.updateUserNote(
                                        uid: widget.currentUser.id,
                                        text: '',
                                        songTitle: track.title,
                                        songArtist: track.artist,
                                        albumArtUrl: track.albumArtUrl,
                                        spotifyUrl: track.spotifyUrl,
                                      );
                                      SpotifyService.instance.setLiveSync(widget.currentUser.id, true);
                                    }
                                  }
                                },
                                child: const Text(
                                  'Connect',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isStatusEnabled
                                ? const Color(0xFF1DB954).withValues(alpha: 0.08)
                                : LqColors.background,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isStatusEnabled
                                  ? const Color(0xFF1DB954).withValues(alpha: 0.3)
                                  : LqColors.line,
                            ),
                          ),
                          child: Row(
                            children: [
                              const LqSpotifyLogo(size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Share Music Status',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: isStatusEnabled ? LqColors.ink : LqColors.muted,
                                      ),
                                    ),
                                    Text(
                                      isStatusEnabled
                                          ? 'Visible to friends'
                                          : 'Status is currently turned off',
                                      style: const TextStyle(fontSize: 11, color: LqColors.muted),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: isStatusEnabled,
                                activeTrackColor: const Color(0xFF1DB954),
                                onChanged: (val) async {
                                  setModalState(() => isStatusEnabled = val);
                                  if (!val) {
                                    await SocialService.instance.clearUserNote(widget.currentUser.id);
                                    SpotifyService.instance.setLiveSync(widget.currentUser.id, false);
                                  } else {
                                    if (selectedTrack != null) {
                                      await SocialService.instance.updateUserNote(
                                        uid: widget.currentUser.id,
                                        text: '',
                                        songTitle: selectedTrack!.title,
                                        songArtist: selectedTrack!.artist,
                                        albumArtUrl: selectedTrack!.albumArtUrl,
                                        spotifyUrl: selectedTrack!.spotifyUrl,
                                      );
                                      SpotifyService.instance.setLiveSync(widget.currentUser.id, true);
                                    } else {
                                      final track = await SpotifyService.instance.fetchCurrentlyPlaying();
                                      if (track != null) {
                                        setModalState(() => selectedTrack = track);
                                        await SocialService.instance.updateUserNote(
                                          uid: widget.currentUser.id,
                                          text: '',
                                          songTitle: track.title,
                                          songArtist: track.artist,
                                          albumArtUrl: track.albumArtUrl,
                                          spotifyUrl: track.spotifyUrl,
                                        );
                                        SpotifyService.instance.setLiveSync(widget.currentUser.id, true);
                                      }
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Large Album Art (Centered)
                      Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: !isLinked
                              ? Container(
                                  color: const Color(0xFF191414),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const LqSpotifyLogo(size: 48),
                                        const SizedBox(height: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'NOT CONNECTED',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.8,
                                              color: LqColors.muted,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : (isStatusEnabled &&
                                      selectedTrack != null &&
                                      selectedTrack!.albumArtUrl != null &&
                                      selectedTrack!.albumArtUrl!.isNotEmpty)
                                  ? Image.network(
                                      selectedTrack!.albumArtUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: const Color(0xFF191414),
                                        child: const Icon(
                                          Icons.music_note,
                                          color: Color(0xFF1DB954),
                                          size: 64,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: const Color(0xFF191414),
                                      child: Icon(
                                        isStatusEnabled ? Icons.music_note : Icons.music_off_outlined,
                                        color: isStatusEnabled
                                            ? const Color(0xFF1DB954)
                                            : LqColors.muted,
                                        size: 64,
                                      ),
                                    ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Song Title and Artist / Status Info
                      if (!isLinked) ...[
                        const Text(
                          'Spotify Not Connected',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: LqColors.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Link your Spotify account to share your currently playing music with friends.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: LqColors.muted),
                        ),
                      ] else if (isStatusEnabled && selectedTrack != null) ...[
                        Text(
                          selectedTrack!.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: LqColors.ink,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selectedTrack!.artist,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: LqColors.muted,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ] else if (isStatusEnabled) ...[
                        const Text(
                          'No Spotify Track Detected',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: LqColors.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Play a song on Spotify or tap Sync below',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: LqColors.muted),
                        ),
                      ] else ...[
                        const Text(
                          'Music Status Disabled',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: LqColors.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Toggle the switch above to share your tune',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: LqColors.muted),
                        ),
                      ],
                      const SizedBox(height: 18),

                      // Action Buttons
                      if (!isLinked) ...[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF1DB954),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const LqSpotifyLogo(size: 20),
                            label: const Text(
                              'Connect Spotify Account',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            onPressed: () async {
                              final success = await SpotifyService.instance
                                  .authenticateWithSpotify(widget.currentUser.id);
                              if (success && ctx.mounted) {
                                final track = await SpotifyService.instance.fetchCurrentlyPlaying();
                                setModalState(() {
                                  isLinked = true;
                                  isStatusEnabled = true;
                                  if (track != null) selectedTrack = track;
                                });
                                if (track != null) {
                                  await SocialService.instance.updateUserNote(
                                    uid: widget.currentUser.id,
                                    text: '',
                                    songTitle: track.title,
                                    songArtist: track.artist,
                                    albumArtUrl: track.albumArtUrl,
                                    spotifyUrl: track.spotifyUrl,
                                  );
                                  SpotifyService.instance.setLiveSync(widget.currentUser.id, true);
                                }
                              }
                            },
                          ),
                        ),
                      ] else if (isStatusEnabled && selectedTrack != null) ...[
                        if (selectedTrack!.spotifyUrl.isNotEmpty) ...[
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF1DB954),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.play_circle_fill, size: 20),
                              label: const Text(
                                'Listen on Spotify',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              onPressed: () {
                                SpotifyService.instance.launchSpotify(selectedTrack!.spotifyUrl);
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF1DB954).withValues(alpha: 0.12),
                              foregroundColor: const Color(0xFF1DB954),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: isSyncingSpotify
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF1DB954),
                                    ),
                                  )
                                : const Icon(Icons.sync, size: 18),
                            label: Text(
                              isSyncingSpotify ? 'Syncing...' : 'Sync Live Track',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            onPressed: isSyncingSpotify
                                ? null
                                : () async {
                                    setModalState(() => isSyncingSpotify = true);
                                    try {
                                      final currentTrack =
                                          await SpotifyService.instance.fetchCurrentlyPlaying();
                                      if (currentTrack != null) {
                                        setModalState(() => selectedTrack = currentTrack);
                                        await SocialService.instance.updateUserNote(
                                          uid: widget.currentUser.id,
                                          text: '',
                                          songTitle: currentTrack.title,
                                          songArtist: currentTrack.artist,
                                          albumArtUrl: currentTrack.albumArtUrl,
                                          spotifyUrl: currentTrack.spotifyUrl,
                                        );
                                      }
                                    } finally {
                                      setModalState(() => isSyncingSpotify = false);
                                    }
                                  },
                          ),
                        ),
                      ] else if (isStatusEnabled) ...[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF1DB954).withValues(alpha: 0.15),
                              foregroundColor: const Color(0xFF1DB954),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: isSyncingSpotify
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF1DB954),
                                    ),
                                  )
                                : const LqSpotifyLogo(size: 20),
                            label: Text(
                              isSyncingSpotify
                                  ? 'Connecting to Spotify...'
                                  : 'Sync Currently Playing on Spotify',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            onPressed: isSyncingSpotify
                                ? null
                                : () async {
                                    setModalState(() => isSyncingSpotify = true);
                                    try {
                                      final currentTrack =
                                          await SpotifyService.instance.fetchCurrentlyPlaying();
                                      if (currentTrack != null) {
                                        setModalState(() {
                                          selectedTrack = currentTrack;
                                        });
                                        await SocialService.instance.updateUserNote(
                                          uid: widget.currentUser.id,
                                          text: '',
                                          songTitle: currentTrack.title,
                                          songArtist: currentTrack.artist,
                                          albumArtUrl: currentTrack.albumArtUrl,
                                          spotifyUrl: currentTrack.spotifyUrl,
                                        );
                                        SpotifyService.instance.setLiveSync(
                                          widget.currentUser.id,
                                          true,
                                        );
                                      } else {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'No song currently playing on Spotify. Start a song in Spotify and tap Sync again!',
                                              ),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      }
                                    } finally {
                                      setModalState(() => isSyncingSpotify = false);
                                    }
                                  },
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: LqColors.ink,
                              side: const BorderSide(color: LqColors.line),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.open_in_new, size: 16, color: Color(0xFF1DB954)),
                            label: const Text('Open Spotify App'),
                            onPressed: () => SpotifyService.instance.openSpotifyApp(),
                          ),
                        ),
                      ],

                      if (isLinked) ...[
                        const SizedBox(height: 10),
                        // Unlink Spotify Account
                        Center(
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: LqColors.muted,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            ),
                            icon: const Icon(Icons.link_off, size: 16),
                            label: const Text(
                              'Unlink Spotify Account',
                              style: TextStyle(fontSize: 12, decoration: TextDecoration.underline),
                            ),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (dCtx) => AlertDialog(
                                  title: const Text('Unlink Spotify?'),
                                  content: const Text(
                                    'This will remove your linked Spotify credentials and clear your current music status from LocalQuest.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dCtx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: LqColors.danger,
                                      ),
                                      onPressed: () => Navigator.pop(dCtx, true),
                                      child: const Text('Unlink'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                await SpotifyService.instance.disconnectUser(widget.currentUser.id);
                                trackSub?.cancel();
                                trackSub = null;
                                pollTimer?.cancel();
                                pollTimer = null;
                                if (ctx.mounted) {
                                  setModalState(() {
                                    isLinked = false;
                                    isStatusEnabled = false;
                                    selectedTrack = null;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Spotify account unlinked')),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      trackSub?.cancel();
      pollTimer?.cancel();
    });
  }

  void _openSearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: LqColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _UserSearchModal(currentUser: widget.currentUser),
    );
  }

  Widget _buildCapsuleTabBar() {
    return StreamBuilder<List<FriendRequest>>(
      stream: SocialService.instance.streamFriendRequests(widget.currentUser.id),
      builder: (context, snapshot) {
        final requestCount = (snapshot.data ?? []).length;
        final tabs = [
          (0, 'Friends'),
          (1, 'Chats'),
          (2, 'Requests'),
        ];

        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    return Semantics(
                      button: true,
                      selected: isSelected,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () {
                          setState(() => _selectedTab = tab.$1);
                          _tabController.animateTo(tab.$1);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
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
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tab.$2,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : LqColors.muted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (tab.$1 == 2 && requestCount > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.white : LqColors.danger,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$requestCount',
                                    style: TextStyle(
                                      color: isSelected ? LqColors.primary : Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LqColors.background,
      floatingActionButton: FloatingActionButton.extended(
        shape: const StadiumBorder(),
        backgroundColor: LqColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text(
          'Add Friend',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        onPressed: _openSearchSheet,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header matching VisitedPlacesScreen (Location History) style
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const LqBackButton(label: 'Profile'),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Friends & Social',
                        style: TextStyle(
                          fontSize: 32,
                          height: 1.12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.2,
                          color: LqColors.ink,
                        ),
                      ),
                      Tooltip(
                        message: 'Leaderboard',
                        child: InkWell(
                          key: const Key('friends_header_leaderboard_btn'),
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LeaderboardScreen(
                                currentUser: widget.currentUser,
                                initialTab: 1, // Opens Friends tab by default
                              ),
                            ),
                          ),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: LqColors.line),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x1A000000),
                                  blurRadius: 3,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.emoji_events_outlined,
                              size: 22,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 24-hr Insta Notes Bar
            _buildNotesSection(),

            // Capsule-style Tab Bar (Merchant Campaign Page design)
            _buildCapsuleTabBar(),

            const SizedBox(height: 4),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFriendsTab(),
                  _buildChatsTab(),
                  _buildRequestsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return StreamBuilder<UserNote?>(
      stream: SocialService.instance.streamUserNote(widget.currentUser.id),
      builder: (context, myNoteSnap) {
        final myNote = myNoteSnap.data;
        return StreamBuilder<List<Friend>>(
          stream: SocialService.instance.streamFriends(widget.currentUser.id),
          builder: (context, friendsSnap) {
            final friends = friendsSnap.data ?? [];
            return Container(
              color: LqColors.surface,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SizedBox(
                height: 106,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // Current User Note Bubble
                    GestureDetector(
                      onTap: () => _openNoteEditor(myNote),
                      child: SizedBox(
                        width: 80,
                        child: Column(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                LqAvatar(
                                  initials: initialsFor(widget.currentUser.displayName),
                                  photoUrl: widget.currentUser.photoUrl,
                                  radius: 28,
                                ),
                                if (myNote != null &&
                                    (myNote.text.isNotEmpty || myNote.hasMusic))
                                  Positioned(
                                    top: -10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      constraints: const BoxConstraints(maxWidth: 80),
                                      decoration: BoxDecoration(
                                        color: myNote.hasMusic
                                            ? const Color(0xFF191414)
                                            : LqColors.ink,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.15),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (myNote.hasMusic) ...[
                                            const Icon(
                                              Icons.music_note,
                                              color: Color(0xFF1DB954),
                                              size: 10,
                                            ),
                                            const SizedBox(width: 2),
                                          ],
                                          Flexible(
                                            child: Text(
                                              myNote.hasMusic
                                                  ? (myNote.songTitle ?? '')
                                                  : myNote.text,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: LqColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.add,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Your Note',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: LqColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Friends Notes (if any)
                    ...friends.map((friend) {
                      return StreamBuilder<UserNote?>(
                        stream: SocialService.instance.streamUserNote(friend.friendUserId),
                        builder: (context, noteSnap) {
                          final note = noteSnap.data;
                          return GestureDetector(
                            onTap: () {
                              if (note != null && note.hasMusic) {
                                _showFriendMusicDialog(friend, note);
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DirectChatScreen(
                                      currentUser: widget.currentUser,
                                      targetUserId: friend.friendUserId,
                                      targetDisplayName: friend.displayName,
                                      targetUsername: friend.username,
                                      targetPhotoUrl: friend.photoUrl,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              width: 80,
                              margin: const EdgeInsets.only(left: 12),
                              child: Column(
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    alignment: Alignment.center,
                                    children: [
                                      LqAvatar(
                                        initials: initialsFor(friend.displayName),
                                        photoUrl: friend.photoUrl,
                                        radius: 28,
                                      ),
                                      if (note != null &&
                                          (note.text.isNotEmpty || note.hasMusic))
                                        Positioned(
                                          top: -10,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            constraints:
                                                const BoxConstraints(maxWidth: 80),
                                            decoration: BoxDecoration(
                                              color: note.hasMusic
                                                  ? const Color(0xFF191414)
                                                  : LqColors.primaryDark,
                                              borderRadius: BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.15),
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (note.hasMusic) ...[
                                                  const Icon(
                                                    Icons.music_note,
                                                    color: Color(0xFF1DB954),
                                                    size: 10,
                                                  ),
                                                  const SizedBox(width: 2),
                                                ],
                                                Flexible(
                                                  child: Text(
                                                    note.hasMusic
                                                        ? (note.songTitle ?? '')
                                                        : note.text,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    friend.displayName.split(' ').first,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: LqColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFriendsTab() {
    return StreamBuilder<List<Friend>>(
      stream: SocialService.instance.streamFriends(widget.currentUser.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: LqColors.primary));
        }

        final friends = snapshot.data ?? [];
        if (friends.isEmpty) {
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
                      Icons.people_outline_rounded,
                      size: 40,
                      color: LqColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Friends Added Yet',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: LqColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Connect with fellow tourists exploring Penang, share notes, and message 1-on-1!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: LqColors.muted),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: LqColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: const Text('Find Tourists'),
                    onPressed: _openSearchSheet,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: friends.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final friend = friends[index];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: LqColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: LqColors.line),
              ),
              child: Row(
                children: [
                  LqAvatar(
                    initials: initialsFor(friend.displayName),
                    photoUrl: friend.photoUrl,
                    radius: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                friend.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: LqColors.ink,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: LqColors.primarySoft,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Lv.${friend.level}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: LqColors.primaryDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          friend.username,
                          style: const TextStyle(fontSize: 12, color: LqColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      backgroundColor: LqColors.primarySoft,
                      foregroundColor: LqColors.primaryDark,
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    tooltip: 'Direct Chat',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DirectChatScreen(
                            currentUser: widget.currentUser,
                            targetUserId: friend.friendUserId,
                            targetDisplayName: friend.displayName,
                            targetUsername: friend.username,
                            targetPhotoUrl: friend.photoUrl,
                          ),
                        ),
                      );
                    },
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20, color: LqColors.muted),
                    onSelected: (val) async {
                      if (val == 'remove') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Remove Friend?'),
                            content: Text(
                              'Are you sure you want to remove ${friend.displayName} from your friends?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
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
                            friendUserId: friend.friendUserId,
                          );
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(Icons.person_remove_outlined, size: 18, color: LqColors.danger),
                            SizedBox(width: 8),
                            Text('Remove Friend', style: TextStyle(color: LqColors.danger)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChatsTab() {
    return StreamBuilder<List<ChatConversation>>(
      stream: DirectChatService.instance.streamConversations(widget.currentUser.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: LqColors.primary));
        }

        final convos = snapshot.data ?? [];
        if (convos.isEmpty) {
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
                      size: 40,
                      color: LqColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Messages Yet',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: LqColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Start a conversation with friends to plan travel adventures across Penang!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: LqColors.muted),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: convos.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final convo = convos[index];
            final timeStr = DateFormat('MMM d, h:mm a').format(convo.lastMessageTime);

            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DirectChatScreen(
                      currentUser: widget.currentUser,
                      targetUserId: convo.otherUserId,
                      targetDisplayName: convo.otherDisplayName,
                      targetUsername: convo.otherUsername,
                      targetPhotoUrl: convo.otherPhotoUrl,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: LqColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: LqColors.line),
                ),
                child: Row(
                  children: [
                    LqAvatar(
                      initials: initialsFor(convo.otherDisplayName),
                      photoUrl: convo.otherPhotoUrl,
                      radius: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                convo.otherDisplayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: LqColors.ink,
                                ),
                              ),
                              Text(
                                timeStr,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: LqColors.muted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  convo.lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: convo.unreadCount > 0 ? LqColors.ink : LqColors.muted,
                                    fontWeight: convo.unreadCount > 0
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (convo.unreadCount > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: LqColors.primary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${convo.unreadCount}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRequestsTab() {
    return StreamBuilder<List<FriendRequest>>(
      stream: SocialService.instance.streamFriendRequests(widget.currentUser.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: LqColors.primary));
        }

        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
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
                      Icons.mark_email_read_outlined,
                      size: 40,
                      color: LqColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Pending Requests',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: LqColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'When another explorer sends you a friend request, it will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: LqColors.muted),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: requests.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final req = requests[index];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: LqColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: LqColors.line),
              ),
              child: Row(
                children: [
                  LqAvatar(
                    initials: initialsFor(req.fromDisplayName),
                    photoUrl: req.fromPhotoUrl,
                    radius: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          req.fromDisplayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: LqColors.ink,
                          ),
                        ),
                        Text(
                          req.fromUsername,
                          style: const TextStyle(fontSize: 12, color: LqColors.muted),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: LqColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(8),
                        ),
                        icon: const Icon(Icons.check, size: 18),
                        tooltip: 'Accept',
                        onPressed: () async {
                          await SocialService.instance.acceptFriendRequest(
                            currentUser: widget.currentUser,
                            request: req,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Accepted ${req.fromDisplayName} as friend!'),
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          backgroundColor: LqColors.field,
                          foregroundColor: LqColors.danger,
                          padding: const EdgeInsets.all(8),
                        ),
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Decline',
                        onPressed: () async {
                          await SocialService.instance.rejectFriendRequest(
                            currentUserId: widget.currentUser.id,
                            requestId: req.id,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showFriendMusicDialog(Friend friend, UserNote note) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: LqColors.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    LqAvatar(
                      initials: initialsFor(friend.displayName),
                      photoUrl: friend.photoUrl,
                      radius: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            friend.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: LqColors.ink,
                            ),
                          ),
                          const Text(
                            'Shared music on Music Note',
                            style: TextStyle(
                              fontSize: 11,
                              color: LqColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: LqColors.muted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: (note.albumArtUrl != null &&
                            note.albumArtUrl!.isNotEmpty)
                        ? Image.network(
                            note.albumArtUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: const Color(0xFF191414),
                              child: const Icon(
                                Icons.music_note,
                                color: Color(0xFF1DB954),
                                size: 64,
                              ),
                            ),
                          )
                        : Container(
                            color: const Color(0xFF191414),
                            child: const Icon(
                              Icons.music_note,
                              color: Color(0xFF1DB954),
                              size: 64,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  note.songTitle ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: LqColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  note.songArtist ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: LqColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (note.text.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: LqColors.field,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '“${note.text}”',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: LqColors.ink,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.play_circle_fill, size: 22),
                    label: const Text(
                      'Listen on Spotify',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    onPressed: () {
                      SpotifyService.instance.launchSpotify(note.spotifyUrl);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    icon: const Icon(
                      Icons.chat_bubble_outline,
                      size: 18,
                      color: LqColors.primary,
                    ),
                    label: Text(
                      'Chat with ${friend.displayName.split(' ').first}',
                      style: const TextStyle(
                        color: LqColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DirectChatScreen(
                            currentUser: widget.currentUser,
                            targetUserId: friend.friendUserId,
                            targetDisplayName: friend.displayName,
                            targetUsername: friend.username,
                            targetPhotoUrl: friend.photoUrl,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _UserSearchModal extends StatefulWidget {
  const _UserSearchModal({required this.currentUser});
  final AppUser currentUser;

  @override
  State<_UserSearchModal> createState() => _UserSearchModalState();
}

class _UserSearchModalState extends State<_UserSearchModal> {
  final _searchController = TextEditingController();
  List<AppUser> _results = [];
  bool _isSearching = false;
  final Set<String> _sentUserIds = {};
  final Set<String> _friendUserIds = {};

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final list = await SocialService.instance.searchUsers(
        query: query,
        currentUserId: widget.currentUser.id,
      );
      if (mounted) {
        setState(() => _results = list);
        for (final user in list) {
          if (!_sentUserIds.contains(user.id)) {
            final hasSent = await SocialService.instance.hasPendingSentRequest(
              currentUserId: widget.currentUser.id,
              targetUserId: user.id,
            );
            if (hasSent && mounted) {
              setState(() => _sentUserIds.add(user.id));
            }
          }
          if (!_friendUserIds.contains(user.id)) {
            final isFr = await SocialService.instance.isFriend(
              currentUserId: widget.currentUser.id,
              targetUserId: user.id,
            );
            if (isFr && mounted) {
              setState(() => _friendUserIds.add(user.id));
            }
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: LqColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Find Tourists in Penang',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: LqColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: _performSearch,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search by name or @username...',
              prefixIcon: const Icon(Icons.search, color: LqColors.primary),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: LqColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      _searchController.text.isEmpty
                          ? 'Search for fellow explorers to connect.'
                          : 'No tourists found matching "${_searchController.text}".',
                      style: const TextStyle(fontSize: 13, color: LqColors.muted),
                    ),
                  )
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final user = _results[index];
                      final isSent = _sentUserIds.contains(user.id);
                      final isFriend = _friendUserIds.contains(user.id);
                      final isActionDisabled = isSent || isFriend;

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: LqColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: LqColors.line),
                        ),
                        child: Row(
                          children: [
                            LqAvatar(
                              initials: initialsFor(user.displayName),
                              photoUrl: user.photoUrl,
                              radius: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: LqColors.ink,
                                    ),
                                  ),
                                  Text(
                                    user.username,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: LqColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                backgroundColor: isActionDisabled
                                    ? LqColors.field
                                    : LqColors.primarySoft,
                                foregroundColor: isActionDisabled
                                    ? LqColors.muted
                                    : LqColors.primaryDark,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              onPressed: isActionDisabled
                                  ? null
                                  : () async {
                                      try {
                                        await SocialService.instance.sendFriendRequest(
                                          currentUser: widget.currentUser,
                                          targetUserId: user.id,
                                          targetDisplayName: user.displayName,
                                          targetUsername: user.username,
                                          targetPhotoUrl: user.photoUrl,
                                          targetLevel: user.level,
                                        );
                                        if (mounted) {
                                          setState(() => _sentUserIds.add(user.id));
                                        }
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Friend request sent to ${user.displayName}!',
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('$e')),
                                          );
                                        }
                                      }
                                    },
                              child: Text(
                                isFriend
                                    ? 'Friends'
                                    : isSent
                                        ? 'Sent'
                                        : 'Add Friend',
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SpotifySongPickerModal extends StatefulWidget {
  const _SpotifySongPickerModal({
    required this.onTrackSelected,
  });

  final ValueChanged<SpotifyTrack> onTrackSelected;

  @override
  State<_SpotifySongPickerModal> createState() => _SpotifySongPickerModalState();
}

class _SpotifySongPickerModalState extends State<_SpotifySongPickerModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<SpotifyTrack> _tracks = [];
  bool _isLoading = false;
  String _selectedFilter = 'Penang Vibes';

  final List<String> _filters = [
    'Penang Vibes',
    'Chill',
    'Acoustic',
    'Pop',
    'Heritage',
  ];

  @override
  void initState() {
    super.initState();
    _tracks = SpotifyService.instance.getCuratedPenangVibes();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    setState(() => _isLoading = true);
    final results = await SpotifyService.instance.searchTracks(query);
    if (mounted) {
      setState(() {
        _tracks = results;
        _isLoading = false;
      });
    }
  }

  bool _isSyncing = false;

  Future<void> _syncCurrentlyPlaying() async {
    setState(() => _isSyncing = true);
    try {
      final track = await SpotifyService.instance.fetchCurrentlyPlaying();
      if (track != null) {
        widget.onTrackSelected(track);
        if (mounted) Navigator.pop(context);
      } else {
        if (mounted) {
          final msg = SpotifyService.instance.lastPlaybackStatus ??
              'No song currently playing on Spotify. Start playing a track and tap again!';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              const Row(
                children: [
                  Icon(Icons.music_note, color: Color(0xFF1DB954), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Pick a Song',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: LqColors.ink,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1DB954).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.stream, color: Color(0xFF1DB954), size: 12),
                    SizedBox(width: 4),
                    Text(
                      'Spotify',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1DB954),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor:
                    const Color(0xFF1DB954).withValues(alpha: 0.15),
                foregroundColor: const Color(0xFF1DB954),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isSyncing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF1DB954),
                      ),
                    )
                  : const LqSpotifyLogo(size: 18),
              label: Text(
                _isSyncing
                    ? 'Connecting to Spotify...'
                    : 'Sync Currently Playing on Spotify',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              onPressed: _isSyncing ? null : _syncCurrentlyPlaying,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchCtrl,
            onSubmitted: _search,
            decoration: InputDecoration(
              hintText: 'Search title or artist...',
              prefixIcon: const Icon(Icons.search, color: LqColors.primary),
              suffixIcon: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.arrow_forward, color: LqColors.primary),
                      onPressed: () => _search(_searchCtrl.text),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    selectedColor: const Color(0xFF1DB954).withValues(alpha: 0.18),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? const Color(0xFF1DB954) : LqColors.muted,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedFilter = filter);
                        _search(filter == 'Penang Vibes' ? '' : filter);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _tracks.isEmpty
                ? const Center(
                    child: Text(
                      'No tracks found. Try another search.',
                      style: TextStyle(fontSize: 13, color: LqColors.muted),
                    ),
                  )
                : ListView.separated(
                    itemCount: _tracks.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final track = _tracks[index];
                      return InkWell(
                        onTap: () {
                          widget.onTrackSelected(track);
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: LqColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: LqColors.line),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: (track.albumArtUrl != null &&
                                        track.albumArtUrl!.isNotEmpty)
                                    ? Image.network(
                                        track.albumArtUrl!,
                                        width: 46,
                                        height: 46,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Container(
                                          width: 46,
                                          height: 46,
                                          color: LqColors.field,
                                          child: const Icon(
                                            Icons.music_note,
                                            color: LqColors.muted,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        width: 46,
                                        height: 46,
                                        color: LqColors.field,
                                        child: const Icon(
                                          Icons.music_note,
                                          color: LqColors.muted,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      track.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: LqColors.ink,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      track.artist,
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
                              const Icon(
                                Icons.check_circle_outline,
                                color: Color(0xFF1DB954),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
