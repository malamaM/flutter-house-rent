import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/services/app_cache.dart';
import 'package:house_rent/screens/details/details.dart';
import 'package:house_rent/screens/home/all_houses_screen.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:house_rent/widgets/property_card.dart';

class BestOffer extends StatefulWidget {
  const BestOffer({Key? key}) : super(key: key);

  @override
  State<BestOffer> createState() => _BestOfferState();
}

class _BestOfferState extends State<BestOffer> {
  late Future<List<House>> offers;

  @override
  void initState() {
    super.initState();
    offers = House.fetchHouses(filters: {'status': 'For Sale'});
    AppCache.instance.refreshes.addListener(_handleRefresh);
  }

  void _handleRefresh() {
    if (AppCache.instance.refreshes.value?.resource == 'houses' && mounted) {
      final refreshedOffers =
          House.fetchHouses(filters: const {'status': 'For Sale'});
      setState(() {
        offers = refreshedOffers;
      });
    }
  }

  @override
  void dispose() {
    AppCache.instance.refreshes.removeListener(_handleRefresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Worth a closer look',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 3),
                    Text('Well-priced homes for sale',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AllHousesScreen(
                        title: 'Homes for sale',
                        filters: {'status': 'For Sale'}),
                  ),
                ),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<House>>(
            future: offers,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Column(
                  children: List.generate(
                      2,
                      (_) => Container(
                            height: 138,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(18)),
                          )),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty)
                return const SizedBox.shrink();
              return Column(
                children: snapshot.data!
                    .take(3)
                    .map((house) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: PropertyCard(
                            horizontal: true,
                            house: house,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => Details(house: house))),
                          ),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
