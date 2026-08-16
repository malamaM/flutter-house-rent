import 'dart:io';

import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/models/recommendation.dart';
import 'package:house_rent/services/premium_haptics.dart';
import 'package:house_rent/services/recommendation_service.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:house_rent/widgets/listing_form_components.dart';
import 'package:house_rent/widgets/map_location_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({Key? key}) : super(key: key);

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final pageController = PageController();
  final picker = ImagePicker();
  final formKeys = List.generate(4, (_) => GlobalKey<FormState>());

  final title = TextEditingController();
  final description = TextEditingController();
  final country = TextEditingController(text: 'Zambia');
  final province = TextEditingController();
  final district = TextEditingController();
  final city = TextEditingController();
  final houseNumber = TextEditingController();
  final rentalPrice = TextEditingController();
  final bedrooms = TextEditingController();
  final bathrooms = TextEditingController();
  final size = TextEditingController();
  final parking = TextEditingController();

  int step = 0;
  String propertyType = 'House';
  bool gym = false;
  bool pool = false;
  bool garage = false;
  bool submitting = false;
  double uploadProgress = 0;
  File? coverImage;
  File? reelVideo;
  final List<File> galleryImages = [];
  final List<File> videos = [];
  double? latitude;
  double? longitude;
  late Future<RecommendationOptions> locationOptions;
  int? selectedCityId;
  int? selectedAreaId;

  @override
  void initState() {
    super.initState();
    locationOptions = _loadLocationOptions();
  }

  Future<RecommendationOptions> _loadLocationOptions() =>
      RecommendationService.instance
          .options()
          .catchError((_) => const RecommendationOptions([], []));

  @override
  void dispose() {
    pageController.dispose();
    for (final controller in [
      title,
      description,
      country,
      province,
      district,
      city,
      houseNumber,
      rentalPrice,
      bedrooms,
      bathrooms,
      size,
      parking,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> next() async {
    FocusScope.of(context).unfocus();
    final state = formKeys[step].currentState;
    if (state != null && !state.validate()) return;
    if (step == 3) {
      if (coverImage == null || galleryImages.isEmpty) {
        _message('Add a cover photo and at least one gallery photo.');
        return;
      }
      await submit();
      return;
    }
    await pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> previous() => pageController.previousPage(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );

  Future<void> pickCover() async {
    try {
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 78,
        maxWidth: 1800,
      );
      if (image != null && mounted) {
        setState(() => coverImage = File(image.path));
      }
    } catch (_) {
      _message(
          'Haven could not open your photo library. Check photo permissions.');
    }
  }

  Future<void> pickGallery() async {
    try {
      final images = await picker.pickMultiImage(
        imageQuality: 75,
        maxWidth: 1800,
      );
      if (images.isNotEmpty && mounted) {
        setState(() {
          galleryImages.addAll(images.map((image) => File(image.path)));
          if (galleryImages.length > 12) {
            galleryImages.removeRange(12, galleryImages.length);
          }
        });
      }
    } catch (_) {
      _message(
          'Haven could not open your photo library. Check photo permissions.');
    }
  }

  Future<void> pickVideo({required bool featured}) async {
    try {
      final video = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: featured ? const Duration(minutes: 2) : null,
      );
      if (video == null || !mounted) return;
      setState(() {
        if (featured) {
          reelVideo = File(video.path);
        } else if (videos.length < 4) {
          videos.add(File(video.path));
        }
      });
    } catch (_) {
      _message('Haven could not open your video library. Check permissions.');
    }
  }

  Future<void> selectLocation() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => MapLocationPicker(
          initialLocation:
              latitude == null ? null : LatLng(latitude!, longitude!),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        latitude = result.latitude;
        longitude = result.longitude;
      });
    }
  }

  Future<void> submit() async {
    setState(() {
      submitting = true;
      uploadProgress = 0;
    });
    final payload = <String, dynamic>{
      'title': title.text.trim(),
      'description': description.text.trim(),
      'type': propertyType,
      'status': 'For Rent',
      'country': country.text.trim(),
      'province': province.text.trim().isEmpty ? 'N/A' : province.text.trim(),
      'district': district.text.trim().isEmpty ? 'N/A' : district.text.trim(),
      'city': city.text.trim(),
      'city_id': selectedCityId,
      'area_id': selectedAreaId,
      'address': city.text.trim(),
      'house_number':
          houseNumber.text.trim().isEmpty ? 'N/A' : houseNumber.text.trim(),
      'price_rental': int.tryParse(rentalPrice.text) ?? 0,
      'bedrooms': int.tryParse(bedrooms.text) ?? 0,
      'bathrooms': int.tryParse(bathrooms.text) ?? 0,
      'size': int.tryParse(size.text) ?? 0,
      'gym': gym ? 1 : 0,
      'swimming_pool': pool ? 1 : 0,
      'garage': garage ? 1 : 0,
      'car_garage': int.tryParse(parking.text) ?? 0,
      'latitude': latitude?.toString() ?? '',
      'longitude': longitude?.toString() ?? '',
    };
    final success = await House.createHouse(
      payload,
      coverImage!.path,
      galleryImages.map((image) => image.path).toList(),
      videoPaths: videos.map((video) => video.path).toList(),
      reelVideoPath: reelVideo?.path,
      onProgress: (value) {
        if (mounted) setState(() => uploadProgress = value);
      },
    );
    if (!mounted) return;
    setState(() => submitting = false);
    if (success) {
      PremiumHaptics.success();
      _message('Your listing is now live.');
      Navigator.pop(context, true);
    } else {
      _message(
          'The listing could not be published. Check the details and try again.');
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create listing'),
            Text(
              'A great listing starts with clear details',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _Progress(step: step),
            Expanded(
              child: PageView(
                controller: pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (value) => setState(() => step = value),
                children: [
                  _basics(),
                  _details(),
                  _location(),
                  _photos(),
                ],
              ),
            ),
            _bottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _page(
      {required GlobalKey<FormState> key, required List<Widget> children}) {
    return Form(
      key: key,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: children,
      ),
    );
  }

  Widget _basics() => _page(
        key: formKeys[0],
        children: [
          const ListingSectionHeader(
            eyebrow: 'Step 1 of 4',
            title: 'Tell us about the property',
            description:
                'Use a clear title and description that help people picture the home.',
          ),
          const SizedBox(height: 26),
          ListingTextField(
            controller: title,
            label: 'Listing title',
            hint: 'e.g. Bright three-bedroom home in Kabulonga',
            requiredField: true,
          ),
          ListingTextField(
            controller: description,
            label: 'Description',
            hint: 'Describe the layout, condition and what makes it special…',
            requiredField: true,
            maxLines: 5,
          ),
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
            onChanged: (value) => setState(() => propertyType = value),
          ),
        ],
      );

  Widget _details() => _page(
        key: formKeys[1],
        children: [
          const ListingSectionHeader(
            eyebrow: 'Step 2 of 4',
            title: 'Price and features',
            description:
                'Accurate information builds trust and brings better enquiries.',
          ),
          const SizedBox(height: 26),
          ListingTextField(
            controller: rentalPrice,
            label: 'Monthly rent',
            hint: '0',
            suffix: 'ZMW',
            numeric: true,
            requiredField: true,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
            ],
          ),
          const SizedBox(height: 4),
          Text('Amenities', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
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
        ],
      );

  Widget _location() => _page(
        key: formKeys[2],
        children: [
          const ListingSectionHeader(
            eyebrow: 'Step 3 of 4',
            title: 'Where is it?',
            description:
                'The public map uses an approximate point to protect the exact address.',
          ),
          const SizedBox(height: 26),
          _canonicalLocationFields(),
          ListingTextField(
              controller: province, label: 'Province', hint: 'Lusaka Province'),
          ListingTextField(
              controller: country, label: 'Country', requiredField: true),
          ListingTextField(
              controller: houseNumber,
              label: 'Street or house number',
              hint: 'Only shared where appropriate'),
          const SizedBox(height: 4),
          ListingSurface(
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.location_on_outlined,
                      color: AppColors.primary),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          latitude == null
                              ? 'Map location'
                              : 'Location selected',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(
                          latitude == null
                              ? 'Add an approximate position'
                              : '${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                TextButton(
                    onPressed: selectLocation,
                    child: Text(latitude == null ? 'Select' : 'Change')),
              ],
            ),
          ),
        ],
      );

  Widget _canonicalLocationFields() => FutureBuilder<RecommendationOptions>(
        future: locationOptions,
        builder: (context, snapshot) {
          final options = snapshot.data;
          if (snapshot.hasError || options?.cities.isEmpty == true) {
            return ListingSurface(
              child: Row(children: [
                const Icon(Icons.cloud_off_outlined),
                const SizedBox(width: 12),
                const Expanded(
                    child: Text(
                        'Could not load cities and areas. Check your connection.')),
                TextButton(
                    onPressed: () => setState(
                        () => locationOptions = _loadLocationOptions()),
                    child: const Text('Retry')),
              ]),
            );
          }
          if (options == null) {
            return const ListingSurface(
              child: SizedBox(
                  height: 58,
                  child: Center(child: CircularProgressIndicator())),
            );
          }
          final selectedCity = options.cities
              .where((item) => item.id == selectedCityId)
              .firstOrNull;
          return Column(children: [
            DropdownButtonFormField<int>(
              value: selectedCityId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'City or town'),
              hint: const Text('Choose a city'),
              items: options.cities
                  .map((item) =>
                      DropdownMenuItem(value: item.id, child: Text(item.name)))
                  .toList(),
              validator: (value) => value == null ? 'Choose a city' : null,
              onChanged: (value) => setState(() {
                selectedCityId = value;
                selectedAreaId = null;
                final selected = options.cities
                    .where((item) => item.id == value)
                    .firstOrNull;
                city.text = selected?.name ?? '';
                province.text = selected?.province ?? '';
                district.clear();
              }),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              value: selectedAreaId,
              isExpanded: true,
              decoration:
                  const InputDecoration(labelText: 'Area or neighbourhood'),
              hint: Text(selectedCity == null
                  ? 'Choose a city first'
                  : 'Choose the closest area'),
              items: (selectedCity?.areas ?? const <RentalArea>[])
                  .map((item) =>
                      DropdownMenuItem(value: item.id, child: Text(item.name)))
                  .toList(),
              validator: (value) => value == null ? 'Choose an area' : null,
              onChanged: selectedCity == null
                  ? null
                  : (value) => setState(() {
                        selectedAreaId = value;
                        district.text = selectedCity.areas
                                .where((item) => item.id == value)
                                .firstOrNull
                                ?.name ??
                            '';
                      }),
            ),
            const SizedBox(height: 14),
          ]);
        },
      );

  Widget _videoPickerCard() => ListingSurface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Video tours',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 5),
          Text(
              'Add regular walkthroughs, plus one featured Haven Tour that becomes this listing’s centerpiece.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          _VideoRow(
            icon: Icons.auto_awesome_motion_rounded,
            title: 'Featured tour',
            subtitle: reelVideo == null
                ? 'Optional · best in portrait'
                : reelVideo!.path.split('/').last,
            action: reelVideo == null ? 'Choose' : 'Replace',
            onTap: () => pickVideo(featured: true),
            onRemove: reelVideo == null
                ? null
                : () => setState(() => reelVideo = null),
          ),
          const Divider(height: 24),
          _VideoRow(
            icon: Icons.video_library_outlined,
            title: 'Property videos',
            subtitle: '${videos.length} of 4 selected',
            action: 'Add',
            onTap: () => pickVideo(featured: false),
          ),
          if (videos.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...videos.map((video) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.play_circle_outline_rounded,
                      color: AppColors.primary),
                  title: Text(video.path.split('/').last,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() => videos.remove(video))),
                )),
          ],
        ]),
      );

  Widget _photos() => _page(
        key: formKeys[3],
        children: [
          const ListingSectionHeader(
            eyebrow: 'Step 4 of 4',
            title: 'Make it stand out',
            description:
                'Use bright, recent photos. You can select up to twelve gallery images.',
          ),
          const SizedBox(height: 26),
          _PhotoPicker(
            title: 'Cover photo',
            subtitle: 'The first image people see',
            icon: Icons.add_photo_alternate_outlined,
            image: coverImage,
            onTap: pickCover,
          ),
          const SizedBox(height: 16),
          ListingSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                        child: Text('Gallery photos',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16))),
                    TextButton.icon(
                        onPressed: pickGallery,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add')),
                  ],
                ),
                Text('${galleryImages.length} of 12 selected',
                    style: Theme.of(context).textTheme.bodyMedium),
                if (galleryImages.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: galleryImages
                        .map((image) => _ImageThumb(
                              image: image,
                              onRemove: () =>
                                  setState(() => galleryImages.remove(image)),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _videoPickerCard(),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(16)),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_user_outlined,
                    color: AppColors.primary, size: 21),
                SizedBox(width: 10),
                Expanded(
                    child: Text(
                        'By publishing, you confirm that the property details and photos are accurate.',
                        style: TextStyle(
                            color: AppColors.primaryDark,
                            fontSize: 12,
                            height: 1.4))),
              ],
            ),
          ),
        ],
      );

  Widget _bottomActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          if (step > 0) ...[
            Expanded(
                child: OutlinedButton(
                    onPressed: submitting ? null : previous,
                    child: const Text('Back'))),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: step > 0 ? 1 : 2,
            child: ElevatedButton(
              onPressed: submitting ? null : next,
              child: submitting
                  ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Text('Uploading ${(uploadProgress * 100).round()}%'),
                    ])
                  : Text(step == 3 ? 'Publish listing' : 'Continue'),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _VideoRow(
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

class _Progress extends StatelessWidget {
  final int step;

  const _Progress({required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Row(
        children: List.generate(
            4,
            (index) => Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: 4,
                    margin: EdgeInsets.only(right: index == 3 ? 0 : 7),
                    decoration: BoxDecoration(
                      color:
                          index <= step ? AppColors.primary : AppColors.divider,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                )),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final File? image;
  final VoidCallback onTap;

  const _PhotoPicker(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.image,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 210,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(
              color: image == null ? AppColors.divider : AppColors.primary),
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: image == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: AppColors.primary, size: 38),
                  const SizedBox(height: 12),
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  const Text('Choose photo',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(image!, fit: BoxFit.cover),
                  const DecoratedBox(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black54]))),
                  const Positioned(
                      left: 16,
                      bottom: 14,
                      child: Text('Tap to replace cover',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700))),
                ],
              ),
      ),
    );
  }
}

class _ImageThumb extends StatelessWidget {
  final File image;
  final VoidCallback onRemove;

  const _ImageThumb({required this.image, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(image, width: 82, height: 82, fit: BoxFit.cover)),
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
                        color: Colors.white, size: 15))),
          ),
        ),
      ],
    );
  }
}
