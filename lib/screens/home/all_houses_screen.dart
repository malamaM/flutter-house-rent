import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/screens/details/details.dart';
import 'package:house_rent/widgets/property_card.dart';
import 'package:house_rent/widgets/screen_state.dart';
import 'package:house_rent/services/session_recommendation.dart';

class AllHousesScreen extends StatefulWidget {
  final String title;
  final Map<String, String>? filters;

  const AllHousesScreen({Key? key, required this.title, this.filters})
      : super(key: key);

  @override
  State<AllHousesScreen> createState() => _AllHousesScreenState();
}

class _AllHousesScreenState extends State<AllHousesScreen> {
  late Future<List<House>> houses;

  @override
  void initState() {
    super.initState();
    // A full-results screen should be authoritative rather than remaining on
    // a recently cached, shorter homepage snapshot.
    _reload(forceRefresh: true);
    SessionRecommendation.instance.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (mounted && _usesRelevance) setState(() {});
  }

  bool get _usesRelevance =>
      widget.filters?['sort'] == null || widget.filters?['sort'] == 'relevance';

  @override
  void dispose() {
    SessionRecommendation.instance.removeListener(_sessionChanged);
    super.dispose();
  }

  void _reload({bool forceRefresh = false}) {
    houses = House.fetchHouses(
      filters: widget.filters ?? {},
      forceRefresh: forceRefresh,
    );
  }

  Future<void> _refresh() async {
    setState(() => _reload(forceRefresh: true));
    await houses;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<List<House>>(
        future: houses,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const PropertyListSkeleton();
          }
          if (snapshot.hasError) {
            return ScreenState(
              icon: Icons.cloud_off_outlined,
              title: 'We could not load these homes',
              message:
                  'Check that the property service is available, then try again.',
              actionLabel: 'Try again',
              onAction: () => setState(() {
                _reload(forceRefresh: true);
              }),
            );
          }
          final rawItems = snapshot.data ?? <House>[];
          final items = _usesRelevance
              ? SessionRecommendation.instance.rank(rawItems)
              : rawItems;
          if (items.isEmpty) {
            return const ScreenState(
              icon: Icons.search_off_rounded,
              title: 'No matching homes',
              message: 'Try broadening your search or changing a few filters.',
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              key: PageStorageKey('all-houses-${widget.title}'),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final house = items[index];
                return PropertyCard(
                  horizontal: true,
                  house: house,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => Details(house: house))),
                );
              },
            ),
          );
        },
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    );
  }
}
