import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/screens/details/details.dart';
import 'package:house_rent/screens/home/all_houses_screen.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:house_rent/widgets/property_card.dart';

class AllHomes extends StatefulWidget {
  final Map<String, String> filters;

  const AllHomes({Key? key, this.filters = const {}}) : super(key: key);

  @override
  State<AllHomes> createState() => _AllHomesState();
}

class _AllHomesState extends State<AllHomes> {
  String sort = 'newest';
  late Future<List<House>> houses;

  Map<String, String> get activeFilters => {
        ...widget.filters,
        'sort': sort,
      };

  @override
  void initState() {
    super.initState();
    houses = House.fetchHouses(filters: activeFilters);
  }

  void _setSort(String value) {
    if (value == sort) return;
    setState(() {
      sort = value;
      houses = House.fetchHouses(filters: activeFilters);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('All homes',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 3),
              Text('Explore every available rental',
                  style: Theme.of(context).textTheme.bodyMedium),
            ]),
          ),
          PopupMenuButton<String>(
            initialValue: sort,
            onSelected: _setSort,
            tooltip: 'Sort homes',
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'newest', child: Text('Newest first')),
              PopupMenuItem(value: 'price_low', child: Text('Lowest price')),
              PopupMenuItem(value: 'price_high', child: Text('Highest price')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(children: [
                Icon(Icons.sort_rounded, size: 18, color: AppColors.primary),
                SizedBox(width: 5),
                Text('Sort', style: TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AllHousesScreen(
                  title: 'All rental homes',
                  filters: activeFilters,
                ),
              ),
            ),
            child: const Text('View all'),
          ),
        ]),
        const SizedBox(height: 12),
        FutureBuilder<List<House>>(
          future: houses,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Column(
                children: List.generate(
                  2,
                  (_) => Container(
                    height: 172,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              );
            }
            final items = snapshot.data ?? [];
            if (items.isEmpty) return const SizedBox.shrink();
            return Column(
              children: items.take(5).map((house) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PropertyCard(
                    horizontal: true,
                    house: house,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => Details(house: house)),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ]),
    );
  }
}
