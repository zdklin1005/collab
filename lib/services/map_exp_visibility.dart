import '../models/reward_marker.dart';
import 'daily_reward_generator.dart';
import 'map_exp_history_repository.dart';

List<RewardMarker> filterMapExpHistory({
  required Iterable<RewardMarker> rewards,
  required Set<String> claimedRewardIds,
  required Map<String, MapCheckpointCooldown> cooldowns,
  required DateTime now,
}) {
  return rewards
      .where((reward) {
        if (!reward.canDisplayAt(now)) return false;

        // Voucher claim history will be connected separately.
        if (reward.type != RewardType.exp) return true;

        if (claimedRewardIds.contains(reward.id)) return false;

        final cooldown = cooldowns[reward.checkpointId];
        if (cooldown == null) return true;

        return !cooldown.blocksBatch(
          candidateBatchStart: DailyRewardGenerator.dayStartUtc(
            reward.availableFrom,
          ),
          now: now,
        );
      })
      .toList(growable: false);
}
