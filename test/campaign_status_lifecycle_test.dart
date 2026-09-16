// ignore_for_file: avoid_redundant_argument_values
import 'package:flutter_test/flutter_test.dart';

import 'package:collab/models/localquest_models.dart';

void main() {
  final today = DateTime.now();
  final todayOnly = DateTime(today.year, today.month, today.day);
  final yesterday = todayOnly.subtract(const Duration(days: 1));
  final tomorrow = todayOnly.add(const Duration(days: 1));
  final nextWeek = todayOnly.add(const Duration(days: 7));
  final lastWeek = todayOnly.subtract(const Duration(days: 7));

  // ---------------------------------------------------------------------------
  // Campaign.resolveStatus
  // ---------------------------------------------------------------------------
  group('Campaign.resolveStatus', () {
    test('Returns inactive when end date is in the past', () {
      expect(
        Campaign.resolveStatus(
          rawStatus: 'active',
          startDate: lastWeek,
          endDate: yesterday,
          referenceDate: todayOnly,
        ),
        'inactive',
      );
    });

    test('Returns inactive for past end date even if raw is scheduled', () {
      expect(
        Campaign.resolveStatus(
          rawStatus: 'scheduled',
          startDate: lastWeek,
          endDate: yesterday,
          referenceDate: todayOnly,
        ),
        'inactive',
      );
    });

    test('Returns scheduled when start date is in the future and raw is active', () {
      expect(
        Campaign.resolveStatus(
          rawStatus: 'active',
          startDate: tomorrow,
          endDate: nextWeek,
          referenceDate: todayOnly,
        ),
        'scheduled',
      );
    });

    test('Preserves inactive when start date is future and merchant paused it', () {
      expect(
        Campaign.resolveStatus(
          rawStatus: 'inactive',
          startDate: tomorrow,
          endDate: nextWeek,
          referenceDate: todayOnly,
        ),
        'inactive',
      );
    });

    test('Upgrades scheduled to active when start date has arrived', () {
      expect(
        Campaign.resolveStatus(
          rawStatus: 'scheduled',
          startDate: yesterday,
          endDate: nextWeek,
          referenceDate: todayOnly,
        ),
        'active',
      );
    });

    test('Upgrades scheduled to active when start date is today', () {
      expect(
        Campaign.resolveStatus(
          rawStatus: 'scheduled',
          startDate: todayOnly,
          endDate: nextWeek,
          referenceDate: todayOnly,
        ),
        'active',
      );
    });

    test('Keeps active when in active window', () {
      expect(
        Campaign.resolveStatus(
          rawStatus: 'active',
          startDate: yesterday,
          endDate: nextWeek,
          referenceDate: todayOnly,
        ),
        'active',
      );
    });

    test('Keeps inactive (paused) when in active window but merchant paused it', () {
      expect(
        Campaign.resolveStatus(
          rawStatus: 'inactive',
          startDate: yesterday,
          endDate: nextWeek,
          referenceDate: todayOnly,
        ),
        'inactive',
      );
    });

    test('Same-day campaign (start == today == end): resolves to active', () {
      expect(
        Campaign.resolveStatus(
          rawStatus: 'active',
          startDate: todayOnly,
          endDate: todayOnly,
          referenceDate: todayOnly,
        ),
        'active',
      );
    });

    test('Campaign ending today is NOT expired (still within range)', () {
      expect(
        Campaign.resolveStatus(
          rawStatus: 'active',
          startDate: yesterday,
          endDate: todayOnly,
          referenceDate: todayOnly,
        ),
        'active',
      );
    });

    test('Campaign that ended yesterday is expired -> inactive', () {
      expect(
        Campaign.resolveStatus(
          rawStatus: 'active',
          startDate: DateTime(2026, 9, 1),
          endDate: DateTime(2026, 9, 13),
          referenceDate: DateTime(2026, 9, 15),
        ),
        'inactive',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Campaign effectiveStatus getters
  // ---------------------------------------------------------------------------
  group('Campaign effectiveStatus getters', () {
    Campaign makeCampaign({
      required String status,
      required DateTime startDate,
      required DateTime endDate,
    }) =>
        Campaign(
          id: 'test',
          ownerId: 'owner',
          businessId: 'biz',
          name: 'Test Campaign',
          description: 'A test description for this campaign fixture.',
          type: 'ad',
          startDate: startDate,
          endDate: endDate,
          status: status,
        );

    test('isExpired true when end date is yesterday', () {
      final c = makeCampaign(
        status: 'active',
        startDate: lastWeek,
        endDate: yesterday,
      );
      expect(c.isExpired, isTrue);
      expect(c.isActive, isFalse);
      expect(c.isInactive, isTrue);
    });

    test('isScheduled true when start date is tomorrow', () {
      final c = makeCampaign(
        status: 'scheduled',
        startDate: tomorrow,
        endDate: nextWeek,
      );
      expect(c.isScheduled, isTrue);
      expect(c.isActive, isFalse);
      expect(c.isExpired, isFalse);
    });

    test('effectiveStatus upgrades scheduled->active when today >= startDate', () {
      final c = makeCampaign(
        status: 'scheduled',
        startDate: yesterday,
        endDate: nextWeek,
      );
      expect(c.effectiveStatus, 'active');
      expect(c.isActive, isTrue);
      expect(c.isScheduled, isFalse);
    });

    test('isActive true for active campaign in valid window', () {
      final c = makeCampaign(
        status: 'active',
        startDate: yesterday,
        endDate: nextWeek,
      );
      expect(c.isActive, isTrue);
      expect(c.isExpired, isFalse);
    });

    test('isInactive true for manually paused campaign', () {
      final c = makeCampaign(
        status: 'inactive',
        startDate: yesterday,
        endDate: nextWeek,
      );
      expect(c.isInactive, isTrue);
      expect(c.isActive, isFalse);
      expect(c.isExpired, isFalse);
    });

    test('Campaign ending today is NOT expired', () {
      final c = makeCampaign(
        status: 'active',
        startDate: yesterday,
        endDate: todayOnly,
      );
      expect(c.isExpired, isFalse);
      expect(c.isActive, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Available statuses logic (mirrors _availableStatuses in the form)
  // ---------------------------------------------------------------------------
  group('Available statuses logic (mirrors form _availableStatuses)', () {
    List<String> availableStatuses(DateTime startDate, DateTime endDate) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final endDay = DateTime(endDate.year, endDate.month, endDate.day);
      final startDay = DateTime(startDate.year, startDate.month, startDate.day);

      if (endDay.isBefore(today)) return ['inactive'];
      if (startDay.isAfter(today)) return ['scheduled', 'inactive'];
      return ['active', 'inactive'];
    }

    test('Expired campaign: only inactive available', () {
      expect(availableStatuses(lastWeek, yesterday), ['inactive']);
    });

    test('Future start campaign: scheduled and inactive available', () {
      expect(availableStatuses(tomorrow, nextWeek), ['scheduled', 'inactive']);
    });

    test('Active window campaign: active and inactive available', () {
      expect(availableStatuses(yesterday, nextWeek), ['active', 'inactive']);
    });

    test('Campaign ending today: active and inactive available (not expired)', () {
      expect(availableStatuses(yesterday, todayOnly), ['active', 'inactive']);
    });
  });
}

