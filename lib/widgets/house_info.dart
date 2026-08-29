import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';

class HouseInfo extends StatefulWidget {
  final House house;

  const HouseInfo({Key? key, required this.house}) : super(key: key);

  @override
  State<HouseInfo> createState() => _HouseInfoState();
}

class _HouseInfoState extends State<HouseInfo> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final facts = [
      _FactData(Icons.bed_outlined, '${widget.house.bedrooms}', 'Bedrooms'),
      _FactData(
          Icons.bathtub_outlined, '${widget.house.bathrooms}', 'Bathrooms'),
      _FactData(Icons.home_work_outlined, widget.house.type ?? 'Not specified',
          'Property type'),
      _FactData(Icons.directions_car_outlined, '${widget.house.carGarage}',
          'Parking'),
    ];
    final visibleFacts = _expanded ? facts : facts.take(2).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Property details',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    const gap = 10.0;
                    final columns = constraints.maxWidth >= 600 ? 4 : 2;
                    final cardWidth =
                        (constraints.maxWidth - gap * (columns - 1)) / columns;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final fact in visibleFacts)
                          _Fact(
                            width: cardWidth,
                            icon: fact.icon,
                            value: fact.value,
                            label: fact.label,
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 2),
                Tooltip(
                  message: _expanded
                      ? 'Hide property details'
                      : 'Show more property details',
                  child: Semantics(
                    button: true,
                    label: _expanded
                        ? 'Hide property details'
                        : 'Show more property details',
                    child: TextButton.icon(
                      onPressed: () => setState(() => _expanded = !_expanded),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: AnimatedRotation(
                        turns: _expanded ? .5 : 0,
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        child: const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 20),
                      ),
                      label: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Text(
                          _expanded ? 'Show less' : 'See more',
                          key: ValueKey(_expanded),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
