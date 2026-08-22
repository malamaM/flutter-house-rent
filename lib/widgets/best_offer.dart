import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/screens/details/details.dart';
import 'package:house_rent/screens/home/all_houses_screen.dart';
import 'package:house_rent/services/app_cache.dart';
import 'package:house_rent/widgets/property_card.dart';
import 'package:house_rent/services/session_recommendation.dart';

class BestOffer extends StatefulWidget {
  final Map<String, String> filters;
  final List<House>? initialHouses;

  const BestOffer({Key? key, this.filters = const {}, this.initialHouses})
      : super(key: key);

  @override
  State<BestOffer> createState() => _BestOfferState();
}

class _BestOfferState extends State<BestOffer> {
  Future<List<House>>? offers;
  List<House>? _settledOffers;

  Map<String, String> get dealFilters => {...widget.filters, 'deal': '1'};

  @override
  void initState() {
    super.initState();
    _settledOffers = widget.initialHouses;
    offers = widget.initialHouses == null
        ? House.fetchHouses(filters: dealFilters)
        : null;
    AppCache.instance.refreshes.addListener(_handleRefresh);
    SessionRecommendation.instance.addListener(_handleSessionChange);
  }

  void _handleSessionChange() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant BestOffer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialHouses != null &&
        !identical(widget.initialHouses, oldWidget.initialHouses)) {
      setState(() {
        _settledOffers = widget.initialHouses;
        offers = null;
      });
    }
  }

  void _handleRefresh() {
    if (AppCache.instance.refreshes.value?.resource == 'houses' && mounted) {
      final refreshedOffers = House.fetchHouses(filters: dealFilters);
      setState(() {
        _settledOffers = null;
        offers = refreshedOffers;
      });
    }
  }

  @override
  void dispose() {
    AppCache.instance.refreshes.removeListener(_handleRefresh);
    SessionRecommendation.instance.removeListener(_handleSessionChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Worth a closer look',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 3),
              Text('Distinctively marked deals worth considering',
                  style: Theme.of(context).textTheme.bodyMedium),
            ]),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AllHousesScreen(
                  title: 'Rental deals',
                  filters: dealFilters,
                ),
              ),
            ),
            child: const Text('View all'),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 355,
        child: FutureBuilder<List<House>>(
          future: offers,
          initialData: _settledOffers,
          builder: (context, snapshot) {
            if (snapshot.data == null &&
                snapshot.connectionState == ConnectionState.waiting) {
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: 2,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (_, __) => Container(
                  width: 278,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
              );
            }
            final items =
                SessionRecommendation.instance.rank(snapshot.data ?? []);
            if (items.isEmpty) return const SizedBox.shrink();
            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: items.take(8).length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final house = items[index];
                return PropertyCard(
                  house: house,
                  onTap: () => Navigator.push(context, Details.route(house)),
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}
