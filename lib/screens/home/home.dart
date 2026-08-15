import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/screens/home/explore.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:house_rent/widgets/best_offer.dart';
import 'package:house_rent/widgets/all_homes.dart';
import 'package:house_rent/widgets/cache_status_banner.dart';
import 'package:house_rent/widgets/categories.dart';
import 'package:house_rent/widgets/custom_app_bar.dart';
import 'package:house_rent/widgets/custom_bottom_navigation_bar.dart';
import 'package:house_rent/widgets/recommended_house.dart';
import 'package:house_rent/widgets/search_input.dart';
import 'package:house_rent/widgets/welcome_text.dart';

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  String? selectedType;

  Map<String, String> get sectionFilters => {
        if (selectedType != null) 'type': selectedType!,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(),
      extendBody: true,
      body: RefreshIndicator(
        onRefresh: () async {
          await House.fetchHouses(forceRefresh: true);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 112),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WelcomeText(),
              const CacheStatusBanner(resource: 'houses'),
              SearchInput(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const Explore()))),
              const SizedBox(height: 24),
              const _SectionLabel(
                  title: 'Browse by type',
                  subtitle: 'A quicker way to narrow it down'),
              const SizedBox(height: 12),
              Categories(
                selectedType: selectedType,
                onSelected: (value) => setState(() => selectedType = value),
              ),
              const SizedBox(height: 28),
              RecommendedHouse(
                key: ValueKey('recommended:$selectedType'),
                filters: sectionFilters,
              ),
              const SizedBox(height: 28),
              BestOffer(
                key: ValueKey('deals:$selectedType'),
                filters: sectionFilters,
              ),
              const SizedBox(height: 28),
              AllHomes(
                key: ValueKey('all:$selectedType'),
                filters: sectionFilters,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const CustomBottomNavigationBar(),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionLabel({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 3),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
