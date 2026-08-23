import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:house_rent/config/api_config.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/services/app_cache.dart';
import 'package:house_rent/services/premium_haptics.dart';
import 'package:house_rent/services/app_feedback.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:house_rent/widgets/glass_surface.dart';
import 'package:share_plus/share_plus.dart';

class DetailsAppBar extends StatefulWidget {
  final House house;

  const DetailsAppBar({Key? key, required this.house}) : super(key: key);

  @override
  State<DetailsAppBar> createState() => _DetailsAppBarState();
}

class _DetailsAppBarState extends State<DetailsAppBar> {
  late bool saved;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    saved = widget.house.isSaved;
    AppCache.instance.refreshes.addListener(_syncSavedState);
  }

  @override
  void dispose() {
    AppCache.instance.refreshes.removeListener(_syncSavedState);
    super.dispose();
  }

  void _syncSavedState() {
    final event = AppCache.instance.refreshes.value;
    if (!mounted || event?.resource != 'saved_state' || loading) return;
    final parts = event!.logicalKey.split(':');
    if (parts.length != 3 || int.tryParse(parts[1]) != widget.house.id) return;
    final isSaved = parts[2] == '1';
    if (saved != isSaved) {
      setState(() {
        saved = isSaved;
        widget.house.isSaved = isSaved;
      });
    }
  }

  Future<void> _save() async {
    if (loading) return;
    final previous = saved;
    setState(() {
      loading = true;
      saved = !previous;
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
      saved = result.isSaved;
      widget.house.isSaved = result.isSaved;
      loading = false;
    });
    if (result.confirmed && result.isSaved != previous) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.isSaved
            ? 'Saved to your shortlist'
            : 'Removed from saved homes'),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
      ));
    } else if (result.queued) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.isSaved
            ? 'Saved on this device · will sync when online'
            : 'Removed on this device · will sync when online'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ));
    } else if (result.errorMessage != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.errorMessage!)));
    }
  }

  Future<void> _share() async {
    final house = widget.house;
    final price = house.priceRental > 0
        ? 'K${house.priceRental.toString()}/month'
        : 'Price on request';
    final details = <String>[
      house.name,
      '${house.address} · $price',
      if (house.bedrooms > 0)
        '${house.bedrooms} bedroom${house.bedrooms == 1 ? '' : 's'}',
      'Find it on Haven Zambia',
      // This URL is deliberately a stable app deep-link shape. The web
      // listing route can be enabled independently of the mobile release.
      'https://havenzambia.com/homes/${house.id}',
    ].join('\n');

    try {
      final renderObject = context.findRenderObject();
      final sharePositionOrigin =
          renderObject is RenderBox && renderObject.hasSize
              ? renderObject.localToGlobal(Offset.zero) & renderObject.size
              : null;
      await SharePlus.instance.share(ShareParams(
        text: details,
        subject: '${house.name} · Haven Zambia',
        sharePositionOrigin: sharePositionOrigin,
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppFeedback.messageFor(error,
            fallback: 'The system share sheet is unavailable on this device.')),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 390,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: ApiConfig.optimizedImageUrl(
              widget.house.imageUrl,
              width: 1440,
              height: 900,
              quality: 82,
            ),
            memCacheWidth: 1440,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
                color: Theme.of(context).colorScheme.surfaceContainer),
            errorWidget: (_, __, ___) => Container(
              color: Theme.of(context).colorScheme.surfaceContainer,
              child: Icon(Icons.home_work_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 54),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black45, Colors.transparent, Colors.black38],
                stops: [0, .55, 1],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _RoundAction(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.pop(context)),
                  _RoundAction(
                    icon: saved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    onTap: loading ? null : _save,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            bottom: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                  color: AppColors.surfaceDark.withValues(alpha: .88),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(
                widget.house.listingStatusLabel,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: 12,
            child: _RoundAction(
              icon: Icons.ios_share_rounded,
              onTap: _share,
              tooltip: 'Share this home',
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  const _RoundAction({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      borderRadius: BorderRadius.circular(99),
      tint: Colors.white.withValues(alpha: .78),
      blur: 20,
      shadows: const [
        BoxShadow(
            color: Color(0x24000000), blurRadius: 16, offset: Offset(0, 6)),
      ],
      child: Material(
        color: Colors.transparent,
        child: IconButton(
            onPressed: onTap,
            tooltip: tooltip,
            icon: Icon(icon, color: AppColors.textPrimary),
            iconSize: 21),
      ),
    );
  }
}
