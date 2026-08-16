import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/theme/app_colors.dart';

class CacheStatusBanner extends StatelessWidget {
  final String? resource;

  const CacheStatusBanner({Key? key, this.resource}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<HouseCacheState>(
      valueListenable: House.cacheState,
      builder: (context, state, _) {
        final relevant = resource == null || state.resource == resource;
        if (!relevant || !state.servedFromCache || !state.isStale) {
          return const SizedBox.shrink();
        }
        return Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.offline_bolt_outlined,
                  color: AppColors.primary, size: 19),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Showing saved results${_age(state.updatedAt)} while Haven Zambia refreshes.',
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _age(DateTime? updatedAt) {
    if (updatedAt == null) return '';
    final elapsed = DateTime.now().difference(updatedAt);
    if (elapsed.inMinutes < 2) return ' from moments ago';
    if (elapsed.inHours < 1) return ' from ${elapsed.inMinutes} minutes ago';
    if (elapsed.inDays < 1) return ' from ${elapsed.inHours} hours ago';
    return ' from ${elapsed.inDays} days ago';
  }
}
