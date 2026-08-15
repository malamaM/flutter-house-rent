import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/services/app_data_service.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:house_rent/widgets/listing_form_components.dart';
import 'package:image_picker/image_picker.dart';

class EditListingScreen extends StatefulWidget {
  final House house;

  const EditListingScreen({Key? key, required this.house}) : super(key: key);

  @override
  State<EditListingScreen> createState() => _EditListingScreenState();
}

class _EditListingScreenState extends State<EditListingScreen> {
  final formKey = GlobalKey<FormState>();
  final picker = ImagePicker();

  late final TextEditingController title;
  late final TextEditingController city;
  late final TextEditingController description;
  late final TextEditingController bedrooms;
  late final TextEditingController bathrooms;
  late final TextEditingController size;
  late final TextEditingController country;
  late final TextEditingController province;
  late final TextEditingController district;
  late final TextEditingController houseNumber;
  late final TextEditingController rentalPrice;
  late final TextEditingController parking;

  late String propertyType;
  late bool gym;
  late bool pool;
  late bool garage;
  File? newCoverImage;
  File? newReelVideo;
  final List<File> newGalleryImages = [];
  final List<File> newVideos = [];
  final List<Map<String, dynamic>> existingGalleryImages = [];
  final List<ListingMediaData> existingMedia = [];
  final List<int> deletedImageIds = [];
  final List<int> deletedMediaIds = [];
  bool loadingImages = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final house = widget.house;
    title = TextEditingController(text: house.name);
    city = TextEditingController(text: house.address);
    description = TextEditingController(text: house.description ?? '');
    bedrooms = TextEditingController(text: house.bedrooms.toString());
    bathrooms = TextEditingController(text: house.bathrooms.toString());
    size = TextEditingController(text: house.size.toString());
    country = TextEditingController(text: house.country ?? '');
    province = TextEditingController(text: house.province ?? '');
    district = TextEditingController(text: house.district ?? '');
    houseNumber = TextEditingController(text: house.houseNumber ?? '');
    rentalPrice = TextEditingController(text: house.priceRental.toString());
    parking = TextEditingController(text: house.carGarage.toString());
    propertyType = _option(
        house.type,
        const ['House', 'Apartment', 'Bedsitter', 'Flat', 'Townhouse', 'Land'],
        'House');
    gym = house.gym == 1;
    pool = house.swimmingPool == 1;
    garage = house.garage == 1;
    _fetchGallery();
    _fetchMedia();
  }

  String _option(String? value, List<String> values, String fallback) {
    return values.contains(value) ? value! : fallback;
  }

  Future<void> _fetchGallery() async {
    try {
      final images = await PropertyDetailsService.gallery(widget.house.id);
      if (!mounted) return;
      setState(() {
        existingGalleryImages
            .addAll(images.map((image) => {'id': image.id, 'url': image.url}));
        loadingImages = false;
      });
    } catch (_) {
      if (mounted) setState(() => loadingImages = false);
    }
  }

  Future<void> _fetchMedia() async {
    final media = await PropertyDetailsService.media(widget.house.id);
    if (mounted) setState(() => existingMedia.addAll(media));
  }

  @override
  void dispose() {
    for (final controller in [
      title,
      city,
      description,
      bedrooms,
      bathrooms,
      size,
      country,
      province,
      district,
      houseNumber,
      rentalPrice,
      parking
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickCover() async {
    try {
      final image = await picker.pickImage(
          source: ImageSource.gallery, imageQuality: 78, maxWidth: 1800);
      if (image != null && mounted) {
        setState(() => newCoverImage = File(image.path));
      }
    } catch (_) {
      _message(
          'Haven could not open your photo library. Check photo permissions.');
    }
  }

  Future<void> _pickGallery() async {
    try {
      final images =
          await picker.pickMultiImage(imageQuality: 75, maxWidth: 1800);
      if (images.isNotEmpty && mounted) {
        setState(() {
          newGalleryImages.addAll(images.map((image) => File(image.path)));
          final available = (12 - existingGalleryImages.length).clamp(0, 12);
          if (newGalleryImages.length > available) {
            newGalleryImages.removeRange(available, newGalleryImages.length);
          }
        });
      }
    } catch (_) {
      _message(
          'Haven could not open your photo library. Check photo permissions.');
    }
  }

  Future<void> _pickVideo({required bool featured}) async {
    try {
      final video = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: featured ? const Duration(minutes: 2) : null,
      );
      if (video == null || !mounted) return;
      setState(() {
        if (featured) {
          newReelVideo = File(video.path);
        } else if (newVideos.length < 4) {
          newVideos.add(File(video.path));
        }
      });
    } catch (_) {
      _message('Haven could not open your video library. Check permissions.');
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!formKey.currentState!.validate()) return;
    setState(() => saving = true);
    final data = <String, dynamic>{
      'title': title.text.trim(),
      'city': city.text.trim(),
      'address': city.text.trim(),
      'description': description.text.trim(),
      'bedrooms': int.tryParse(bedrooms.text) ?? widget.house.bedrooms,
      'bathrooms': int.tryParse(bathrooms.text) ?? widget.house.bathrooms,
      'size': int.tryParse(size.text) ?? widget.house.size,
      'status': 'For Rent',
      'country': country.text.trim(),
      'province': province.text.trim(),
      'district': district.text.trim(),
      'house_number': houseNumber.text.trim(),
      'type': propertyType,
      'price_rental':
          int.tryParse(rentalPrice.text) ?? widget.house.priceRental,
      'gym': gym ? 1 : 0,
      'swimming_pool': pool ? 1 : 0,
      'garage': garage ? 1 : 0,
      'car_garage': int.tryParse(parking.text) ?? widget.house.carGarage,
    };
    final success = await House.updateHouse(
      widget.house.id,
      data,
      coverImagePath: newCoverImage?.path,
      galleryImagePaths: newGalleryImages.isEmpty
          ? null
          : newGalleryImages.map((image) => image.path).toList(),
      deletedImageIds: deletedImageIds,
      videoPaths: newVideos.map((video) => video.path).toList(),
      reelVideoPath: newReelVideo?.path,
      deletedMediaIds: deletedMediaIds,
    );
    if (!mounted) return;
    setState(() => saving = false);
    if (success) {
      _message('Your listing changes are live.');
      Navigator.pop(context, true);
    } else {
      _message('The listing could not be updated. Please try again.');
    }
  }

  void _message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Listing'),
            Text('Keep every detail accurate and inviting',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
          children: [
            const ListingSectionHeader(
                eyebrow: 'Property details',
                title: 'Refine your listing',
                description:
                    'Fresh details and strong photos help renters decide with confidence.'),
            const SizedBox(height: 26),
            ListingTextField(
                controller: title, label: 'Listing title', requiredField: true),
            ListingTextField(
                controller: description,
                label: 'Description',
                requiredField: true,
                maxLines: 5),
            ListingChoice(
                label: 'Property type',
                options: const [
                  'House',
                  'Apartment',
                  'Bedsitter',
                  'Flat',
                  'Townhouse',
                  'Land'
                ],
                selected: propertyType,
                onChanged: (value) => setState(() => propertyType = value)),
            _section('Price & features', 'Set expectations clearly'),
            ListingTextField(
                controller: rentalPrice,
                label: 'Monthly rent',
                suffix: 'ZMW',
                numeric: true,
                requiredField: true),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: ListingTextField(
                      controller: bedrooms,
                      label: 'Bedrooms',
                      numeric: true,
                      requiredField: true)),
              const SizedBox(width: 12),
              Expanded(
                  child: ListingTextField(
                      controller: bathrooms,
                      label: 'Bathrooms',
                      numeric: true,
                      requiredField: true)),
            ]),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: ListingTextField(
                      controller: size,
                      label: 'Floor size',
                      suffix: 'm²',
                      numeric: true,
                      requiredField: true)),
              const SizedBox(width: 12),
              Expanded(
                  child: ListingTextField(
                      controller: parking, label: 'Parking', numeric: true)),
            ]),
            AmenityTile(
                icon: Icons.fitness_center_rounded,
                label: 'Gym',
                value: gym,
                onChanged: (value) => setState(() => gym = value)),
            const SizedBox(height: 10),
            AmenityTile(
                icon: Icons.pool_rounded,
                label: 'Swimming pool',
                value: pool,
                onChanged: (value) => setState(() => pool = value)),
            const SizedBox(height: 10),
            AmenityTile(
                icon: Icons.garage_outlined,
                label: 'Garage',
                value: garage,
                onChanged: (value) => setState(() => garage = value)),
            _section('Location', 'Help people understand the neighbourhood'),
            ListingTextField(
                controller: city, label: 'City or town', requiredField: true),
            ListingTextField(controller: district, label: 'District'),
            ListingTextField(controller: province, label: 'Province'),
            ListingTextField(
                controller: country, label: 'Country', requiredField: true),
            ListingTextField(
                controller: houseNumber, label: 'Street or house number'),
            _section('Photos', 'Keep the presentation bright and current'),
            _coverCard(),
            const SizedBox(height: 16),
            _galleryCard(),
            const SizedBox(height: 16),
            _mediaCard(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.divider))),
          child: ElevatedButton(
            onPressed: saving ? null : _save,
            child: saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Save changes'),
          ),
        ),
      ),
    );
  }

  Widget _section(String title, String subtitle) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ]),
      );

  Widget _coverCard() => ListingSurface(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(children: [
            SizedBox(
              height: 200,
              width: double.infinity,
              child: newCoverImage != null
                  ? Image.file(newCoverImage!, fit: BoxFit.cover)
                  : CachedNetworkImage(
                      imageUrl: widget.house.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          const Center(child: CircularProgressIndicator()),
                      errorWidget: (_, __, ___) => const ColoredBox(
                          color: AppColors.primaryLight,
                          child: Center(
                              child: Icon(Icons.home_work_outlined,
                                  color: AppColors.primary, size: 42))),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Cover photo',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      SizedBox(height: 3),
                      Text('The first image people see',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12))
                    ])),
                TextButton.icon(
                    onPressed: _pickCover,
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: const Text('Replace')),
              ]),
            ),
          ]),
        ),
      );

  Widget _galleryCard() => ListingSurface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(
                    'Gallery · ${existingGalleryImages.length + newGalleryImages.length}/12',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16))),
            TextButton.icon(
                onPressed: _pickGallery,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add')),
          ]),
          const SizedBox(height: 10),
          if (loadingImages)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(18),
                    child: CircularProgressIndicator()))
          else if (existingGalleryImages.isEmpty && newGalleryImages.isEmpty)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text(
                    'No gallery photos yet. Add a few views of the property.',
                    style: TextStyle(color: AppColors.textSecondary)))
          else
            Wrap(spacing: 9, runSpacing: 9, children: [
              ...existingGalleryImages.map((image) => _NetworkThumb(
                    url: image['url'] as String,
                    onRemove: () => setState(() {
                      deletedImageIds.add(image['id'] as int);
                      existingGalleryImages.remove(image);
                    }),
                  )),
              ...newGalleryImages.map((image) => _FileThumb(
                  image: image,
                  onRemove: () =>
                      setState(() => newGalleryImages.remove(image)))),
            ]),
        ]),
      );

  Widget _mediaCard() {
    final featured = existingMedia.where((media) => media.featured).toList();
    final regular = existingMedia.where((media) => !media.featured).toList();
    return ListingSurface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Video tours',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 5),
        Text(
            'A featured tour leads this listing in Haven Tours. Regular videos are shown when no featured tour exists.',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 14),
        _EditVideoRow(
          icon: Icons.auto_awesome_motion_rounded,
          title: 'Featured tour',
          subtitle: newReelVideo != null
              ? newReelVideo!.path.split('/').last
              : featured.isNotEmpty
                  ? 'Current featured tour'
                  : 'Optional · best in portrait',
          action:
              newReelVideo == null && featured.isEmpty ? 'Choose' : 'Replace',
          onTap: () => _pickVideo(featured: true),
          onRemove: newReelVideo != null
              ? () => setState(() => newReelVideo = null)
              : featured.isEmpty
                  ? null
                  : () => setState(() {
                        deletedMediaIds.add(featured.first.id);
                        existingMedia.remove(featured.first);
                      }),
        ),
        const Divider(height: 24),
        _EditVideoRow(
            icon: Icons.video_library_outlined,
            title: 'Property videos',
            subtitle: '${regular.length + newVideos.length} uploaded',
            action: 'Add',
            onTap: () => _pickVideo(featured: false)),
        ...regular.map((media) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.play_circle_outline_rounded,
                color: AppColors.primary),
            title: const Text('Property walkthrough'),
            trailing: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() {
                      deletedMediaIds.add(media.id);
                      existingMedia.remove(media);
                    })))),
        ...newVideos.map((video) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.play_circle_outline_rounded,
                color: AppColors.primary),
            title: Text(video.path.split('/').last,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() => newVideos.remove(video))))),
      ]),
    );
  }
}

