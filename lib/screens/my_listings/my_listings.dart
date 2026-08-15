import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/screens/details/details.dart';
import 'package:house_rent/screens/my_listings/create_listing_screen.dart';
import 'package:house_rent/screens/my_listings/edit_listing.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:house_rent/widgets/property_card.dart';
import 'package:house_rent/widgets/screen_state.dart';

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({Key? key}) : super(key: key);

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  late Future<List<House>> listings;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload({bool forceRefresh = false}) {
    listings = House.fetchMyHouses(forceRefresh: forceRefresh);
  }

  Future<void> _create() async {
    final created = await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const CreateListingScreen()));
    if (created == true && mounted) {
      setState(() {
        _reload(forceRefresh: true);
      });
    }
  }

  Future<void> _edit(House house) async {
    final changed = await Navigator.push(context,
        MaterialPageRoute(builder: (_) => EditListingScreen(house: house)));
    if (changed == true && mounted) {
      setState(() {
        _reload(forceRefresh: true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My listings'),
            Text('Manage your published properties',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: FutureBuilder<List<House>>(
        future: listings,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const PropertyListSkeleton();
          }
          if (snapshot.hasError) {
            return ScreenState(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load your listings',
              message: 'Check your connection and try again.',
              actionLabel: 'Try again',
              onAction: () => setState(() {
                _reload(forceRefresh: true);
              }),
            );
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return ScreenState(
              icon: Icons.add_home_work_outlined,
              title: 'List your first property',
              message: 'Reach people looking for a new place across Zambia.',
              actionLabel: 'Create listing',
              onAction: _create,
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _reload(forceRefresh: true));
              await listings;
            },
            child: ListView.separated(
              key: const PageStorageKey('my-listings'),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final house = items[index];
                return PropertyCard(
                  horizontal: true,
                  showSave: false,
                  house: house,
                  secondaryLabel: 'Edit listing',
                  onSecondaryAction: () => _edit(house),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              Details(house: house, isOwnerView: true))),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New listing'),
      ),
    );
  }
}
