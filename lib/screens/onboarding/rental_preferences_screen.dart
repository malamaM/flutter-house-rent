import 'package:flutter/material.dart';
import 'package:house_rent/models/recommendation.dart';
import 'package:house_rent/services/premium_haptics.dart';
import 'package:house_rent/services/app_feedback.dart';
import 'package:house_rent/services/recommendation_service.dart';
import 'package:house_rent/services/session_recommendation.dart';

class RentalPreferencesScreen extends StatefulWidget {
  final bool allowCancel;
  final bool editExisting;
  final bool startNewSearch;
  const RentalPreferencesScreen({
    super.key,
    this.allowCancel = false,
    this.editExisting = false,
    this.startNewSearch = false,
  });
  @override
  State<RentalPreferencesScreen> createState() =>
      _RentalPreferencesScreenState();
}

class _RentalPreferencesScreenState extends State<RentalPreferencesScreen> {
  final pages = PageController();
  late Future<RecommendationOptions> options;
  int step = 0;
  RentalCity? city;
  final Set<int> areaIds = {};
  final Set<int> amenityIds = {};
  int bedroomStart = 1;
  int minMonthlyPrice = 3000;
  int maxMonthlyPrice = 6000;
  String areaSearch = '';
  bool saving = false;

  @override
  void initState() {
    super.initState();
    options = _loadOptions();
  }

  Future<RecommendationOptions> _loadOptions() async {
    final loaded = await RecommendationService.instance.options();
    if (widget.editExisting && !widget.startNewSearch) {
      final profile = await RecommendationService.instance.profile();
      if (profile != null) {
        final cityId = int.tryParse('${profile['city_id']}');
        city = loaded.cities.where((item) => item.id == cityId).firstOrNull;
        areaIds.addAll(
            (profile['areas'] is List ? profile['areas'] as List : const [])
                .whereType<Map>()
                .map((item) => int.tryParse('${item['id']}'))
                .whereType<int>());
        amenityIds.addAll((profile['amenities'] is List
                ? profile['amenities'] as List
                : const [])
            .whereType<Map>()
            .map((item) => int.tryParse('${item['id']}'))
            .whereType<int>());
        bedroomStart = int.tryParse('${profile['min_bedrooms']}') ?? 1;
        minMonthlyPrice =
            int.tryParse('${profile['min_monthly_price']}') ?? 3000;
        maxMonthlyPrice =
            int.tryParse('${profile['max_monthly_price']}') ?? 6000;
      }
    }
    return loaded;
  }

  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  bool get valid => switch (step) {
        0 => city != null,
        1 => areaIds.length >= 3 && areaIds.length <= 10,
        _ => true,
      };

  void _retry() => setState(() {
        options = RecommendationService.instance.options();
      });

  Future<void> _continue() async {
    if (!valid) return;
    PremiumHaptics.action();
    if (step < 4) {
      setState(() => step++);
      await pages.animateToPage(step,
          duration: const Duration(milliseconds: 440),
          curve: Curves.easeOutCubic);
      return;
    }
    setState(() => saving = true);
    try {
      await RecommendationService.instance.saveProfile(
        cityId: city!.id,
        areaIds: areaIds,
        minBedrooms: bedroomStart,
        maxBedrooms: bedroomStart + 1,
        minMonthlyPrice: minMonthlyPrice,
        maxMonthlyPrice: maxMonthlyPrice,
        amenityIds: amenityIds,
        startNewSearch: widget.startNewSearch,
      );
      if (widget.startNewSearch) SessionRecommendation.instance.reset();
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => saving = false);
      AppFeedback.error(error,
          fallback: 'We could not save your preferences. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: widget.allowCancel,
        child: Scaffold(
          body: SafeArea(
            child: FutureBuilder<RecommendationOptions>(
              future: options,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _RetryState(
                      message: AppFeedback.messageFor(snapshot.error!),
                      onRetry: _retry);
                }
                final data = snapshot.data;
                if (data == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
                    child: Row(children: [
                      if (step > 0)
                        IconButton(
                          onPressed: () {
                            setState(() => step--);
                            pages.animateToPage(step,
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeOutCubic);
                          },
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        )
                      else if (widget.allowCancel)
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        )
                      else
                        const SizedBox(width: 48),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            5,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 260),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: index == step ? 28 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: index <= step
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .outlineVariant,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ]),
                  ),
                  Expanded(
                    child: PageView(
                      controller: pages,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _CityStep(
                            cities: data.cities,
                            selected: city,
                            onSelect: (value) => setState(() {
                                  city = value;
                                  areaIds.clear();
                                })),
                        _AreaStep(
                          city: city,
                          selected: areaIds,
                          search: areaSearch,
                          onSearch: (value) =>
                              setState(() => areaSearch = value),
                          onToggle: (id) => setState(() {
                            if (!areaIds.remove(id) && areaIds.length < 10) {
                              areaIds.add(id);
                            }
                          }),
                        ),
                        _BedroomStep(
                            value: bedroomStart,
                            onChanged: (value) =>
                                setState(() => bedroomStart = value)),
                        _BudgetStep(
                          minimum: minMonthlyPrice,
                          maximum: maxMonthlyPrice,
                          onChanged: (range) => setState(() {
                            minMonthlyPrice = range.$1;
                            maxMonthlyPrice = range.$2;
                          }),
                        ),
                        _AmenityStep(
                          amenities: data.amenities,
                          selected: amenityIds,
                          onToggle: (id) => setState(() {
                            if (!amenityIds.remove(id)) amenityIds.add(id);
                          }),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: FilledButton(
                        onPressed: valid && !saving ? _continue : null,
                        child: saving
                            ? const SizedBox.square(
                                dimension: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : Text(step == 4
                                ? 'Build my Haven'
                                : 'Continue'),
                      ),
                    ),
                  ),
                ]);
              },
            ),
          ),
        ),
      );
}

