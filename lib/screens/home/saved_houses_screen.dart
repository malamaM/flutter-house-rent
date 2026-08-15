import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/screens/details/details.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:house_rent/widgets/custom_bottom_navigation_bar.dart';
import 'package:house_rent/widgets/property_card.dart';
import 'package:house_rent/widgets/screen_state.dart';

class SavedHousesScreen extends StatefulWidget {
  const SavedHousesScreen({Key? key}) : super(key: key);

  @override
  State<SavedHousesScreen> createState() => _SavedHousesScreenState();
}

class _SavedHousesScreenState extends State<SavedHousesScreen> {
  late Future<List<House>> houses;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload({bool forceRefresh = false}) =>
      houses = House.fetchSavedHouses(forceRefresh: forceRefresh);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saved homes'),
            Text('Your shortlist, all in one place',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: FutureBuilder<List<House>>(
        future: houses,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const PropertyListSkeleton();
          if (snapshot.hasError) {
            return ScreenState(
              icon: Icons.lock_outline_rounded,
              title: 'Sign in to see saved homes',
              message:
                  'Your saved properties will appear here whenever you return.',
              actionLabel: 'Try again',
              onAction: () => setState(_reload),
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 112),
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
      bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 2),
    );
  }
}
