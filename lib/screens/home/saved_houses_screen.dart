import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/services/app_cache.dart';
import 'package:house_rent/screens/details/details.dart';
import 'package:house_rent/widgets/property_card.dart';
import 'package:house_rent/widgets/screen_state.dart';
import 'package:house_rent/widgets/cache_status_banner.dart';

class SavedHousesScreen extends StatefulWidget {
  const SavedHousesScreen({Key? key}) : super(key: key);

  @override
  State<SavedHousesScreen> createState() => _SavedHousesScreenState();
}

class _SavedHousesScreenState extends State<SavedHousesScreen> {
  late Future<List<House>> houses;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    AppCache.instance.refreshes.addListener(_handleTabRefresh);
    _reload();
  }

  void _handleTabRefresh() {
    final event = AppCache.instance.refreshes.value;
    if (!mounted || event == null) return;
    if (event.resource == 'saved_houses') {
      // Confirmed online changes invalidate this cache first; queued offline
      // changes update it in place. A normal read handles both instantly.
      setState(_reload);
      return;
    }
    if (event.resource != 'tab-refresh' || event.logicalKey != '3') {
      return;
    }
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
    }
    setState(() => _reload(forceRefresh: true));
  }

  @override
  void dispose() {
    AppCache.instance.refreshes.removeListener(_handleTabRefresh);
    _scrollController.dispose();
    super.dispose();
  }

  void _reload({bool forceRefresh = false}) {
    houses = House.fetchSavedHouses(forceRefresh: forceRefresh);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Saved homes'),
            Text('Your shortlist, all in one place',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: Column(children: [
        const CacheStatusBanner(resource: 'saved_houses'),
        Expanded(
          child: FutureBuilder<List<House>>(
            future: houses,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const PropertyListSkeleton();
              }
              if (snapshot.hasError) {
                return ScreenState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Saved homes are unavailable offline',
                  message:
                      'Connect once to prepare your shortlist for offline use.',
                  actionLabel: 'Try again',
                  onAction: () => setState(() {
                    _reload(forceRefresh: true);
                  }),
                );
              }
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return const ScreenState(
                  icon: Icons.bookmark_add_outlined,
                  title: 'Build your shortlist',
                  message:
                      'Tap the bookmark on any property and it will be waiting here.',
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  setState(() => _reload(forceRefresh: true));
                  await houses;
                },
                child: ListView.separated(
                  controller: _scrollController,
                  key: const PageStorageKey('saved-houses'),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 112),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final house = items[index];
                    return PropertyCard(
                      horizontal: true,
                      house: house,
                      onTap: () =>
                          Navigator.push(context, Details.route(house)),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ]),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    );
  }
}
