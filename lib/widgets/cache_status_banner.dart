import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';

class CacheStatusBanner extends StatelessWidget {
  final String? resource;

  const CacheStatusBanner({Key? key, this.resource}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<HouseCacheState>(
      valueListenable: House.cacheState,
      builder: (context, state, _) {
        final relevant = resource == null || state.resource == resource;
        if (!relevant ||
            !state.servedFromCache ||
            !state.isStale ||
            !state.refreshFailed) {
          return const SizedBox.shrink();
        }
        return Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(Icons.cloud_off_outlined,
                  color: Theme.of(context).colorScheme.primary, size: 19),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Connection unavailable. Showing saved results${_age(state.updatedAt)}.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
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
