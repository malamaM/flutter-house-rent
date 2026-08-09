import 'package:flutter/material.dart';

import 'package:house_rent/widgets/custom_bottom_navigation_bar.dart';
import 'package:house_rent/widgets/recommended_house.dart';
import 'package:house_rent/widgets/custom_app_bar.dart';
import 'package:house_rent/widgets/search_input.dart';
import 'package:house_rent/widgets/welcome_text.dart';
import 'package:house_rent/widgets/categories.dart';
import 'package:house_rent/widgets/best_offer.dart';
import 'package:house_rent/screens/home/explore.dart';
import 'package:house_rent/theme/app_colors.dart';

class Home extends StatelessWidget {
  const Home({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(),
      extendBody: true, // This allows the body to go under the floating bottom nav bar
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100), // Add padding for bottom nav
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WelcomeText(),
            SearchInput(onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Explore()),
              );
            }),
            const SizedBox(height: 16),
            const Categories(),
            const SizedBox(height: 16),
            const RecommendedHouse(),
            const BestOffer(),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavigationBar(),
    );
  }
}
