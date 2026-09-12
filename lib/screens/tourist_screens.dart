import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/password_field.dart';
import '../core/password_policy.dart';
import 'package:intl/intl.dart';

import 'rewards_tab.dart';
import '../services/check_in_service.dart';
import 'write_review_screen.dart';

import '../core/localquest_theme.dart';
import '../core/localquest_widgets.dart';
import '../core/input_validators.dart';
import '../core/profile_photo_editor.dart';
import '../models/localquest_models.dart';
import '../services/localquest_services.dart';
import '../services/biometric_auth_service.dart';

import 'interactive_map/interactive_map_screen.dart';

class TouristHome extends StatefulWidget {
  const TouristHome({
    super.key,
    required this.user,
    this.initialIndex = 0,
  });
  final AppUser user;
  final int initialIndex;

  @override
  State<TouristHome> createState() => _TouristHomeState();
}

class _TouristHomeState extends State<TouristHome> {
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    final profile = TouristProfileScreen(user: widget.user);
    final pages = [
      InteractiveMapScreen(user: widget.user),
      RewardsTab(user: widget.user),   // was: const _ModulePlaceholder(...)
      profile,
    ];
    return LqPage(
      bottomNavigationBar: LqFloatingNavBar(
        selectedIndex: _index,
        onSelected: (value) => setState(() => _index = value),
        items: const [
          (Icons.explore_outlined, 'Discover'),
          (Icons.confirmation_num_outlined, 'Rewards'),
          (Icons.person_outline, 'Profile'),
        ],
        profileInitials: initialsFor(widget.user.displayName),
        profilePhotoUrl: widget.user.photoUrl,
      ),
      child: pages[_index],
    );
  }
}

class _DailyCheckInCard extends StatefulWidget {
  const _DailyCheckInCard({required this.uid});
  final String uid;

  @override
  State<_DailyCheckInCard> createState() => _DailyCheckInCardState();
}

