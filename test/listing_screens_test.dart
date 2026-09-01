import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/models/marketplace.dart';
import 'package:house_rent/screens/my_listings/create_listing_screen.dart';
import 'package:house_rent/screens/my_listings/edit_listing.dart';
import 'package:house_rent/screens/my_listings/listing_preview_screen.dart';
import 'package:house_rent/widgets/all_homes.dart';
import 'package:house_rent/services/app_cache.dart';
import 'package:house_rent/widgets/demand_badge.dart';
import 'package:house_rent/widgets/categories.dart';
import 'package:house_rent/widgets/custom_bottom_navigation_bar.dart';
import 'package:house_rent/widgets/lister_trust_badges.dart';
import 'package:house_rent/widgets/recommended_house.dart';
import 'package:house_rent/widgets/best_offer.dart';
import 'package:house_rent/widgets/property_card.dart';
import 'package:house_rent/theme/app_theme.dart';
import 'package:house_rent/theme/haven_responsive_media.dart';
import 'package:house_rent/widgets/custom_app_bar.dart';
import 'package:house_rent/widgets/house_info.dart';
import 'package:house_rent/widgets/house_amenities.dart';
import 'package:house_rent/widgets/content_intro.dart';
import 'package:house_rent/screens/profile/marketplace_hub_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  test('public listing notices survive parsing and cache round trips', () {
    final house = House.fromMap({
      'id': 12,
      'title': 'A home needing a closer look',
      'public_notice': {
        'label': 'Details may need confirmation',
        'message': 'Confirm the price before arranging a viewing.',
      },
    });

    expect(house.hasPublicNotice, isTrue);
    expect(house.publicNoticeLabel, 'Details may need confirmation');
    expect(House.fromMap(house.toCacheMap()).publicNoticeMessage,
        'Confirm the price before arranging a viewing.');
  });

  testWidgets('public listing notices are visible on the property introduction',
      (tester) async {
    final house = House.fromMap({
      'id': 13,
      'title': 'A home with a community notice',
      'city': 'Lusaka',
      'public_notice': {
        'label': 'Details may need confirmation',
        'message': 'Confirm the price before arranging a viewing.',
      },
    });

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: ContentIntro(house: house)),
    ));

    expect(find.text('Details may need confirmation'), findsOneWidget);
    expect(find.text('Confirm the price before arranging a viewing.'),
        findsOneWidget);
  });

  testWidgets('draft listing preview stays usable on a phone-sized screen',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const draft = ListingDraftPreviewData(
      title: 'A bright garden home',
      description: 'A comfortable home close to everyday amenities.',
      location: 'Lusaka, Kabulonga',
      province: 'Lusaka',
      propertyType: 'House',
      price: 5200,
      bedrooms: 2,
      bathrooms: 1,
      size: 90,
      parking: 1,
      qualityScore: 86,
      cover: null,
      gallery: [],
      amenities: ['Security', 'Garden'],
    );

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const ListingPreviewScreen(draft: draft),
    ));
    await tester.pumpAndSettle();

    expect(find.text('A bright garden home'), findsOneWidget);
    expect(find.text('86% listing score'), findsOneWidget);
    expect(find.text('Property details'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('marketplace models preserve read receipts and viewing details', () {
    final message = ChatMessage.fromMap({
      'id': 4,
      'body': 'See you then',
      'is_mine': true,
      'created_at': '2026-08-29T10:00:00Z',
      'delivered_at': '2026-08-29T10:00:01Z',
      'read_at': '2026-08-29T10:01:00Z',
    });
    final incoming = ChatMessage.fromMap({
      'id': 5,
      'body': 'I can show you around.',
      'is_mine': '0',
    });
    final viewing = ViewingSummary.fromMap({
      'id': 8,
      'status': 'confirmed',
      'viewer_role': 'renter',
      'requested_at': '2026-08-30T12:00:00Z',
      'responded_at': '2026-08-29T11:00:00Z',
      'note': 'I will bring my sister.',
      'lister_response': 'Please call when you arrive.',
      'house': {
        'title': 'Kabulonga Home',
        'image-cover': 'houses/cover.webp',
        'district': 'Kabulonga',
        'city': 'Lusaka',
      },
      'lister': {'first_name': 'Mary', 'last_name': 'Banda'},
    });

    expect(message.readAt, isNotNull);
    expect(message.deliveredAt, isNotNull);
    expect(message.isMine, isTrue);
    expect(incoming.isMine, isFalse);
    expect(viewing.imagePath, 'houses/cover.webp');
    expect(viewing.otherPartyName, 'Mary Banda');
    expect(viewing.note, 'I will bring my sister.');
    expect(viewing.listerResponse, 'Please call when you arrive.');
    expect(viewing.respondedAt, isNotNull);
  });

  testWidgets('house amenities are parsed and shown as detail cards',
      (tester) async {
    final house = House.fromMap({
      'id': 7,
      'title': 'Garden home',
      'amenities': [
        {'id': 4, 'key': 'security', 'name': 'Security'},
        {'id': 10, 'key': 'garden', 'name': 'Garden'},
      ],
    });

    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: HouseAmenities(house: house))));

    expect(house.amenities.map((amenity) => amenity.key),
        containsAll(['security', 'garden']));
    expect(find.text('Amenities'), findsOneWidget);
    expect(find.text('Security'), findsOneWidget);
    expect(find.text('Garden'), findsOneWidget);
  });

  testWidgets('property facts and amenities are fully visible without swiping',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final house = House.fromMap({
      'id': 8,
      'title': 'Complete home',
      'bedrooms': 3,
      'self_contained_bedrooms': 2,
      'bathrooms': 2,
      'size': 140,
      'car_garage': 1,
      'type': 'Apartment',
      'amenities': [
        {'id': 1, 'key': 'security', 'name': 'Security'},
        {'id': 2, 'key': 'garden', 'name': 'Garden'},
        {'id': 3, 'key': 'gym', 'name': 'Gym'},
      ],
    });

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(children: [
            HouseInfo(house: house),
            HouseAmenities(house: house),
          ]),
        ),
      ),
    ));

    expect(
      find.descendant(
        of: find.byType(HouseInfo),
        matching: find.byType(ListView),
      ),
      findsNothing,
    );
    expect(find.text('Property type'), findsNothing);
    expect(find.text('See more'), findsOneWidget);
    await tester.tap(find.text('See more'));
    await tester.pumpAndSettle();

    expect(find.text('Bedrooms'), findsNWidgets(2));
    expect(find.text('Property details'), findsOneWidget);
    expect(find.text('All property details'), findsOneWidget);
    expect(find.text('Bathrooms'), findsNWidgets(2));
    expect(house.selfContainedBedrooms, 2);
    expect(find.text('Self-contained bedrooms'), findsNWidgets(2));
    expect(find.text('Apartment'), findsOneWidget);
    expect(find.text('Property type'), findsOneWidget);
    expect(find.text('Parking'), findsOneWidget);
    expect(find.text('Security'), findsOneWidget);
    expect(find.text('Garden'), findsOneWidget);
    expect(find.text('Gym'), findsNothing);
    expect(find.text('View all (3)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('property-details-close-pill')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View all (3)'));
    await tester.pumpAndSettle();
    expect(find.text('Gym'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('zero self-contained bedrooms stay hidden from property details',
      (tester) async {
    final house = House.fromMap({
      'id': 80,
      'title': 'Standard bedroom home',
      'bedrooms': 2,
      'self_contained_bedrooms': 0,
      'bathrooms': 1,
      'type': 'House',
    });

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: HouseInfo(house: house)),
    ));

    expect(find.text('Self-contained bedrooms'), findsNothing);
    await tester.tap(find.text('See more'));
    await tester.pumpAndSettle();
    expect(find.text('Self-contained bedrooms'), findsNothing);
  });

  testWidgets('additional amenities open in a complete bottom sheet',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final house = House.fromMap({
      'id': 9,
      'title': 'Amenity rich home',
      'amenities': [
        {'id': 1, 'key': 'security', 'name': 'Security'},
        {'id': 2, 'key': 'garden', 'name': 'Garden'},
        {'id': 3, 'key': 'gym', 'name': 'Gym'},
        {'id': 4, 'key': 'garage', 'name': 'Garage'},
        {'id': 5, 'key': 'swimming_pool', 'name': 'Swimming pool'},
      ],
    });

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: HouseAmenities(house: house)),
    ));

    expect(find.text('View all (5)'), findsOneWidget);
    expect(find.text('Swimming pool'), findsNothing);

    await tester.tap(find.text('View all (5)'));
    await tester.pumpAndSettle();

    expect(find.text('All amenities'), findsOneWidget);
    expect(find.text('5 included with this home'), findsOneWidget);
    expect(find.text('Swimming pool'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

  testWidgets(
      'Haven hub groups related tabs and preserves saved-search deep links',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(const MarketplaceHubScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Viewings'), findsOneWidget);
    expect(find.text('Updates'), findsNothing);
    expect(find.text('Saved searches'), findsNothing);
    expect(find.text('Paid reservations'), findsNothing);

    await tester.tap(find.text('Activity'));
    await tester.pump();
    expect(find.text('Updates'), findsOneWidget);
    expect(find.text('Saved searches'), findsOneWidget);
    expect(find.text('Messages'), findsNothing);
    expect(find.text('Viewings'), findsNothing);
    expect(find.text('Paid reservations'), findsNothing);

    await tester.pumpWidget(app(const MarketplaceHubScreen(
      key: ValueKey('saved-searches-entry'),
      initialTab: 3,
      selectSavedSearch: true,
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Saved searches'), findsOneWidget);
    expect(find.text('Save a search'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

  testWidgets('closer look shows an empty state instead of a blank carousel',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BestOffer(initialHouses: <House>[]),
        ),
      ),
    ));

    expect(find.text('Worth a closer look'), findsOneWidget);
    expect(find.text('New homes coming soon'), findsOneWidget);
  });

  testWidgets('bottom navigation exposes Haven Tours', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
          bottomNavigationBar: CustomBottomNavigationBar(currentIndex: 2)),
    ));

    expect(find.text('Tours'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.play_rectangle_fill), findsOneWidget);
  });

  testWidgets('compact home cards support large Android text scaling',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final house = House(
      'A comfortably long property name',
      'Lusaka, Kabulonga',
      '',
      bedrooms: 3,
      bathrooms: 2,
      size: 145,
      priceRental: 12500,
      isVerified: true,
    );
    double? effectiveTextScale;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.5)),
        child: HavenResponsiveMedia(
          child: Builder(
            builder: (context) {
              effectiveTextScale =
                  MediaQuery.textScalerOf(context).scale(14) / 14;
              return Scaffold(
                appBar: const CustomAppBar(),
                bottomNavigationBar:
                    const CustomBottomNavigationBar(currentIndex: 0),
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      Categories(selectedType: null, onSelected: (_) {}),
                      HouseInfo(house: house),
                      Builder(
                        builder: (context) => SizedBox(
                          height: propertyCardCarouselHeight(context),
                          child: PropertyCard(house: house, onTap: () {}),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(effectiveTextScale, closeTo(1.35, .001));
    expect(
      MediaQuery.textScalerOf(tester.element(find.text('Bedrooms'))).scale(14) /
          14,
      closeTo(1.35, .001),
    );
    expect(
      MediaQuery.textScalerOf(tester.element(find.text('HAVEN ZAMBIA')))
              .scale(14) /
          14,
      closeTo(1.35, .001),
    );
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('zoomed Android layouts keep horizontal card content balanced',
      (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});

    final house = House(
      'Kafue River Townhouse',
      'Kafue',
      '',
      bedrooms: 2,
      bathrooms: 2,
      size: 130,
      priceRental: 5700,
      isVerified: true,
    );

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.5)),
        child: HavenResponsiveMedia(
          child: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  PropertyCard(horizontal: true, house: house, onTap: () {}),
                  const SizedBox(height: 20),
                  AllHomes(initialHouses: [house]),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    final bedY = tester.getCenter(find.byIcon(Icons.bed_outlined).first).dy;
    final bathY =
        tester.getCenter(find.byIcon(Icons.bathtub_outlined).first).dy;
    expect((bedY - bathY).abs(), lessThan(2));
    expect(tester.takeException(), isNull);
  });
}
