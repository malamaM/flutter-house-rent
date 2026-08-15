import 'package:flutter/material.dart';
import 'package:house_rent/theme/app_colors.dart';

class SearchInput extends StatelessWidget {
  final VoidCallback? onTap;
  final String hint;

  const SearchInput(
      {Key? key, this.onTap, this.hint = 'Search by area or property'})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 58,
            padding: const EdgeInsets.fromLTRB(16, 0, 7, 0),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.divider),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded,
                    color: AppColors.textPrimary, size: 23),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(hint,
                        style: Theme.of(context).textTheme.bodyMedium)),
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
    );
  }
}
