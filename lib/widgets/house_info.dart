import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/widgets/glass_surface.dart';

class HouseInfo extends StatelessWidget {
  final House house;

  const HouseInfo({Key? key, required this.house}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final facts = [
      _FactData(Icons.bed_outlined, '${house.bedrooms}', 'Bedrooms'),
      _FactData(Icons.bathtub_outlined, '${house.bathrooms}', 'Bathrooms'),
      if (house.selfContainedBedrooms > 0)
        _FactData(Icons.bedroom_parent_outlined,
            '${house.selfContainedBedrooms}', 'Self-contained bedrooms'),
      _FactData(Icons.home_work_outlined, house.type ?? 'Not specified',
          'Property type'),
      _FactData(Icons.directions_car_outlined, '${house.carGarage}', 'Parking'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Property details',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _FactGrid(facts: facts.take(3).toList()),
          const SizedBox(height: 2),
          Center(
            child: TextButton.icon(
              onPressed: () => _showAllFacts(context, facts),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              label: const Text('See more'),
            ),
          ),
        ],
      ),
    );
  }

  void _showAllFacts(BuildContext context, List<_FactData> facts) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      showDragHandle: false,
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * .82,
        ),
        child: GlassSurface(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          tint:
              Theme.of(sheetContext).colorScheme.surface.withValues(alpha: .8),
          blur: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Align(
                child: Tooltip(
                  message: 'Close',
                  child: Semantics(
                    button: true,
                    label: 'Close property details',
                    child: GestureDetector(
                      key: const Key('property-details-close-pill'),
                      onTap: () => Navigator.pop(sheetContext),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 6),
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(sheetContext)
                                .colorScheme
                                .outlineVariant,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('All property details',
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .headlineSmall),
                          const SizedBox(height: 4),
                          Text('A quick overview of this home',
                              style:
                                  Theme.of(sheetContext).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  child: _FactGrid(facts: facts),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FactData {
  final IconData icon;
  final String value;
  final String label;

  const _FactData(this.icon, this.value, this.label);
}

class _FactGrid extends StatelessWidget {
  final List<_FactData> facts;

  const _FactGrid({required this.facts});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final columns = constraints.maxWidth >= 600 ? 4 : 2;
        final cardWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final fact in facts)
              _Fact(
                width: cardWidth,
                icon: fact.icon,
                value: fact.value,
                label: fact.label,
              ),
          ],
        );
      },
    );
  }
}

class _Fact extends StatelessWidget {
  final double width;
  final IconData icon;
  final String value;
  final String label;

  const _Fact({
    required this.width,
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 84,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
          const SizedBox(width: 9),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                          height: 1,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(label,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                          height: 1,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 10)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
