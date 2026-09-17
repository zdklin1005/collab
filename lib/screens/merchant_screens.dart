import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../core/localquest_theme.dart';
import '../core/localquest_location.dart';
import '../core/localquest_widgets.dart';
import '../core/merchant_validation.dart';
import '../core/certificate_scan.dart';
import '../core/ssm_verification.dart';
import '../core/business_photo_field.dart';
import '../core/lq_image_cropper.dart';
import '../models/localquest_models.dart';
import '../services/localquest_services.dart';
import 'tourist_screens.dart';
import 'merchant_redeem_voucher_screen.dart';

class MerchantHome extends StatefulWidget {
  const MerchantHome({super.key, required this.user});
  final AppUser user;
  @override
  State<MerchantHome> createState() => _MerchantHomeState();
}

class _MerchantHomeState extends State<MerchantHome> {
  int _index = 0;
  String _campaignType = 'ad';
  String? _businessId;
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Business>>(
    stream: MerchantRepository.instance.businesses(widget.user.id),
    builder: (context, snapshot) {
      final businesses = snapshot.data ?? [];
      final selectedBusiness = businesses.isEmpty
          ? null
          : businesses.firstWhere(
              (item) => item.id == _businessId,
              orElse: () => businesses.first,
            );
      final pages = [
        MerchantOverview(
          user: widget.user,
          business: selectedBusiness,
          openCampaigns: () => setState(() => _index = 1),
        ),
        CampaignsScreen(
          key: ValueKey('$_campaignType:${selectedBusiness?.id}'),
          user: widget.user,
          business: selectedBusiness,
          initialType: _campaignType,
        ),
        MerchantProfile(
          user: widget.user,
          businesses: businesses,
          selectedBusiness: selectedBusiness,
          onBusinessSelected: (id) => setState(() => _businessId = id),
          openAds: () => setState(() {
            _campaignType = 'ad';
            _index = 1;
          }),
          openVouchers: () => setState(() {
            _campaignType = 'voucher';
            _index = 1;
          }),
        ),
      ];
      return LqPage(
        bottomNavigationBar: LqFloatingNavBar(
          selectedIndex: _index,
          onSelected: (value) => setState(() => _index = value),
          items: const [
            (Icons.business_center_outlined, 'Home'),
            (Icons.auto_awesome_outlined, 'Campaign'),
            (Icons.person_outline, 'Profile'),
          ],
          profileInitials: initialsFor(widget.user.displayName),
          profilePhotoUrl: widget.user.photoUrl,
        ),
        child: pages[_index],
      );
    },
  );
}

class MerchantOverview extends StatelessWidget {
  const MerchantOverview({
    super.key,
    required this.user,
    required this.business,
    required this.openCampaigns,
    this.campaignStream,
  });
  final AppUser user;
  final Business? business;
  final VoidCallback openCampaigns;
  final Stream<List<Campaign>>? campaignStream;
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Campaign>>(
    stream: campaignStream ??
        MerchantRepository.instance.campaigns(
          user.id,
          businessId: business?.id,
        ),
    builder: (context, snapshot) {
      final campaigns = snapshot.data ?? [];
      final liveAds = campaigns
          .where((item) =>
              item.type == 'ad' &&
              item.effectiveStatus == 'active' &&
              !item.isScheduled &&
              item.status != 'scheduled')
          .toList();
      final views = campaigns.fold<int>(0, (sum, item) => sum + item.views);
      final claims = campaigns.fold<int>(0, (sum, item) => sum + item.claims);
      final recentAds =
          campaigns.where((item) => item.type == 'ad').take(4).toList();
      final latestVouchers =
          campaigns.where((item) => item.type == 'voucher').take(4).toList();
      return Stack(
        fit: StackFit.expand,
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 44, 16, 170),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LqTitleBlock(
                  eyebrow: 'Merchant portal',
                  title: 'Business\noverview',
                ),
                if (business != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        business!.name,
                        style: monoLabel.copyWith(color: LqColors.primary),
                      ),
                      if (business!.isSsmVerified)
                        const SsmVerifiedBadge(compact: true),
                    ],
                  ),
                ],
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        icon: Icons.confirmation_num_outlined,
                        color: LqColors.greenSoft,
                        value: '$claims',
                        label: 'Vouchers claimed',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        icon: Icons.people_outline,
                        color: LqColors.primarySoft,
                        value: '$views',
                        label: 'Campaign views',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _MetricCard(
                  icon: Icons.auto_awesome_outlined,
                  color: LqColors.peachSoft,
                  value: liveAds.length.toString().padLeft(2, '0'),
                  label: 'Active campaigns',
                ),
                const SizedBox(height: 40),
                _LiveCampaignCarousel(
                  campaigns: liveAds,
                  monoLabel: monoLabel,
                  onEdit: (camp) => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CampaignEditor(
                        user: user,
                        businessId: business?.id ?? '',
                        campaign: camp,
                        initialType: 'ad',
                      ),
                    ),
                  ),
                  onToggle: (camp, val) => _setCampaignActive(context, camp, val),
                ),
                const SizedBox(height: 28),
                Text('RECENT ADS', style: monoLabel),
                const SizedBox(height: 10),
                LqCard(
                  child: recentAds.isEmpty
                      ? const Text(
                          'No promotional ads yet.',
                          style: TextStyle(color: LqColors.muted),
                        )
                      : Column(
                          children: recentAds
                              .map(
                                (item) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: LqColors.primarySoft,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.auto_awesome,
                                      color: LqColors.primary,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    item.isScheduled
                                        ? 'Scheduled · Starts ${DateFormat('d MMM').format(item.startDate)}'
                                        : item.isExpired
                                            ? 'Inactive · Ended ${DateFormat('d MMM').format(item.endDate)}'
                                            : '${item.effectiveStatus.toUpperCase()} · ${item.views} views',
                                    style: const TextStyle(
                                      color: LqColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CampaignEditor(
                                        user: user,
                                        businessId: business?.id ?? '',
                                        campaign: item,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
                const SizedBox(height: 24),
                Text('LATEST VOUCHERS', style: monoLabel),
                const SizedBox(height: 10),
                LqCard(
                  child: latestVouchers.isEmpty
                      ? const Text(
                          'No vouchers yet.',
                          style: TextStyle(color: LqColors.muted),
                        )
                      : Column(
                          children: latestVouchers
                              .map(
                                (item) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: LqColors.greenSoft,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.confirmation_num_outlined,
                                      color: Color(0xFF42723B),
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${item.claims} claimed · ${item.effectiveStatus.toUpperCase()}',
                                    style: const TextStyle(
                                      color: LqColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CampaignEditor(
                                        user: user,
                                        businessId: business?.id ?? '',
                                        campaign: item,
                                        initialType: 'voucher',
                                      ),
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
          if (business?.active == true)
            Positioned(
              right: 16,
              bottom: 96,
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CampaignEditor(user: user, businessId: business!.id),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Create campaign'),
              ),
            ),
        ],
      );
    },
  );

  Future<void> _setCampaignActive(
    BuildContext context,
    Campaign campaign,
    bool active,
  ) async {
    try {
      await MerchantRepository.instance.setCampaignStatus(campaign.id, active);
      if (context.mounted && !active && campaign.type == 'ad') {
        showLqMessage(
          context,
          'Campaign paused. Any associated vouchers have also been set to inactive.',
        );
      }
    } catch (_) {
      if (context.mounted) {
        showLqMessage(
          context,
          'Could not update the campaign status. Please try again.',
          error: true,
        );
      }
    }
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => LqCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: LqColors.primary, size: 22),
        ),
        const SizedBox(height: 20),
        Text(
          value,
          style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: LqColors.muted, fontSize: 12),
        ),
      ],
    ),
  );
}

class _LiveCampaignCarousel extends StatefulWidget {
  const _LiveCampaignCarousel({
    required this.campaigns,
    required this.monoLabel,
    required this.onEdit,
    required this.onToggle,
  });

  final List<Campaign> campaigns;
  final TextStyle monoLabel;
  final ValueChanged<Campaign> onEdit;
  final void Function(Campaign campaign, bool active) onToggle;

  @override
  State<_LiveCampaignCarousel> createState() => _LiveCampaignCarouselState();
}

class _LiveCampaignCarouselState extends State<_LiveCampaignCarousel> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    final initialPage = widget.campaigns.length > 1
        ? (1000 * widget.campaigns.length)
        : 0;
    _pageController = PageController(initialPage: initialPage);
  }

  @override
  void didUpdateWidget(covariant _LiveCampaignCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.campaigns.length != widget.campaigns.length) {
      final initialPage = widget.campaigns.length > 1
          ? (1000 * widget.campaigns.length)
          : 0;
      _pageController.dispose();
      _pageController = PageController(initialPage: initialPage);
      _currentIndex = 0;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.campaigns.isEmpty) {
      return const LqCard(
        child: Text(
          'No active campaigns yet. Create one to reach nearby LocalQuest explorers.',
          style: TextStyle(color: LqColors.muted),
        ),
      );
    }

    if (widget.campaigns.length == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: _buildCard(widget.campaigns.first),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 244,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (page) {
              setState(() {
                _currentIndex = page % widget.campaigns.length;
              });
            },
            itemBuilder: (context, index) {
              final campaign =
                  widget.campaigns[index % widget.campaigns.length];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _buildCard(campaign),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < widget.campaigns.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentIndex == i ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _currentIndex == i ? LqColors.primary : LqColors.line,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildCard(Campaign campaign) {
    return LqCard(
      color: LqColors.primarySoft,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('LIVE CAMPAIGN', style: widget.monoLabel),
              Switch(
                value: true,
                onChanged: (value) => widget.onToggle(campaign, value),
              ),
            ],
          ),
          Text(
            campaign.name,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'ACTIVE · ENDS ${DateFormat('d MMM').format(campaign.endDate).toUpperCase()}',
            style: widget.monoLabel.copyWith(color: LqColors.success),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                campaign.description,
                style: const TextStyle(
                  color: LqColors.muted,
                  height: 1.35,
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => widget.onEdit(campaign),
            child: const Text('Edit details'),
          ),
        ],
      ),
    );
  }
}

