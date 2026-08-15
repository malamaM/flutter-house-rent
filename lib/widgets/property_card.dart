import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:house_rent/widgets/demand_badge.dart';
import 'package:house_rent/widgets/lister_trust_badges.dart';

String formatPropertyPrice(House house) {
  final isRental =
      house.isForRent || (!house.isForSale && house.priceRental > 0);
  final value = isRental ? house.priceRental : house.pricePurchase;
  if (value <= 0) return 'Price on request';
  final digits = value.toString();
  final formatted = digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return 'K$formatted${isRental ? ' / month' : ''}';
}

class PropertyCard extends StatefulWidget {
  final House house;
  final VoidCallback onTap;
  final bool horizontal;
  final bool showSave;
  final VoidCallback? onSecondaryAction;
  final String? secondaryLabel;

  const PropertyCard({
    Key? key,
    required this.house,
    required this.onTap,
    this.horizontal = false,
    this.showSave = true,
    this.onSecondaryAction,
    this.secondaryLabel,
  }) : super(key: key);

  @override
  State<PropertyCard> createState() => _PropertyCardState();
}

class _PropertyCardState extends State<PropertyCard> {
  bool _saving = false;

  Future<void> _toggleSave() async {
    if (_saving) return;
    setState(() => _saving = true);
    final saved = await House.toggleSaveHouse(
      widget.house.id,
      currentlySaved: widget.house.isSaved,
    );
    if (!mounted) return;
    setState(() {
      widget.house.isSaved = saved;
      _saving = false;
    });
  }

  Widget _image(
      {required double width, required double height, BorderRadius? radius}) {
    return ClipRRect(
      borderRadius: radius ?? BorderRadius.zero,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: widget.house.imageUrl,
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 180),
            placeholder: (_, __) => Container(
              color: AppColors.surfaceContainer,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              color: AppColors.surfaceContainer,
              alignment: Alignment.center,
              child: const Icon(Icons.home_work_outlined,
                  color: AppColors.textSecondary, size: 36),
            ),
          ),
          Positioned(
            left: 12,
            top: 12,
            child: _StatusPill(label: widget.house.listingStatusLabel),
          ),
          if (widget.house.demandLabel != null)
            Positioned(
              left: 12,
              bottom: 12,
              child: DemandBadge(
                demandLabel: widget.house.demandLabel,
                compact: widget.horizontal,
              ),
            ),
          if (widget.showSave)
            Positioned(
              right: 10,
              top: 10,
              child: Material(
                color: Colors.white.withOpacity(.94),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _toggleSave,
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: _saving
                        ? const Padding(
                            padding: EdgeInsets.all(11),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            widget.house.isSaved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            color: AppColors.primary,
                            size: 21,
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.horizontal) return _buildHorizontal(context);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 278,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 176,
                width: double.infinity,
                child: _image(
                  width: double.infinity,
                  height: 176,
                  radius: const BorderRadius.vertical(top: Radius.circular(21)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: _PropertyCopy(house: widget.house),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontal(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 116,
                height: 116,
                child: _image(
                  width: 116,
                  height: 116,
                  radius: BorderRadius.circular(13),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PropertyCopy(house: widget.house, compact: true),
                    if (widget.onSecondaryAction != null) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: widget.onSecondaryAction,
                        child: Text(
                          widget.secondaryLabel ?? 'Manage listing',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PropertyCopy extends StatelessWidget {
  final House house;
  final bool compact;

  const _PropertyCopy({required this.house, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          house.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: compact ? 15 : 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -.2,
          ),
        ),
        if (house.isVerified || house.isTopRated) ...[
          const SizedBox(height: 7),
          ListerTrustBadges(
            verified: house.isVerified,
            topRated: house.isTopRated,
            compact: true,
          ),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.location_on_outlined,
                size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                house.address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _MiniFact(icon: Icons.bed_outlined, value: '${house.bedrooms}'),
            const SizedBox(width: 12),
            _MiniFact(
                icon: Icons.bathtub_outlined, value: '${house.bathrooms}'),
            if (!compact) ...[
              const SizedBox(width: 12),
              _MiniFact(
                  icon: Icons.square_foot_outlined, value: '${house.size} m²'),
            ],
          ],
        ),
        const SizedBox(height: 11),
        Text(
          formatPropertyPrice(house),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: compact ? 14 : 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _MiniFact extends StatelessWidget {
  final IconData icon;
  final String value;

  const _MiniFact({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(value,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;

  const _StatusPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withOpacity(.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}
