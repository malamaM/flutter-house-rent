import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:house_rent/screens/home/explore.dart' as house_explore;
import 'package:house_rent/screens/home/saved_houses_screen.dart';

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
      padding: const EdgeInsets.symmetric(vertical: 15),
      margin: const EdgeInsets.only(bottom: 25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
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
                    // Navigate to Home
                    Navigator.popUntil(context, (route) => route.isFirst);
                  } else if (item == 'home_mark') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SavedHousesScreen()),
                    );
                  }
                },
                child: SvgPicture.asset(
                  'assets/icons/$item.svg',
                  color: bottomBarItems.indexOf(item) == currentIndex
                      ? Theme.of(context).primaryColor
                      : Colors.grey.withOpacity(0.5),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
