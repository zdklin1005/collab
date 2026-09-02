import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/localquest_theme.dart';
import '../core/localquest_widgets.dart';
import '../models/localquest_models.dart';
import '../services/localquest_services.dart';

class TouristHome extends StatefulWidget {
  const TouristHome({super.key, required this.user});
  final AppUser user;

  @override
  State<TouristHome> createState() => _TouristHomeState();
}

class _TouristHomeState extends State<TouristHome> {
  int _index = 2;

  @override
  Widget build(BuildContext context) {
    final profile = TouristProfileScreen(user: widget.user);
    final pages = [
      const _ModulePlaceholder(
        title: 'Discover',
        subtitle: 'The interactive map belongs to the Map & Navigation module.',
      ),
      const _ModulePlaceholder(
        title: 'Rewards',
        subtitle: 'Rewards and missions belong to the Reward & Review module.',
      ),
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
      ),
      child: pages[_index],
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
            color: LqColors.primarySoft,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: const Color(0xFFE4C8B7),
                        child: Text(
                          initialsFor(user.displayName),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: Color(0xFF573725),
                          ),
                        ),
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
                                  child: Chip(
                                    label: Text(
                                      'EXPLORER · LEVEL ${user.level}',
                                      overflow: TextOverflow.ellipsis,
                                      style: monoLabel.copyWith(
                                        color: LqColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${user.exp}/3,000XP',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: LqColors.primary,
                                  size: 18,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: ((user.exp % 3000) / 3000).clamp(0, 1),
                              minHeight: 7,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ],
                        ),
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
                        icon: Icons.confirmation_num_outlined,
                      ),
                    ),
                    const SizedBox(
                      height: 92,
                      child: LqDashedDivider(vertical: true),
                    ),
                    Expanded(
                      child: _Stat(
                        label: 'Reviews',
                        value: '${user.reviewCount}',
                        icon: Icons.star_border,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text('YOUR JOURNEY', style: monoLabel),
        const SizedBox(height: 12),
        LqCard(
          child: Column(
            children: [
              _JourneyItem(
                icon: Icons.confirmation_num_outlined,
                title: 'My vouchers',
                subtitle: '${user.voucherCount} ready to use',
              ),
              _JourneyItem(
                icon: Icons.star_outline,
                title: 'Reviews & ratings',
                subtitle: '${user.reviewCount} posted',
              ),
              const _JourneyItem(
                icon: Icons.auto_awesome_outlined,
                title: 'Missions',
                subtitle: 'View current progress',
              ),
              const _JourneyItem(
                icon: Icons.calendar_month_outlined,
                title: 'Daily check-in',
                subtitle: 'Keep your streak',
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
  const _Stat({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;
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
      ],
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
    leading: CircleAvatar(
      backgroundColor: const Color(0xFFF0F4FC),
      foregroundColor: LqColors.primary,
      child: Icon(icon),
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
  const SettingsScreen({super.key, required this.user});
  final AppUser user;

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
                MaterialPageRoute(builder: (_) => const HelpCentreScreen()),
              ),
            ),
            _SettingTile(
              icon: Icons.shield_outlined,
              title: 'Privacy & data',
              subtitle: 'Manage your data and permissions',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyScreen()),
              ),
            ),
          ]),
          const SizedBox(height: 100),
          LqLogoutButton(
            onPressed: () =>
                confirmLqSignOut(context, AuthService.instance.signOut),
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
    leading: CircleAvatar(
      backgroundColor: const Color(0xFFF0F4FC),
      foregroundColor: LqColors.primary,
      child: Icon(icon),
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
    leading: CircleAvatar(
      backgroundColor: const Color(0xFFF0F4FC),
      foregroundColor: LqColors.primary,
      child: Icon(widget.icon),
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
    children: [
      Center(
        child: CircleAvatar(
          radius: 36,
          backgroundColor: const Color(0xFFE4C8B7),
          child: Text(
            initialsFor(widget.user.displayName),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
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
    final chosen = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Select birthday',
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
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  @override
  Widget build(BuildContext context) => _SimpleFormPage(
    eyebrow: 'Contact',
    title: 'Email address',
    subtitle: 'Use an address you can access for account recovery.',
    children: [
      TextFormField(
        initialValue:
            widget.currentEmail ?? FirebaseAuth.instance.currentUser?.email,
        enabled: false,
        decoration: const InputDecoration(labelText: 'Current email'),
      ),
      const SizedBox(height: 16),
      LqField(controller: _email, label: 'New email address'),
      const SizedBox(height: 16),
      LqField(
        controller: _password,
        label: 'Current password',
        obscureText: true,
      ),
      const SizedBox(height: 12),
      const Text(
        'We’ll send a verification link before your email address changes.',
        style: TextStyle(color: LqColors.muted, fontSize: 12),
      ),
      const SizedBox(height: 24),
      LqButton(label: 'Send verification', busy: _busy, onPressed: _save),
    ],
  );

  Future<void> _save() async {
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
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  @override
  Widget build(BuildContext context) => _SimpleFormPage(
    eyebrow: 'Security',
    title: 'Password & security',
    subtitle: 'Keep your account protected with a strong password.',
    children: [
      LqField(
        controller: _current,
        label: 'Current password',
        obscureText: true,
      ),
      const SizedBox(height: 16),
      LqField(controller: _next, label: 'New password', obscureText: true),
      const SizedBox(height: 16),
      LqField(
        controller: _confirm,
        label: 'Confirm password',
        obscureText: true,
      ),
      const SizedBox(height: 24),
      LqButton(
        label: 'Save changes',
        busy: _busy,
        icon: Icons.lock_outline,
        onPressed: _save,
      ),
    ],
  );

  Future<void> _save() async {
    if (_next.text.length < 8 || _next.text != _confirm.text) {
      showLqMessage(
        context,
        'Passwords must match and use at least 8 characters.',
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
      if (mounted) showLqMessage(context, 'Password updated.');
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
  });
  final String eyebrow;
  final String title;
  final String? subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LqPage(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 26, 16, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LqBackButton(label: 'Back to settings'),
          LqTitleBlock(eyebrow: eyebrow, title: title, subtitle: subtitle),
          const SizedBox(height: 28),
          LqCard(child: Column(children: children)),
        ],
      ),
    ),
  );
}

class VisitedPlacesScreen extends StatelessWidget {
  const VisitedPlacesScreen({super.key, required this.userId});
  final String userId;
  @override
  Widget build(BuildContext context) => LqPage(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LqBackButton(label: 'Profile'),
          const LqTitleBlock(eyebrow: 'This month', title: 'Visited places'),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: UserRepository.instance.visitedPlaces(userId),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No visited locations found.',
                      style: TextStyle(color: LqColors.muted),
                    ),
                  );
                }
                return LqCard(
                  child: ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      final date = (data['visitedAt'] as Timestamp?)?.toDate();
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: LqColors.primarySoft,
                          child: Icon(
                            Icons.place_outlined,
                            color: LqColors.primary,
                          ),
                        ),
                        title: Text(
                          data['name'] as String? ?? 'Visited place',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${data['area'] as String? ?? ''}${date == null ? '' : '\n${DateFormat('d MMM, HH:mm').format(date)}'}',
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Center(
              child: Text(
                'Location history is private to you.',
                style: TextStyle(color: LqColors.muted, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class HelpCentreScreen extends StatefulWidget {
  const HelpCentreScreen({super.key});
  @override
  State<HelpCentreScreen> createState() => _HelpCentreScreenState();
}

class _HelpCentreScreenState extends State<HelpCentreScreen> {
  final _query = TextEditingController();
  final faqs = const {
    'How does automatic place logging work?':
        'When location history is enabled, LocalQuest records a visit only after a verified proximity event.',
    'How do I redeem a voucher?':
        'Open the voucher in Rewards and present its active redemption screen to the participating merchant.',
    'Why is my check-in not showing?':
        'Check location permission and network access, then reopen the app near the registered location.',
    'Can I use one account as a Tourist and Merchant?':
        'Tourist and Merchant accounts are separate so that data and permissions remain clear and secure.',
  };
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
            const LqTitleBlock(
              eyebrow: 'Support',
              title: 'Help centre',
              subtitle: 'Find answers for your LocalQuest account.',
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
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
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
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LqBackButton(label: 'Profile'),
          const LqTitleBlock(
            eyebrow: 'Activity',
            title: 'Notifications',
            subtitle: 'Account updates and LocalQuest alerts in one place.',
          ),
          const SizedBox(height: 24),
          LqCard(
            child: Column(
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
                  textAlign: TextAlign.center,
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
  );
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) => LqPage(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LqBackButton(label: 'Back to settings'),
          const LqTitleBlock(
            eyebrow: 'Privacy',
            title: 'Privacy & data',
            subtitle:
                'Review personal data, permissions, and account-export options.',
          ),
          const SizedBox(height: 22),
          const LqCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LocalQuest Privacy Notice',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 14),
                Text(
                  '1. Information we collect',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Profile information, device identifiers, optional location history, and content you submit.',
                  style: TextStyle(color: LqColors.muted, height: 1.5),
                ),
                SizedBox(height: 14),
                Text(
                  '2. How we use your information',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'To provide account features, deliver rewards, log eligible visits, and protect the LocalQuest community.',
                  style: TextStyle(color: LqColors.muted, height: 1.5),
                ),
                SizedBox(height: 14),
                Text(
                  '3. Location data',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Location history is optional and can be paused from Settings.',
                  style: TextStyle(color: LqColors.muted, height: 1.5),
                ),
                SizedBox(height: 14),
                Text(
                  '4. Your rights',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'You may request access, correction, export, or deletion of your information.',
                  style: TextStyle(color: LqColors.muted, height: 1.5),
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
