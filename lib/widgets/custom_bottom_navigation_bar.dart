import 'package:flutter/material.dart';
import 'package:house_rent/theme/app_colors.dart';

class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onSelected;

  const CustomBottomNavigationBar({
    Key? key,
    required this.currentIndex,
    this.onSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const items = <_NavItem>[
      _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
      _NavItem(Icons.travel_explore_outlined, Icons.travel_explore_rounded,
          'Explore'),
      _NavItem(
          Icons.smart_display_outlined, Icons.smart_display_rounded, 'Tours'),
      _NavItem(Icons.bookmark_border_rounded, Icons.bookmark_rounded, 'Saved'),
    ];

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white12, width: .8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3317332D),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
            BoxShadow(
              color: Color(0x18FFFFFF),
              blurRadius: 1,
              offset: Offset(0, -1),
            ),
          ],
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final selected = index == currentIndex;
            return Expanded(
              child: InkWell(
                onTap: () => onSelected?.call(index),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin:
                      const EdgeInsets.symmetric(horizontal: 3, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: .12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        selected ? item.selectedIcon : item.icon,
                        color: selected ? Colors.white : Colors.white60,
                        size: 22,
                      ),
                      if (selected) ...[
                        const SizedBox(width: 7),
                        Text(
                          item.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavItem(this.icon, this.selectedIcon, this.label);
}
