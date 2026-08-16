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
  final Set<int> _renewing = {};

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

  Future<void> _renew(House house) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renew this listing?'),
        content: Text(
            '“${house.name}” will remain visible to renters for another 30 days.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Renew listing')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _renewing.add(house.id));
    final renewed = await House.renewListing(house.id);
    if (!mounted) return;
    if (renewed) {
      setState(() {
        _renewing.remove(house.id);
        _reload(forceRefresh: true);
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing renewed for 30 days')));
    } else {
      setState(() => _renewing.remove(house.id));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not renew this listing. Try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('My listings'),
            Text('Manage your published properties',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                return Column(
                  children: [
                    PropertyCard(
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
                    ),
                    _ListingLifecycleBar(
                      house: house,
                      renewing: _renewing.contains(house.id),
                      onRenew: () => _renew(house),
                    ),
                  ],
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

class _ListingLifecycleBar extends StatelessWidget {
  const _ListingLifecycleBar({
    required this.house,
    required this.renewing,
    required this.onRenew,
  });

  final House house;
  final bool renewing;
  final VoidCallback onRenew;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final urgent = house.isArchived || house.daysUntilExpiry <= 3;
    final label = house.isArchived
        ? 'Archived after 30 days'
        : house.daysUntilExpiry == 0
            ? 'Expires today'
            : '${house.daysUntilExpiry} days remaining';
    return Container(
      margin: const EdgeInsets.only(top: 7),
      padding: const EdgeInsets.fromLTRB(13, 8, 9, 8),
      decoration: BoxDecoration(
        color: urgent ? colors.errorContainer : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: urgent
                ? colors.error.withValues(alpha: .25)
                : colors.outlineVariant),
      ),
      child: Row(children: [
        Icon(house.isArchived ? Icons.inventory_2_outlined : Icons.schedule,
            size: 17, color: urgent ? colors.onErrorContainer : colors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  color: urgent
                      ? colors.onErrorContainer
                      : colors.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ),
        if (house.canRenew)
          TextButton.icon(
            onPressed: renewing ? null : onRenew,
            icon: renewing
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Renew'),
          ),
      ]),
    );
  }
}