class _EditVideoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  const _EditVideoRow(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.action,
      required this.onTap,
      this.onRemove});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: 11),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium)
        ])),
        if (onRemove != null)
          IconButton(
              onPressed: onRemove, icon: const Icon(Icons.close_rounded)),
        TextButton(onPressed: onTap, child: Text(action)),
      ]);
}

class _NetworkThumb extends StatelessWidget {
  final String url;
  final VoidCallback onRemove;
  const _NetworkThumb({required this.url, required this.onRemove});

  @override
  Widget build(BuildContext context) => _ThumbFrame(
        onRemove: onRemove,
        child: CachedNetworkImage(
            imageUrl: url,
            width: 88,
            height: 88,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) =>
                const ColoredBox(color: AppColors.primaryLight)),
      );
}

class _FileThumb extends StatelessWidget {
  final File image;
  final VoidCallback onRemove;
  const _FileThumb({required this.image, required this.onRemove});

  @override
  Widget build(BuildContext context) => _ThumbFrame(
      onRemove: onRemove,
      child: Image.file(image, width: 88, height: 88, fit: BoxFit.cover));
}

class _ThumbFrame extends StatelessWidget {
  final Widget child;
  final VoidCallback onRemove;
  const _ThumbFrame({required this.child, required this.onRemove});

  @override
  Widget build(BuildContext context) =>
      Stack(clipBehavior: Clip.none, children: [
        ClipRRect(borderRadius: BorderRadius.circular(13), child: child),
        Positioned(
          right: -7,
          top: -7,
          child: Material(
              color: AppColors.surfaceDark,
              shape: const CircleBorder(),
              child: InkWell(
                  onTap: onRemove,
                  customBorder: const CircleBorder(),
                  child: const Padding(
                      padding: EdgeInsets.all(5),
                      child: Icon(Icons.close_rounded,
                          color: Colors.white, size: 15)))),
        ),
      ]);
}
