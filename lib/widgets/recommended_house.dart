import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/screens/details/details.dart';
import 'package:house_rent/screens/home/all_houses_screen.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:house_rent/widgets/property_card.dart';
import 'package:house_rent/widgets/screen_state.dart';

class RecommendedHouse extends StatefulWidget {
  const RecommendedHouse({Key? key}) : super(key: key);

  @override
  State<RecommendedHouse> createState() => _RecommendedHouseState();
}

class _RecommendedHouseState extends State<RecommendedHouse> {
  late Future<List<House>> houses;

  @override
  void initState() {
    super.initState();
    houses = House.fetchHouses();
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
            MaterialPageRoute(
                builder: (_) =>
                    const AllHousesScreen(title: 'Recommended homes')),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 323,
          child: FutureBuilder<List<House>>(
            future: houses,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: 2,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (_, __) => Container(
                    width: 278,
                    decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(22)),
                  ),
                );
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return const ScreenState(
                  icon: Icons.wifi_off_rounded,
                  title: 'Could not load homes',
                  message: 'Check your connection and try again.',
                );
              }
              if (snapshot.data!.isEmpty) {
                return const ScreenState(
                  icon: Icons.home_work_outlined,
                  title: 'New homes coming soon',
                  message: 'There are no active properties to show yet.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: snapshot.data!.take(8).length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final house = snapshot.data![index];
                  return PropertyCard(
                    house: house,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => Details(house: house))),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 3),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          TextButton(onPressed: onSeeAll, child: const Text('View all')),
        ],
      ),
    );
  }
}