class _DailyCheckInCardState extends State<_DailyCheckInCard> {
  bool _checkingIn = false;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _checkIn() async {
    if (_checkingIn) return;
    setState(() => _checkingIn = true);
    try {
      final result = await CheckInService.instance.checkIn(widget.uid);
      if (!mounted) return;
      final message = result.alreadyCheckedInToday
          ? "You've already checked in today — come back tomorrow!"
          : 'Checked in! +${result.expAwarded} EXP'
          '${result.levelUpResult != null ? ' — Level up!' : ''}'
          ' · ${result.streakCount}-day streak';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not check in. Check your connection and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reads streakCount/lastCheckInDate directly off the raw user doc —
    // these fields deliberately aren't on AppUser (see CheckInService's
    // class doc), so this bypasses UserRepository.watch() and streams
    // the document itself instead.
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final streakCount = (data['streakCount'] as num?)?.toInt() ?? 0;
        final lastCheckIn = (data['lastCheckInDate'] as Timestamp?)?.toDate();
        final alreadyCheckedInToday =
            lastCheckIn != null && _isSameDay(lastCheckIn, DateTime.now());

        return LqCard(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: LqColors.peachSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.local_fire_department,
                  color: Colors.deepOrange,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      streakCount > 0
                          ? '$streakCount-day streak'
                          : 'Start your streak',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      alreadyCheckedInToday
                          ? 'Come back tomorrow to keep it going'
                          : 'Check in today to earn EXP',
                      style: const TextStyle(
                        color: LqColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (alreadyCheckedInToday)
                const Chip(
                  avatar: Icon(
                    Icons.check_circle,
                    size: 16,
                    color: LqColors.success,
                  ),
                  label: Text('Done'),
                  visualDensity: VisualDensity.compact,
                )
              else
                FilledButton(
                  onPressed: _checkingIn ? null : _checkIn,
                  child: _checkingIn
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text('Check in'),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ModulePlaceholder extends StatelessWidget {
  const _ModulePlaceholder({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: LqTitleBlock(
        eyebrow: 'LocalQuest',
        title: title,
        subtitle: subtitle,
      ),
    ),
  );
}

class TouristProfileScreen extends StatelessWidget {
  const TouristProfileScreen({super.key, required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 42, 16, 116),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const LqTitleBlock(eyebrow: 'My passport', title: 'Profile'),
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Notifications',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NotificationsScreen(user: user),
                    ),
                  ),
                  icon: const Icon(Icons.notifications_none),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(user: user),
                    ),
                  ),
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 28),
        InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AccountDetailsScreen(user: user)),
          ),
          child: LqCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Container(
                  color: LqColors.primarySoft,
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      LqAvatar(
                        radius: 36,
                        initials: initialsFor(user.displayName),
                        photoUrl: user.photoUrl,
                        shape: LqAvatarShape.roundedSquare,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                              ),
                            ),
                            Text(
                              user.username,
                              style: const TextStyle(color: LqColors.muted),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: LqTierBadge(level: user.level),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${user.exp}/3,000XP',
                                  style: monoLabel.copyWith(
                                    color: const Color(0xFF466294),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 9,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: ((user.exp % 3000) / 3000).clamp(0, 1),
                              minHeight: 7,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right,
                        color: LqColors.primary,
                        size: 24,
                      ),
                    ],
                  ),
                ),
                const LqDashedDivider(),
                Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        label: 'Vouchers',
                        value: '${user.voucherCount}',
                        badgeText: user.voucherCount > 0
                            ? '${user.voucherCount > 3 ? 3 : user.voucherCount} expiring soon'
                            : '0 expiring soon',
                        icon: Icons.confirmation_num_outlined,
                      ),
                    ),
                    const SizedBox(
                      height: 104,
                      child: LqDashedDivider(vertical: true),
                    ),
                    Expanded(
                      child: _Stat(
                        label: 'Reviews',
                        value: '${user.reviewCount}',
                        badgeText: user.reviewCount > 0
                            ? 'Top 8% storyteller'
                            : 'Top storyteller',
                        icon: Icons.star_border,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _DailyCheckInCard(uid: user.id),
        const SizedBox(height: 28),
        Text('YOUR JOURNEY', style: monoLabel),
        LqCard(
          child: Column(
            children: [
              _JourneyItem(
                icon: Icons.confirmation_num_outlined,
                title: 'My vouchers',
                subtitle: '${user.voucherCount} ready to use',
                onTap: () => _showJourneySheet(
                  context,
                  title: 'My vouchers',
                  eyebrow: 'Rewards',
                  icon: Icons.confirmation_num_outlined,
                  message:
                      'You currently have ${user.voucherCount} voucher${user.voucherCount == 1 ? '' : 's'} ready in your passport. Present active voucher barcodes in-store to participating local merchants.',
                ),
              ),
              _JourneyItem(
                icon: Icons.star_outline,
                title: 'Reviews & ratings',
                subtitle: '${user.reviewCount} posted',
                onTap: () => _showJourneySheet(
                  context,
                  title: 'Reviews & ratings',
                  eyebrow: 'Storyteller',
                  icon: Icons.star_outline,
                  message:
                      'You have contributed ${user.reviewCount} verified review${user.reviewCount == 1 ? '' : 's'}. Reviews can only be posted after visiting physical merchant checkpoints to safeguard authentic feedback.',
                ),
              ),
              _JourneyItem(
                icon: Icons.auto_awesome_outlined,
                title: 'Missions',
                subtitle: '2 in progress',
                onTap: () => _showJourneySheet(
                  context,
                  title: 'Dynamic Missions',
                  eyebrow: 'Side quests',
                  icon: Icons.auto_awesome_outlined,
                  message:
                      '2 location missions currently in progress! Complete heritage photo check-ins and merchant explorations to earn bonus experience points.',
                ),
              ),
              _JourneyItem(
                icon: Icons.history,
                title: 'Visited places',
                subtitle: 'Your automatic location history',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VisitedPlacesScreen(userId: user.id),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        LqLogoutButton(
          onPressed: () =>
              confirmLqSignOut(context, AuthService.instance.signOut),
        ),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    this.badgeText,
  });
  final String label;
  final String value;
  final IconData icon;
  final String? badgeText;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label.toUpperCase(), style: monoLabel),
            Icon(icon, color: LqColors.primary),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
        ),
        if (badgeText != null && badgeText!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            badgeText!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: LqColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    ),
  );
}

