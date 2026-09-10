import 'package:flutter/material.dart';

import '../../models/reward_marker.dart';
import '../../services/demo_map_claim_store.dart';

class RewardSuccessScreen extends StatelessWidget {
  const RewardSuccessScreen({
    super.key,
    required this.claim,
    required this.onContinue,

    // Demo values for the user's EXP level and progress.
    this.currentLevel = 1,
    this.demoExpBefore = 0,
    this.demoTargetExp = 3000,
  });

  final DemoMapClaim claim;
  final VoidCallback onContinue;

  final int currentLevel;

  // Account EXP baseline plus earlier demo EXP claims in this session.
  final int demoExpBefore;

  // Illustrative UI target only—not a real level-up threshold.
  final int demoTargetExp;

  @override
  Widget build(BuildContext context) {
    final reward = claim.reward;
    final isExp = reward.type == RewardType.exp;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3267D8), Color(0xFF567FC8), Color(0xFFF4F5F7)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 48).clamp(
                      0.0,
                      double.infinity,
                    ),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 24),
                          Container(
                            width: 164,
                            height: 164,
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white38,
                                width: 4,
                              ),
                            ),
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x403267D8),
                                    blurRadius: 30,
                                    offset: Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Icon(
                                isExp ? Icons.star_rounded : Icons.bolt_rounded,
                                size: 82,
                                color: isExp
                                    ? const Color(0xFFFFC914)
                                    : const Color(0xFF3267D8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          const Text(
                            'DEMO SUCCESS!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 32),

                          if (isExp)
                            DemoExpProgressCard(
                              currentLevel: currentLevel,
                              expBefore: demoExpBefore,
                              expGained: reward.expAmount,
                              targetExp: demoTargetExp,
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    isExp
                                        ? '${reward.expAmount} EXP'
                                        : reward.title,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF17233E),
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    isExp
                                        ? 'Demo EXP collection recorded.'
                                        : 'Demo voucher collection recorded.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF3267D8),
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    isExp
                                        ? 'Your real EXP total and level have not changed.'
                                        : 'No real voucher has been added to Rewards.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 15,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 24),
                          const Text(
                            'This demo collection is saved on this device for your account. '
                            'Its marker stays hidden after restarting the app. '
                            'No real EXP or voucher was issued.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF17233E),
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: onContinue,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3267D8),
                                foregroundColor: Colors.white,
                                elevation: 6,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 20,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: const Text(
                                'CONTINUE EXPLORING',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class DemoExpProgressCard extends StatelessWidget {
  const DemoExpProgressCard({
    super.key,
    required this.currentLevel,
    required this.expBefore,
    required this.expGained,
    required this.targetExp,
  });

  final int currentLevel;
  final int expBefore;
  final int expGained;
  final int targetExp;

  @override
  Widget build(BuildContext context) {
    // Defensive display handling; these values do not update account data.
    final before = expBefore < 0 ? 0 : expBefore;
    final gained = expGained < 0 ? 0 : expGained;
    final target = targetExp > 0 ? targetExp : 3000;
    final after = before + gained;
    final remaining = after >= target ? 0 : target - after;

    final startProgress = (before / target).clamp(0.0, 1.0);
    final endProgress = (after / target).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x263267D8),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SIMULATED PROGRESS',
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Level $currentLevel',
                style: const TextStyle(
                  color: Color(0xFF17233E),
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '+$gained EXP',
                  style: const TextStyle(
                    color: Color(0xFF3267D8),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: startProgress, end: endProgress),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return LinearProgressIndicator(
                value: value,
                minHeight: 14,
                borderRadius: BorderRadius.circular(20),
                backgroundColor: const Color(0xFFF0F2F5),
                color: const Color(0xFF3267D8),
                semanticsLabel: 'Simulated EXP progress',
              );
            },
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              Text(
                '$after EXP · demo total',
                style: const TextStyle(
                  color: Color(0xFF3267D8),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                remaining == 0
                    ? 'Demo target reached'
                    : '$remaining EXP to demo target',
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Illustrative target: $target EXP. '
            'This is not a confirmed level-up threshold.',
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your real EXP total and level have not changed.',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