class _Heading extends StatelessWidget {
  final String eyebrow, title, subtitle;
  const _Heading(this.eyebrow, this.title, this.subtitle);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(eyebrow.toUpperCase(),
              style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3)),
          const SizedBox(height: 9),
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .displaySmall
                  ?.copyWith(fontWeight: FontWeight.w800, height: 1.04)),
          const SizedBox(height: 10),
          Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
        ]),
      );
}

class _CityStep extends StatelessWidget {
  final List<RentalCity> cities;
  final RentalCity? selected;
  final ValueChanged<RentalCity> onSelect;
  const _CityStep(
      {required this.cities, required this.selected, required this.onSelect});
  @override
  Widget build(BuildContext context) => Column(children: [
        const _Heading('Your search starts here', 'Where do you want to live?',
            'Choose the city you want Haven Zambia to understand first.'),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.34,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12),
            itemCount: cities.length,
            itemBuilder: (_, index) {
              final item = cities[index];
              final active = selected?.id == item.id;
              return _ChoiceCard(
                active: active,
                onTap: () => onSelect(item),
                icon: Icons.location_city_rounded,
                title: item.name,
                subtitle: item.province,
              );
            },
          ),
        ),
      ]);
}

class _AreaStep extends StatelessWidget {
  final RentalCity? city;
  final Set<int> selected;
  final String search;
  final ValueChanged<String> onSearch;
  final ValueChanged<int> onToggle;
  const _AreaStep(
      {required this.city,
      required this.selected,
      required this.search,
      required this.onSearch,
      required this.onToggle});
  @override
  Widget build(BuildContext context) {
    final areas = (city?.areas ?? const <RentalArea>[])
        .where((area) => area.name.toLowerCase().contains(search.toLowerCase()))
        .toList();
    return Column(children: [
      _Heading('Pick 3–10', 'Which areas feel right?',
          'Choose neighbourhoods in ${city?.name ?? 'your city'}. We will learn and refine this over time.'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: TextField(
          onChanged: onSearch,
          decoration: InputDecoration(
              hintText: 'Search neighbourhoods',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: Padding(
                padding: const EdgeInsets.all(14),
                child: Text('${selected.length}/10',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              )),
        ),
      ),
      const SizedBox(height: 14),
      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.1,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10),
          itemCount: areas.length,
          itemBuilder: (_, index) {
            final area = areas[index];
            return _ChoiceCard(
                active: selected.contains(area.id),
                onTap: () => onToggle(area.id),
                icon: Icons.place_outlined,
                title: area.name);
          },
        ),
      ),
    ]);
  }
}