void _showJourneySheet(
  BuildContext context, {
  required String title,
  required String eyebrow,
  required IconData icon,
  required String message,
}) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: const BoxDecoration(
        color: LqColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          LqTitleBlock(eyebrow: eyebrow, title: title),
          const SizedBox(height: 16),
          LqCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: LqColors.primarySoft,
                  foregroundColor: LqColors.primary,
                  child: Icon(icon),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: LqColors.muted,
                      height: 1.5,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _JourneyItem extends StatelessWidget {
  const _JourneyItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    contentPadding: EdgeInsets.zero,
    leading: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FC),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: LqColors.primary, size: 22),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(
      subtitle,
      style: const TextStyle(color: LqColors.muted, fontSize: 12),
    ),
    trailing: onTap == null
        ? null
        : const Icon(Icons.chevron_right, color: LqColors.muted),
  );
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.user, this.onSignOut});
  final AppUser user;
  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) => LqPage(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LqBackButton(label: 'Profile'),
          const LqTitleBlock(eyebrow: 'Profile', title: 'Settings'),
          const SizedBox(height: 26),
          _section('Personal details', [
            _SettingTile(
              icon: Icons.email_outlined,
              title: 'Email address',
              subtitle: user.email,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EmailAddressScreen()),
              ),
            ),
            _SettingTile(
              icon: Icons.lock_outline,
              title: 'Password & security',
              subtitle: 'Protect your LocalQuest account',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PasswordSecurityScreen(),
                ),
              ),
            ),
            _BiometricSettingTile(userId: user.id),
          ]),
          const SizedBox(height: 24),
          _section(
            'Preferences',
            user.role == AccountRole.merchant
                ? [
                    _PreferenceTile(
                      user: user,
                      keyName: 'campaignNotifications',
                      icon: Icons.campaign_outlined,
                      title: 'Campaign notifications',
                      subtitle: 'Campaign status and performance updates',
                    ),
                    _PreferenceTile(
                      user: user,
                      keyName: 'claimNotifications',
                      icon: Icons.confirmation_num_outlined,
                      title: 'Voucher claim notifications',
                      subtitle: 'Alerts when tourists claim your vouchers',
                    ),
                  ]
                : [
                    _PreferenceTile(
                      user: user,
                      keyName: 'tripNotifications',
                      icon: Icons.notifications_none,
                      title: 'Trip notifications',
                      subtitle: 'Check-ins, rewards & reminders',
                    ),
                    _PreferenceTile(
                      user: user,
                      keyName: 'locationHistory',
                      icon: Icons.location_on_outlined,
                      title: 'Location history',
                      subtitle: 'Automatic visit logging',
                    ),
                    _PreferenceTile(
                      user: user,
                      keyName: 'partnerOffers',
                      icon: Icons.card_giftcard,
                      title: 'Partner offers',
                      subtitle: 'Occasional local reward updates',
                    ),
                  ],
          ),
          const SizedBox(height: 24),
          _section('Support', [
            _SettingTile(
              icon: Icons.explore_outlined,
              title: 'Help centre',
              subtitle: 'Answers for your LocalQuest account',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HelpCentreScreen(role: user.role),
                ),
              ),
            ),
            _SettingTile(
              icon: Icons.shield_outlined,
              title: 'Privacy & data',
              subtitle: 'Manage your data and permissions',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PrivacyScreen(role: user.role),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 100),
          LqLogoutButton(
            onPressed: () => confirmLqSignOut(
              context,
              onSignOut ?? AuthService.instance.signOut,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _section(String label, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(), style: monoLabel),
      const SizedBox(height: 10),
      LqCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              children[index],
              if (index != children.length - 1) const LqDashedDivider(),
            ],
          ],
        ),
      ),
    ],
  );
}

class _BiometricSettingTile extends StatefulWidget {
  const _BiometricSettingTile({this.userId});
  final String? userId;
  @override
  State<_BiometricSettingTile> createState() => _BiometricSettingTileState();
}

class _BiometricSettingTileState extends State<_BiometricSettingTile> {
  bool _enabled = false;
  bool _supported = false;

