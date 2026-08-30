import 'package:flutter/material.dart';
import 'package:house_rent/navigation/haven_page_route.dart';
import 'package:house_rent/screens/onboarding/rental_preferences_screen.dart';
import 'package:house_rent/services/app_feedback.dart';
import 'package:house_rent/services/recommendation_service.dart';
import 'package:house_rent/services/session_recommendation.dart';
import 'package:house_rent/widgets/haven_navigation_bar.dart';

String _budgetLabel(Map<String, dynamic> profile) {
  final minimum = int.tryParse('${profile['min_monthly_price']}') ?? 0;
  final maximum = int.tryParse('${profile['max_monthly_price']}') ?? 0;
  String amount(int value) => value >= 1000000
      ? 'Any'
      : 'K${value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}';
  if (minimum == 0) return 'Up to ${amount(maximum)}';
  if (maximum >= 1000000) return '${amount(minimum)}+';
  return '${amount(minimum)}–${amount(maximum)}';
}

class RecommendationHistoryScreen extends StatefulWidget {
  const RecommendationHistoryScreen({super.key});
  @override
  State<RecommendationHistoryScreen> createState() =>
      _RecommendationHistoryScreenState();
}

class _RecommendationHistoryScreenState
    extends State<RecommendationHistoryScreen> {
  late Future<Map<String, dynamic>> data;

  @override
  void initState() {
    super.initState();
    data = RecommendationService.instance.history();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      data = RecommendationService.instance.history();
    });
  }

  Future<void> _openPreferences({required bool newSearch}) async {
    if (newSearch) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start a new home search?'),
          content: const Text(
              'Your previous search will be archived. Saved homes stay intact, but old behaviour will no longer influence the new feed.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Start fresh')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    final changed = await Navigator.push<bool>(
      context,
      HavenPageRoute(
        builder: (_) => RentalPreferencesScreen(
          allowCancel: true,
          editExisting: !newSearch,
          startNewSearch: newSearch,
        ),
      ),
    );
    if (changed == true) _reload();
  }

  Future<void> _resetHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset recommendation learning?'),
        content: const Text(
            'Haven Zambia will forget viewing, skipping, saving and contact patterns. Your chosen locations, amenities and saved homes will remain.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reset learning')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await RecommendationService.instance.resetHistory();
      SessionRecommendation.instance.reset();
      if (!mounted) return;
      _reload();
      AppFeedback.success('Recommendation learning has been reset.');
    } catch (error) {
      AppFeedback.error(error,
          fallback: 'Could not reset recommendation learning.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const HavenNavigationBar(title: 'Your home search'),
        body: FutureBuilder<Map<String, dynamic>>(
          future: data,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data?['profile'] is! Map) {
              return AppErrorView(
                message: snapshot.hasError
                    ? AppFeedback.messageFor(snapshot.error!)
                    : 'Your recommendation preferences are not available yet.',
                onRetry: _reload,
              );
            }
            final payload = snapshot.data!;
            final profile = Map<String, dynamic>.from(payload['profile']);
            final city = profile['city'] is Map
                ? Map<String, dynamic>.from(profile['city'])['name']
                : 'Your city';
            final areas =
                (profile['areas'] is List ? profile['areas'] as List : const [])
                    .whereType<Map>()
                    .map((item) => item['name'])
                    .whereType<String>()
                    .join(', ');
            final amenities = (profile['amenities'] is List
                    ? profile['amenities'] as List
                    : const [])
                .whereType<Map>()
                .map((item) => item['name'])
                .whereType<String>()
                .join(', ');
            final activity = payload['activity'] is Map
                ? Map<String, dynamic>.from(payload['activity'])
                : const <String, dynamic>{};
            final searches = payload['searches'] is List
                ? payload['searches'] as List
                : const [];
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (payload['intent_shift_detected'] == true)
                  const _IntentShiftPanel(),
                _Panel(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current preferences',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 14),
                        _Fact(Icons.location_city_outlined, '$city', areas),
                        _Fact(
                            Icons.bed_outlined,
                            '${profile['min_bedrooms']}–${profile['max_bedrooms']} bedrooms',
                            amenities.isEmpty
                                ? 'No required amenities'
                                : amenities),
                        const SizedBox(height: 10),
                        _Fact(
                          Icons.bedroom_parent_outlined,
                          profile['min_self_contained_bedrooms'] == null
                              ? 'No minimum'
                              : '${profile['min_self_contained_bedrooms']}–${profile['max_self_contained_bedrooms']} self-contained',
                          'Bedrooms with their own bathroom',
                        ),
                        const SizedBox(height: 10),
                        _Fact(Icons.payments_outlined, _budgetLabel(profile),
                            'Preferred monthly rent'),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                            onPressed: () => _openPreferences(newSearch: false),
                            icon: const Icon(Icons.tune_rounded),
                            label: const Text('Edit preferences')),
                      ]),
                ),
                const SizedBox(height: 16),
                Text('What Haven Zambia remembers',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: _MemoryTile(
                          'Now', '72 hours', activity['short_term'] ?? 0)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _MemoryTile(
                          'Recent', '3 weeks', activity['medium_term'] ?? 0)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _MemoryTile(
                          'Older', 'Fades', activity['long_term'] ?? 0)),
                ]),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: () => _openPreferences(newSearch: true),
                  icon: const Icon(Icons.add_home_work_outlined),
                  label: const Text('Start a new home search'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 54)),
                ),
                TextButton.icon(
                    onPressed: _resetHistory,
                    icon: const Icon(Icons.history_toggle_off_rounded),
                    label: const Text('Reset recommendation learning')),
                if (searches.length > 1) ...[
                  const SizedBox(height: 18),
                  Text('Previous searches',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  ...searches.skip(1).whereType<Map>().map((item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                            child: Icon(Icons.history_rounded, size: 18)),
                        title: Text('Home search ${item['search_version']}'),
                        subtitle: Text(item['status'] == 'active'
                            ? 'Current search'
                            : 'Archived preferences'),
                      )),
                ],
              ],
            );
          },
        ),
      );
}

class _Panel extends StatelessWidget {
  final Widget child;
  final Color? color;
  const _Panel({required this.child, this.color});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color ?? Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: child,
      );
}

class _IntentShiftPanel extends StatelessWidget {
  const _IntentShiftPanel();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? const Color(0xFF243B5A) : const Color(0xFFE7F0FC);
    final foreground = dark ? const Color(0xFFBBD7FF) : const Color(0xFF164C86);
    return _Panel(
      color: background,
      child: Row(children: [
        Icon(Icons.auto_awesome_rounded, color: foreground),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Your recent activity looks different from your saved preferences. You can update them or start a fresh search.',
            style: TextStyle(color: foreground, height: 1.35),
          ),
        ),
      ]),
    );
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _Fact(this.icon, this.title, this.subtitle);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 11),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ])),
        ]),
      );
}

class _MemoryTile extends StatelessWidget {
  final String title, subtitle;
  final dynamic count;
  const _MemoryTile(this.title, this.subtitle, this.count);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(17)),
        child: Column(children: [
          Text('$count',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900)),
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
}
