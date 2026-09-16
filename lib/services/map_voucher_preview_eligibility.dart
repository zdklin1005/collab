import '../models/localquest_models.dart';

enum MapVoucherPreviewEligibility {
  eligible,
  invalidData,
  inactive,
  wrongCollectionMethod,
  unavailableBusiness,
  notStarted,
  expired,
  outOfStock,
}

MapVoucherPreviewEligibility checkMapVoucherPreviewEligibility({
  required Campaign campaign,
  required Business? issuingBusiness,
  required DateTime now,
}) {
  if (campaign.id.trim().isEmpty ||
      campaign.ownerId.trim().isEmpty ||
      campaign.businessId.trim().isEmpty ||
      campaign.name.trim().isEmpty ||
      campaign.type != 'voucher' ||
      campaign.quantity < 0 ||
      campaign.claims < 0 ||
      campaign.perCustomerLimit < 1 ||
      !campaign.endDate.isAfter(campaign.startDate) ||
      !const {
        'welcome',
        'promotional',
        'seasonal',
      }.contains(campaign.voucherType)) {
    return MapVoucherPreviewEligibility.invalidData;
  }

  if (campaign.status != 'active') {
    return MapVoucherPreviewEligibility.inactive;
  }

  if (campaign.collectionMethod != 'walk_up_collect' &&
      campaign.collectionMethod != 'both') {
    return MapVoucherPreviewEligibility.wrongCollectionMethod;
  }

  if (issuingBusiness == null ||
      !issuingBusiness.active ||
      issuingBusiness.id != campaign.businessId ||
      issuingBusiness.ownerId != campaign.ownerId) {
    return MapVoucherPreviewEligibility.unavailableBusiness;
  }

  if (now.isBefore(campaign.startDate)) {
    return MapVoucherPreviewEligibility.notStarted;
  }

  // Start is inclusive; end is exclusive.
  if (!now.isBefore(campaign.endDate)) {
    return MapVoucherPreviewEligibility.expired;
  }

  if (campaign.claims >= campaign.quantity) {
    return MapVoucherPreviewEligibility.outOfStock;
  }

  return MapVoucherPreviewEligibility.eligible;
}
