import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/theme/app_colors.dart';

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
  }

  Future<void> _save() async {
    if (loading) return;
    setState(() => loading = true);
    final result = await House.toggleSaveHouse(
      widget.house.id,
      currentlySaved: saved,
    );
    if (!mounted) return;
    setState(() {
      saved = result;
      widget.house.isSaved = result;
      loading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(saved ? 'Added to saved homes' : 'Removed from saved homes')));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 390,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: widget.house.imageUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) =>
                Container(color: AppColors.surfaceContainer),
            errorWidget: (_, __, ___) => Container(
              color: AppColors.surfaceContainer,
              child: const Icon(Icons.home_work_outlined,
                  color: AppColors.textSecondary, size: 54),
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
                  color: AppColors.surfaceDark.withOpacity(.88),
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
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _RoundAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(.94),
      shape: const CircleBorder(),
      child: IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: AppColors.textPrimary),
          iconSize: 21),
    );
  }
}
