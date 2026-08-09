import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:house_rent/screens/home/explore.dart' as house_explore;
import 'package:house_rent/screens/home/saved_houses_screen.dart';
import 'package:house_rent/theme/app_colors.dart';

class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  
  final bottomBarItems = [
    'home',
    'home_search',
    'notification',
    'chat',
    'home_mark'
  ];

  CustomBottomNavigationBar({Key? key, this.currentIndex = 0}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: bottomBarItems
              .map(
                (item) => GestureDetector(
                  onTap: () {
                    if (item == 'home_search') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const house_explore.Explore()),
                      );
                    } else if (item == 'home') {
                      Navigator.popUntil(context, (route) => route.isFirst);
                    } else if (item == 'home_mark') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SavedHousesScreen()),
                      );
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: bottomBarItems.indexOf(item) == currentIndex 
                        ? AppColors.primary 
                        : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: SvgPicture.asset(
                      'assets/icons/$item.svg',
                      width: 24,
                      height: 24,
                      color: bottomBarItems.indexOf(item) == currentIndex
                            ? Colors.white
                            : AppColors.textSecondary,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
