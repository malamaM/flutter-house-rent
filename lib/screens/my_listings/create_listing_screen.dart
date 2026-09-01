import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:house_rent/navigation/haven_page_route.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/models/recommendation.dart';
import 'package:house_rent/services/premium_haptics.dart';
import 'package:house_rent/services/recommendation_service.dart';
import 'package:house_rent/services/listing_draft_service.dart';
import 'package:house_rent/services/media_upload_policy.dart';
import 'package:house_rent/services/video_preparation_service.dart';
import 'package:house_rent/services/app_feedback.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:house_rent/widgets/listing_form_components.dart';
import 'package:house_rent/widgets/map_location_picker.dart';
import 'package:house_rent/widgets/amenity_icon.dart';
import 'package:house_rent/widgets/haven_navigation_bar.dart';
import 'package:house_rent/screens/my_listings/listing_preview_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({Key? key}) : super(key: key);

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  static const _draftId = 'create';
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
  final selfContainedBedrooms = TextEditingController(text: '0');
  final bathrooms = TextEditingController();
  final size = TextEditingController();
  final parking = TextEditingController();

  int step = 0;
  String propertyType = 'House';
  bool gym = false;
  bool pool = false;
  bool garage = false;
  final Set<int> amenityIds = {};
  List<RentalAmenity> availableAmenities = const [];
  bool submitting = false;
  double uploadProgress = 0;
  bool preparingVideo = false;
  double videoPreparationProgress = 0;
  File? coverImage;
  File? reelVideo;
  final List<File> galleryImages = [];
  final Map<String, String> galleryImageTypes = {};
  final List<File> videos = [];
  double? latitude;
  double? longitude;
  late Future<RecommendationOptions> locationOptions;
  int? selectedCityId;
  int? selectedAreaId;
  Timer? _draftDebounce;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    locationOptions = _loadLocationOptions();
    for (final controller in _controllers) {
      controller.addListener(_scheduleDraft);
    }
    unawaited(_restoreDraft());
  }

  List<TextEditingController> get _controllers => [
        title,
        description,
        country,
        province,
        district,
        city,
        houseNumber,
        rentalPrice,
        bedrooms,
        selfContainedBedrooms,
        bathrooms,
        size,
        parking,
      ];

  void _scheduleDraft() {
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 700), _saveDraft);
    if (mounted) setState(() {});
  }

  List<String> get _qualityImprovements => [
        if (title.text.trim().length < 12)
          'Use a title with at least 12 characters.',
        if (description.text.trim().length < 80)
          'Describe the home and surroundings in at least 80 characters.',
        if (galleryImages.length < 3) 'Add at least three gallery photos.',
        if (latitude == null || longitude == null)
          'Select an approximate map location.',
        if (selectedCityId == null || selectedAreaId == null)
          'Choose a recognised city and area.',
        if ((int.tryParse(rentalPrice.text) ?? 0) < 300)
          'Confirm a monthly rent of at least K300.',
        if (coverImage == null) 'Add a cover photo.',
      ];

  int get _estimatedQualityScore =>
      (100 - (_qualityImprovements.length * 14)).clamp(0, 100);

  Future<void> _restoreDraft() async {
    final draft = await ListingDraftService.instance.load(_draftId);
    if (draft == null || !mounted) return;
    void text(TextEditingController controller, String key) {
      controller.text = draft[key]?.toString() ?? controller.text;
    }

    text(title, 'title');
    text(description, 'description');
    text(country, 'country');
    text(province, 'province');
    text(district, 'district');
    text(city, 'city');
    text(houseNumber, 'house_number');
    text(rentalPrice, 'price');
    text(bedrooms, 'bedrooms');
    text(selfContainedBedrooms, 'self_contained_bedrooms');
    text(bathrooms, 'bathrooms');
    text(size, 'size');
    text(parking, 'parking');
    File? file(String key) {
      final value = draft[key]?.toString();
      return value != null && File(value).existsSync() ? File(value) : null;
    }

    List<File> files(String key) =>
        (draft[key] is List ? draft[key] as List : const [])
            .map((item) => File('$item'))
            .where((item) => item.existsSync())
            .toList();
    setState(() {
      propertyType = draft['type']?.toString() ?? propertyType;
      gym = draft['gym'] == true;
      pool = draft['pool'] == true;
      garage = draft['garage'] == true;
      amenityIds.addAll((draft['amenity_ids'] is List
              ? draft['amenity_ids'] as List
              : const [])
          .map((id) => int.tryParse('$id') ?? 0)
          .where((id) => id > 0));
      selectedCityId = int.tryParse('${draft['city_id']}');
      selectedAreaId = int.tryParse('${draft['area_id']}');
      latitude = double.tryParse('${draft['latitude']}');
      longitude = double.tryParse('${draft['longitude']}');
      coverImage = file('cover');
      reelVideo = file('reel_video');
      galleryImages.addAll(files('gallery'));
      final savedTypes = draft['gallery_types'];
      if (savedTypes is Map) {
        galleryImageTypes.addAll(savedTypes
            .map((key, value) => MapEntry(key.toString(), value.toString())));
      }
      videos.addAll(files('videos'));
    });
    _message('Your listing draft was restored.');
  }

  Future<void> _saveDraft() => ListingDraftService.instance.save(_draftId, {
        'title': title.text,
        'description': description.text,
        'country': country.text,
        'province': province.text,
        'district': district.text,
        'city': city.text,
        'house_number': houseNumber.text,
        'price': rentalPrice.text,
        'bedrooms': bedrooms.text,
        'self_contained_bedrooms': selfContainedBedrooms.text,
        'bathrooms': bathrooms.text,
        'size': size.text,
        'parking': parking.text,
        'type': propertyType,
        'gym': gym,
        'pool': pool,
        'garage': garage,
        'amenity_ids': amenityIds.toList(),
        'city_id': selectedCityId,
        'area_id': selectedAreaId,
        'latitude': latitude,
        'longitude': longitude,
        'cover': coverImage?.path,
        'reel_video': reelVideo?.path,
        'gallery': galleryImages.map((item) => item.path).toList(),
        'gallery_types': galleryImageTypes,
        'videos': videos.map((item) => item.path).toList(),
      });

  Future<RecommendationOptions> _loadLocationOptions() async {
    try {
      final options = await RecommendationService.instance.options();
      availableAmenities = options.amenities;
      for (final amenity in options.amenities) {
        if ((amenity.key == 'gym' && gym) ||
            (amenity.key == 'swimming_pool' && pool) ||
            (amenity.key == 'garage' && garage)) {
          amenityIds.add(amenity.id);
        }
      }
      return options;
    } catch (_) {
      return const RecommendationOptions([], []);
    }
  }

  void _toggleAmenity(RentalAmenity amenity, bool selected) {
    setState(() {
      if (selected) {
        amenityIds.add(amenity.id);
      } else {
        amenityIds.remove(amenity.id);
      }
      if (amenity.key == 'gym') gym = selected;
      if (amenity.key == 'swimming_pool') pool = selected;
      if (amenity.key == 'garage') garage = selected;
      if (amenity.key == 'self_contained_bedrooms') {
        selfContainedBedrooms.text = selected
            ? ((int.tryParse(selfContainedBedrooms.text) ?? 0) == 0
                ? '1'
                : selfContainedBedrooms.text)
            : '0';
      }
    });
    _scheduleDraft();
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
    if (!_completed) unawaited(_saveDraft());
    pageController.dispose();
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> next() async {
    FocusScope.of(context).unfocus();
    final state = formKeys[step].currentState;
    if (state != null && !state.validate()) return;
    if (step == 1 &&
        (int.tryParse(selfContainedBedrooms.text) ?? 0) >
            (int.tryParse(bedrooms.text) ?? 0)) {
      _message('Self-contained bedrooms cannot exceed total bedrooms.');
      return;
    }
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
        final retained = await ListingDraftService.instance
            .retainMedia(_draftId, image.path);
        if (mounted) setState(() => coverImage = retained);
        unawaited(_saveDraft());
      }
    } catch (error) {
      _message(AppFeedback.messageFor(error,
          fallback:
              'Haven could not open your photo library. Check photo permissions.'));
    }
  }

  Future<void> pickGallery() async {
    try {
      final images = await picker.pickMultiImage(
        imageQuality: 75,
        maxWidth: 1800,
      );
      if (images.isNotEmpty && mounted) {
        final retained = await Future.wait(images.map((image) =>
            ListingDraftService.instance.retainMedia(_draftId, image.path)));
        setState(() {
          galleryImages.addAll(retained);
          for (final image in retained) {
            galleryImageTypes[image.path] = 'other';
          }
          if (galleryImages.length > 12) {
            galleryImages.removeRange(12, galleryImages.length);
          }
        });
        unawaited(_saveDraft());
      }
    } catch (error) {
      _message(AppFeedback.messageFor(error,
          fallback:
              'Haven could not open your photo library. Check photo permissions.'));
    }
  }

  Future<void> pickVideo({required bool featured}) async {
    if (preparingVideo || submitting) return;
    if (!featured && videos.length >= MediaUploadPolicy.maxRegularVideos) {
      _message('A listing can have up to 4 regular videos.');
      return;
    }
    PreparedVideo? prepared;
    try {
      final video = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: featured ? const Duration(minutes: 2) : null,
      );
      if (video == null || !mounted) return;
      setState(() {
        preparingVideo = true;
        videoPreparationProgress = 0;
      });
      prepared = await VideoPreparationService.instance.prepare(
        video.path,
        onProgress: (value) {
          if (mounted) setState(() => videoPreparationProgress = value);
        },
      );
      await MediaUploadPolicy.validateFile(
        prepared.path,
        maxBytes: featured
            ? MediaUploadPolicy.maxReelVideoBytes
            : MediaUploadPolicy.maxVideoBytes,
        label: featured ? 'Featured reel video' : 'Video',
      );
      final retained = await ListingDraftService.instance
          .retainMedia(_draftId, prepared.path);
      if (!mounted) return;
      setState(() {
        if (featured) {
          reelVideo = retained;
        } else if (videos.length < 4) {
          videos.add(retained);
        }
      });
      unawaited(_saveDraft());
    } on MediaUploadException catch (error) {
      _message(error.message);
    } catch (error) {
      _message(AppFeedback.messageFor(error,
          fallback:
              'Haven could not open your video library. Check media permissions.'));
    } finally {
      await prepared?.deleteTemporaryCopy();
      if (mounted) {
        setState(() {
          preparingVideo = false;
          videoPreparationProgress = 0;
        });
      }
    }
  }

  Future<void> selectLocation() async {
    final result = await Navigator.push<LatLng>(
      context,
      HavenPageRoute(
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
      unawaited(_saveDraft());
    }
  }

  Future<void> submit() async {
    if (preparingVideo || submitting) return;
    // This must be local and immediate, not delayed by the media upload.
    PremiumHaptics.action();
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
      'self_contained_bedrooms': int.tryParse(selfContainedBedrooms.text) ?? 0,
      'bathrooms': int.tryParse(bathrooms.text) ?? 0,
      'size': int.tryParse(size.text) ?? 0,
      'gym': gym ? 1 : 0,
      'swimming_pool': pool ? 1 : 0,
      'garage': garage ? 1 : 0,
      'car_garage': int.tryParse(parking.text) ?? 0,
      'amenity_ids': amenityIds.toList(),
      'latitude': latitude?.toString() ?? '',
      'longitude': longitude?.toString() ?? '',
    };
    try {
      await House.createHouse(
        payload,
        coverImage!.path,
        galleryImages.map((image) => image.path).toList(),
        galleryImageTypes: galleryImages
            .map((image) => galleryImageTypes[image.path] ?? 'other')
            .toList(),
        videoPaths: videos.map((video) => video.path).toList(),
        reelVideoPath: reelVideo?.path,
        onProgress: (value) {
          if (mounted) setState(() => uploadProgress = value);
        },
      );
      if (!mounted) return;
      _completed = true;
      await ListingDraftService.instance.clear(_draftId);
      PremiumHaptics.success();
      _message('Your listing is now live.');
      Navigator.pop(context, true);
    } on MediaUploadException catch (error) {
      await _saveDraft();
      _message(error.message);
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  void _showPreview() {
    final selectedAmenities = availableAmenities
        .where((amenity) => amenityIds.contains(amenity.id))
        .map((amenity) => amenity.name)
        .toList();
    Navigator.push<void>(
      context,
      HavenPageRoute(
        builder: (_) => ListingPreviewScreen(
          draft: ListingDraftPreviewData(
            title: title.text.trim(),
            description: description.text.trim(),
            location: [city.text.trim(), district.text.trim()]
                .where((item) => item.isNotEmpty)
                .join(', '),
            province: province.text.trim(),
            propertyType: propertyType,
            price: int.tryParse(rentalPrice.text) ?? 0,
            bedrooms: int.tryParse(bedrooms.text) ?? 0,
            bathrooms: int.tryParse(bathrooms.text) ?? 0,
            size: int.tryParse(size.text) ?? 0,
            parking: int.tryParse(parking.text) ?? 0,
            qualityScore: _estimatedQualityScore,
            cover: coverImage,
            gallery: List<File>.of(galleryImages),
            amenities: selectedAmenities,
          ),
        ),
      ),
    );
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const HavenNavigationBar(title: 'Create listing'),
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
          ListingTextField(
            controller: selfContainedBedrooms,
            label: 'Self-contained bedrooms',
            hint: 'Bedrooms with their own bathroom',
            numeric: true,
            requiredField: true,
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
          FutureBuilder<RecommendationOptions>(
            future: locationOptions,
            builder: (context, snapshot) {
              final amenities = snapshot.data?.amenities ?? const [];
              if (amenities.isEmpty &&
                  snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              return Column(
                children: [
                  for (final amenity in amenities) ...[
                    AmenityTile(
                      icon: amenityIcon(amenity.key),
                      label: amenity.name,
                      value: amenityIds.contains(amenity.id),
                      onChanged: (value) => _toggleAmenity(amenity, value),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
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
          const ListingSurface(
            child: Row(children: [
              Icon(Icons.location_city_outlined),
              SizedBox(width: 12),
              Expanded(
                  child: Text(
                      'Select a city and area below. Both are required before publishing.')),
            ]),
          ),
          const SizedBox(height: 14),
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
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14)),
                  child: Icon(Icons.location_on_outlined,
                      color: Theme.of(context).colorScheme.primary),
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
                Expanded(
                    child: Text(snapshot.hasError
                        ? AppFeedback.messageFor(snapshot.error!,
                            fallback: 'Haven could not load cities and areas.')
                        : 'No active cities or areas are currently available.')),
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
              key: ValueKey('city:$selectedCityId'),
              initialValue: selectedCityId,
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
              key: ValueKey('area:$selectedCityId:$selectedAreaId'),
              initialValue: selectedAreaId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Area or suburb'),
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
                  leading: Icon(Icons.play_circle_outline_rounded,
                      color: Theme.of(context).colorScheme.primary),
                  title: Text(video.path.split('/').last,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() => videos.remove(video))),
                )),
          ],
          if (preparingVideo)
            MediaPreparationIndicator(progress: videoPreparationProgress),
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
          ListingQualityGuide(
            score: _estimatedQualityScore,
            improvements: _qualityImprovements,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: submitting || preparingVideo ? null : _showPreview,
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Preview customer view'),
          ),
          const SizedBox(height: 16),
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
                              type: galleryImageTypes[image.path] ?? 'other',
                              onTypeChanged: (type) => setState(
                                  () => galleryImageTypes[image.path] = type),
                              onRemove: () => setState(() {
                                galleryImages.remove(image);
                                galleryImageTypes.remove(image.path);
                              }),
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
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_user_outlined,
                    color: Theme.of(context).colorScheme.primary, size: 21),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(
                        'By publishing, you confirm that the property details and photos are accurate.',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
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
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
            top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          if (step > 0) ...[
            Expanded(
                child: OutlinedButton(
                    onPressed: submitting || preparingVideo ? null : previous,
                    child: const Text('Back'))),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: step > 0 ? 1 : 2,
            child: ElevatedButton(
              onPressed: submitting || preparingVideo ? null : next,
              child: submitting
                  ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Text(
                          'Uploading media ${(uploadProgress * 100).round()}%'),
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
        Icon(icon, color: Theme.of(context).colorScheme.primary),
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
                      color: index <= step
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
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
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          border: Border.all(
              color: image == null
                  ? Theme.of(context).colorScheme.outlineVariant
                  : Theme.of(context).colorScheme.primary),
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: image == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      color: Theme.of(context).colorScheme.primary, size: 38),
                  const SizedBox(height: 12),
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  Text('Choose photo',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
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
  final String type;
  final ValueChanged<String> onTypeChanged;
  final VoidCallback onRemove;

  const _ImageThumb(
      {required this.image,
      required this.type,
      required this.onTypeChanged,
      required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: Column(
        children: [
          Stack(clipBehavior: Clip.none, children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(image,
                    width: 82, height: 82, fit: BoxFit.cover)),
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
          ]),
          const SizedBox(height: 7),
          ListingPhotoTypePicker(value: type, onChanged: onTypeChanged)
        ],
      ),
    );
  }
}