  @override
  void initState() {
    super.initState();
    _loadBiometrics();
  }

  Future<void> _loadBiometrics() async {
    final supported = await BiometricAuthService.instance.isSupported();
    final enabled =
        await BiometricAuthService.instance.isEnabled(widget.userId);
    if (mounted) {
      setState(() {
        _supported = supported;
        _enabled = enabled;
      });
    }
  }

  Future<void> _toggleBiometrics(bool value) async {
    if (value) {
      final authenticated = await BiometricAuthService.instance.authenticate(
        localizedReason:
            'Verify biometric identity to enable biometric sign-in',
      );
      if (!authenticated) return;
    }
    await BiometricAuthService.instance.setEnabled(value, widget.userId);
    if (mounted) {
      setState(() => _enabled = value);
      showLqMessage(
        context,
        value ? 'Biometric sign-in enabled.' : 'Biometric sign-in disabled.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) return const SizedBox.shrink();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4FC),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.fingerprint_rounded,
          color: LqColors.primary,
          size: 24,
        ),
      ),
      title: const Text(
        'Biometric sign-in',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: const Text(
        'Use fingerprint or Face ID for faster login',
        style: TextStyle(color: LqColors.muted, fontSize: 12),
      ),
      trailing: Switch(
        value: _enabled,
        onChanged: _toggleBiometrics,
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    contentPadding: EdgeInsets.zero,
    leading: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FC),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: LqColors.primary, size: 22),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(
      subtitle,
      style: const TextStyle(color: LqColors.muted, fontSize: 12),
    ),
    trailing: onTap == null
        ? null
        : const Icon(Icons.chevron_right, color: LqColors.muted),
  );
}

class _PreferenceTile extends StatefulWidget {
  const _PreferenceTile({
    required this.user,
    required this.keyName,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final AppUser user;
  final String keyName;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  State<_PreferenceTile> createState() => _PreferenceTileState();
}

class _PreferenceTileState extends State<_PreferenceTile> {
  late bool value = widget.user.preferences[widget.keyName] as bool? ?? true;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FC),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(widget.icon, color: LqColors.primary, size: 22),
    ),
    title: Text(
      widget.title,
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
    subtitle: Text(
      widget.subtitle,
      style: const TextStyle(color: LqColors.muted, fontSize: 12),
    ),
    trailing: Switch(
      value: value,
      onChanged: (next) async {
        setState(() => value = next);
        try {
          await UserRepository.instance.updatePreference(
            widget.user.id,
            widget.keyName,
            next,
          );
        } catch (_) {
          if (context.mounted) {
            setState(() => value = !next);
            showLqMessage(
              context,
              'Could not update this preference. Please try again.',
              error: true,
            );
          }
        }
      },
    ),
  );
}

class AccountDetailsScreen extends StatefulWidget {
  const AccountDetailsScreen({super.key, required this.user});
  final AppUser user;
  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  late final _name = TextEditingController(text: widget.user.displayName);
  late final _username = TextEditingController(text: widget.user.username);
  late final _phone = TextEditingController(text: widget.user.phone);
  late final _birthday = TextEditingController(
    text: widget.user.birthday == null
        ? ''
        : DateFormat('dd/MM/yyyy').format(widget.user.birthday!),
  );
  bool _busy = false;
  @override
  Widget build(BuildContext context) => _SimpleFormPage(
    eyebrow: 'Identity',
    title: 'Account details',
    subtitle: 'Your personal details and how we reach you.',
    headerIcon: Icons.person_outline,
    children: [
      ProfilePhotoEditor(user: widget.user),
      const SizedBox(height: 20),
      LqField(controller: _name, label: 'Display name'),
      const SizedBox(height: 16),
      LqField(controller: _username, label: 'Username'),
      const SizedBox(height: 16),
      LqField(controller: _phone, label: 'Phone number'),
      const SizedBox(height: 16),
      LqField(
        controller: _birthday,
        label: 'Birthday',
        hint: 'Choose date',
        readOnly: true,
        suffixIcon: Icons.calendar_month_outlined,
        onTap: _pickBirthday,
      ),
      const SizedBox(height: 24),
      LqButton(
        label: 'Save changes',
        busy: _busy,
        icon: Icons.save_outlined,
        onPressed: _save,
      ),
    ],
  );

