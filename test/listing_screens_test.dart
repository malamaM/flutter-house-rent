import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/screens/my_listings/create_listing_screen.dart';
import 'package:house_rent/screens/my_listings/edit_listing.dart';
import 'package:house_rent/services/app_cache.dart';
import 'package:house_rent/widgets/demand_badge.dart';
import 'package:house_rent/widgets/custom_bottom_navigation_bar.dart';
import 'package:house_rent/widgets/lister_trust_badges.dart';
import 'package:house_rent/widgets/recommended_house.dart';
import 'package:house_rent/widgets/property_card.dart';
import 'package:house_rent/theme/app_theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('all listings use monthly rental pricing', () {
    final rental = House(
      'Rental home',
      'Lusaka',
      '',
      status: 'For Rent',
      priceRental: 6500,
    );

    expect(rental.listingStatusLabel, 'For Rent');
    expect(formatPropertyPrice(rental), 'K6,500 / month');
  });

  test('listing verification follows the current owner status', () {
    final staleBadge = House.fromMap({
      'id': 1,
      'user': {
        'id': 9,
        'is_verified': false,
        'verification_status': 'unverified',
        'trust_badges': [
          {'type': 'verified'}
        ],
      },
    });
    final verifiedOwner = House.fromMap({
      'id': 2,
      'user': {
        'id': 9,
        'is_verified': false,
        'verification_status': 'verified',
      },
    });

    expect(staleBadge.isVerified, isFalse);
    expect(verifiedOwner.isVerified, isTrue);
  });

  Widget app(Widget child) =>
      MaterialApp(theme: AppTheme.lightTheme, home: child);

  testWidgets('create listing opens without a framework exception',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(const CreateListingScreen()));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Create listing'), findsOneWidget);
  });

  testWidgets('edit listing opens without a framework exception',
      (tester) async {
    final house = House(
      'Test home',
      'Lusaka',
      '',
      id: 1,
      bedrooms: 3,
      bathrooms: 2,
      size: 120,
    );

    await tester.pumpWidget(app(EditListingScreen(house: house)));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Edit Listing'), findsOneWidget);
  });

  testWidgets('demand badges stay hidden until a listing qualifies',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: DemandBadge(demandLabel: null)),
    ));
    expect(find.text('Hot right now'), findsNothing);
    expect(find.text('Popular recently'), findsNothing);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: DemandBadge(demandLabel: 'hot')),
    ));
    expect(find.text('Hot right now'), findsOneWidget);
  });

  testWidgets('verification and top-rated badges remain distinct',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ListerTrustBadges(verified: true, topRated: false)),
    ));
    expect(find.text('Identity verified'), findsOneWidget);
    expect(find.text('Top rated'), findsNothing);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ListerTrustBadges(verified: false, topRated: true)),
    ));
    expect(find.text('Identity verified'), findsNothing);
    expect(find.text('Top rated'), findsOneWidget);
  });

  testWidgets('recommended homes handles a cache refresh synchronously',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: RecommendedHouse())),
    ));
    AppCache.instance.announce('houses', 'restart-regression');
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('bottom navigation exposes Haven Tours', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
          bottomNavigationBar: CustomBottomNavigationBar(currentIndex: 2)),
    ));

    expect(find.text('Tours'), findsOneWidget);
    expect(find.byIcon(Icons.smart_display_rounded), findsOneWidget);
  });
}
