import 'dart:async';

import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/screens/home/app_shell.dart';
import 'package:house_rent/screens/home/explore.dart';
import 'package:house_rent/widgets/best_offer.dart';
import 'package:house_rent/widgets/all_homes.dart';
import 'package:house_rent/widgets/cache_status_banner.dart';
import 'package:house_rent/widgets/categories.dart';
import 'package:house_rent/widgets/custom_app_bar.dart';
import 'package:house_rent/widgets/recommended_house.dart';
import 'package:house_rent/widgets/search_input.dart';
import 'package:house_rent/widgets/welcome_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:house_rent/screens/onboarding/rental_preferences_screen.dart';
import 'package:house_rent/services/recommendation_service.dart';
import 'package:house_rent/services/app_cache.dart';

class Home extends StatefulWidget {
  const Home({
    Key? key,
    this.initialFeed,
    this.initialType,
  }) : super(key: key);

  final HomeFeedData? initialFeed;
  final String? initialType;

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  String? selectedType;
  Future<HomeFeedData>? feed;
  HomeFeedData? _settledFeed;
  bool _refreshing = false;
  final ScrollController _scrollController = ScrollController();
  Timer? _preferenceCheckTimer;

  @override
  void initState() {
    super.initState();
    selectedType = widget.initialType;
    _settledFeed = widget.initialFeed;
    feed = widget.initialFeed == null ? _initialFeed() : null;
    _preferenceCheckTimer = Timer(
      const Duration(milliseconds: 5000),
      _checkPreferences,
    );
    AppCache.instance.refreshes.addListener(_handleRecommendationRefresh);
  }

  void _handleRecommendationRefresh() {
    if (!mounted) return;
    final event = AppCache.instance.refreshes.value!;
    final isActiveTabRefresh =
        event.resource == 'tab-refresh' && event.logicalKey == '0';
    if (event.resource != 'houses' && !isActiveTabRefresh) return;
    if (isActiveTabRefresh && _scrollController.hasClients) {
      unawaited(_scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      ));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final refreshedFeed =
            House.fetchHomeFeed(type: selectedType, forceRefresh: true);
        setState(() {
          _settledFeed = null;
          feed = refreshedFeed;
        });
      }
    });
  }

  @override
  void dispose() {
    AppCache.instance.refreshes.removeListener(_handleRecommendationRefresh);
    _preferenceCheckTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkPreferences() async {
    try {
      if (!await RecommendationService.instance.needsOnboarding() || !mounted) {
        return;
      }
      final completed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const RentalPreferencesScreen(),
        ),
      );
      if (completed == true && mounted) {
        final refreshedFeed =
            House.fetchHomeFeed(type: selectedType, forceRefresh: true);
        setState(() {
          _settledFeed = null;
          feed = refreshedFeed;
        });
      }
    } catch (_) {}
  }

  Future<HomeFeedData> _initialFeed() async {
    final prefs = await SharedPreferences.getInstance();
    selectedType = prefs.getString('home_property_type');
    return House.fetchHomeFeed(type: selectedType);
  }

  void _selectType(String? value) {
    unawaited(SharedPreferences.getInstance().then((prefs) => value == null
        ? prefs.remove('home_property_type')
        : prefs.setString('home_property_type', value)));
    setState(() {
      selectedType = value;
      _settledFeed = null;
      feed = House.fetchHomeFeed(type: value, forceRefresh: true);
    });
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final refreshed =
          await House.fetchHomeFeed(type: selectedType, forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _settledFeed = refreshed;
        feed = null;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Showing saved homes. Fresh updates are unavailable right now.')));
      }
    } finally {
      _refreshing = false;
    }
  }

  Map<String, String> get sectionFilters => {
        if (selectedType != null) 'type': selectedType!,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const CustomAppBar(),
      extendBody: true,
      body: FutureBuilder<HomeFeedData>(
        future: feed,
        initialData: _settledFeed,
        builder: (context, snapshot) {
          final data = snapshot.data;
          final waiting = data == null &&
              snapshot.connectionState == ConnectionState.waiting;
          final sections = <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WelcomeText(),
                const CacheStatusBanner(resource: 'houses'),
                SearchInput(onTap: () {
                  if (!AppShell.selectTab(context, 1)) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const Explore()));
                  }
                }),
                const SizedBox(height: 24),
                const _SectionLabel(
                    title: 'Browse by type',
                    subtitle: 'A quicker way to narrow it down'),
                const SizedBox(height: 12),
                Categories(
                  selectedType: selectedType,
                  onSelected: _selectType,
                ),
                const SizedBox(height: 28),
              ],
            ),
            if (waiting)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: _FeedSkeleton(height: 323),
              )
            else
              RecommendedHouse(
                key: ValueKey('recommended:$selectedType'),
                filters: sectionFilters,
                initialHouses: data?.recommended,
              ),
            if (!waiting) const SizedBox(height: 28),
            if (!waiting)
              BestOffer(
                key: ValueKey('deals:$selectedType'),
                filters: sectionFilters,
                initialHouses: data?.deals,
              ),
            if (!waiting) const SizedBox(height: 28),
            if (!waiting)
              AllHomes(
                key: ValueKey('all:$selectedType'),
                filters: sectionFilters,
                initialHouses: data?.all,
              ),
            const SizedBox(height: 112),
          ];
          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              controller: _scrollController,
              key: const PageStorageKey('home-scroll'),
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverList.builder(
                  itemCount: sections.length,
                  itemBuilder: (_, index) => sections[index],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FeedSkeleton extends StatelessWidget {
  final double height;
  const _FeedSkeleton({required this.height});

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(22),
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionLabel({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 3),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
