import 'package:flutter/material.dart';
import 'package:house_rent/services/app_cache.dart';
import 'package:house_rent/services/network_status_service.dart';
import 'package:house_rent/services/offline_sync_service.dart';
import 'package:house_rent/services/recommendation_service.dart';

class OfflineStatusPill extends StatelessWidget {
  final VoidCallback? onTap;
  const OfflineStatusPill({super.key, this.onTap});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([
          NetworkStatusService.instance.availability,
          OfflineSyncService.instance.pendingCount,
          RecommendationService.instance.pendingCount,
        ]),
        builder: (context, _) {
          final network = NetworkStatusService.instance.availability.value;
          final offlineActions = OfflineSyncService.instance.pendingCount.value;
          final recommendationSignals =
              RecommendationService.instance.pendingCount.value;
          final pending = offlineActions + recommendationSignals;
          if (network != NetworkAvailability.offline && pending == 0) {
            return const SizedBox.shrink();
          }
          return FutureBuilder<bool>(
            future: AppCache.instance.hasDownloadedContent(),
            builder: (context, snapshot) {
              final offline = network == NetworkAvailability.offline;
              final hasContent = snapshot.data == true;
              final text = offline
                  ? pending > 0
                      ? 'Offline · $pending pending'
                      : hasContent
                          ? 'Offline · cached content'
                          : 'Offline · no downloaded content'
                  : 'Syncing $pending ${pending == 1 ? 'change' : 'changes'}';
              final syncingSignalsOnly =
                  !offline && offlineActions == 0 && recommendationSignals > 0;
              final syncText = syncingSignalsOnly
                  ? 'Syncing $recommendationSignals recommendation ${recommendationSignals == 1 ? 'signal' : 'signals'}'
                  : 'Syncing $pending ${pending == 1 ? 'change' : 'changes'}';
              final displayText = offline ? text : syncText;
              return Semantics(
                button: onTap != null,
                label: displayText,
                child: Material(
                  color: Theme.of(context).colorScheme.inverseSurface,
                  borderRadius: BorderRadius.circular(99),
                  elevation: 3,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(99),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          offline
                              ? Icons.cloud_off_rounded
                              : Icons.sync_rounded,
                          size: 15,
                          color: Theme.of(context).colorScheme.onInverseSurface,
                        ),
                        const SizedBox(width: 7),
                        Text(displayText,
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onInverseSurface,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
}
