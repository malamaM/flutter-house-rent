import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/screens/details/details.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:house_rent/widgets/property_card.dart';
import 'package:house_rent/widgets/screen_state.dart';

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
    _reload();
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
          final items = snapshot.data ?? [];
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
      backgroundColor: AppColors.background,
    );
  }
}