  Future<void> _save() async {
    setState(() => _busy = true);
    final parts = _birthday.text.split('/');
    final birthday = parts.length == 3
        ? DateTime.tryParse('${parts[2]}-${parts[1]}-${parts[0]}')
        : null;
    try {
      await UserRepository.instance.updateProfile(
        uid: widget.user.id,
        displayName: _name.text,
        username: _username.text,
        phone: _phone.text,
        birthday: birthday,
      );
      if (mounted) showLqMessage(context, 'Account details updated.');
    } catch (_) {
      if (mounted) {
        showLqMessage(
          context,
          'Could not update your account details. Please try again.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickBirthday() async {
    final parts = _birthday.text.split('/');
    final current = parts.length == 3
        ? DateTime.tryParse('${parts[2]}-${parts[1]}-${parts[0]}')
        : null;
    final chosen = await showLqDatePicker(
      context,
      initialDate: current ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      title: 'Select birthday',
    );
    if (chosen != null) {
      setState(() => _birthday.text = DateFormat('dd/MM/yyyy').format(chosen));
    }
  }
}

class EmailAddressScreen extends StatefulWidget {
  const EmailAddressScreen({super.key, this.currentEmail});
  final String? currentEmail;
  @override
  State<EmailAddressScreen> createState() => _EmailAddressScreenState();
}

class _EmailAddressScreenState extends State<EmailAddressScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SimpleFormPage(
    eyebrow: 'Contact',
    title: 'Email address',
    subtitle: 'Use an address you can access for account recovery.',
    headerIcon: Icons.email_outlined,
    children: [
      Form(
        key: _form,
        autovalidateMode: AutovalidateMode.disabled,
        child: Column(
          children: [
            TextFormField(
              initialValue:
                  widget.currentEmail ?? FirebaseAuth.instance.currentUser?.email,
              enabled: false,
              decoration: const InputDecoration(labelText: 'Current email'),
            ),
            const SizedBox(height: 16),
            LqField(
              key: const Key('change_email_new_field'),
              controller: _email,
              label: 'New email address',
              keyboardType: TextInputType.emailAddress,
              validator: LqInputValidators.validateEmailFormat,
            ),
            const SizedBox(height: 16),
            LqField(
              key: const Key('change_email_password_field'),
              controller: _password,
              label: 'Current password',
              obscureText: true,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Enter your current password.' : null,
            ),
            const SizedBox(height: 12),
            const Text(
              'We’ll send a verification link before your email address changes.',
              style: TextStyle(color: LqColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 24),
            LqButton(label: 'Send verification', busy: _busy, onPressed: _save),
          ],
        ),
      ),
    ],
  );

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await AuthService.instance.requestEmailChange(
        currentPassword: _password.text,
        newEmail: _email.text,
      );
      if (mounted) showLqMessage(context, 'Verification email sent.');
    } on LocalQuestException catch (error) {
      if (mounted) showLqMessage(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class PasswordSecurityScreen extends StatefulWidget {
  const PasswordSecurityScreen({super.key});
  @override
  State<PasswordSecurityScreen> createState() => _PasswordSecurityScreenState();
}

class _PasswordSecurityScreenState extends State<PasswordSecurityScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SimpleFormPage(
    eyebrow: 'Security',
    title: 'Password & security',
    subtitle: 'Keep your account protected with a strong password.',
    headerIcon: Icons.shield_outlined,
    children: [
      Form(
        key: _form,
        autovalidateMode: AutovalidateMode.disabled,
        child: Column(
          children: [
            LqField(
              key: const Key('change_password_current_field'),
              controller: _current,
              label: 'Current password',
              obscureText: true,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Enter your current password.' : null,
            ),
            const SizedBox(height: 16),
            LqNewPasswordField(
              key: const Key('change_password_new_field'),
              controller: _next,
              label: 'New password',
            ),
            const SizedBox(height: 16),
            LqField(
              key: const Key('change_password_confirm_field'),
              controller: _confirm,
              label: 'Confirm password',
              obscureText: true,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Confirm your new password.';
                if (v != _next.text) return 'Passwords do not match.';
                return null;
              },
            ),
            const SizedBox(height: 24),
            LqButton(
              label: 'Save changes',
              busy: _busy,
              icon: Icons.lock_outline,
              onPressed: _save,
            ),
          ],
        ),
      ),
    ],
  );

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final policyError = PasswordPolicy.validate(_next.text);
    if (policyError != null) {
      showLqMessage(context, policyError, error: true);
      return;
    }
    if (_next.text == _current.text) {
      showLqMessage(
        context,
        'Choose a different password from your current one.',
        error: true,
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await AuthService.instance.updatePassword(
        currentPassword: _current.text,
        newPassword: _next.text,
      );
      if (mounted) {
        _current.clear();
        _next.clear();
        _confirm.clear();
        showLqMessage(context, 'Password updated.');
      }
    } on LocalQuestException catch (error) {
      if (mounted) showLqMessage(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _SimpleFormPage extends StatelessWidget {
  const _SimpleFormPage({
    required this.eyebrow,
    required this.title,
    required this.children,
    this.subtitle,
    this.headerIcon,
  });
  final String eyebrow;
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final IconData? headerIcon;

  @override
  Widget build(BuildContext context) => LqPage(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LqBackButton(label: 'Back to settings'),
          const SizedBox(height: 14),
          LqTitleBlock(
            eyebrow: eyebrow,
            title: title,
            subtitle: subtitle,
            icon: headerIcon,
          ),
          const SizedBox(height: 24),
          LqCard(child: Column(children: children)),
        ],
      ),
    ),
  );
}

class VisitedPlacesScreen extends StatelessWidget {
  const VisitedPlacesScreen({super.key, required this.userId});
  final String userId;

  static const _pastelBgs = [
    Color(0xFFF5D9CE), // warm peach / terracotta (#FEF4EF in figma)
    Color(0xFFDCE8C9), // soft sage green
    Color(0xFFD7E2FB), // soft sky blue
    Color(0xFFFCE3D8), // soft apricot
    Color(0xFFE2DCF7), // soft lavender
  ];

  static const _iconColors = [
    Color(0xFFE0694F),
    Color(0xFF4C8A36),
    Color(0xFF3267D4),
    Color(0xFFD97736),
    Color(0xFF6B4EC4),
  ];

  String _formatVisitedDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    if (isToday) {
      return 'Today, ${DateFormat('HH:mm').format(date)}';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday =
        date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
    if (isYesterday) {
      return 'Yesterday, ${DateFormat('HH:mm').format(date)}';
    }
    return DateFormat('d MMM, HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) => LqPage(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const LqBackButton(label: 'Profile'),
                  const SizedBox(height: 8),
                  const Text(
                    'Visited places',
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
              Tooltip(
                message: 'Simulate check-in',
                child: InkWell(
                  key: const Key('visited_places_demo_checkin_btn'),
                  onTap: () async {
                    final recorded = await UserRepository.instance.recordVisit(
                      userId: userId,
                      name: 'LocalQuest Heritage Hub',
                      area: 'Bukit Bintang, Kuala Lumpur',
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            recorded
                                ? 'Demo visit recorded! Location history updated.'
                                : 'Could not record: Location history is disabled in Settings.',
                          ),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.add_location_alt_outlined,
                      size: 20,
                      color: LqColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'THIS MONTH',
            style: monoLabel.copyWith(
              fontSize: 10,
              letterSpacing: 1.6,
              color: LqColors.muted,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: UserRepository.instance.visitedPlaces(userId),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.location_off_outlined,
                            size: 48,
                            color: LqColors.muted,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No visited locations found.',
                            style: TextStyle(
                              color: LqColors.muted,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'When you visit partnered merchants or local spots, they will be automatically recorded here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: LqColors.muted, fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          OutlinedButton.icon(
                            key: const Key('visited_places_empty_simulate_btn'),
                            onPressed: () async {
                              final recorded = await UserRepository.instance.recordVisit(
                                userId: userId,
                                name: 'LocalQuest Heritage Hub',
                                area: 'Bukit Bintang, Kuala Lumpur',
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      recorded
                                          ? 'Demo visit recorded! Location history updated.'
                                          : 'Could not record: Location history is disabled in Settings.',
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.add_location_alt_outlined),
                            label: const Text('Simulate visit check-in (Demo)'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final date = (data['visitedAt'] as Timestamp?)?.toDate();
                    final businessId = data['businessId'] as String? ?? '';
                    final pastelBg = _pastelBgs[index % _pastelBgs.length];
                    final iconColor = _iconColors[index % _iconColors.length];

                    return Dismissible(
                      key: ValueKey(docs[index].id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFECEB),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Color(0xFFD9534F),
                        ),
                      ),
                      onDismissed: (_) => docs[index].reference.delete(),
                      child: LqCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: pastelBg,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.place_outlined,
                                color: iconColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['name'] as String? ?? 'Visited place',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: LqColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    data['area'] as String? ?? '',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      color: LqColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _formatVisitedDate(date),
                              style: const TextStyle(
                                fontFamily: 'DM Mono',
                                fontSize: 10,
                                color: LqColors.muted,
                              ),
                            ),
                            if (businessId.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                tooltip: 'Write a review',
                                icon: const Icon(
                                  Icons.rate_review_outlined,
                                  size: 20,
                                  color: LqColors.primary,
                                ),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => WriteReviewScreen(
                                      userId: userId,
                                      businessId: businessId,
                                      businessName:
                                      data['name'] as String? ?? 'this business',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 14,
                  color: Color(0xFF8A94A6),
                ),
                SizedBox(width: 6),
                Text(
                  'Location history is private to you.',
                  style: TextStyle(
                    color: Color(0xFF8A94A6),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class HelpCentreScreen extends StatefulWidget {
  const HelpCentreScreen({super.key, this.role});
  final AccountRole? role;

  @override
  State<HelpCentreScreen> createState() => _HelpCentreScreenState();
}

class _HelpCentreScreenState extends State<HelpCentreScreen> {
  final _query = TextEditingController();

  Map<String, String> get faqs {
    if (widget.role == AccountRole.merchant) {
      return const {
        'How do I verify my SSM registration?':
            'Open the business editor, tap "Scan SSM registration certificate" or enter your 12-digit SSM number to request verification.',
        'How do campaigns and advertisements work?':
            'Active businesses can create ads and campaigns to reach nearby tourists and attract visitors to your location.',
        'How do customers redeem vouchers at my business?':
            'Tourists present an active redemption screen in Rewards. Check their redemption code and apply the offer.',
        'How do I adjust my business entrance pin on the map?':
            'Open your business listing, tap "Street address", and use "Pin location on map" to set the exact storefront location.',
        'Can I use one account as a Tourist and Merchant?':
            'Tourist and Merchant accounts are separate so that business operations and personal travel activity remain distinct.',
      };
    }
    return const {
      'How does automatic place logging work?':
          'When location history is enabled, LocalQuest records a visit only after a verified proximity event.',
      'How do I redeem a voucher?':
          'Open the voucher in Rewards and present its active redemption screen to the participating merchant.',
      'Why is my check-in not showing?':
          'Check location permission and network access, then reopen the app near the registered location.',
      'Can I use one account as a Tourist and Merchant?':
          'Tourist and Merchant accounts are separate so that data and permissions remain clear and secure.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text.toLowerCase();
    final values = faqs.entries
        .where((entry) => entry.key.toLowerCase().contains(query))
        .toList();
    return LqPage(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LqBackButton(label: 'Back to settings'),
            const SizedBox(height: 14),
            LqTitleBlock(
              eyebrow: widget.role == AccountRole.merchant
                  ? 'Merchant support'
                  : 'Support',
              title: 'Help centre',
              subtitle: widget.role == AccountRole.merchant
                  ? 'Find answers and guidance for managing your business.'
                  : 'Find answers for your LocalQuest account.',
              icon: Icons.help_outline,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search a question',
              ),
            ),
            const SizedBox(height: 18),
            LqCard(
              color: Colors.transparent,
              child: Column(
                children: values.indexed
                    .map(
                      (item) => Padding(
                        padding: EdgeInsets.only(
                          bottom: item.$1 == values.length - 1 ? 0 : 8,
                        ),
                        child: LqCard(
                          padding: EdgeInsets.zero,
                          child: ExpansionTile(
                            initiallyExpanded: item.$1 == 0,
                            shape: const Border(),
                            collapsedShape: const Border(),
                            title: Text(
                              item.$2.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            children: [
                              const LqDashedDivider(color: Color(0xFFE8ECF2)),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  16,
                                ),
                                child: Text(
                                  item.$2.value,
                                  style: const TextStyle(
                                    color: LqColors.muted,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) => LqPage(
    child: SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LqBackButton(label: 'Profile'),
            const SizedBox(height: 14),
            const LqTitleBlock(
              eyebrow: 'Activity',
              title: 'Notifications',
              subtitle: 'Account updates and LocalQuest alerts in one place.',
              icon: Icons.notifications_none_outlined,
            ),
            const SizedBox(height: 24),
            LqCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    backgroundColor: LqColors.primarySoft,
                    foregroundColor: LqColors.primary,
                    child: Icon(Icons.notifications_active_outlined),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'You’re all caught up',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    user.role == AccountRole.merchant
                        ? 'Campaign and voucher activity will appear here.'
                        : 'Trip, reward and voucher activity will appear here.',
                    style: const TextStyle(color: LqColors.muted, height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            LqButton(
              label: 'Notification preferences',
              icon: Icons.tune,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SettingsScreen(user: user)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key, this.role});
  final AccountRole? role;

  @override
  Widget build(BuildContext context) => LqPage(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LqBackButton(label: 'Back to settings'),
          const SizedBox(height: 14),
          LqTitleBlock(
            eyebrow:
                role == AccountRole.merchant ? 'Merchant privacy' : 'Privacy',
            title: 'Privacy & data',
            subtitle: role == AccountRole.merchant
                ? 'Review business data policies, certificate confidentiality, and permissions.'
                : 'Review personal data, permissions, and account-export options.',
            icon: Icons.privacy_tip_outlined,
          ),
          const SizedBox(height: 22),
          LqCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LocalQuest Privacy Notice',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                const Text(
                  '1. Information we collect',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  role == AccountRole.merchant
                      ? 'Business profile information, SSM certificates, verified store entrance coordinates, and campaign data.'
                      : 'Profile information, device identifiers, optional location history, and content you submit.',
                  style: const TextStyle(color: LqColors.muted, height: 1.5),
                ),
                const SizedBox(height: 14),
                const Text(
                  '2. How we use your information',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  role == AccountRole.merchant
                      ? 'To list your verified business, facilitate coupon redemptions, protect against fraud, and comply with Malaysian regulations.'
                      : 'To provide account features, deliver rewards, log eligible visits, and protect the LocalQuest community.',
                  style: const TextStyle(color: LqColors.muted, height: 1.5),
                ),
                const SizedBox(height: 14),
                const Text(
                  '3. Location data',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  role == AccountRole.merchant
                      ? 'Business coordinates are used to display your store location accurately on the map for visitors.'
                      : 'Location history is optional and can be paused from Settings.',
                  style: const TextStyle(color: LqColors.muted, height: 1.5),
                ),
                const SizedBox(height: 14),
                const Text(
                  '4. Your rights',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  role == AccountRole.merchant
                      ? 'You may edit business listings, update SSM numbers, export records, or delete your account at any time.'
                      : 'You may request access, correction, export, or deletion of your information.',
                  style: const TextStyle(color: LqColors.muted, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => _deleteDialog(context),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete account'),
            style: OutlinedButton.styleFrom(
              foregroundColor: LqColors.danger,
              side: const BorderSide(color: LqColors.danger),
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ],
      ),
    ),
  );

  void _deleteDialog(BuildContext context) {
    final password = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This action cannot be undone. Enter your current password to continue.',
            ),
            const SizedBox(height: 16),
            LqField(
              key: const Key('delete_account_password_field'),
              controller: password,
              label: 'Current password',
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await AuthService.instance.deleteAccount(password.text);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } on LocalQuestException catch (error) {
                if (dialogContext.mounted) {
                  showLqMessage(dialogContext, error.message, error: true);
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: LqColors.danger),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
  }
}
