import 'package:collab/models/map_location.dart';
import 'package:collab/screens/interactive_map/map_location_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const business = MapLocation(
    id: 'business-test',
    businessId: 'merchant-business-test',
    type: MapLocationType.business,
    title: 'Demo Café',
    category: 'Food & Beverage',
    address: 'Fictional test address',
    description: 'A fictional café used for interface testing.',
    latitude: 3,
    longitude: 101,
  );

  const landmark = MapLocation(
    id: 'landmark-test',
    type: MapLocationType.landmark,
    title: 'Demo Heritage Point',
    category: 'Heritage',
    description: 'A fictional heritage location.',
    latitude: 3,
    longitude: 101,
  );

  Widget host(
    MapLocation location, {
    VoidCallback? onClose,
    VoidCallback? onNavigate,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: MapLocationDetails(
          location: location,
          onClose: onClose ?? () {},
          onNavigate: onNavigate,
        ),
      ),
    );
  }

  testWidgets('Business details show the correct information', (tester) async {
    await tester.pumpWidget(host(business));

    expect(find.text('Business details'), findsOneWidget);
    expect(find.text('Demo Café'), findsOneWidget);
    expect(find.text('Food & Beverage'), findsOneWidget);
    expect(find.text('Fictional test address'), findsOneWidget);
    expect(
      find.text('A fictional café used for interface testing.'),
      findsOneWidget,
    );
    expect(find.text('Promotions'), findsOneWidget);
    expect(find.text('Business vouchers'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Landmark details exclude business-only sections', (
    tester,
  ) async {
    await tester.pumpWidget(host(landmark));

    expect(find.text('Landmark details'), findsOneWidget);
    expect(find.text('Demo Heritage Point'), findsOneWidget);
    expect(find.text('About this landmark'), findsOneWidget);
    expect(find.text('Address not provided.'), findsOneWidget);
    expect(find.text('Promotions'), findsNothing);
    expect(find.text('Business vouchers'), findsNothing);
  });

  testWidgets('Missing description has an honest fallback', (tester) async {
    const incomplete = MapLocation(
      id: 'incomplete',
      type: MapLocationType.business,
      title: 'Incomplete demo',
      latitude: 3,
      longitude: 101,
    );

    await tester.pumpWidget(host(incomplete));

    expect(find.text('Not specified.'), findsOneWidget);
    expect(find.text('Address not provided.'), findsOneWidget);
    expect(find.text('Description not provided yet.'), findsOneWidget);
  });

  testWidgets('Close button calls the supplied action', (tester) async {
    var closed = false;

    await tester.pumpWidget(host(business, onClose: () => closed = true));

    await tester.tap(find.byTooltip('Close details'));

    expect(closed, isTrue);
  });

  testWidgets('business details display the supplied voucher section', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapLocationDetails(
            location: business,
            onClose: () {},
            voucherSection: const Text('Injected voucher section'),
          ),
        ),
      ),
    );

    expect(find.text('Injected voucher section'), findsOneWidget);
    expect(
      find.text('Voucher availability is not connected for this business.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('landmarks do not display a supplied business voucher section', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapLocationDetails(
            location: landmark,
            onClose: () {},
            voucherSection: const Text('Injected voucher section'),
          ),
        ),
      ),
    );

    expect(find.text('Injected voucher section'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigation button calls the supplied action', (tester) async {
    var navigationRequested = false;

    await tester.pumpWidget(
      host(business, onNavigate: () => navigationRequested = true),
    );

    final button = find.byKey(const ValueKey('navigate-location-button'));

    expect(button, findsOneWidget);

    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();

    expect(navigationRequested, isTrue);
  });
}
