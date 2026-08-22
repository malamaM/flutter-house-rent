import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:house_rent/widgets/demand_badge.dart';
import 'package:house_rent/widgets/lister_trust_badges.dart';
import 'package:house_rent/services/premium_haptics.dart';
import 'package:house_rent/services/recommendation_service.dart';
import 'package:house_rent/services/session_recommendation.dart';
import 'package:house_rent/services/app_cache.dart';
import 'dart:async';

String formatPropertyPrice(House house) {
  final value = house.priceRental;
  if (value <= 0) return 'Price on request';
  final digits = value.toString();
  final formatted = digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return 'K$formatted / month';
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

  @override
  void initState() {
    super.initState();
    AppCache.instance.refreshes.addListener(_syncSavedState);
  }

  @override
  void dispose() {
    AppCache.instance.refreshes.removeListener(_syncSavedState);
    super.dispose();
  }

  void _syncSavedState() {
    final event = AppCache.instance.refreshes.value;
    if (!mounted || event?.resource != 'saved_state') return;
    final parts = event!.logicalKey.split(':');
    if (parts.length != 3 ||
        int.tryParse(parts[1]) != widget.house.id ||
        _saving) {
      return;
    }
    final isSaved = parts[2] == '1';
    if (widget.house.isSaved != isSaved) {
      setState(() => widget.house.isSaved = isSaved);
    }
  }

  Future<void> _toggleSave() async {
    if (_saving) return;
    final previous = widget.house.isSaved;
    setState(() {
      _saving = true;
      widget.house.isSaved = !previous;
    });
    if (!previous) PremiumHaptics.save();
    final result = await House.toggleSaveHouse(
      widget.house.id,
      currentlySaved: previous,
      house: widget.house,
    );
    if (!mounted) return;
    setState(() {
      widget.house.isSaved = result.isSaved;
      _saving = false;
    });
    SessionRecommendation.instance
        .observe(widget.house, result.isSaved ? 3.8 : -1.5);
    unawaited(RecommendationService.instance.track(
        result.isSaved ? 'save' : 'unsave', widget.house.id,
        surface: 'home'));
    if (result.confirmed && result.isSaved != previous) {
      _showSavedBanner(result.isSaved);
    } else if (result.queued) {
      _showQueuedBanner(result.isSaved);
    }
  }

  void _showSavedBanner(bool saved) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text(saved ? 'Saved to your shortlist' : 'Removed from saved homes'),
      duration: const Duration(milliseconds: 1500),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showQueuedBanner(bool saved) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(saved
          ? 'Saved on this device · will sync when online'
          : 'Removed on this device · will sync when online'),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Widget _image(
      {required double width, required double height, BorderRadius? radius}) {
    final logicalWidth = width.isFinite && width > 0 ? width : 278.0;
    final pixelWidth =
        (logicalWidth * MediaQuery.devicePixelRatioOf(context)).round();
    return ClipRRect(
      borderRadius: radius ?? BorderRadius.zero,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: widget.house.thumbnailUrl,
            memCacheWidth: pixelWidth.clamp(320, 1200),
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
              color: Theme.of(context).colorScheme.surfaceContainer,
              alignment: Alignment.center,
              child: Icon(Icons.home_work_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 36),
            ),
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
                color: Colors.white.withValues(alpha: .94),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _toggleSave,
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: Icon(
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
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 278,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: AppColors.glassBorder, width: .8),
            borderRadius: BorderRadius.circular(22),
            boxShadow: AppColors.premiumShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 176,
                width: double.infinity,
                child: _image(
                  width: 278,
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
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: AppColors.glassBorder, width: .8),
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppColors.premiumShadow,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 172,
                height: 156,
                child: _image(
                  width: 172,
                  height: 156,
                  radius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PropertyCopy(house: widget.house, compact: true),
                    if (widget.onSecondaryAction != null) ...[
                      const SizedBox(height: 8),
                      Material(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          onTap: widget.onSecondaryAction,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimary
                                    .withValues(alpha: .2),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.edit_outlined,
                                    size: 15,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimary),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    widget.secondaryLabel ?? 'Manage listing',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
            color: Theme.of(context).colorScheme.onSurface,
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
            Icon(Icons.location_on_outlined,
                size: 15,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                house.address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12),
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
        Icon(icon,
            size: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(value,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12)),
      ],
    );
  }
}
