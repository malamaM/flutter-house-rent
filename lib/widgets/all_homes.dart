import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/screens/details/details.dart';
import 'package:house_rent/screens/home/all_houses_screen.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:house_rent/widgets/property_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AllHomes extends StatefulWidget {
  final Map<String, String> filters;
  final List<House>? initialHouses;

  const AllHomes({Key? key, this.filters = const {}, this.initialHouses})
      : super(key: key);

  @override
  State<AllHomes> createState() => _AllHomesState();
}

class _AllHomesState extends State<AllHomes> {
  static const pageSize = 4;
  String sort = 'newest';
  List<House> homes = [];
  int page = 0;
  bool loadingInitial = true;
  bool loadingMore = false;
  bool hasMore = true;
  bool loadFailed = false;

  Map<String, String> get baseFilters => {...widget.filters, 'sort': sort};

  String get sortLabel {
    if (sort == 'price_low') return 'Lowest price';
    if (sort == 'price_high') return 'Highest price';
    return 'Newest first';
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant AllHomes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialHouses != null &&
        !identical(widget.initialHouses, oldWidget.initialHouses) &&
        sort == 'newest') {
      setState(() {
        homes = widget.initialHouses!;
        page = 1;
        hasMore = homes.length == pageSize;
        loadingInitial = false;
        loadFailed = false;
      });
    }
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    sort = prefs.getString('all_homes_sort') ?? 'newest';
    final initial = widget.initialHouses;
    if (initial != null && sort == 'newest') {
      if (!mounted) return;
      setState(() {
        homes = initial;
        page = 1;
        hasMore = initial.length == pageSize;
        loadingInitial = false;
      });
      return;
    }
    await _loadFirstPage();
  }

  Future<List<House>> _fetchPage(int nextPage) {
    return House.fetchHouses(filters: {
      ...baseFilters,
      'page': '$nextPage',
      'per_page': '$pageSize',
    });
  }

  Future<void> _loadFirstPage() async {
    try {
      final result = await _fetchPage(1);
      if (!mounted) return;
      setState(() {
        homes = result;
        page = 1;
        hasMore = result.length == pageSize;
        loadingInitial = false;
        loadingMore = false;
        loadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loadingInitial = false;
        loadingMore = false;
        loadFailed = true;
      });
    }
  }

  Future<void> _loadMore() async {
    if (loadingMore || !hasMore) return;
    setState(() => loadingMore = true);
    final nextPage = page + 1;
    try {
      final result = await _fetchPage(nextPage);
      if (!mounted) return;
      setState(() {
        homes = [...homes, ...result];
        page = nextPage;
        hasMore = result.length == pageSize;
        loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => loadingMore = false);
    }
  }

  void _setSort(String value) {
    if (value == sort) return;
    setState(() {
      sort = value;
      homes = [];
      page = 0;
      hasMore = true;
      loadingInitial = true;
      loadFailed = false;
    });
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setString('all_homes_sort', value));
    _loadFirstPage();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('All homes',
                    style: Theme.of(context).textTheme.headlineMedium),
                if (homes.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${homes.length} loaded',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ]),
              const SizedBox(height: 3),
              Text('Explore every available rental',
                  style: Theme.of(context).textTheme.bodyMedium),
            ]),
          ),
          PopupMenuButton<String>(
            initialValue: sort,
            onSelected: _setSort,
            tooltip: 'Sort homes',
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'newest', child: Text('Newest first')),
              PopupMenuItem(value: 'price_low', child: Text('Lowest price')),
              PopupMenuItem(value: 'price_high', child: Text('Highest price')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.sort_rounded,
                  size: 19, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 3),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AllHousesScreen(
                    title: widget.filters['type'] == null
                        ? 'All rental homes'
                        : '${widget.filters['type']} rental homes',
                    filters: baseFilters),
              ),
            ),
            child: const Text('View all'),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.auto_awesome_rounded,
              color: AppColors.primary, size: 14),
          const SizedBox(width: 5),
          Text('Showing $sortLabel',
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: loadingInitial
              ? const _LoadingHomes(key: ValueKey('loading'))
              : loadFailed
                  ? _LoadError(
                      key: const ValueKey('error'), onRetry: _loadFirstPage)
                  : Column(
                      key: ValueKey('homes-${homes.length}-$sort'),
                      children: [
                        ...homes.map((house) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: PropertyCard(
                                horizontal: true,
                                house: house,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => Details(house: house)),
                                ),
                              ),
                            )),
                        if (hasMore)
                          Padding(
                            padding: const EdgeInsets.only(top: 2, bottom: 8),
                            child: OutlinedButton.icon(
                              onPressed: loadingMore ? null : _loadMore,
                              icon: loadingMore
                                  ? const SizedBox(
                                      width: 17,
                                      height: 17,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.expand_more_rounded),
                              label: Text(loadingMore
                                  ? 'Finding more homes…'
                                  : 'Show more homes'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 48),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          )
                        else if (homes.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline_rounded,
                                      size: 16, color: AppColors.textSecondary),
                                  SizedBox(width: 6),
                                  Text('You have reached the end',
                                      style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 11)),
                                ]),
                          ),
                      ],
                    ),
        ),
      ]),
    );
  }
}

class _LoadingHomes extends StatelessWidget {
  const _LoadingHomes({super.key});

  @override
  Widget build(BuildContext context) => Column(
        children: List.generate(
          2,
          (_) => Container(
            height: 172,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      );
}

class _LoadError extends StatelessWidget {
  final VoidCallback onRetry;

  const _LoadError({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.textSecondary),
          const SizedBox(height: 8),
          const Text('Homes could not be loaded'),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ]),
      );
}
