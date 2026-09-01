import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:house_rent/config/api_config.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/screens/details/details.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:house_rent/widgets/haven_navigation_bar.dart';

class ListingDraftPreviewData {
  final String title;
  final String description;
  final String location;
  final String? province;
  final String propertyType;
  final int price;
  final int bedrooms;
  final int bathrooms;
  final int size;
  final int parking;
  final int qualityScore;
  final File? cover;
  final String? coverUrl;
  final List<File> gallery;
  final List<String> galleryUrls;
  final List<String> amenities;

  const ListingDraftPreviewData({
    required this.title,
    required this.description,
    required this.location,
    required this.province,
    required this.propertyType,
    required this.price,
    required this.bedrooms,
    required this.bathrooms,
    required this.size,
    required this.parking,
    required this.qualityScore,
    required this.cover,
    this.coverUrl,
    required this.gallery,
    this.galleryUrls = const [],
    required this.amenities,
  });
}

class ListingPreviewScreen extends StatelessWidget {
  final House? house;
  final ListingDraftPreviewData? draft;

  const ListingPreviewScreen({super.key, this.house, this.draft})
      : assert(house != null || draft != null);

  @override
  Widget build(BuildContext context) {
    if (house != null) {
      return Details(house: house!, isPreview: true);
    }
    return _DraftListingPreview(data: draft!);
  }
}

class _DraftListingPreview extends StatelessWidget {
  final ListingDraftPreviewData data;

  const _DraftListingPreview({required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final photos = <_PreviewPhoto>[
      if (data.cover != null || data.coverUrl != null)
        _PreviewPhoto(file: data.cover, url: data.coverUrl),
      ...data.gallery.map((image) => _PreviewPhoto(file: image)),
      ...data.galleryUrls.map((url) => _PreviewPhoto(url: url)),
    ];
    return Scaffold(
      appBar: const HavenNavigationBar(title: 'Listing preview'),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 36),
        children: [
          SizedBox(
            height: 310,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (photos.isNotEmpty)
                  PageView(
                      children:
                          photos.map((photo) => _previewPhoto(photo)).toList())
                else
                  ColoredBox(
                    color: colors.primaryContainer,
                    child: Icon(Icons.home_work_outlined,
                        size: 58, color: colors.onPrimaryContainer),
                  ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black38,
                        Colors.transparent,
                        Colors.black54
                      ],
                      stops: [0, .45, 1],
                    ),
                  ),
                ),
                const Positioned(
                  left: 18,
                  bottom: 18,
                  child: _PreviewChip(
                    icon: Icons.visibility_outlined,
                    label: 'Preview · not published',
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.title.trim().isEmpty ? 'Untitled home' : data.title,
                    style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 11),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PreviewChip(
                      icon: Icons.auto_awesome_rounded,
                      label: '${data.qualityScore}% listing score',
                      foreground: colors.onPrimaryContainer,
                      background: colors.primaryContainer,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        color: colors.onSurfaceVariant, size: 19),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        [data.location, data.province]
                            .whereType<String>()
                            .where((part) => part.trim().isNotEmpty)
                            .join(', '),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                Text(_price(data.price),
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 22),
                const _PreviewSectionTitle(title: 'Property details'),
                const SizedBox(height: 12),
                _DetailGrid(data: data),
                if (data.amenities.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  const _PreviewSectionTitle(title: 'Amenities'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: data.amenities
                        .map((item) => Chip(
                              avatar: Icon(Icons.check_rounded,
                                  size: 16, color: colors.primary),
                              label: Text(item),
                              side: BorderSide(color: colors.outlineVariant),
                              backgroundColor: colors.surface,
                            ))
                        .toList(),
                  ),
                ],
                if (data.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 28),
                  const _PreviewSectionTitle(title: 'About this home'),
                  const SizedBox(height: 10),
                  Text(data.description,
                      style: Theme.of(context).textTheme.bodyLarge),
                ],
                if (photos.length > 1) ...[
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      const Expanded(
                          child: _PreviewSectionTitle(title: 'Gallery')),
                      Text('${photos.length} photos',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 118,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: photos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, index) => ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: SizedBox(
                            width: 156, child: _previewPhoto(photos[index])),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: .65),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline_rounded,
                          color: colors.onPrimaryContainer),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This is the customer-facing view. Publish when the photos, price and description feel ready.',
                          style: TextStyle(
                              color: colors.onPrimaryContainer, height: 1.35),
                        ),
                      ),
                    ],
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

class _PreviewPhoto {
  final File? file;
  final String? url;

  const _PreviewPhoto({this.file, this.url});
}

Widget _previewPhoto(_PreviewPhoto photo) {
  if (photo.file != null) return Image.file(photo.file!, fit: BoxFit.cover);
  if (photo.url?.isNotEmpty == true) {
    return CachedNetworkImage(
      imageUrl: ApiConfig.optimizedImageUrl(
        photo.url!,
        width: 1200,
        height: 800,
        quality: 82,
      ),
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => const _PreviewImageFallback(),
    );
  }
  return const _PreviewImageFallback();
}

class _PreviewImageFallback extends StatelessWidget {
  const _PreviewImageFallback();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.primaryContainer,
      child: Icon(Icons.home_work_outlined,
          size: 58, color: colors.onPrimaryContainer),
    );
  }
}

class _DetailGrid extends StatelessWidget {
  final ListingDraftPreviewData data;

  const _DetailGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final entries = [
      (Icons.bed_outlined, '${data.bedrooms}', 'Bedrooms'),
      (Icons.bathtub_outlined, '${data.bathrooms}', 'Bathrooms'),
      (Icons.home_work_outlined, data.propertyType, 'Property type'),
      if (data.size > 0)
        (Icons.square_foot_outlined, '${data.size} m²', 'Floor size'),
      if (data.parking > 0)
        (Icons.local_parking_outlined, '${data.parking}', 'Parking'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: entries
              .map((entry) => Container(
                    width: width,
                    constraints: const BoxConstraints(minHeight: 92),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(
                            color:
                                Theme.of(context).colorScheme.outlineVariant)),
                    child: Row(
                      children: [
                        Icon(entry.$1,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(entry.$2,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 3),
                              Text(entry.$3,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _PreviewSectionTitle extends StatelessWidget {
  final String title;

  const _PreviewSectionTitle({required this.title});

  @override
  Widget build(BuildContext context) =>
      Text(title, style: Theme.of(context).textTheme.headlineSmall);
}

class _PreviewChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? foreground;
  final Color? background;

  const _PreviewChip({
    required this.icon,
    required this.label,
    this.foreground,
    this.background,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: background ?? AppColors.surfaceDark.withValues(alpha: .88),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: foreground ?? Colors.white),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: foreground ?? Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800)),
        ]),
      );
}

String _price(int value) {
  if (value <= 0) return 'Price on request';
  return 'K${value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')} / month';
}
