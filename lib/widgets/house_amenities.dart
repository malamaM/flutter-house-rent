import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/models/recommendation.dart';
import 'package:house_rent/widgets/amenity_icon.dart';
import 'package:house_rent/widgets/glass_surface.dart';

class HouseAmenities extends StatelessWidget {
  final House house;

  const HouseAmenities({super.key, required this.house});

  List<RentalAmenity> get _amenities {
    if (house.amenities.isNotEmpty) return house.amenities;
    return [
      if (house.gym == 1) const RentalAmenity(0, 'gym', 'Gym', null),
      if (house.swimmingPool == 1)
        const RentalAmenity(0, 'swimming_pool', 'Swimming pool', null),
      if (house.garage == 1 || house.carGarage > 0)
        const RentalAmenity(0, 'garage', 'Garage', null),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final amenities = _amenities;
    if (amenities.isEmpty) return const SizedBox.shrink();
    final visibleAmenities = amenities.take(2).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Amenities',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              if (amenities.length > visibleAmenities.length)
                TextButton(
                  onPressed: () => _showAllAmenities(context, amenities),
                  child: Text('View all (${amenities.length})'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _AmenityGrid(amenities: visibleAmenities),
        ],
      ),
    );
  }

  void _showAllAmenities(BuildContext context, List<RentalAmenity> amenities) {
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
                    label: 'Close amenities',
                    child: GestureDetector(
                      key: const Key('amenities-close-pill'),
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
                          Text('All amenities',
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .headlineSmall),
                          const SizedBox(height: 4),
                          Text(
                            '${amenities.length} included with this home',
                            style: Theme.of(sheetContext).textTheme.bodyMedium,
                          ),
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
                  child: _AmenityGrid(amenities: amenities),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmenityGrid extends StatelessWidget {
  final List<RentalAmenity> amenities;

  const _AmenityGrid({required this.amenities});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final columns = constraints.maxWidth >= 600 ? 3 : 2;
        final cardWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final amenity in amenities)
              _AmenityCard(amenity: amenity, width: cardWidth),
          ],
        );
      },
    );
  }
}

class _AmenityCard extends StatelessWidget {
  final RentalAmenity amenity;
  final double width;

  const _AmenityCard({required this.amenity, required this.width});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Icon(
              amenityIcon(amenity.key),
              size: 19,
              color: colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              amenity.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
