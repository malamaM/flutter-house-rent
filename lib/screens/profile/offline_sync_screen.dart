import 'package:flutter/material.dart';
import 'package:house_rent/services/network_status_service.dart';
import 'package:house_rent/services/offline_sync_service.dart';
import 'package:house_rent/services/recommendation_service.dart';
import 'package:house_rent/services/app_cache.dart';
import 'package:house_rent/widgets/offline_status_pill.dart';
import 'package:house_rent/widgets/screen_state.dart';
import 'package:house_rent/widgets/haven_navigation_bar.dart';

class OfflineSyncScreen extends StatefulWidget {
  const OfflineSyncScreen({super.key});

  @override
  State<OfflineSyncScreen> createState() => _OfflineSyncScreenState();
}

class _OfflineSyncScreenState extends State<OfflineSyncScreen> {
  late Future<List<Map<String, dynamic>>> _actions;
  late Future<int> _signalCount;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _reload();
    OfflineSyncService.instance.pendingCount.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(_reload);
  }

  void _reload() {
    _actions = OfflineSyncService.instance.pendingActions();
    _signalCount = RecommendationService.instance.pendingEventCount();
  }

  @override
  void dispose() {
    OfflineSyncService.instance.pendingCount.removeListener(_changed);
    super.dispose();
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    await NetworkStatusService.instance.checkNow();
    await OfflineSyncService.instance.flush();
    if (mounted) {
      setState(() {
        _syncing = false;
        _reload();
      });
    }
  }

  Future<void> _discard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard pending changes?'),
        content: const Text(
            'Only changes that have not reached Haven Zambia will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep them')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard')),
        ],
      ),
    );
    if (confirmed == true) await OfflineSyncService.instance.discardPending();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const HavenNavigationBar(title: 'Offline & sync'),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _actions,
          builder: (context, snapshot) {
            final actions = snapshot.data ?? const [];
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Align(
                    alignment: Alignment.centerLeft,
                    child: OfflineStatusPill(onTap: _sync)),
                const SizedBox(height: 20),
                Text('Pending changes',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  'Haven keeps lightweight actions safely on this device and syncs them when the server is reachable.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else if (actions.isEmpty)
                  const SizedBox(
                    height: 230,
                    child: ScreenState(
                      icon: Icons.cloud_done_outlined,
                      title: 'Everything is synced',
                      message: 'There are no changes waiting on this device.',
                    ),
                  )
                else
                  ...actions.map(_PendingActionCard.new),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: actions.isEmpty || _syncing ? null : _sync,
                  icon: _syncing
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync_rounded),
                  label: const Text('Sync now'),
                ),
                if (actions.isNotEmpty)
                  TextButton(
                      onPressed: _discard,
                      child: const Text('Discard pending changes')),
                FutureBuilder<int>(
                  future: _signalCount,
                  builder: (context, signalSnapshot) {
                    final count = signalSnapshot.data ?? 0;
                    if (count == 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: _SignalQueueCard(count: count),
                    );
                  },
                ),
                const SizedBox(height: 28),
                Text('Offline storage',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                FutureBuilder<CacheDiagnostics>(
                  future: AppCache.instance.diagnostics(),
                  builder: (context, cacheSnapshot) {
                    final cache = cacheSnapshot.data;
                    final megabytes =
                        (cache?.approximateCharacters ?? 0) / (1024 * 1024);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.storage_rounded),
                      title: Text(cache == null
                          ? 'Calculating downloaded content…'
                          : '${megabytes.toStringAsFixed(1)} MB of API content'),
                      subtitle: const Text(
                          'Recently viewed images and map tiles are managed separately by the device cache.'),
                    );
                  },
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await AppCache.instance.clearContentCache();
                    if (mounted) setState(_reload);
                  },
                  icon: const Icon(Icons.cleaning_services_outlined),
                  label: const Text('Clear downloaded API content'),
                ),
              ],
            );
          },
        ),
      );
}

class _PendingActionCard extends StatelessWidget {
  const _PendingActionCard(this.action);

  final Map<String, dynamic> action;

  @override
  Widget build(BuildContext context) {
    final profile = action['type'] == 'recommendation_profile';
    final message = action['type'] == 'contact_message';
    final saved = action['is_saved'] == true;
    final title = message
        ? 'Message property owner'
        : profile
            ? 'Update home-search preferences'
            : saved
                ? 'Save property'
                : 'Remove saved property';
    final subtitle = message
        ? 'Property ${action['house_id']} · stored on this device until sync'
        : profile
            ? 'Latest preferences · waiting to sync'
            : 'Property ${action['house_id']} · waiting to sync';
    final icon = message
        ? Icons.mark_chat_unread_outlined
        : profile
            ? Icons.tune_rounded
            : saved
                ? Icons.bookmark_added_rounded
                : Icons.bookmark_remove_outlined;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalQueueCard extends StatelessWidget {
  const _SignalQueueCard({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const Icon(Icons.auto_awesome_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$count recommendation ${count == 1 ? 'signal is' : 'signals are'} saved on this device and will upload automatically when Haven is reachable.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ]),
        ),
      );
}
