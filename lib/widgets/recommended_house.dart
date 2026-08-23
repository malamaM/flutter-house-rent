import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/navigation/haven_page_route.dart';
import 'package:house_rent/services/app_cache.dart';
import 'package:house_rent/screens/details/details.dart';
import 'package:house_rent/screens/home/all_houses_screen.dart';
import 'package:house_rent/widgets/property_card.dart';
import 'package:house_rent/widgets/screen_state.dart';
import 'package:house_rent/services/session_recommendation.dart';
import 'package:house_rent/services/app_feedback.dart';

class RecommendedHouse extends StatefulWidget {
  final Map<String, String> filters;
  final List<House>? initialHouses;

  const RecommendedHouse(
      {Key? key, this.filters = const {}, this.initialHouses})
      : super(key: key);

  @override
  State<RecommendedHouse> createState() => _RecommendedHouseState();
}

class _RecommendedHouseState extends State<RecommendedHouse> {
  Future<List<House>>? houses;
  List<House>? _settledHouses;

  Map<String, String> get recommendedFilters => {
        ...widget.filters,
        'recommended': '1',
      };

  @override
  void initState() {
    super.initState();
    _settledHouses = widget.initialHouses;
    houses = widget.initialHouses == null
        ? House.fetchHouses(filters: recommendedFilters)
        : null;
    AppCache.instance.refreshes.addListener(_handleRefresh);
    SessionRecommendation.instance.addListener(_handleSessionChange);
  }

  void _handleSessionChange() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant RecommendedHouse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialHouses != null &&
        !identical(widget.initialHouses, oldWidget.initialHouses)) {
      setState(() {
        _settledHouses = widget.initialHouses;
        houses = null;
      });
    }
  }

  void _handleRefresh() {
    if (AppCache.instance.refreshes.value?.resource == 'houses' && mounted) {
      final refreshedHouses = House.fetchHouses(filters: recommendedFilters);
      setState(() {
        _settledHouses = null;
        houses = refreshedHouses;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          title: 'Homes you may love',
          subtitle: 'Fresh picks based on what renters view most',
          onSeeAll: () => Navigator.push(
            context,
            HavenPageRoute(
              builder: (_) => AllHousesScreen(
                title: 'Recommended homes',
                filters: recommendedFilters,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: propertyCardCarouselHeight(context),
          child: FutureBuilder<List<House>>(
            future: houses,
            initialData: _settledHouses,
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
                        borderRadius: BorderRadius.circular(22)),
                  ),
                );
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return ScreenState(
                  icon: Icons.wifi_off_rounded,
                  title: 'Could not load homes',
                  message: snapshot.hasError
                      ? AppFeedback.messageFor(snapshot.error!,
                          fallback:
                              'Haven could not load your recommended homes.')
                      : 'Haven did not return any home information.',
                );
              }
              final items = SessionRecommendation.instance.rank(snapshot.data!);
              if (items.isEmpty) {
                return const ScreenState(
                  icon: Icons.home_work_outlined,
                  title: 'New homes coming soon',
                  message: 'There are no active properties to show yet.',
                );
              }
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
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onSeeAll;

  const _Header(
      {required this.title, required this.subtitle, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineMedium),
              ),
              TextButton(onPressed: onSeeAll, child: const Text('View all')),
            ],
          ),
          const SizedBox(height: 3),
          Text(subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
