import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/device_location_service.dart';
import '../services/mission_service.dart';

/// "My Missions — Explore & earn" screen.
///
/// Two tabs:
/// - "In progress": live list of the tourist's active missions (all
///   missions generated so far — see the note on [Mission] about why
///   there's no separate "accepted" step).
/// - "Available": a discovery affordance. Since missions start active
///   immediately on generation, this tab doesn't list pickable missions —
///   it shows an empty state with a "Refresh nearby area" button that
///   calls [MissionService.generateDailyMissions] and any new missions
///   then appear under "In progress".
class MissionListScreen extends StatefulWidget {
  const MissionListScreen({
    super.key,
    required this.uid,
    required this.currentLat,
    required this.currentLng,
  });

  final String uid;
  final double currentLat;
  final double currentLng;

  @override
  State<MissionListScreen> createState() => _MissionListScreenState();
}

class _MissionListScreenState extends State<MissionListScreen> {
  late double _lat;
  late double _lng;

  @override
  void initState() {
    super.initState();
    _lat = widget.currentLat;
    _lng = widget.currentLng;
    _refreshLocation();
  }

  Future<void> _refreshLocation() async {
    try {
      final pos = await DeviceLocationService.instance.getCurrentPosition();
      if (mounted) {
        setState(() {
          _lat = pos.latitude;
          _lng = pos.longitude;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFE7),
      appBar: canPop
          ? AppBar(
              backgroundColor: const Color(0xFFF3EFE7),
              elevation: 0,
              leading: const BackButton(color: Color(0xFF1B1F5C)),
              title: const Text(
                'Missions',
                style: TextStyle(
                  color: Color(0xFF1B1F5C),
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: MissionListView(
          uid: widget.uid,
          currentLat: _lat,
          currentLng: _lng,
        ),
      ),
    );
  }
}

/// The screen content without its own Scaffold/bottom nav — drop this
/// into an existing tab shell if one already exists.
class MissionListView extends StatefulWidget {
  const MissionListView({
    super.key,
    required this.uid,
    required this.currentLat,
    required this.currentLng,
  });

  final String uid;
  final double currentLat;
  final double currentLng;

  @override
  State<MissionListView> createState() => _MissionListViewState();
}

class _MissionListViewState extends State<MissionListView> {
  static const _navy = Color(0xFF1B1F5C);

  int _tabIndex = 0; // 0 = In progress, 1 = Available
  bool _refreshing = false;
  bool _completing = false; // guards against double-tap while a checkpoint is in flight

  Future<void> _refreshNearbyArea() async {
    setState(() => _refreshing = true);
    try {
      await MissionService.instance.generateDailyMissions(
        widget.uid,
        currentLat: widget.currentLat,
        currentLng: widget.currentLng,
      );
      if (mounted) setState(() => _tabIndex = 0);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _completeCheckpoint(Mission mission) async {
    if (_completing) return;

    final checkpoint = mission.nextIncompleteCheckpoint;
    if (checkpoint == null) return; // nothing left to complete on this mission

    String? photoPath;

    if (checkpoint.type == MissionType.photo) {
      try {
        final photo = await ImagePicker().pickImage(
          source: ImageSource.camera,
          maxWidth: 1600,
          imageQuality: 85,
        );
        if (photo == null) return; // user cancelled the camera, no message needed
        photoPath = photo.path;
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open the camera. Check permissions and try again.'),
            ),
          );
        }
        return;
      }
    }

    setState(() => _completing = true);
    try {
      final result = await MissionService.instance.completeNextCheckpoint(
        widget.uid,
        mission.id,
        currentLat: widget.currentLat,
        currentLng: widget.currentLng,
        photoPath: photoPath,
      );

      if (!mounted) return;

      if (!result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.failureReason ?? 'Could not complete.')),
        );
        return;
      }

      if (result.missionCompleted) {
        final message = result.voucherAwarded
            ? 'Mission complete! Voucher awarded.'
            : 'Mission complete! +${result.expAwarded} EXP'
            '${result.levelUpResult != null ? ' — Level up!' : ''}';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Checkpoint complete!')),
        );
      }
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SIDE QUESTS',
                    style: TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Dynamic Missions',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: _navy,
                    ),
                  ),
                ],
              ),
              const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.notifications_none, color: _navy),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _SegmentedTabs(
            index: _tabIndex,
            labels: const ['In progress', 'Available'],
            onChanged: (i) => setState(() => _tabIndex = i),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _tabIndex == 0
              ? _InProgressList(
            uid: widget.uid,
            currentLat: widget.currentLat,
            currentLng: widget.currentLng,
            onCompletePressed: _completing ? null : _completeCheckpoint,
            onDiscoverPressed: _refreshNearbyArea,
          )
              : _AvailableEmptyState(
            refreshing: _refreshing,
            onRefresh: _refreshNearbyArea,
          ),
        ),
      ],
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  static const _navy = Color(0xFF1B1F5C);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = i == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? _navy : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _InProgressList extends StatelessWidget {
  const _InProgressList({
    required this.uid,
    required this.currentLat,
    required this.currentLng,
    required this.onCompletePressed,
    this.onDiscoverPressed,
  });

  final String uid;
  final double currentLat;
  final double currentLng;
  final ValueChanged<Mission>? onCompletePressed;
  final VoidCallback? onDiscoverPressed;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Mission>>(
      stream: MissionService.instance.watchMissions(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final missions = (snapshot.data ?? const <Mission>[])
            .where((m) => m.status == MissionStatus.active)
            .toList();

        if (missions.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.explore_outlined,
                    size: 48,
                    color: Colors.black26,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No missions in progress yet.',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Discover nearby merchant and heritage side quests to earn EXP and rewards.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  if (onDiscoverPressed != null) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: onDiscoverPressed,
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text('Discover Missions Nearby'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1B1F5C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          itemCount: missions.length,
          itemBuilder: (context, i) {
            final mission = missions[i];
            final distance = MissionService.instance.distanceToNextCheckpoint(
              mission,
              currentLat,
              currentLng,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _MissionCard(
                mission: mission,
                distanceMeters: distance,
                onTap: onCompletePressed == null
                    ? null
                    : () => onCompletePressed!(mission),
              ),
            );
          },
        );
      },
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({
    required this.mission,
    required this.distanceMeters,
    required this.onTap,
  });

  final Mission mission;
  final double? distanceMeters;
  final VoidCallback? onTap;

  static const _navy = Color(0xFF1B1F5C);

  IconData get _icon {
    if (mission.rewardType == MissionRewardType.voucher) {
      return Icons.calendar_today;
    }
    return mission.totalCheckpointCount > 1
        ? Icons.show_chart
        : Icons.location_on;
  }

  Color get _iconBg {
    if (mission.rewardType == MissionRewardType.voucher) {
      return const Color(0xFFDDD8F7);
    }
    return mission.totalCheckpointCount > 1
        ? const Color(0xFFFBDFC9)
        : const Color(0xFFDDD8F7);
  }

  String get _subtitle {
    if (mission.rewardType == MissionRewardType.voucher &&
        mission.scheduledStartAt != null) {
      final dist = distanceMeters != null
          ? '${distanceMeters!.round()}m away'
          : '';
      return 'Starts ${_weekdayLabel(mission.scheduledStartAt!)}${dist.isNotEmpty ? ' \u00b7 $dist' : ''}';
    }
    final checkpointsText =
        '${mission.completedCheckpointCount} of ${mission.totalCheckpointCount} checkpoints';
    final distText = distanceMeters != null
        ? '${distanceMeters!.round()}m away'
        : '';
    return distText.isNotEmpty
        ? '$checkpointsText \u00b7 $distText'
        : checkpointsText;
  }

  String _weekdayLabel(DateTime date) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _iconBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_icon, color: _navy),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mission.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _navy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _subtitle,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBE0C4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    mission.rewardType == MissionRewardType.voucher
                        ? (mission.voucherLabel ?? 'Voucher')
                        : '+${mission.expReward} EXP',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: Color(0xFF8A5A22),
                    ),
                  ),
                ),
              ],
            ),
            if (mission.rewardType == MissionRewardType.exp) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: mission.progressFraction,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFEDE8DD),
                  valueColor: const AlwaysStoppedAnimation(_navy),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AvailableEmptyState extends StatelessWidget {
  const _AvailableEmptyState({
    required this.refreshing,
    required this.onRefresh,
  });

  final bool refreshing;
  final VoidCallback onRefresh;

  static const _navy = Color(0xFF1B1F5C);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFFDDD8F7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search, color: _navy, size: 32),
            ),
            const SizedBox(height: 20),
            const Text(
              'No missions nearby',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _navy,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "There's nothing to explore within range right now. "
              'Move to a new area or check back later for fresh missions.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: refreshing ? null : onRefresh,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: refreshing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Refresh nearby area',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
