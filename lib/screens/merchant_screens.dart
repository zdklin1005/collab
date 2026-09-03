import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../core/localquest_theme.dart';
import '../core/localquest_location.dart';
import '../core/localquest_widgets.dart';
import '../models/localquest_models.dart';
import '../services/localquest_services.dart';
import 'tourist_screens.dart';

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
  });
  final AppUser user;
  final Business? business;
  final VoidCallback openCampaigns;
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Campaign>>(
    stream: MerchantRepository.instance.campaigns(
      user.id,
      businessId: business?.id,
    ),
    builder: (context, snapshot) {
      final campaigns = snapshot.data ?? [];
      final active = campaigns
          .where((item) => item.status == 'active')
          .toList();
      final views = campaigns.fold<int>(0, (sum, item) => sum + item.views);
      final claims = campaigns.fold<int>(0, (sum, item) => sum + item.claims);
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 44, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LqTitleBlock(
              eyebrow: 'Merchant portal',
              title: 'Business\noverview',
            ),
            if (business != null) ...[
              const SizedBox(height: 8),
              Text(
                business!.name,
                style: monoLabel.copyWith(color: LqColors.primary),
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
              value: active.length.toString().padLeft(2, '0'),
              label: 'Active campaigns',
            ),
            const SizedBox(height: 40),
            if (active.isNotEmpty)
              LqCard(
                color: LqColors.primarySoft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('LIVE CAMPAIGN', style: monoLabel),
                        Switch(
                          value: true,
                          onChanged: (value) =>
                              _setCampaignActive(context, active.first, value),
                        ),
                      ],
                    ),
                    Text(
                      active.first.name,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ACTIVE · ENDS ${DateFormat('d MMM').format(active.first.endDate).toUpperCase()}',
                      style: monoLabel.copyWith(color: LqColors.success),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      active.first.description,
                      style: const TextStyle(
                        color: LqColors.muted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: openCampaigns,
                      child: const Text('Edit details'),
                    ),
                  ],
                ),
              )
            else
              const LqCard(
                child: Text(
                  'No active campaigns yet. Create one to reach nearby LocalQuest explorers.',
                  style: TextStyle(color: LqColors.muted),
                ),
              ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('RECENT CAMPAIGNS', style: monoLabel),
                FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CampaignEditor(
                        user: user,
                        businessId: business?.id ?? '',
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Create campaign'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LqCard(
              child: campaigns.isEmpty
                  ? const Text(
                      'Your campaigns will appear here.',
                      style: TextStyle(color: LqColors.muted),
                    )
                  : Column(
                      children: campaigns
                          .take(4)
                          .map(
                            (item) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                backgroundColor: LqColors.primarySoft,
                                foregroundColor: LqColors.primary,
                                child: Icon(Icons.auto_awesome),
                              ),
                              title: Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '${item.status.toUpperCase()} · ${item.views} views',
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
          ],
        ),
      );
    },
  );

  Future<void> _setCampaignActive(
    BuildContext context,
    Campaign campaign,
    bool active,
  ) async {
    try {
      await MerchantRepository.instance.saveCampaign(
        Campaign(
          id: campaign.id,
          ownerId: campaign.ownerId,
          name: campaign.name,
          description: campaign.description,
          type: campaign.type,
          startDate: campaign.startDate,
          endDate: campaign.endDate,
          status: active ? 'active' : 'inactive',
          businessId: campaign.businessId,
          views: campaign.views,
          claims: campaign.claims,
          imageUrl: campaign.imageUrl,
        ),
      );
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
        CircleAvatar(
          backgroundColor: color,
          foregroundColor: LqColors.primary,
          child: Icon(icon),
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

class CampaignsScreen extends StatefulWidget {
  const CampaignsScreen({
    super.key,
    required this.user,
    required this.business,
    this.initialType = 'ad',
  });
  final AppUser user;
  final Business? business;
  final String initialType;
  @override
  State<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen> {
  late String type = widget.initialType;
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Campaign>>(
    stream: MerchantRepository.instance.campaigns(
      widget.user.id,
      businessId: widget.business?.id,
    ),
    builder: (context, snapshot) {
      final campaigns = (snapshot.data ?? [])
          .where((item) => item.type == type)
          .toList();
      return Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 44, 16, 110),
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
                if (campaigns.isEmpty)
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
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: widget.business == null
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CampaignEditor(
                                        user: widget.user,
                                        businessId: widget.business!.id,
                                        initialType: type,
                                      ),
                                    ),
                                  ),
                            icon: const Icon(Icons.add),
                            label: Text(
                              type == 'ad'
                                  ? 'Create campaign'
                                  : 'Create voucher',
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...campaigns.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: LqCard(
                        color: item.status == 'active'
                            ? LqColors.primarySoft
                            : (item.status == 'scheduled'
                                  ? LqColors.peachSoft
                                  : const Color(0xFFF0F1F4)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.white,
                              foregroundColor: LqColors.primary,
                              child: Icon(
                                item.type == 'voucher'
                                    ? Icons.confirmation_num_outlined
                                    : Icons.auto_awesome_outlined,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: LqColors.primaryDark,
                                height: 1.05,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.description.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: monoLabel.copyWith(
                                color: LqColors.primaryDark,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: LqDashedDivider(),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item.status[0].toUpperCase()}${item.status.substring(1)} · Ends ${DateFormat('d MMM').format(item.endDate)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      '${item.views} views · ${item.claims} claims',
                                      style: monoLabel,
                                    ),
                                  ],
                                ),
                                TextButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CampaignEditor(
                                        user: widget.user,
                                        businessId: widget.business?.id ?? '',
                                        campaign: item,
                                      ),
                                    ),
                                  ),
                                  child: const Text('Edit'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (campaigns.isNotEmpty)
            Positioned(
              right: 16,
              bottom: 22,
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

class CampaignEditor extends StatefulWidget {
  const CampaignEditor({
    super.key,
    required this.user,
    this.businessId = '',
    this.campaign,
    this.initialType = 'ad',
  });
  final AppUser user;
  final String businessId;
  final Campaign? campaign;
  final String initialType;
  @override
  State<CampaignEditor> createState() => _CampaignEditorState();
}

class _CampaignEditorState extends State<CampaignEditor> {
  late final _name = TextEditingController(text: widget.campaign?.name ?? '');
  late final _description = TextEditingController(
    text: widget.campaign?.description ?? '',
  );
  late String type = widget.campaign?.type ?? widget.initialType;
  late String status = widget.campaign?.status ?? 'active';
  late DateTime startDate = widget.campaign?.startDate ?? DateTime.now();
  late DateTime endDate =
      widget.campaign?.endDate ?? DateTime.now().add(const Duration(days: 30));
  Uint8List? poster;
  String? extension;
  bool busy = false;

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
            child: Column(
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'ad', label: Text('Promotional ad')),
                    ButtonSegment(value: 'voucher', label: Text('Voucher')),
                  ],
                  selected: {type},
                  onSelectionChanged: (value) =>
                      setState(() => type = value.first),
                ),
                const SizedBox(height: 22),
                InkWell(
                  onTap: _pickPoster,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: LqColors.field,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: LqColors.primary),
                    ),
                    child: poster == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.upload_file, color: LqColors.primary),
                              SizedBox(height: 8),
                              Text(
                                'Upload campaign poster',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                'PNG, JPG or WEBP · recommended 4:3',
                                style: TextStyle(
                                  color: LqColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(19),
                            child: Image.memory(poster!, fit: BoxFit.cover),
                          ),
                  ),
                ),
                const SizedBox(height: 18),
                LqField(
                  controller: _name,
                  label: type == 'ad' ? 'Campaign name' : 'Voucher name',
                ),
                const SizedBox(height: 16),
                LqField(
                  controller: _description,
                  label: 'Description',
                  maxLines: 4,
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
                  items: const ['active', 'scheduled', 'inactive'],
                  onChanged: (value) {
                    if (value != null) setState(() => status = value);
                  },
                ),
                const SizedBox(height: 24),
                LqButton(
                  label: 'Save changes',
                  busy: busy,
                  icon: Icons.save_outlined,
                  onPressed: _save,
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
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _pickPoster() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 88,
    );
    if (file == null) return;
    poster = await file.readAsBytes();
    extension = file.name.split('.').last.toLowerCase();
    if (mounted) setState(() {});
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
      setState(() => start ? startDate = value : endDate = value);
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || endDate.isBefore(startDate)) {
      showLqMessage(
        context,
        'Add a name and choose a valid date range.',
        error: true,
      );
      return;
    }
    setState(() => busy = true);
    final existing = widget.campaign;
    try {
      await MerchantRepository.instance.saveCampaign(
        Campaign(
          id: existing?.id ?? '',
          ownerId: widget.user.id,
          businessId: existing?.businessId.isNotEmpty == true
              ? existing!.businessId
              : widget.businessId,
          name: _name.text,
          description: _description.text,
          type: type,
          startDate: startDate,
          endDate: endDate,
          status: status,
          views: existing?.views ?? 0,
          claims: existing?.claims ?? 0,
          imageUrl: existing?.imageUrl,
        ),
        posterBytes: poster,
        posterExtension: extension,
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
          error.message ?? 'Could not save this item.',
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
                CircleAvatar(
                  radius: 34,
                  backgroundColor: const Color(0xFFE4C8B7),
                  child: Text(
                    initialsFor(user.displayName),
                    style: const TextStyle(fontWeight: FontWeight.w800),
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
                        user.email,
                        style: const TextStyle(color: LqColors.muted),
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

  @override
  Widget build(BuildContext context) {
    if (businesses.isEmpty) {
      return LqCard(
        child: Row(
          children: [
            const Icon(Icons.storefront_outlined, color: LqColors.primary),
            const SizedBox(width: 12),
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
            const Icon(Icons.keyboard_arrow_down, color: LqColors.primary),
          ],
        ),
      );
    }
    final value = selectedBusiness?.id ?? businesses.first.id;
    return InkWell(
      borderRadius: BorderRadius.circular(25),
      onTap: () async {
        final next = await showLqSelectionSheet<String>(
          context,
          title: 'Choose business workspace',
          selected: value,
          options: businesses.map((item) => (item.id, item.name)).toList(),
        );
        if (next != null) onSelected?.call(next);
      },
      child: LqCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: LqColors.greenSoft,
              foregroundColor: Color(0xFF42723B),
              child: Icon(Icons.storefront_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Manage workspace for',
                    style: TextStyle(color: LqColors.muted, fontSize: 11),
                  ),
                  Text(
                    selectedBusiness?.name ?? businesses.first.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
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
    leading: CircleAvatar(
      backgroundColor: const Color(0xFFF0F4FC),
      foregroundColor: LqColors.primary,
      child: Icon(icon),
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
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: index.isEven
                                      ? const Color(0xFFE4C8B7)
                                      : LqColors.primarySoft,
                                  foregroundColor: LqColors.primaryDark,
                                  child: const Icon(Icons.storefront_outlined),
                                ),
                                const SizedBox(width: 16),
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
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        item.address,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: LqColors.muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                LqStatusPill(active: item.active),
                                const SizedBox(width: 8),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    backgroundColor: const Color(0xFFEDF1F9),
                                    shape: const StadiumBorder(),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
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
  late final _phone = TextEditingController(text: widget.business?.phone ?? '');
  late LqLocation? _location =
      widget.business?.latitude == null || widget.business?.longitude == null
      ? null
      : LqLocation(
          latitude: widget.business!.latitude!,
          longitude: widget.business!.longitude!,
        );
  late bool active = widget.business?.active ?? true;
  bool busy = false;

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _registration.dispose();
    _address.dispose();
    _phone.dispose();
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
            child: Column(
              children: [
                LqField(controller: _name, label: 'Business name'),
                const SizedBox(height: 16),
                LqDropdownField(
                  value: _category.text.isEmpty ? null : _category.text,
                  label: 'Business category',
                  items: lqBusinessCategories,
                  onChanged: (value) =>
                      setState(() => _category.text = value ?? ''),
                ),
                const SizedBox(height: 16),
                LqField(
                  controller: _registration,
                  label: 'Registration number',
                ),
                const SizedBox(height: 16),
                LqAddressField(
                  controller: _address,
                  label: 'Street address',
                  initialLocation: _location,
                  onLocationChanged: (value) => _location = value,
                ),
                const SizedBox(height: 16),
                LqField(controller: _phone, label: 'Contact number'),
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
        ],
      ),
    ),
  );

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _address.text.trim().isEmpty) {
      showLqMessage(
        context,
        'Business name and street address are required.',
        error: true,
      );
      return;
    }
    setState(() => busy = true);
    try {
      await MerchantRepository.instance.saveBusiness(
        Business(
          id: widget.business?.id ?? '',
          ownerId: widget.user.id,
          name: _name.text,
          category: _category.text,
          address: _address.text,
          phone: _phone.text,
          registrationNumber: _registration.text,
          active: active,
          latitude: _location?.latitude,
          longitude: _location?.longitude,
        ),
      );
      if (mounted) Navigator.pop(context);
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
}
