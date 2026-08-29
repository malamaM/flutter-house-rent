import 'package:flutter/material.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:house_rent/widgets/glass_surface.dart';

class SearchInput extends StatelessWidget {
  final VoidCallback? onTap;
  final String hint;

  const SearchInput(
      {Key? key, this.onTap, this.hint = 'Search by area or property'})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final darkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(16),
        tint: Colors.white,
        borderColor: const Color(0xFFE2E7E3),
        blur: 0,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 58,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 7, 0),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded,
                        color:
                            darkMode ? Colors.white : const Color(0xFF17211E),
                        size: 23),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(hint,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: const Color(0xFF6D7773)))),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.tune_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