class _BedroomStep extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _BedroomStep({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Column(children: [
        const _Heading('Your ideal space', 'How many bedrooms?',
            'Pick a comfortable range. Homes just outside it can still appear occasionally.'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            children: List.generate(5, (index) {
              final start = index + 1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ChoiceCard(
                  active: value == start,
                  onTap: () => onChanged(start),
                  icon: Icons.bed_rounded,
                  title: '$start–${start + 1} bedrooms',
                  subtitle: start == 1 ? 'Compact and comfortable' : null,
                ),
              );
            }),
          ),
        ),
      ]);
}

class _BudgetStep extends StatelessWidget {
  final int minimum;
  final int maximum;
  final ValueChanged<(int, int)> onChanged;
  const _BudgetStep({
    required this.minimum,
    required this.maximum,
    required this.onChanged,
  });

  static const ranges = <(int, int, String)>[
    (0, 3000, 'Up to K3,000'),
    (3000, 6000, 'K3,000–K6,000'),
    (6000, 10000, 'K6,000–K10,000'),
    (10000, 15000, 'K10,000–K15,000'),
    (15000, 25000, 'K15,000–K25,000'),
    (25000, 1000000, 'K25,000+'),
  ];

  @override
  Widget build(BuildContext context) => Column(children: [
        const _Heading('Your monthly budget', 'What range feels comfortable?',
            'Price strongly shapes your matches, but Haven Zambia can still occasionally show an exceptional home just outside your range.'),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
            itemCount: ranges.length,
            itemBuilder: (context, index) {
              final range = ranges[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: _ChoiceCard(
                  active: minimum == range.$1 && maximum == range.$2,
                  onTap: () => onChanged((range.$1, range.$2)),
                  icon: Icons.payments_outlined,
                  title: range.$3,
                  subtitle: 'per month',
                ),
              );
            },
          ),
        ),
      ]);
}

class _AmenityStep extends StatelessWidget {
  final List<RentalAmenity> amenities;
  final Set<int> selected;
  final ValueChanged<int> onToggle;
  const _AmenityStep(
      {required this.amenities,
      required this.selected,
      required this.onToggle});
  @override
  Widget build(BuildContext context) => Column(children: [
        const _Heading('The finishing touches', 'What matters at home?',
            'Choose anything important to you, or continue without selecting any.'),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.55,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12),
            itemCount: amenities.length,
            itemBuilder: (_, index) {
              final amenity = amenities[index];
              return _ChoiceCard(
                active: selected.contains(amenity.id),
                onTap: () => onToggle(amenity.id),
                icon: _amenityIcon(amenity.key),
                title: amenity.name,
              );
            },
          ),
        ),
      ]);
}

class _ChoiceCard extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final String? subtitle;
  const _ChoiceCard(
      {required this.active,
      required this.onTap,
      required this.icon,
      required this.title,
      this.subtitle});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: active ? colors.primary : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border:
            Border.all(color: active ? colors.primary : colors.outlineVariant),
        boxShadow: active
            ? [
                BoxShadow(
                    color: colors.primary.withValues(alpha: .2),
                    blurRadius: 18,
                    offset: const Offset(0, 7))
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final boundedHeight = constraints.hasBoundedHeight;
              final compact = boundedHeight && constraints.maxHeight < 100;
              return Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 15, vertical: compact ? 9 : 15),
                child: Column(
                  mainAxisSize:
                      boundedHeight ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon,
                        size: compact ? 22 : 24,
                        color: active ? colors.onPrimary : colors.primary),
                    SizedBox(height: compact ? 5 : 8),
                    Text(title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: active ? colors.onPrimary : colors.onSurface,
                            fontWeight: FontWeight.w800)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: active
                                  ? colors.onPrimary.withValues(alpha: .78)
                                  : colors.onSurfaceVariant,
                              fontSize: 11)),
                    ]
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RetryState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _RetryState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded, size: 46),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ]),
        ),
      );
}

IconData _amenityIcon(String key) => switch (key) {
      'gym' => Icons.fitness_center_rounded,
      'swimming_pool' => Icons.pool_rounded,
      'garage' => Icons.garage_rounded,
      'security' => Icons.shield_outlined,
      'furnished' => Icons.chair_outlined,
      'backup_power' => Icons.bolt_rounded,
      'water_tank' => Icons.water_drop_outlined,
      'internet' => Icons.wifi_rounded,
      'pet_friendly' => Icons.pets_rounded,
      'garden' => Icons.yard_outlined,
      _ => Icons.check_circle_outline_rounded,
    };