class CampaignsScreen extends StatefulWidget {
  const CampaignsScreen({
    super.key,
    required this.user,
    required this.business,
    this.initialType = 'ad',
    this.campaignStream,
  });
  final AppUser user;
  final Business? business;
  final String initialType;
  final Stream<List<Campaign>>? campaignStream;
  @override
  State<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen> {
  late String type = widget.initialType;
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Campaign>>(
    stream:
        widget.campaignStream ??
        MerchantRepository.instance.campaigns(
          widget.user.id,
          businessId: widget.business?.id,
        ),
    builder: (context, snapshot) {
      final campaigns = (snapshot.data ?? [])
          .where((item) => item.type == type)
          .toList();
      return Stack(
        fit: StackFit.expand,
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 44, 16, 170),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LqTitleBlock(
                  eyebrow: 'Merchant portal',
                  title: 'Campaigns &\nvouchers',
                ),
                if (widget.business != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.business!.name,
                    style: monoLabel.copyWith(color: LqColors.primary),
                  ),
                ],
                const SizedBox(height: 22),
                Center(
                  child: LqSegmentedControl<String>(
                    segments: const [
                      ('ad', 'Promotional ads'),
                      ('voucher', 'Vouchers'),
                    ],
                    selected: type,
                    onChanged: (value) => setState(() => type = value),
                  ),
                ),
                const SizedBox(height: 20),
                if (snapshot.hasError)
                  const LqCard(
                    child: Text(
                      'Could not load offers. Check your connection and reopen this page.',
                    ),
                  )
                else if (snapshot.connectionState == ConnectionState.waiting)
                  const LinearProgressIndicator()
                else if (campaigns.isEmpty)
                  LqCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: type == 'ad'
                              ? LqColors.primarySoft
                              : LqColors.greenSoft,
                          foregroundColor: LqColors.primary,
                          child: Icon(
                            type == 'ad'
                                ? Icons.auto_awesome_outlined
                                : Icons.confirmation_num_outlined,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          type == 'ad'
                              ? 'No promotional ads yet'
                              : 'No vouchers yet',
                          style: const TextStyle(
                            color: LqColors.primaryDark,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create the first ${type == 'ad' ? 'campaign' : 'voucher'} for ${widget.business?.name ?? 'this workspace'}.',
                          style: const TextStyle(
                            color: LqColors.muted,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...campaigns.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _CampaignCreativeCard(
                        campaign: item,
                        user: widget.user,
                        businessId: widget.business?.id ?? '',
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (widget.business?.active == true)
            Positioned(
              right: 16,
              bottom: 96,
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CampaignEditor(
                      user: widget.user,
                      businessId: widget.business?.id ?? '',
                      initialType: type,
                    ),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: Text(
                  type == 'ad' ? 'Create campaign' : 'Create voucher',
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// A campaign poster fills the creative area; the white area below is reserved
/// for live status and edit actions so campaign text remains readable.
class _CampaignCreativeCard extends StatelessWidget {
  const _CampaignCreativeCard({
    required this.campaign,
    required this.user,
    required this.businessId,
  });

  final Campaign campaign;
  final AppUser user;
  final String businessId;

  Color get _fallbackColor => switch (campaign.status) {
    'scheduled' => LqColors.peachSoft,
    'active' => LqColors.primarySoft,
    _ => const Color(0xFFF0F1F4),
  };

  @override
  Widget build(BuildContext context) => LqCard(
    color: Colors.white,
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 178,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: _fallbackColor),
              if (campaign.imageUrl != null)
                Image.network(
                  campaign.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.expand(),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x08FFFFFF), Color(0xB3FFFFFF)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.white,
                          foregroundColor: LqColors.primary,
                          child: Icon(
                            campaign.type == 'voucher'
                                ? (campaign.isWelcomeVoucher
                                    ? Icons.card_giftcard
                                    : (campaign.isSeasonalVoucher
                                        ? Icons.celebration_outlined
                                        : Icons.confirmation_num_outlined))
                                : Icons.auto_awesome_outlined,
                          ),
                        ),
                        if (campaign.type == 'voucher')
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: campaign.isWelcomeVoucher
                                  ? const Color(0xFFEFF6FF)
                                  : (campaign.isSeasonalVoucher
                                      ? const Color(0xFFFFF7ED)
                                      : const Color(0xFFF0FDF4)),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: campaign.isWelcomeVoucher
                                    ? const Color(0xFF93C5FD)
                                    : (campaign.isSeasonalVoucher
                                        ? const Color(0xFFFDBA74)
                                        : const Color(0xFF86EFAC)),
                              ),
                            ),
                            child: Text(
                              campaign.isWelcomeVoucher
                                  ? 'WELCOME'
                                  : (campaign.isSeasonalVoucher
                                      ? (campaign.seasonName?.isNotEmpty == true
                                          ? campaign.seasonName!.toUpperCase()
                                          : 'SEASONAL')
                                      : 'PROMO'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: campaign.isWelcomeVoucher
                                    ? const Color(0xFF1D4ED8)
                                    : (campaign.isSeasonalVoucher
                                        ? const Color(0xFFC2410C)
                                        : const Color(0xFF15803D)),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      campaign.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: LqColors.primaryDark,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      campaign.description.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: monoLabel.copyWith(color: LqColors.primaryDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const LqDashedDivider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      () {
                        final s = campaign.effectiveStatus;
                        final label =
                            '${s[0].toUpperCase()}${s.substring(1)}';
                        if (campaign.isExpired) {
                          return '$label · Ended ${DateFormat('d MMM').format(campaign.endDate)}';
                        }
                        if (campaign.isScheduled) {
                          return '$label · Starts ${DateFormat('d MMM').format(campaign.startDate)}';
                        }
                        return '$label · Ends ${DateFormat('d MMM').format(campaign.endDate)}';
                      }(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      campaign.type == 'ad'
                          ? '${campaign.views} views'
                          : '${campaign.views} views · ${campaign.claims} claims'
                            '${campaign.linkedAdId != null ? ' · 🔗 Linked Ad' : ''}',
                      style: monoLabel,
                    ),
                    if (campaign.type == 'voucher' &&
                        ((campaign.validDays != null &&
                                campaign.validDays!.isNotEmpty &&
                                campaign.validDays != 'All Days') ||
                            (campaign.effectiveHours != null &&
                                campaign.effectiveHours!.isNotEmpty) ||
                            (campaign.dailyQuota != null &&
                                campaign.dailyQuota! > 0))) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (campaign.validDays != null &&
                              campaign.validDays!.isNotEmpty &&
                              campaign.validDays != 'All Days')
                            _ControlBadge(
                              icon: Icons.calendar_month_outlined,
                              label: campaign.validDays!,
                              color: const Color(0xFF4F46E5),
                            ),
                          if (campaign.effectiveHours != null &&
                              campaign.effectiveHours!.isNotEmpty)
                            _ControlBadge(
                              icon: Icons.schedule,
                              label: campaign.effectiveHours!,
                              color: const Color(0xFFD97706),
                            ),
                          if (campaign.dailyQuota != null &&
                              campaign.dailyQuota! > 0)
                            _ControlBadge(
                              icon: Icons.bolt,
                              label: 'Cap: ${campaign.dailyQuota}/day',
                              color: const Color(0xFF059669),
                            ),
                        ],
                      ),
                    ],
                    if (campaign.type == 'ad') ...[
                      const SizedBox(height: 6),
                      StreamBuilder<List<Campaign>>(
                        stream: MerchantRepository.instance.campaigns(
                          user.id,
                          businessId: businessId.isNotEmpty
                              ? businessId
                              : campaign.businessId,
                        ),
                        builder: (context, snapshot) {
                          final attached = (snapshot.data ?? [])
                              .where(
                                (c) =>
                                    c.type == 'voucher' &&
                                    c.linkedAdId == campaign.id,
                              )
                              .toList();
                          if (attached.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${attached.length} ATTACHED VOUCHER${attached.length == 1 ? '' : 'S'}',
                              style: monoLabel.copyWith(
                                fontWeight: FontWeight.w700,
                                color: LqColors.primaryDark,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CampaignEditor(
                      user: user,
                      businessId: businessId,
                      campaign: campaign,
                    ),
                  ),
                ),
                child: const Text('Edit'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ControlBadge extends StatelessWidget {
  const _ControlBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );
}

class _ReviewMetricChip extends StatelessWidget {
  const _ReviewMetricChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: LqColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: LqColors.primaryDark),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  color: LqColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: LqColors.ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A small hint row shown below the Status dropdown in the campaign form.
/// Explains the effective status rule based on the selected date range.
class _StatusHintText extends StatelessWidget {
  const _StatusHintText({
    required this.status,
    required this.startDate,
    required this.endDate,
    this.type,
  });

  final String status;
  final DateTime startDate;
  final DateTime endDate;
  final String? type;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDay = DateTime(endDate.year, endDate.month, endDate.day);
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);

    String message;
    IconData icon;
    Color color;

    if (endDay.isBefore(today)) {
      message = 'This campaign has expired — extend the end date to make it active again.';
      icon = Icons.info_outline;
      color = LqColors.danger;
    } else if (startDay.isAfter(today)) {
      message = 'Campaign is scheduled and will automatically go live on ${DateFormat('d MMM yyyy').format(startDate)}.';
      icon = Icons.schedule;
      color = const Color(0xFFD97706);
    } else if (status == 'active') {
      message = 'Campaign is live. You can pause it by switching to Inactive.';
      icon = Icons.check_circle_outline;
      color = const Color(0xFF15803D);
    } else {
      message = type == 'ad'
          ? 'Campaign is paused. Attached vouchers will also be set to inactive.'
          : 'Campaign is paused. Switch to Active to make it live again.';
      icon = Icons.pause_circle_outline;
      color = LqColors.muted;
    }

    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            message,
            style: TextStyle(fontSize: 11, color: color, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class CampaignEditor extends StatefulWidget {
  const CampaignEditor({
    super.key,
    required this.user,
    this.businessId = '',
    this.campaign,
    this.initialType = 'ad',
    this.preLinkedAdId,
  });
  final AppUser user;
  final String businessId;
  final Campaign? campaign;
  final String initialType;
  final String? preLinkedAdId;

  @override
  State<CampaignEditor> createState() => _CampaignEditorState();
}

class _CampaignEditorState extends State<CampaignEditor> {
  final _form = GlobalKey<FormState>();
  int _currentStep = 0;

  late final _terms = TextEditingController(text: widget.campaign?.terms ?? '');
  late final _discount = TextEditingController(
    text: '${widget.campaign?.discountValue ?? 10}',
  );
  late final _minimum = TextEditingController(
    text: '${widget.campaign?.minimumSpend ?? 0}',
  );
  late final _quantity = TextEditingController(
    text: '${widget.campaign?.quantity ?? 100}',
  );
  late final _limit = TextEditingController(
    text: '${widget.campaign?.perCustomerLimit ?? 1}',
  );
  late String discountType = widget.campaign?.discountType ?? 'percentage';
  late String voucherType = widget.campaign?.voucherType == 'welcome'
      ? 'welcome'
      : 'promotional';
  late String validDays = widget.campaign?.validDays ?? 'All Days';
  late final _validHours = TextEditingController(
    text: widget.campaign?.validHours ?? widget.campaign?.redemptionHours ?? '',
  );
  late final _dailyQuota = TextEditingController(
    text: widget.campaign?.dailyQuota != null
        ? '${widget.campaign!.dailyQuota}'
        : '',
  );
  late String? linkedAdId = widget.campaign?.linkedAdId ?? widget.preLinkedAdId;
  late final _name = TextEditingController(text: widget.campaign?.name ?? '');
  late final _description = TextEditingController(
    text: widget.campaign?.description ?? '',
  );
  late String type = widget.campaign?.type ?? widget.initialType;
  late DateTime startDate = widget.campaign?.startDate ?? DateTime.now();
  late DateTime endDate =
      widget.campaign?.endDate ?? DateTime.now().add(const Duration(days: 30));
  late String status = Campaign.resolveStatus(
    rawStatus: widget.campaign?.status ?? 'active',
    startDate: startDate,
    endDate: endDate,
  );
  Uint8List? poster;
  String? extension;
  bool busy = false;
  final Set<String> _attachedVoucherIds = {};
  bool _initialVouchersLoaded = false;

  int get _totalSteps => type == 'voucher' ? 4 : 3;
  List<String> get _stepTitles => type == 'voucher'
      ? const [
          'Details',
          'Value & limits',
          'Rules & schedule',
          'Review & confirm',
        ]
      : const [
          'Details',
          'Schedule & vouchers',
          'Review & confirm',
        ];

  @override
  void initState() {
    super.initState();
    if (widget.campaign != null && type == 'ad') {
      final bizId = widget.businessId.isNotEmpty
          ? widget.businessId
          : widget.campaign?.businessId ?? '';
      if (bizId.isNotEmpty) {
        MerchantRepository.instance
            .campaigns(widget.user.id, businessId: bizId)
            .first
            .then((list) {
          if (mounted && !_initialVouchersLoaded && list.isNotEmpty) {
            final attached = list
                .where((c) =>
                    c.type == 'voucher' && c.linkedAdId == widget.campaign!.id)
                .map((c) => c.id)
                .toSet();
            if (attached.isNotEmpty) {
              setState(() {
                _attachedVoucherIds.addAll(attached);
                _initialVouchersLoaded = true;
              });
            }
          }
        }).catchError((_) {});
      }
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _description,
      _terms,
      _discount,
      _minimum,
      _quantity,
      _limit,
      _validHours,
      _dailyQuota,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LqPage(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LqBackButton(label: 'Back to campaigns'),
          LqTitleBlock(
            eyebrow: 'Merchant portal',
            title: widget.campaign == null
                ? (type == 'voucher' ? 'Create voucher' : 'Create campaign')
                : (type == 'voucher' ? 'Edit voucher' : 'Edit campaign'),
          ),
          const SizedBox(height: 20),
          LqCard(
            child: Form(
              key: _form,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StepProgressHeader(
                    currentStep: _currentStep,
                    stepTitles: _stepTitles,
                    onStepTapped: (index) => setState(() => _currentStep = index),
                  ),
                  if (_currentStep == 0) ..._buildStep0(),
                  if (_currentStep == 1 && type == 'voucher')
                    ..._buildStep1Voucher(),
                  if (_currentStep == 2 && type == 'voucher')
                    ..._buildStep2Voucher(),
                  if (_currentStep == 3 && type == 'voucher')
                    ..._buildReviewStepVoucher(),
                  if (_currentStep == 1 && type == 'ad') ..._buildStep1Ad(),
                  if (_currentStep == 2 && type == 'ad') ..._buildReviewStepAd(),
                  const SizedBox(height: 24),
                  _buildNavigationButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  List<Widget> _buildStep0() {
    return [
      const Text(
        '1 · Offer details',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 12),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'ad', label: Text('Promotional ad')),
          ButtonSegment(value: 'voucher', label: Text('Voucher')),
        ],
        selected: {type},
        onSelectionChanged: (value) => setState(() {
          type = value.first;
          if (_currentStep >= _totalSteps) {
            _currentStep = _totalSteps - 1;
          }
        }),
      ),
      const SizedBox(height: 20),
      InkWell(
        onTap: busy ? null : _pickPoster,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 160,
          width: double.infinity,
          decoration: BoxDecoration(
            color: LqColors.field,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: LqColors.primary),
          ),
          child: poster == null && widget.campaign?.imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(19),
                  child: Image.network(
                    widget.campaign!.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stack) => const Center(
                      child: Text('Poster unavailable. Tap to replace.'),
                    ),
                  ),
                )
              : poster == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.upload_file, color: LqColors.primary),
                    const SizedBox(height: 8),
                    Text(
                      type == 'voucher'
                          ? 'Upload voucher banner'
                          : 'Upload campaign banner',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Text(
                      'JPG, PNG, WEBP · under 5 MB · 16:9',
                      style: TextStyle(color: LqColors.muted, fontSize: 11),
                    ),
                  ],
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(19),
                  child: Image.memory(poster!, fit: BoxFit.cover),
                ),
        ),
      ),
      if (poster != null) ...[
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: busy
                ? null
                : () => setState(() {
                    poster = null;
                    extension = null;
                  }),
            child: const Text('Discard selected image'),
          ),
        ),
      ],
      const SizedBox(height: 18),
      LqField(
        controller: _name,
        label: type == 'ad' ? 'Campaign name' : 'Voucher name',
        validator: (value) => MerchantValidation.text(value, 'Name', 3, 80),
      ),
      const SizedBox(height: 16),
      LqField(
        controller: _description,
        label: 'Description',
        maxLines: 4,
        validator: (value) =>
            MerchantValidation.text(value, 'Description', 20, 1500),
      ),
      if (type == 'voucher') ...[
        const SizedBox(height: 20),
        const Text(
          'Voucher category',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'welcome',
              label: Text('Welcome'),
              icon: Icon(Icons.card_giftcard),
            ),
            ButtonSegment(
              value: 'promotional',
              label: Text('Promo'),
              icon: Icon(Icons.local_offer_outlined),
            ),
          ],
          selected: {voucherType},
          onSelectionChanged: (value) {
            final selected = value.first;
            setState(() {
              voucherType = selected;
              if (selected == 'welcome') {
                _limit.text = '1';
              }
            });
          },
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: voucherType == 'welcome'
                ? const Color(0xFFEFF6FF)
                : const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: voucherType == 'welcome'
                  ? const Color(0xFFBFDBFE)
                  : const Color(0xFFBBF7D0),
            ),
          ),
          child: Row(
            children: [
              Icon(
                voucherType == 'welcome'
                    ? Icons.auto_awesome
                    : Icons.storefront,
                size: 20,
                color: voucherType == 'welcome'
                    ? const Color(0xFF1D4ED8)
                    : const Color(0xFF15803D),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  voucherType == 'welcome'
                      ? 'Welcome voucher: 1-time gift for tourists discovering your business on the map or business page.'
                      : 'Promotional voucher: Standard or seasonal discount offer collectible via GPS walk-up or in-app.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: voucherType == 'welcome'
                        ? const Color(0xFF1E40AF)
                        : const Color(0xFF166534),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<Campaign>>(
          stream: MerchantRepository.instance.campaigns(
            widget.user.id,
            businessId: widget.businessId.isNotEmpty
                ? widget.businessId
                : widget.campaign?.businessId,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            final ads = (snapshot.data ?? [])
                .where((c) => c.type == 'ad' && c.effectiveStatus != 'inactive')
                .toList();
            if (ads.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: LqColors.field,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: LqColors.line),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: LqColors.muted),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No active or scheduled ad campaigns found for this business. You can create an ad campaign later and attach this voucher to it.',
                        style: TextStyle(fontSize: 12, color: LqColors.muted),
                      ),
                    ),
                  ],
                ),
              );
            }
            final selectedAd =
                ads.where((a) => a.id == linkedAdId).firstOrNull;
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                final options = <(String?, String)>[
                  (null, 'None (Standalone voucher)'),
                  ...ads.map((ad) => (ad.id as String?, '${ad.name} (${ad.effectiveStatus.toUpperCase()})')),
                ];
                final chosen = await showLqSelectionSheet<String?>(
                  context,
                  title: 'Link to ad campaign',
                  options: options,
                  selected: linkedAdId,
                );
                setState(() => linkedAdId = chosen);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Link to ad campaign (Optional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: LqColors.line),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            selectedAd != null
                                ? '${selectedAd.name} (${selectedAd.effectiveStatus.toUpperCase()})'
                                : 'None (Standalone voucher)',
                            style: TextStyle(
                              fontSize: 14,
                              color: selectedAd != null
                                  ? LqColors.primaryDark
                                  : LqColors.muted,
                              fontWeight: selectedAd != null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          Icons.arrow_drop_down,
                          color: LqColors.muted,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    ];
  }

  List<Widget> _buildStep1Voucher() {
    return [
      const Text(
        '2 · Voucher value & limits',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 16),
      LqDropdownField(
        label: 'Discount type',
        value: discountType,
        items: const ['percentage', 'fixed'],
        onChanged: (value) =>
            setState(() => discountType = value ?? 'percentage'),
      ),
      const SizedBox(height: 16),
      LqField(
        controller: _discount,
        label: discountType == 'percentage'
            ? 'Discount (%)'
            : 'Discount (RM)',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (value) => MerchantValidation.amount(
          value,
          percentage: discountType == 'percentage',
        ),
      ),
      const SizedBox(height: 16),
      LqField(
        controller: _minimum,
        label: 'Minimum spend (RM)',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (value) => MerchantValidation.amount(value, zero: true),
      ),
      const SizedBox(height: 16),
      LqField(
        controller: _quantity,
        label: 'Total vouchers available',
        keyboardType: TextInputType.number,
        validator: MerchantValidation.quantity,
      ),
      const SizedBox(height: 16),
      LqField(
        controller: _limit,
        label: 'Limit per customer',
        hint: voucherType == 'welcome'
            ? 'Locked to 1 for Welcome vouchers'
            : null,
        readOnly: voucherType == 'welcome',
        keyboardType: TextInputType.number,
        validator: MerchantValidation.quantity,
      ),
    ];
  }

  List<Widget> _buildStep2Voucher() {
    return [
      const Text(
        '3 · Redemption rules & schedule',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 16),
      LqDropdownField(
        label: 'Valid days',
        value: validDays,
        items: const [
          'All Days',
          'Weekdays (Mon–Fri)',
          'Weekends (Sat–Sun)',
        ],
        onChanged: (value) => setState(() => validDays = value ?? 'All Days'),
      ),
      const SizedBox(height: 16),
      LqField(
        controller: _validHours,
        label: 'Valid operating hours (Optional)',
        hint: 'e.g. 2:00 PM – 5:00 PM (Off-peak) or All Day',
      ),
      const SizedBox(height: 16),
      LqField(
        controller: _dailyQuota,
        label: 'Daily redemption quota (Optional)',
        hint: 'e.g. 25 vouchers/day',
        keyboardType: TextInputType.number,
      ),
      const SizedBox(height: 16),
      LqField(
        controller: _terms,
        label: 'Terms & conditions',
        maxLines: 3,
        hint: 'Eligibility, exclusions and how to redeem at this business.',
        validator: (value) => MerchantValidation.text(value, 'Terms', 10, 2000),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: _DateButton(
              label: 'Start date',
              date: startDate,
              onTap: () => _date(true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _DateButton(
              label: 'End date',
              date: endDate,
              onTap: () => _date(false),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      LqDropdownField(
        label: 'Status',
        value: status,
        items: _availableStatuses,
        onChanged: (value) {
          if (value != null) setState(() => status = value);
        },
      ),
      const SizedBox(height: 6),
      _StatusHintText(
        status: status,
        startDate: startDate,
        endDate: endDate,
        type: type,
      ),
    ];
  }

  List<Widget> _buildStep1Ad() {
    final effectiveBizId = widget.businessId.isNotEmpty
        ? widget.businessId
        : (widget.campaign?.businessId ?? '');

    return [
      const Text(
        '2 · Schedule & attached vouchers',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 16),
      LqField(
        controller: _terms,
        label: 'Terms & conditions',
        maxLines: 3,
        hint: 'Eligibility, campaign rules and highlights.',
        validator: (value) => MerchantValidation.text(value, 'Terms', 10, 2000),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: _DateButton(
              label: 'Start date',
              date: startDate,
              onTap: () => _date(true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _DateButton(
              label: 'End date',
              date: endDate,
              onTap: () => _date(false),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      LqDropdownField(
        label: 'Status',
        value: status,
        items: _availableStatuses,
        onChanged: (value) {
          if (value != null) setState(() => status = value);
        },
      ),
      const SizedBox(height: 6),
      _StatusHintText(
        status: status,
        startDate: startDate,
        endDate: endDate,
        type: type,
      ),
      const SizedBox(height: 20),
      const Divider(color: LqColors.line),
      const SizedBox(height: 12),
      const Text(
        'Attached vouchers (Optional)',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      const Text(
        'Select which shop vouchers will be showcased and promoted within this ad.',
        style: TextStyle(fontSize: 12, color: LqColors.muted),
      ),
      const SizedBox(height: 12),
      StreamBuilder<List<Campaign>>(
        stream: MerchantRepository.instance.campaigns(
          widget.user.id,
          businessId: effectiveBizId.isNotEmpty ? effectiveBizId : null,
        ),
        builder: (context, snapshot) {
          final allCampaigns = snapshot.data ?? [];
          final vouchers =
              allCampaigns.where((c) => c.type == 'voucher').toList();

          if (!_initialVouchersLoaded && snapshot.hasData && snapshot.data != null) {
            if (widget.campaign != null) {
              final preAttached = vouchers
                  .where((c) => c.linkedAdId == widget.campaign!.id)
                  .map((c) => c.id)
                  .toSet();
              _attachedVoucherIds.addAll(preAttached);
            }
            _initialVouchersLoaded = true;
          }

          if (vouchers.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: LqColors.field,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: LqColors.line),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: LqColors.muted),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No vouchers found for this business yet. You can create a voucher later and link it to this campaign.',
                      style: TextStyle(fontSize: 12, color: LqColors.muted),
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: vouchers.map((v) {
              final isChecked = _attachedVoucherIds.contains(v.id);
              final isLinkedOther = v.linkedAdId != null &&
                  v.linkedAdId!.isNotEmpty &&
                  v.linkedAdId != widget.campaign?.id;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isChecked ? LqColors.primarySoft : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isChecked ? LqColors.primary : LqColors.line,
                  ),
                ),
                child: CheckboxListTile(
                  dense: true,
                  value: isChecked,
                  activeColor: LqColors.primaryDark,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _attachedVoucherIds.add(v.id);
                      } else {
                        _attachedVoucherIds.remove(v.id);
                      }
                    });
                  },
                  title: Text(
                    v.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isChecked ? LqColors.primaryDark : LqColors.ink,
                    ),
                  ),
                  subtitle: Text(
                    '${v.discountValue.toStringAsFixed(0)}${v.discountType == 'percentage' ? '%' : ' RM'} off · Min RM ${v.minimumSpend.toStringAsFixed(0)} · ${v.voucherType == 'welcome' ? 'Welcome' : 'Promo'}${isLinkedOther ? ' (Linked to another ad)' : ''}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isLinkedOther
                          ? const Color(0xFFC2410C)
                          : LqColors.muted,
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    ];
  }

  List<Widget> _buildReviewStepVoucher() {
    return [
      const Text(
        '4 · Review & confirm',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      const Text(
        'Review your voucher summary and redemption terms before confirming.',
        style: TextStyle(fontSize: 13, color: LqColors.muted),
      ),
      const SizedBox(height: 16),
      Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: LqColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (poster != null)
              SizedBox(
                height: 160,
                width: double.infinity,
                child: Image.memory(
                  poster!,
                  fit: BoxFit.cover,
                ),
              )
            else if (widget.campaign?.imageUrl != null)
              SizedBox(
                height: 160,
                width: double.infinity,
                child: Image.network(
                  widget.campaign!.imageUrl!,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 120,
                width: double.infinity,
                color: LqColors.primarySoft,
                alignment: Alignment.center,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.confirmation_num_outlined,
                      color: LqColors.primaryDark,
                      size: 36,
                    ),
                    SizedBox(height: 6),
                    Text(
                      'No poster uploaded',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: LqColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _ControlBadge(
                        icon: voucherType == 'welcome'
                            ? Icons.auto_awesome
                            : Icons.local_offer_outlined,
                        label: voucherType == 'welcome'
                            ? 'WELCOME VOUCHER'
                            : 'PROMOTIONAL VOUCHER',
                        color: voucherType == 'welcome'
                            ? const Color(0xFF1D4ED8)
                            : const Color(0xFF15803D),
                      ),
                      _ControlBadge(
                        icon: status == 'active'
                            ? Icons.check_circle_outline
                            : (status == 'scheduled'
                                ? Icons.schedule
                                : Icons.pause_circle_outline),
                        label: status.toUpperCase(),
                        color: status == 'active'
                            ? const Color(0xFF15803D)
                            : const Color(0xFFB45309),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _name.text.trim().isEmpty
                        ? 'Unnamed Voucher'
                        : _name.text.trim(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _description.text.trim(),
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: LqColors.line),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _ReviewMetricChip(
                        label: 'Discount',
                        value:
                            '${_discount.text}${discountType == 'percentage' ? '%' : ' RM'} OFF',
                        icon: Icons.percent,
                      ),
                      _ReviewMetricChip(
                        label: 'Min spend',
                        value:
                            'RM ${_minimum.text.isEmpty ? '0' : _minimum.text}',
                        icon: Icons.shopping_bag_outlined,
                      ),
                      _ReviewMetricChip(
                        label: 'Total supply',
                        value: '${_quantity.text} vouchers',
                        icon: Icons.layers_outlined,
                      ),
                      _ReviewMetricChip(
                        label: 'Per customer',
                        value:
                            '${voucherType == 'welcome' ? '1' : _limit.text} max',
                        icon: Icons.person_outline,
                      ),
                    ],
                  ),
                  if (validDays != 'All Days' ||
                      _validHours.text.trim().isNotEmpty ||
                      _dailyQuota.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.storefront_outlined,
                          size: 14,
                          color: LqColors.muted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Merchant Controls: $validDays'
                            '${_validHours.text.trim().isNotEmpty ? ' · ${_validHours.text.trim()}' : ''}'
                            '${_dailyQuota.text.trim().isNotEmpty ? ' · Daily quota: ${_dailyQuota.text.trim()}' : ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: LqColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: LqColors.muted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Validity: ${DateFormat('d MMM yyyy').format(startDate)} – ${DateFormat('d MMM yyyy').format(endDate)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: LqColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: LqColors.line),
                  const SizedBox(height: 8),
                  const Text(
                    'Terms & conditions',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _terms.text.trim(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: LqColors.muted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 18,
              color: Color(0xFF15803D),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ready to publish. Tap below to confirm and activate this voucher.',
                style: TextStyle(fontSize: 12, color: Color(0xFF166534)),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildReviewStepAd() {
    return [
      const Text(
        '3 · Review & confirm',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      const Text(
        'Review your promotional campaign before confirming and publishing.',
        style: TextStyle(fontSize: 13, color: LqColors.muted),
      ),
      const SizedBox(height: 16),
      Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: LqColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (poster != null)
              SizedBox(
                height: 160,
                width: double.infinity,
                child: Image.memory(
                  poster!,
                  fit: BoxFit.cover,
                ),
              )
            else if (widget.campaign?.imageUrl != null)
              SizedBox(
                height: 160,
                width: double.infinity,
                child: Image.network(
                  widget.campaign!.imageUrl!,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 120,
                width: double.infinity,
                color: LqColors.primarySoft,
                alignment: Alignment.center,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.campaign_outlined,
                      color: LqColors.primaryDark,
                      size: 36,
                    ),
                    SizedBox(height: 6),
                    Text(
                      'No poster uploaded',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: LqColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      const _ControlBadge(
                        icon: Icons.campaign_outlined,
                        label: 'PROMOTIONAL AD',
                        color: Color(0xFF1D4ED8),
                      ),
                      _ControlBadge(
                        icon: status == 'active'
                            ? Icons.check_circle_outline
                            : (status == 'scheduled'
                                ? Icons.schedule
                                : Icons.pause_circle_outline),
                        label: status.toUpperCase(),
                        color: status == 'active'
                            ? const Color(0xFF15803D)
                            : const Color(0xFFB45309),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _name.text.trim().isEmpty
                        ? 'Unnamed Campaign'
                        : _name.text.trim(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _description.text.trim(),
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: LqColors.line),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: LqColors.muted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Duration: ${DateFormat('d MMM yyyy').format(startDate)} – ${DateFormat('d MMM yyyy').format(endDate)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: LqColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.confirmation_num_outlined,
                        size: 14,
                        color: LqColors.muted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Attached vouchers: ${_attachedVoucherIds.length} selected',
                          style: const TextStyle(
                            fontSize: 12,
                            color: LqColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: LqColors.line),
                  const SizedBox(height: 8),
                  const Text(
                    'Terms & conditions',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _terms.text.trim(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: LqColors.muted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 18,
              color: Color(0xFF15803D),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ready to publish. Tap below to confirm and launch this campaign.',
                style: TextStyle(fontSize: 12, color: Color(0xFF166534)),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildNavigationButtons() {
    final isLastStep = _currentStep == _totalSteps - 1;
    String nextLabel;
    if (_currentStep == 0) {
      nextLabel = type == 'voucher'
          ? 'Next: Value & limits'
          : 'Next: Schedule & vouchers';
    } else if (_currentStep == 1 && type == 'voucher') {
      nextLabel = 'Next: Rules & schedule';
    } else if ((_currentStep == 2 && type == 'voucher') ||
        (_currentStep == 1 && type == 'ad')) {
      nextLabel = 'Next: Review & confirm';
    } else {
      nextLabel = type == 'voucher'
          ? 'Confirm & save voucher'
          : 'Confirm & save campaign';
    }

    return Column(
      children: [
        Row(
          children: [
            if (_currentStep > 0) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : () => setState(() => _currentStep--),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Previous'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: LqButton(
                label: nextLabel,
                busy: busy,
                icon: isLastStep
                    ? Icons.check_circle_outline
                    : Icons.arrow_forward,
                onPressed: () {
                  if (_currentStep == 0) {
                    if (_validateStep0()) {
                      setState(() => _currentStep++);
                    }
                  } else if (_currentStep == 1 && type == 'voucher') {
                    if (_validateStep1Voucher()) {
                      setState(() => _currentStep++);
                    }
                  } else if (_currentStep == 1 && type == 'ad') {
                    if (_validateStep1Ad()) {
                      setState(() => _currentStep++);
                    }
                  } else if (_currentStep == 2 && type == 'voucher') {
                    if (_validateStep2Voucher()) {
                      setState(() => _currentStep++);
                    }
                  } else {
                    _save();
                  }
                },
              ),
            ),
          ],
        ),
        if (widget.campaign != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy ? null : _delete,
            icon: const Icon(Icons.delete_outline),
            label: Text(
              type == 'voucher' ? 'Delete voucher' : 'Delete campaign',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: LqColors.danger,
              side: const BorderSide(color: LqColors.danger),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickPoster() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        imageQuality: 90,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final format = MerchantValidation.imageType(bytes);
      if (!mounted) return;
      if (format == null) {
        showLqMessage(
          context,
          'Choose a JPG, PNG or WEBP image smaller than 5 MB.',
          error: true,
        );
        return;
      }
      final croppedBytes = await cropImageFile(
        context: context,
        sourcePath: file.path,
        aspectRatioX: 16.0,
        aspectRatioY: 9.0,
        lockAspectRatio: true,
        title: type == 'voucher' ? 'Crop Voucher Banner' : 'Crop Campaign Banner',
      );
      if (croppedBytes == null || !mounted) return;
      setState(() {
        poster = croppedBytes;
        extension = 'png';
      });
    } catch (_) {
      if (mounted) {
        showLqMessage(
          context,
          'Could not open that image. Try another photo.',
          error: true,
        );
      }
    }
  }

  Future<void> _date(bool start) async {
    final initial = start ? startDate : endDate;
    final value = await showLqDatePicker(
      context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDate: initial,
      title: start ? 'Campaign start date' : 'Campaign end date',
    );
    if (value != null) {
      setState(() {
        if (start) {
          startDate = value;
        } else {
          endDate = value;
        }
        _autoAdjustStatus();
      });
    }
  }

  /// Automatically adjusts [status] to match the currently selected
  /// [startDate] and [endDate]. Called whenever either date is changed.
  void _autoAdjustStatus() {
    status = Campaign.resolveStatus(
      rawStatus: status,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Returns the list of statuses available to the merchant given the
  /// currently selected date range.
  ///
  /// - Expired (endDate in the past): only `inactive`.
  /// - Future start (startDate after today): `scheduled` or `inactive`.
  /// - Active window: `active` or `inactive`.
  List<String> get _availableStatuses {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDay = DateTime(endDate.year, endDate.month, endDate.day);
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);

    if (endDay.isBefore(today)) return const ['inactive'];
    if (startDay.isAfter(today)) return const ['scheduled', 'inactive'];
    return const ['active', 'inactive'];
  }

  bool _validateStep0() {
    if (_currentStep == 0) {
      return _form.currentState?.validate() ?? false;
    }
    final nameErr = MerchantValidation.text(_name.text, 'Name', 3, 80);
    if (nameErr != null) {
      showLqMessage(context, nameErr, error: true);
      return false;
    }
    final descErr =
        MerchantValidation.text(_description.text, 'Description', 20, 1500);
    if (descErr != null) {
      showLqMessage(context, descErr, error: true);
      return false;
    }
    return true;
  }

  bool _validateStep1Voucher() {
    if (_currentStep == 1 && !(_form.currentState?.validate() ?? false)) {
      return false;
    }
    final discountErr = MerchantValidation.amount(
      _discount.text,
      percentage: discountType == 'percentage',
    );
    if (discountErr != null) {
      showLqMessage(context, discountErr, error: true);
      return false;
    }
    final minErr = MerchantValidation.amount(_minimum.text, zero: true);
    if (minErr != null) {
      showLqMessage(context, minErr, error: true);
      return false;
    }
    final qtyErr = MerchantValidation.quantity(_quantity.text);
    if (qtyErr != null) {
      showLqMessage(context, qtyErr, error: true);
      return false;
    }
    final limErr = MerchantValidation.quantity(_limit.text);
    if (limErr != null) {
      showLqMessage(context, limErr, error: true);
      return false;
    }
    final qty = int.tryParse(_quantity.text) ?? 0;
    final lim = int.tryParse(_limit.text) ?? 0;
    if (lim > qty) {
      showLqMessage(
        context,
        'The per-customer limit cannot exceed the total quantity.',
        error: true,
      );
      return false;
    }
    final claims = widget.campaign?.claims ?? 0;
    if (qty < claims) {
      showLqMessage(
        context,
        'Quantity cannot be lower than vouchers already claimed ($claims).',
        error: true,
      );
      return false;
    }
    return true;
  }

  bool _validateStep1Ad() {
    if (_currentStep == 1 && !(_form.currentState?.validate() ?? false)) {
      return false;
    }
    final termsErr = MerchantValidation.text(_terms.text, 'Terms', 10, 2000);
    if (termsErr != null) {
      showLqMessage(context, termsErr, error: true);
      return false;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDay = DateTime(endDate.year, endDate.month, endDate.day);
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    // End date must be on or after start date, and must not have already passed
    if (endDay.isBefore(startDay) || endDay.isBefore(today)) {
      showLqMessage(
        context,
        'The end date must be today or later and on or after the start date.',
        error: true,
      );
      return false;
    }
    // The resolved status should not contradict the date range.
    // _autoAdjustStatus() is called on every date change so this is defensive.
    final resolved = Campaign.resolveStatus(
      rawStatus: status,
      startDate: startDate,
      endDate: endDate,
    );
    if (resolved != status) {
      setState(() => status = resolved);
    }
    return true;
  }

  bool _validateStep2Voucher() {
    if (_currentStep == 2 && !(_form.currentState?.validate() ?? false)) {
      return false;
    }
    final termsErr = MerchantValidation.text(_terms.text, 'Terms', 10, 2000);
    if (termsErr != null) {
      showLqMessage(context, termsErr, error: true);
      return false;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDay = DateTime(endDate.year, endDate.month, endDate.day);
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    // End date must be on or after start date, and must not have already passed
    if (endDay.isBefore(startDay) || endDay.isBefore(today)) {
      showLqMessage(
        context,
        'The end date must be today or later and on or after the start date.',
        error: true,
      );
      return false;
    }
    // The resolved status should not contradict the date range.
    final resolved = Campaign.resolveStatus(
      rawStatus: status,
      startDate: startDate,
      endDate: endDate,
    );
    if (resolved != status) {
      setState(() => status = resolved);
    }
    return true;
  }

  Future<void> _save() async {
    if (busy) return;
    if (!_validateStep0()) {
      setState(() => _currentStep = 0);
      return;
    }
    if (type == 'voucher') {
      if (!_validateStep1Voucher()) {
        setState(() => _currentStep = 1);
        return;
      }
      if (!_validateStep2Voucher()) {
        setState(() => _currentStep = 2);
        return;
      }
    } else {
      if (!_validateStep1Ad()) {
        setState(() => _currentStep = 1);
        return;
      }
    }

    setState(() => busy = true);
    final existing = widget.campaign;
    final targetBizId = existing?.businessId.isNotEmpty == true
        ? existing!.businessId
        : widget.businessId;

    try {
      final savedId = await MerchantRepository.instance.saveCampaign(
        Campaign(
          id: existing?.id ?? '',
          ownerId: widget.user.id,
          businessId: targetBizId,
          name: _name.text.trim(),
          description: _description.text.trim(),
          type: type,
          startDate: startDate,
          endDate: endDate,
          status: status,
          views: existing?.views ?? 0,
          claims: existing?.claims ?? 0,
          imageUrl: existing?.imageUrl,
          terms: _terms.text.trim(),
          discountType: discountType,
          discountValue:
              type == 'voucher' ? (double.tryParse(_discount.text) ?? 0) : 0,
          minimumSpend:
              type == 'voucher' ? (double.tryParse(_minimum.text) ?? 0) : 0,
          quantity:
              type == 'voucher' ? (int.tryParse(_quantity.text) ?? 0) : 0,
          perCustomerLimit: type == 'voucher'
              ? (voucherType == 'welcome'
                  ? 1
                  : (int.tryParse(_limit.text) ?? 1))
              : 1,
          voucherType: type == 'voucher' ? voucherType : 'promotional',
          collectionMethod: type == 'voucher'
              ? (voucherType == 'welcome' ? 'discovery_claim' : 'both')
              : 'both',
          seasonName: null,
          linkedAdId: type == 'voucher' &&
                  linkedAdId != null &&
                  linkedAdId!.isNotEmpty
              ? linkedAdId
              : null,
          validDays: type == 'voucher' ? validDays : null,
          validHours: type == 'voucher' && _validHours.text.trim().isNotEmpty
              ? _validHours.text.trim()
              : null,
          redemptionHours:
              type == 'voucher' && _validHours.text.trim().isNotEmpty
                  ? _validHours.text.trim()
                  : null,
          dailyQuota: type == 'voucher' && _dailyQuota.text.trim().isNotEmpty
              ? int.tryParse(_dailyQuota.text.trim())
              : null,
        ),
        posterBytes: poster,
        posterExtension: extension,
      );

      if (type == 'ad' && targetBizId.isNotEmpty) {
        final isAdInactive = Campaign.resolveStatus(
              rawStatus: status,
              startDate: startDate,
              endDate: endDate,
            ) ==
            'inactive';
        await MerchantRepository.instance.attachVouchersToAd(
          savedId,
          _attachedVoucherIds,
          targetBizId,
          isAdInactive: isAdInactive,
        );
      }

      if (mounted) {
        showLqMessage(
          context,
          type == 'voucher'
              ? 'Voucher saved successfully.'
              : 'Campaign saved successfully.',
        );
        Navigator.pop(context);
      }
    } on LocalQuestException catch (error) {
      if (mounted) {
        showLqMessage(context, error.message, error: true);
        setState(() => busy = false);
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        showLqMessage(
          context,
          error.code == 'permission-denied'
              ? 'You do not have permission to save this offer for that business.'
              : 'Could not save this offer. Check your connection and retry.',
          error: true,
        );
        setState(() => busy = false);
      }
    }
  }

  Future<void> _delete() async {
    final campaign = widget.campaign;
    if (campaign == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(type == 'voucher' ? 'Delete voucher?' : 'Delete campaign?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: LqColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      await MerchantRepository.instance.deleteCampaign(campaign.id);
      if (mounted) Navigator.pop(context);
    } on FirebaseException catch (error) {
      if (mounted) {
        showLqMessage(
          context,
          error.message ?? 'Could not delete this item.',
          error: true,
        );
        setState(() => busy = false);
      }
    }
  }
}

class _StepProgressHeader extends StatelessWidget {
  const _StepProgressHeader({
    required this.currentStep,
    required this.stepTitles,
    this.onStepTapped,
  });

  final int currentStep;
  final List<String> stepTitles;
  final ValueChanged<int>? onStepTapped;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(stepTitles.length, (index) {
            final isCompleted = index < currentStep;
            final isCurrent = index == currentStep;
            return Expanded(
              child: InkWell(
                onTap: isCompleted && onStepTapped != null
                    ? () => onStepTapped!(index)
                    : null,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index < stepTitles.length - 1 ? 8.0 : 0.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: isCurrent || isCompleted
                              ? LqColors.primary
                              : LqColors.line,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${index + 1}. ${stepTitles[index]}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isCurrent ? FontWeight.w800 : FontWeight.w600,
                          color: isCurrent
                              ? LqColors.primaryDark
                              : (isCompleted ? LqColors.ink : LqColors.muted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.date,
    required this.onTap,
  });
  final String label;
  final DateTime date;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Text(DateFormat('d MMM yyyy').format(date)),
    ),
  );
}

class MerchantProfile extends StatelessWidget {
  const MerchantProfile({
    super.key,
    required this.user,
    this.businesses = const [],
    this.selectedBusiness,
    this.onBusinessSelected,
    this.openAds,
    this.openVouchers,
  });
  final AppUser user;
  final List<Business> businesses;
  final Business? selectedBusiness;
  final ValueChanged<String?>? onBusinessSelected;
  final VoidCallback? openAds;
  final VoidCallback? openVouchers;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 44, 16, 116),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const LqTitleBlock(eyebrow: 'Merchant account', title: 'Profile'),
            IconButton.filledTonal(
              tooltip: 'Settings',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SettingsScreen(user: user)),
              ),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        const SizedBox(height: 26),
        InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AccountDetailsScreen(user: user)),
          ),
          child: LqCard(
            color: LqColors.primarySoft,
            child: Row(
              children: [
                LqAvatar(
                  radius: 34,
                  initials: initialsFor(user.displayName),
                  photoUrl: user.photoUrl,
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
                      if (user.username.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          user.username.startsWith('@')
                              ? user.username
                              : '@${user.username}',
                          style: const TextStyle(
                            color: LqColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: const TextStyle(
                          color: LqColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: LqColors.primary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('BUSINESS', style: monoLabel),
        const SizedBox(height: 8),
        _BusinessSelector(
          user: user,
          businesses: businesses,
          selectedBusiness: selectedBusiness,
          onSelected: onBusinessSelected,
        ),
        const SizedBox(height: 22),
        LqCard(
          child: Column(
            children: [
              _MerchantProfileAction(
                icon: Icons.qr_code_scanner_outlined,
                label: 'Redeem a voucher',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MerchantRedeemVoucherScreen(merchant: user),
                  ),
                ),
              ),
              _MerchantProfileAction(
                icon: Icons.auto_awesome_outlined,
                label: 'Ads',
                onTap: openAds ?? () {},
              ),
              _MerchantProfileAction(
                icon: Icons.confirmation_num_outlined,
                label: 'Vouchers',
                onTap: openVouchers ?? () {},
              ),
              _MerchantProfileAction(
                icon: Icons.business_outlined,
                label: 'Business registrations',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BusinessRegistrationsScreen(user: user),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        LqLogoutButton(
          onPressed: () =>
              confirmLqSignOut(context, AuthService.instance.signOut),
        ),
      ],
    ),
  );
}

class _BusinessSelector extends StatelessWidget {
  const _BusinessSelector({
    required this.user,
    required this.businesses,
    this.selectedBusiness,
    this.onSelected,
  });
  final AppUser user;
  final List<Business> businesses;
  final Business? selectedBusiness;
  final ValueChanged<String?>? onSelected;

  Future<void> _showWorkspaceSheet(BuildContext context) async {
    final currentId = selectedBusiness?.id ?? (businesses.isNotEmpty ? businesses.first.id : '');
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: const BoxDecoration(
          color: LqColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: LqColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Choose business workspace',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Switch active location or register a new business workspace.',
              style: TextStyle(fontSize: 12, color: LqColors.muted),
            ),
            const SizedBox(height: 14),
            ...businesses.map((b) {
              final isCurrent = b.id == currentId;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isCurrent ? LqColors.primarySoft : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isCurrent ? LqColors.primary : LqColors.line,
                    width: isCurrent ? 1.5 : 1,
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isCurrent ? LqColors.primary : const Color(0xFFF0F4FC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.storefront_outlined,
                      color: isCurrent ? Colors.white : LqColors.primary,
                      size: 20,
                    ),
                  ),
                  title: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      Text(
                        b.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isCurrent ? LqColors.primaryDark : Colors.black87,
                        ),
                      ),
                      if (b.isSsmVerified)
                        const SsmVerifiedBadge(compact: true),
                    ],
                  ),
                  subtitle: Text(
                    b.area.isNotEmpty ? b.area : b.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: LqColors.muted),
                  ),
                  trailing: isCurrent
                      ? const Icon(Icons.check_circle, color: LqColors.primary, size: 20)
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    onSelected?.call(b.id);
                  },
                ),
              );
            }),
            const SizedBox(height: 6),
            const LqDashedDivider(),
            const SizedBox(height: 6),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              tileColor: Colors.white,
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: LqColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.add_business_outlined,
                  color: LqColors.primary,
                  size: 20,
                ),
              ),
              title: const Text(
                'Create new business workspace',
                style: TextStyle(fontWeight: FontWeight.w800, color: LqColors.primary),
              ),
              subtitle: const Text(
                'Register a new branch or business profile',
                style: TextStyle(fontSize: 11, color: LqColors.muted),
              ),
              trailing: const Icon(Icons.chevron_right, color: LqColors.primary),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => BusinessEditor(user: user)),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
  }

  @override
  Widget build(BuildContext context) {
    if (businesses.isEmpty) {
      return InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BusinessEditor(user: user)),
        ),
        child: LqCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FC),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.storefront_outlined,
                  color: LqColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Manage workspace for',
                      style: TextStyle(color: LqColors.muted, fontSize: 11),
                    ),
                    Text(
                      user.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.add_rounded, color: LqColors.primary),
            ],
          ),
        ),
      );
    }
    return InkWell(
      borderRadius: BorderRadius.circular(25),
      onTap: () => _showWorkspaceSheet(context),
      child: LqCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FC),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.storefront_outlined,
                color: LqColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Manage workspace for',
                    style: TextStyle(color: LqColors.muted, fontSize: 11),
                  ),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      Text(
                        selectedBusiness?.name ?? businesses.first.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      if ((selectedBusiness ?? businesses.firstOrNull)?.isSsmVerified == true)
                        const SsmVerifiedBadge(compact: true),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: LqColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _MerchantProfileAction extends StatelessWidget {
  const _MerchantProfileAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
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
      child: Icon(icon, color: LqColors.primary, size: 22),
    ),
    title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    trailing: const Icon(Icons.chevron_right, color: LqColors.muted),
    onTap: onTap,
  );
}

class BusinessRegistrationsScreen extends StatelessWidget {
  const BusinessRegistrationsScreen({super.key, required this.user});
  final AppUser user;
  @override
  Widget build(BuildContext context) => LqPage(
    child: StreamBuilder<List<Business>>(
      stream: MerchantRepository.instance.businesses(user.id),
      builder: (context, snapshot) {
        final values = snapshot.data ?? [];
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LqBackButton(label: 'Back to profile'),
              const LqTitleBlock(
                eyebrow: 'Merchant workspace',
                title: 'Business registrations',
                subtitle:
                    'Manage the locations connected to your merchant account.',
              ),
              const SizedBox(height: 22),
              Expanded(
                child: values.isEmpty
                    ? const LqCard(
                        child: Center(
                          child: Text(
                            'No registered businesses.',
                            style: TextStyle(color: LqColors.muted),
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: values.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = values[index];
                          return LqCard(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0F4FC),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.storefront_outlined,
                                    color: LqColors.primary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.area.isNotEmpty
                                            ? item.area
                                            : item.address,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: LqColors.muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (item.isSsmVerified ||
                                              (item.dietaryStatus != null &&
                                                  item.dietaryStatus!.trim().isNotEmpty &&
                                                  lqIsDietaryCategory(item.category))) ...[
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              children: [
                                                if (item.isSsmVerified)
                                                  const SsmVerifiedBadge(
                                                    compact: true,
                                                  ),
                                                if (item.dietaryStatus != null &&
                                                    item.dietaryStatus!.trim().isNotEmpty &&
                                                    lqIsDietaryCategory(item.category))
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFE8F5E9),
                                                      borderRadius:
                                                          BorderRadius.circular(6),
                                                      border: Border.all(
                                                        color: const Color(0xFFA5D6A7),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(
                                                          Icons.restaurant_outlined,
                                                          size: 11,
                                                          color: Color(0xFF2E7D32),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          item.dietaryStatus!,
                                                          style: const TextStyle(
                                                            color: Color(0xFF2E7D32),
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 5),
                                          ],
                                          LqStatusPill(active: item.active),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    backgroundColor: const Color(0xFFEDF1F9),
                                    shape: const StadiumBorder(),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                  ),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => BusinessEditor(
                                        user: user,
                                        business: item,
                                      ),
                                    ),
                                  ),
                                  child: const Text(
                                    'Edit',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add business'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BusinessEditor(user: user),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class BusinessEditor extends StatefulWidget {
  const BusinessEditor({super.key, required this.user, this.business});
  final AppUser user;
  final Business? business;
  @override
  State<BusinessEditor> createState() => _BusinessEditorState();
}

class _BusinessStatusSelector extends StatelessWidget {
  const _BusinessStatusSelector({
    required this.active,
    required this.onChanged,
  });
  final bool active;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: LqColors.field,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: LqColors.line),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [_option('Active', true), _option('Inactive', false)],
    ),
  );

  Widget _option(String label, bool value) {
    final selected = active == value;
    final color = value ? const Color(0xFF46815B) : const Color(0xFF7B8492);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? (value ? const Color(0xFFE4F2DF) : const Color(0xFFEEF0F4))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: selected ? Border.all(color: color) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : LqColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _BusinessEditorState extends State<BusinessEditor> {
  final _form = GlobalKey<FormState>();
  Uint8List? _photo;
  late final _name = TextEditingController(text: widget.business?.name ?? '');
  late final _category = TextEditingController(
    text: widget.business?.category ?? '',
  );
  late final _registration = TextEditingController(
    text: widget.business?.registrationNumber ?? '',
  );
  late final _address = TextEditingController(
    text: widget.business?.address ?? '',
  );
  late final _postcode = TextEditingController(
    text: widget.business?.postcode ?? '',
  );
  late final _area = TextEditingController(text: widget.business?.area ?? '');
  late final _state = TextEditingController(
    text: widget.business?.state ?? '',
  );
  late final _phone = TextEditingController(text: widget.business?.phone ?? '');
  late final List<_OperatingHoursSlot> _operatingHoursSlots;
  late String? _dietaryStatus = widget.business?.dietaryStatus;
  late final _website = TextEditingController(
    text: widget.business?.website ?? '',
  );
  late final _description = TextEditingController(
    text: widget.business?.description ?? '',
  );
  late LqLocation? _location =
      widget.business?.latitude == null || widget.business?.longitude == null
      ? null
      : LqLocation(
          latitude: widget.business!.latitude!,
          longitude: widget.business!.longitude!,
        );
  late bool active = widget.business?.active ?? true;
  late String _verificationStatus = widget.business?.verificationStatus == 'verified' ||
          (widget.business?.verificationStatus != 'rejected' &&
              SsmVerificationEngine.isValidRegistrationNumber(
                widget.business?.registrationNumber,
              ))
      ? 'verified'
      : (widget.business?.verificationStatus ?? 'unverified');
  bool busy = false;

  @override
  void initState() {
    super.initState();
    if (!lqIsDietaryCategory(_category.text)) {
      _dietaryStatus = null;
    }
    _operatingHoursSlots = _parseOperatingHours(widget.business?.operatingHours);
    if (_postcode.text.isEmpty && _address.text.isNotEmpty) {
      final parsed = MalaysianAddressComponents.parse(
        '${_address.text}, ${_area.text}',
      );
      if (parsed.postcode.isNotEmpty) _postcode.text = parsed.postcode;
      if (parsed.city.isNotEmpty && _area.text.isEmpty) {
        _area.text = parsed.city;
      }
      if (parsed.state.isNotEmpty && _state.text.isEmpty) {
        _state.text = parsed.state;
      }
      if (parsed.street.isNotEmpty && parsed.street != _address.text) {
        _address.text = parsed.street;
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _registration.dispose();
    _address.dispose();
    _postcode.dispose();
    _area.dispose();
    _state.dispose();
    _phone.dispose();
    for (final slot in _operatingHoursSlots) {
      slot.hoursController.dispose();
    }
    _website.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LqPage(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LqBackButton(label: 'Back to business registrations'),
          LqTitleBlock(
            eyebrow: 'Merchant workspace',
            title: widget.business == null ? 'Add business' : 'Edit business',
            subtitle:
                'Set up the information LocalQuest uses for your business.',
          ),
          const SizedBox(height: 22),
          LqCard(
            child: Form(
              key: _form,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                children: [
                  LqField(
                    controller: _name,
                    label: 'Business name',
                    validator: (v) =>
                        MerchantValidation.text(v, 'Business name', 3, 120),
                  ),
                  const SizedBox(height: 16),
                  BusinessPhotoField(
                    url: widget.business?.photoUrl,
                    enabled: !busy,
                    onChanged: (bytes) => _photo = bytes,
                  ),
                  const SizedBox(height: 16),
                  LqDropdownField(
                    value: _category.text.isEmpty ? null : _category.text,
                    label: 'Business category',
                    items: lqBusinessCategories,
                    onChanged: (value) => setState(() {
                      _category.text = value ?? '';
                      if (!lqIsDietaryCategory(_category.text)) {
                        _dietaryStatus = null;
                      }
                    }),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Choose a business category.' : null,
                  ),
                  const SizedBox(height: 16),
                  LqField(
                    controller: _registration,
                    label: 'Registration number',
                    hint: 'e.g. 201934234321 (RT0069300-M) or 201901032124',
                    validator: MerchantValidation.registration,
                    onChanged: (v) {
                      if (_verificationStatus != 'rejected') {
                        setState(() {
                          if (SsmVerificationEngine.isValidRegistrationNumber(v)) {
                            _verificationStatus = 'verified';
                          } else if (_verificationStatus == 'verified' &&
                              (widget.business?.verificationStatus ?? 'unverified') != 'verified') {
                            _verificationStatus = 'unverified';
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  CertificateScanButton(
                    businessName: _name.text,
                    onRegistration: (number) => setState(() {
                      _registration.text = number;
                      if (SsmVerificationEngine.isValidRegistrationNumber(number) &&
                          _verificationStatus != 'rejected') {
                        _verificationStatus = 'verified';
                      }
                    }),
                    onVerificationResult: (result) {
                      setState(() {
                        _verificationStatus = result.status;
                      });
                    },
                  ),
                  if (_verificationStatus == 'verified' ||
                      (_verificationStatus != 'rejected' &&
                          SsmVerificationEngine.isValidRegistrationNumber(_registration.text))) ...[
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: SsmVerifiedBadge(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  LqAddressField(
                    controller: _address,
                    label: 'Street address',
                    validator: (v) =>
                        MerchantValidation.text(v, 'Address', 3, 500),
                    initialLocation: _location,
                    onLocationChanged: (value) => _location = value,
                    onAddressComponentsChanged: (components) {
                      setState(() {
                        if (components.postcode.isNotEmpty) {
                          _postcode.text = components.postcode;
                        }
                        if (components.city.isNotEmpty) {
                          _area.text = components.city;
                        }
                        if (components.state.isNotEmpty) {
                          _state.text = components.state;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: LqField(
                          controller: _postcode,
                          label: 'Postcode',
                          hint: 'e.g. 13500',
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required.';
                            if (!RegExp(r'^\d{5}$').hasMatch(v.trim())) {
                              return '5-digit code.';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LqField(
                          controller: _area,
                          label: 'Area / city',
                          hint: 'e.g. Permatang Pauh',
                          validator: (v) =>
                              MerchantValidation.text(v, 'Area / city', 2, 80),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LqDropdownField(
                    value: _state.text.isEmpty ? null : _state.text,
                    label: 'State',
                    items: MalaysianAddressComponents.malaysianStates,
                    onChanged: (value) =>
                        setState(() => _state.text = value ?? ''),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Choose a state.' : null,
                  ),
                  const SizedBox(height: 16),
                  LqField(
                    controller: _phone,
                    label: 'Contact number',
                    hint: 'e.g. 04-261 2345, 03-8888 1234, or 012-345 6789',
                    validator: MerchantValidation.phone,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  _buildOperatingHoursSection(),
                  if (lqIsDietaryCategory(_category.text)) ...[
                    const SizedBox(height: 16),
                    LqDropdownField(
                      key: ValueKey('dietary_status_${_category.text}_$_dietaryStatus'),
                      value: _dietaryStatus,
                      label: 'Halal & dietary certification',
                      items: lqDietaryStatuses,
                      onChanged: (value) =>
                          setState(() => _dietaryStatus = value),
                      validator: (v) {
                        if (lqIsDietaryCategory(_category.text)) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please choose a Halal & dietary certification.';
                          }
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  LqField(
                    controller: _website,
                    label: 'Website / social link',
                    hint: 'e.g. https://instagram.com/mybusiness or https://mybiz.com',
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 16),
                  LqField(
                    controller: _description,
                    label: 'Store story & description',
                    hint: 'Brief story or highlights for visiting tourists...',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Business status',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Only active businesses can run ads and issue vouchers.',
                              style: TextStyle(
                                color: LqColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _BusinessStatusSelector(
                        active: active,
                        onChanged: (value) => setState(() => active = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  LqButton(
                    label: 'Save business',
                    busy: busy,
                    icon: Icons.save_outlined,
                    onPressed: _save,
                  ),
                  if (widget.business != null) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: busy ? null : _delete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove business'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: LqColors.danger,
                        side: const BorderSide(color: LqColors.danger),
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _save() async {
    if (busy || !_form.currentState!.validate()) return;
    if (!lqBusinessCategories.contains(_category.text)) {
      showLqMessage(context, 'Choose a business category.', error: true);
      return;
    }
    if (lqIsDietaryCategory(_category.text) &&
        (_dietaryStatus == null || _dietaryStatus!.trim().isEmpty)) {
      showLqMessage(
        context,
        'Please choose a Halal & dietary certification for your food business.',
        error: true,
      );
      return;
    }
    setState(() => busy = true);
    try {
      final effectiveVerificationStatus = _verificationStatus == 'verified' ||
              (_verificationStatus != 'rejected' &&
                  SsmVerificationEngine.isValidRegistrationNumber(
                    _registration.text,
                  ))
          ? 'verified'
          : _verificationStatus;
      await MerchantRepository.instance.saveBusiness(
        Business(
          id: widget.business?.id ?? '',
          ownerId: widget.user.id,
          name: _name.text,
          category: _category.text,
          address: _address.text,
          area: _area.text,
          postcode: _postcode.text,
          state: _state.text,
          phone: _phone.text,
          registrationNumber: _registration.text,
          verificationStatus: effectiveVerificationStatus,
          active: active,
          latitude: _location?.latitude,
          longitude: _location?.longitude,
          operatingHours: _formattedOperatingHours(),
          dietaryStatus:
              lqIsDietaryCategory(_category.text) ? _dietaryStatus : null,
          website: _website.text.trim().isEmpty ? null : _website.text.trim(),
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
        ),
        photoBytes: _photo,
      );
      if (mounted) Navigator.pop(context);
    } on LocalQuestException catch (error) {
      if (mounted) {
        showLqMessage(context, error.message, error: true);
        setState(() => busy = false);
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        showLqMessage(
          context,
          error.message ?? 'Could not save this business.',
          error: true,
        );
        setState(() => busy = false);
      }
    }
  }

  Future<void> _delete() async {
    final business = widget.business;
    if (business == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove business?'),
        content: Text(
          '${business.name} will be removed from your LocalQuest account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: LqColors.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      await MerchantRepository.instance.deleteBusiness(business.id);
      if (mounted) Navigator.pop(context);
    } on FirebaseException catch (error) {
      if (mounted) {
        showLqMessage(
          context,
          error.message ?? 'Could not remove this business.',
          error: true,
        );
        setState(() => busy = false);
      }
    }
  }

  Widget _buildOperatingHoursSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.schedule, size: 16, color: LqColors.primary),
            SizedBox(width: 8),
            Text(
              'Operating hours',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: LqColors.primaryDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Select the days of the week and specify operating hours for each period.',
          style: TextStyle(fontSize: 12, color: LqColors.muted),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              flex: 5,
              child: Text(
                'DAY(S) OF WEEK',
                style: monoLabel.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: LqColors.muted,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 6,
              child: Text(
                'OPERATING HOURS',
                style: monoLabel.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: LqColors.muted,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            if (_operatingHoursSlots.length > 1)
              const SizedBox(width: 36),
          ],
        ),
        const SizedBox(height: 6),
        ...List.generate(_operatingHoursSlots.length, (index) {
          final slot = _operatingHoursSlots[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 5,
                  child: InkWell(
                    onTap: () => _pickDaysForSlot(index),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: LqColors.field,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: LqColors.line),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_outlined,
                            size: 15,
                            color: LqColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              slot.daysSummary,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: LqColors.primaryDark,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.arrow_drop_down,
                            size: 18,
                            color: LqColors.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 6,
                  child: SizedBox(
                    height: 48,
                    child: TextFormField(
                      controller: slot.hoursController,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: LqColors.ink,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. 8:30 AM – 10:00 PM',
                        hintStyle: const TextStyle(
                          fontSize: 11,
                          color: LqColors.muted,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: LqColors.field,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: LqColors.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: LqColors.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: LqColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_operatingHoursSlots.length > 1) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Color(0xFFDC2626),
                      size: 20,
                    ),
                    onPressed: () => _removeOperatingHoursSlot(index),
                    tooltip: 'Remove row',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 48,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: _addOperatingHoursSlot,
          icon: const Icon(Icons.add, size: 16),
          label: const Text(
            'Add schedule row',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: LqColors.primary,
            side: const BorderSide(color: Color(0xFFBFDBFE)),
            backgroundColor: const Color(0xFFF8FAFC),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  Future<void> _pickDaysForSlot(int index) async {
    final slot = _operatingHoursSlots[index];
    final selectedDays = List<String>.from(slot.days);

    const dayKeys = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const dayFull = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isAllSelected = selectedDays.length == 7;
            final isWeekdaysSelected = selectedDays.length == 5 &&
                ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'].every(selectedDays.contains);
            final isWeekendsSelected = selectedDays.length == 2 &&
                ['Sat', 'Sun'].every(selectedDays.contains);

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.78,
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: LqColors.line,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Operating Days',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select 1 day or multiple days for this schedule',
                    style: TextStyle(fontSize: 13, color: LqColors.muted),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Daily (Mon–Sun)'),
                        selected: isAllSelected,
                        selectedColor: LqColors.primarySoft,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isAllSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isAllSelected
                              ? LqColors.primaryDark
                              : LqColors.ink,
                        ),
                        onSelected: (val) {
                          setSheetState(() {
                            selectedDays
                              ..clear()
                              ..addAll(dayKeys);
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('Mon – Fri'),
                        selected: isWeekdaysSelected,
                        selectedColor: LqColors.primarySoft,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isWeekdaysSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isWeekdaysSelected
                              ? LqColors.primaryDark
                              : LqColors.ink,
                        ),
                        onSelected: (val) {
                          setSheetState(() {
                            selectedDays
                              ..clear()
                              ..addAll(['Mon', 'Tue', 'Wed', 'Thu', 'Fri']);
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('Sat – Sun'),
                        selected: isWeekendsSelected,
                        selectedColor: LqColors.primarySoft,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isWeekendsSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isWeekendsSelected
                              ? LqColors.primaryDark
                              : LqColors.ink,
                        ),
                        onSelected: (val) {
                          setSheetState(() {
                            selectedDays
                              ..clear()
                              ..addAll(['Sat', 'Sun']);
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: LqColors.line),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: 7,
                      itemBuilder: (context, i) {
                        final short = dayKeys[i];
                        final full = dayFull[i];
                        final checked = selectedDays.contains(short);

                        return CheckboxListTile(
                          value: checked,
                          dense: true,
                          title: Text(
                            full,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: checked
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                          ),
                          secondary: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: checked
                                  ? LqColors.primarySoft
                                  : LqColors.field,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              short,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: checked
                                    ? LqColors.primaryDark
                                    : LqColors.muted,
                              ),
                            ),
                          ),
                          activeColor: LqColors.primary,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (bool? val) {
                            setSheetState(() {
                              if (val == true) {
                                if (!selectedDays.contains(short)) {
                                  selectedDays.add(short);
                                  selectedDays.sort((a, b) => dayKeys
                                      .indexOf(a)
                                      .compareTo(dayKeys.indexOf(b)));
                                }
                              } else {
                                selectedDays.remove(short);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: LqButton(
                      label: selectedDays.isEmpty
                          ? 'Select at least 1 day'
                          : 'Apply Days (${selectedDays.length} selected)',
                      onPressed: selectedDays.isEmpty
                          ? null
                          : () => Navigator.pop(sheetContext, selectedDays),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        slot.days = result;
      });
    }
  }

  void _addOperatingHoursSlot() {
    setState(() {
      _operatingHoursSlots.add(
        _OperatingHoursSlot(
          days: ['Sat', 'Sun'],
          hoursController: TextEditingController(text: '9:00 AM – 11:00 PM'),
        ),
      );
    });
  }

  void _removeOperatingHoursSlot(int index) {
    if (_operatingHoursSlots.length <= 1) return;
    setState(() {
      final removed = _operatingHoursSlots.removeAt(index);
      removed.hoursController.dispose();
    });
  }

  String? _formattedOperatingHours() {
    final lines = <String>[];
    for (final slot in _operatingHoursSlots) {
      final hours = slot.hoursController.text.trim();
      if (hours.isNotEmpty) {
        lines.add('${slot.daysSummary}: $hours');
      }
    }
    return lines.isEmpty ? null : lines.join('\n');
  }

  static List<_OperatingHoursSlot> _parseOperatingHours(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return [
        _OperatingHoursSlot(
          days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
          hoursController: TextEditingController(text: '8:00 AM – 10:00 PM'),
        ),
      ];
    }

    final lines = raw
        .split(RegExp(r'[\r\n|;]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return [
        _OperatingHoursSlot(
          days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
          hoursController: TextEditingController(),
        ),
      ];
    }

    final slots = <_OperatingHoursSlot>[];
    for (final line in lines) {
      if (line.contains(':')) {
        final colonIndex = line.indexOf(':');
        final left = line.substring(0, colonIndex).trim();
        final right = line.substring(colonIndex + 1).trim();
        slots.add(
          _OperatingHoursSlot(
            days: _parseDaysFromString(left),
            hoursController: TextEditingController(text: right),
          ),
        );
      } else {
        slots.add(
          _OperatingHoursSlot(
            days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
            hoursController: TextEditingController(text: line),
          ),
        );
      }
    }

    return slots.isEmpty
        ? [
            _OperatingHoursSlot(
              days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
              hoursController: TextEditingController(),
            ),
          ]
        : slots;
  }

  static List<String> _parseDaysFromString(String left) {
    final lower = left.toLowerCase();
    if (lower.contains('daily') ||
        lower.contains('all') ||
        lower.contains('mon–sun') ||
        lower.contains('mon-sun')) {
      return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    }
    if (lower.contains('weekday') ||
        lower.contains('mon–fri') ||
        lower.contains('mon-fri')) {
      return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    }
    if (lower.contains('weekend') ||
        lower.contains('sat–sun') ||
        lower.contains('sat-sun')) {
      return ['Sat', 'Sun'];
    }
    final matched = <String>[];
    for (final d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
      if (lower.contains(d.toLowerCase())) {
        matched.add(d);
      }
    }
    return matched.isNotEmpty ? matched : [left];
  }
}

class _OperatingHoursSlot {
  _OperatingHoursSlot({
    required this.days,
    required this.hoursController,
  });

  List<String> days;
  final TextEditingController hoursController;

  String get daysSummary {
    if (days.isEmpty) return 'Select days';
    if (days.length == 7) return 'Daily (Mon–Sun)';
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    const weekends = ['Sat', 'Sun'];
    if (days.length == 5 && weekdays.every(days.contains)) return 'Mon–Fri';
    if (days.length == 2 && weekends.every(days.contains)) return 'Sat–Sun';
    return days.join(', ');
  }
}
