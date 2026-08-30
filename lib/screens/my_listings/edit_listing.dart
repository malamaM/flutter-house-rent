import 'dart:io';
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/models/recommendation.dart';
import 'package:house_rent/navigation/haven_page_route.dart';
import 'package:house_rent/services/app_data_service.dart';
import 'package:house_rent/services/premium_haptics.dart';
import 'package:house_rent/services/listing_draft_service.dart';
import 'package:house_rent/services/media_upload_policy.dart';
import 'package:house_rent/services/video_preparation_service.dart';
import 'package:house_rent/services/app_feedback.dart';
import 'package:house_rent/services/recommendation_service.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:house_rent/widgets/listing_form_components.dart';
import 'package:house_rent/widgets/amenity_icon.dart';
import 'package:house_rent/widgets/haven_navigation_bar.dart';
import 'package:house_rent/widgets/map_location_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

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
  late final TextEditingController selfContainedBedrooms;
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
  final Set<int> amenityIds = {};
  late final Future<List<RentalAmenity>> amenityOptions;
  late Future<RecommendationOptions> locationOptions;
  int? selectedCityId;
  int? selectedAreaId;
  double? latitude;
  double? longitude;
  File? newCoverImage;
  File? newReelVideo;
  final List<File> newGalleryImages = [];
  final Map<String, String> newGalleryImageTypes = {};
  final List<File> newVideos = [];
  final List<Map<String, dynamic>> existingGalleryImages = [];
  final List<ListingMediaData> existingMedia = [];
  final List<int> deletedImageIds = [];
  final List<int> deletedMediaIds = [];
  bool loadingImages = true;
  bool saving = false;
  double uploadProgress = 0;
  bool preparingVideo = false;
  double videoPreparationProgress = 0;
  Timer? _draftDebounce;
  bool _completed = false;
  String get _draftId => 'edit-${widget.house.id}';
  int get _activeRegularVideoCount =>
      existingMedia.where((media) => !media.featured).length + newVideos.length;

  List<TextEditingController> get _controllers => [
        title,
        city,
        description,
        bedrooms,
        selfContainedBedrooms,
        bathrooms,
        size,
        country,
        province,
        district,
        houseNumber,
        rentalPrice,
        parking,
      ];

  @override
  void initState() {
    super.initState();
    final house = widget.house;
    title = TextEditingController(text: house.name);
    city = TextEditingController(text: house.address);
    description = TextEditingController(text: house.description ?? '');
    bedrooms = TextEditingController(text: house.bedrooms.toString());
    selfContainedBedrooms =
        TextEditingController(text: house.selfContainedBedrooms.toString());
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
    amenityIds.addAll(house.amenities.map((amenity) => amenity.id));
    amenityOptions = _loadAmenities();
    selectedCityId = house.cityId;
    selectedAreaId = house.areaId;
    latitude = house.latitude;
    longitude = house.longitude;
    locationOptions = _loadLocationOptions();
    for (final controller in _controllers) {
      controller.addListener(_scheduleDraft);
    }
    unawaited(_restoreDraft());
    _fetchGallery();
    _fetchMedia();
  }

  String _option(String? value, List<String> values, String fallback) {
    return values.contains(value) ? value! : fallback;
  }

  Future<RecommendationOptions> _loadLocationOptions() async {
    final options = await RecommendationService.instance.options();
    if (!options.cities.any((item) => item.id == selectedCityId)) {
      selectedCityId = options.cities
          .where((item) => item.name.toLowerCase() == city.text.toLowerCase())
          .firstOrNull
          ?.id;
    }
    final selectedCity =
        options.cities.where((item) => item.id == selectedCityId).firstOrNull;
    if (selectedCity?.areas.any((item) => item.id == selectedAreaId) != true) {
      selectedAreaId = selectedCity?.areas
          .where(
              (item) => item.name.toLowerCase() == district.text.toLowerCase())
          .firstOrNull
          ?.id;
    }
    return options;
  }

  Future<void> _selectMapLocation() async {
    final result = await Navigator.push<LatLng>(
      context,
      HavenPageRoute(
        builder: (_) => MapLocationPicker(
          initialLocation: latitude == null || longitude == null
              ? null
              : LatLng(latitude!, longitude!),
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

  Future<List<RentalAmenity>> _loadAmenities() async {
    final amenities =
        (await RecommendationService.instance.options()).amenities;
    if (amenityIds.isEmpty) {
      for (final amenity in amenities) {
        if ((amenity.key == 'gym' && gym) ||
            (amenity.key == 'swimming_pool' && pool) ||
            (amenity.key == 'garage' && garage) ||
            (amenity.key == 'self_contained_bedrooms' &&
                (int.tryParse(selfContainedBedrooms.text) ?? 0) > 0)) {
          amenityIds.add(amenity.id);
        }
      }
    }
    return amenities;
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
        if (existingGalleryImages.length + newGalleryImages.length < 3)
          'Keep at least three gallery photos.',
        if (latitude == null || longitude == null)
          'Add an approximate map location.',
        if (selectedCityId == null || selectedAreaId == null)
          'Choose a recognised city and area.',
        if ((int.tryParse(rentalPrice.text) ?? 0) < 300)
          'Confirm a monthly rent of at least K300.',
        if (widget.house.imageUrl.isEmpty && newCoverImage == null)
          'Add a cover photo.',
      ];

  int get _estimatedQualityScore =>
      (100 - (_qualityImprovements.length * 14)).clamp(0, 100);

  Future<void> _restoreDraft() async {
    final draft = await ListingDraftService.instance.load(_draftId);
    if (draft == null || !mounted) return;
    final fields = <String, TextEditingController>{
      'title': title,
      'city': city,
      'description': description,
      'bedrooms': bedrooms,
      'self_contained_bedrooms': selfContainedBedrooms,
      'bathrooms': bathrooms,
      'size': size,
      'country': country,
      'province': province,
      'district': district,
      'house_number': houseNumber,
      'price': rentalPrice,
      'parking': parking,
    };
    for (final entry in fields.entries) {
      if (draft[entry.key] != null) entry.value.text = '${draft[entry.key]}';
    }
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
      if (draft['amenity_ids'] is List) {
        amenityIds
          ..clear()
          ..addAll((draft['amenity_ids'] as List)
              .map((id) => int.tryParse('$id') ?? 0)
              .where((id) => id > 0));
      }
      newCoverImage = file('cover');
      newReelVideo = file('reel_video');
      newGalleryImages.addAll(files('gallery'));
      final savedTypes = draft['gallery_types'];
      if (savedTypes is Map) {
        newGalleryImageTypes.addAll(savedTypes
            .map((key, value) => MapEntry(key.toString(), value.toString())));
      }
      newVideos.addAll(files('videos'));
      selectedCityId = int.tryParse('${draft['city_id']}') ?? selectedCityId;
      selectedAreaId = int.tryParse('${draft['area_id']}') ?? selectedAreaId;
      latitude = double.tryParse('${draft['latitude']}') ?? latitude;
      longitude = double.tryParse('${draft['longitude']}') ?? longitude;
      deletedImageIds.addAll((draft['deleted_image_ids'] is List
              ? draft['deleted_image_ids'] as List
              : const [])
          .map((item) => int.tryParse('$item') ?? 0)
          .where((id) => id > 0));
      deletedMediaIds.addAll((draft['deleted_media_ids'] is List
              ? draft['deleted_media_ids'] as List
              : const [])
          .map((item) => int.tryParse('$item') ?? 0)
          .where((id) => id > 0));
    });
    _message('Your unsent listing changes were restored.');
  }

  Future<void> _saveDraft() => ListingDraftService.instance.save(_draftId, {
        'title': title.text,
        'city': city.text,
        'description': description.text,
        'bedrooms': bedrooms.text,
        'self_contained_bedrooms': selfContainedBedrooms.text,
        'bathrooms': bathrooms.text,
        'size': size.text,
        'country': country.text,
        'province': province.text,
        'district': district.text,
        'house_number': houseNumber.text,
        'price': rentalPrice.text,
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
        'cover': newCoverImage?.path,
        'reel_video': newReelVideo?.path,
        'gallery': newGalleryImages.map((item) => item.path).toList(),
        'gallery_types': newGalleryImageTypes,
        'videos': newVideos.map((item) => item.path).toList(),
        'deleted_image_ids': deletedImageIds,
        'deleted_media_ids': deletedMediaIds,
      });

  Future<void> _fetchGallery() async {
    try {
      final images = await PropertyDetailsService.gallery(widget.house.id);
      if (!mounted) return;
      setState(() {
        existingGalleryImages.addAll(images.map((image) => {
              'id': image.id,
              'url': image.url,
              'type': image.type,
            }));
        loadingImages = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() => loadingImages = false);
        _message(AppFeedback.messageFor(error,
            fallback: 'Haven could not load the existing gallery photos.'));
      }
    }
  }

  Future<void> _fetchMedia() async {
    final media = await PropertyDetailsService.media(widget.house.id);
    if (mounted) setState(() => existingMedia.addAll(media));
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
    if (!_completed) unawaited(_saveDraft());
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickCover() async {
    try {
      final image = await picker.pickImage(
          source: ImageSource.gallery, imageQuality: 78, maxWidth: 1800);
      if (image != null && mounted) {
        final retained = await ListingDraftService.instance
            .retainMedia(_draftId, image.path);
        if (mounted) setState(() => newCoverImage = retained);
        unawaited(_saveDraft());
      }
    } catch (error) {
      _message(AppFeedback.messageFor(error,
          fallback:
              'Haven could not open your photo library. Check photo permissions.'));
    }
  }

  Future<void> _pickGallery() async {
    try {
      final images =
          await picker.pickMultiImage(imageQuality: 75, maxWidth: 1800);
      if (images.isNotEmpty && mounted) {
        final retained = await Future.wait(images.map((image) =>
            ListingDraftService.instance.retainMedia(_draftId, image.path)));
        setState(() {
          newGalleryImages.addAll(retained);
          for (final image in retained) {
            newGalleryImageTypes[image.path] = 'other';
          }
          final available = (12 - existingGalleryImages.length).clamp(0, 12);
          if (newGalleryImages.length > available) {
            newGalleryImages.removeRange(available, newGalleryImages.length);
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

  Future<void> _pickVideo({required bool featured}) async {
    if (preparingVideo || saving) return;
    if (!featured &&
        _activeRegularVideoCount >= MediaUploadPolicy.maxRegularVideos) {
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
          newReelVideo = retained;
        } else if (_activeRegularVideoCount <
            MediaUploadPolicy.maxRegularVideos) {
          newVideos.add(retained);
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

  Future<void> _save() async {
    if (preparingVideo || saving) return;
    FocusScope.of(context).unfocus();
    if (!formKey.currentState!.validate()) return;
    if ((int.tryParse(selfContainedBedrooms.text) ?? 0) >
        (int.tryParse(bedrooms.text) ?? 0)) {
      _message('Self-contained bedrooms cannot exceed total bedrooms.');
      return;
    }
    if (selectedCityId == null) {
      _message('Choose a city or town for this listing.');
      return;
    }
    if (selectedAreaId == null) {
      _message('Choose an area or suburb for this listing.');
      return;
    }
    // Acknowledge the tap straight away; publishing feedback remains separate
    // and is only used once the request actually succeeds.
    PremiumHaptics.action();
    setState(() {
      saving = true;
      uploadProgress = 0;
    });
    final data = <String, dynamic>{
      'title': title.text.trim(),
      'city': city.text.trim(),
      'address': city.text.trim(),
      'description': description.text.trim(),
      'bedrooms': int.tryParse(bedrooms.text) ?? widget.house.bedrooms,
      'self_contained_bedrooms': int.tryParse(selfContainedBedrooms.text) ??
          widget.house.selfContainedBedrooms,
      'bathrooms': int.tryParse(bathrooms.text) ?? widget.house.bathrooms,
      'size': int.tryParse(size.text) ?? widget.house.size,
      'status': 'For Rent',
      'country': country.text.trim(),
      'province': province.text.trim(),
      'district': district.text.trim(),
      if (selectedCityId != null) 'city_id': selectedCityId,
      if (selectedAreaId != null) 'area_id': selectedAreaId,
      'house_number': houseNumber.text.trim(),
      'type': propertyType,
      'price_rental':
          int.tryParse(rentalPrice.text) ?? widget.house.priceRental,
      'gym': gym ? 1 : 0,
      'swimming_pool': pool ? 1 : 0,
      'garage': garage ? 1 : 0,
      'car_garage': int.tryParse(parking.text) ?? widget.house.carGarage,
      'amenity_ids': amenityIds.toList(),
      'amenity_ids_present': 1,
      'latitude': latitude?.toString() ?? '',
      'longitude': longitude?.toString() ?? '',
    };
    try {
      await House.updateHouse(
        widget.house.id,
        data,
        coverImagePath: newCoverImage?.path,
        galleryImagePaths: newGalleryImages.isEmpty
            ? null
            : newGalleryImages.map((image) => image.path).toList(),
        galleryImageTypes: newGalleryImages
            .map((image) => newGalleryImageTypes[image.path] ?? 'other')
            .toList(),
        existingImageTypes: {
          for (final image in existingGalleryImages)
            if (image['id'] is int)
              image['id'] as int: image['type']?.toString() ?? 'other',
        },
        deletedImageIds: deletedImageIds,
        videoPaths: newVideos.map((video) => video.path).toList(),
        reelVideoPath: newReelVideo?.path,
        deletedMediaIds: deletedMediaIds,
        onProgress: (value) {
          if (mounted) setState(() => uploadProgress = value);
        },
      );
      if (!mounted) return;
      _completed = true;
      await ListingDraftService.instance.clear(_draftId);
      PremiumHaptics.success();
      _message('Your listing changes are live.');
      Navigator.pop(context, true);
    } on MediaUploadException catch (error) {
      await _saveDraft();
      _message(error.message);
    } finally {
      if (mounted) setState(() => saving = false);
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
      appBar: const HavenNavigationBar(title: 'Edit Listing'),
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
            ListingQualityGuide(
              score: _estimatedQualityScore,
              improvements: _qualityImprovements,
            ),
            const SizedBox(height: 16),
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
            ListingTextField(
              controller: selfContainedBedrooms,
              label: 'Self-contained bedrooms',
              hint: 'Bedrooms with their own bathroom',
              numeric: true,
              requiredField: true,
            ),
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
            FutureBuilder<List<RentalAmenity>>(
              future: amenityOptions,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final amenities = snapshot.data ?? widget.house.amenities;
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
            _section('Location', 'Help people understand the neighbourhood'),
            const ListingSurface(
              child: Row(children: [
                Icon(Icons.location_city_outlined),
                SizedBox(width: 12),
                Expanded(
                    child: Text(
                        'Select a city and area below. Both are required.')),
              ]),
            ),
            const SizedBox(height: 14),
            FutureBuilder<RecommendationOptions>(
              future: locationOptions,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ListingSurface(
                    child: Row(children: [
                      const Expanded(
                          child: Text('Locations could not be loaded.')),
                      TextButton(
                        onPressed: () => setState(
                            () => locationOptions = _loadLocationOptions()),
                        child: const Text('Retry'),
                      ),
                    ]),
                  );
                }
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final options = snapshot.data!;
                final selectedCity = options.cities
                    .where((item) => item.id == selectedCityId)
                    .firstOrNull;
                return Column(children: [
                  ListingPickerField<int>(
                    label: 'City or town',
                    valueLabel: selectedCity?.name ??
                        (city.text.trim().isEmpty ? null : city.text.trim()),
                    placeholder: 'Choose a city or town',
                    items: options.cities
                        .map((item) => PopupMenuItem<int>(
                              value: item.id,
                              child: Text(item.name),
                            ))
                        .toList(),
                    onSelected: (value) => setState(() {
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
                  ListingPickerField<int>(
                    label: 'Area or suburb',
                    valueLabel: selectedCity?.areas
                        .where((item) => item.id == selectedAreaId)
                        .firstOrNull
                        ?.name,
                    placeholder: selectedCity == null
                        ? 'Choose a city first'
                        : 'Choose an area or suburb',
                    enabled: selectedCity != null,
                    items: (selectedCity?.areas ?? const <RentalArea>[])
                        .map((item) => PopupMenuItem<int>(
                              value: item.id,
                              child: Text(item.name),
                            ))
                        .toList(),
                    onSelected: (value) => setState(() {
                      selectedAreaId = value;
                      district.text = selectedCity!.areas
                              .where((item) => item.id == value)
                              .firstOrNull
                              ?.name ??
                          '';
                    }),
                  ),
                  const SizedBox(height: 14),
                ]);
              },
            ),
            ListingTextField(
                controller: province, label: 'Province', enabled: false),
            ListingTextField(
                controller: country, label: 'Country', requiredField: true),
            ListingTextField(
                controller: houseNumber, label: 'Street or house number'),
            ListingSurface(
              child: Row(children: [
                const Icon(Icons.location_on_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(latitude == null
                      ? 'Select an approximate map location'
                      : 'Map location selected'),
                ),
                TextButton(
                  onPressed: _selectMapLocation,
                  child: Text(latitude == null ? 'Select' : 'Change'),
                ),
              ]),
            ),
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
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                  top: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant))),
          child: ElevatedButton(
            onPressed: saving || preparingVideo ? null : _save,
            child: saving
                ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2)),
                    const SizedBox(width: 10),
                    Text('Uploading media ${(uploadProgress * 100).round()}%'),
                  ])
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
                      errorWidget: (_, __, ___) => ColoredBox(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: Center(
                              child: Icon(Icons.home_work_outlined,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 42))),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('Cover photo',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text('The first image people see',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 12))
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
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                    'No gallery photos yet. Add a few views of the property.',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)))
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final tileWidth = ((constraints.maxWidth - 12) / 2)
                    .clamp(136.0, 220.0)
                    .toDouble();
                return Wrap(spacing: 12, runSpacing: 14, children: [
                  ...existingGalleryImages.map((image) => _NetworkThumb(
                        width: tileWidth,
                        url: image['url'] as String,
                        type: image['type']?.toString() ?? 'other',
                        onTypeChanged: (type) =>
                            setState(() => image['type'] = type),
                        onRemove: () => setState(() {
                          deletedImageIds.add(image['id'] as int);
                          existingGalleryImages.remove(image);
                        }),
                      )),
                  ...newGalleryImages.map((image) => _FileThumb(
                      width: tileWidth,
                      image: image,
                      type: newGalleryImageTypes[image.path] ?? 'other',
                      onTypeChanged: (type) => setState(
                          () => newGalleryImageTypes[image.path] = type),
                      onRemove: () => setState(() {
                            newGalleryImages.remove(image);
                            newGalleryImageTypes.remove(image.path);
                          }))),
                ]);
              },
            ),
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
            leading: Icon(Icons.play_circle_outline_rounded,
                color: Theme.of(context).colorScheme.primary),
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
            leading: Icon(Icons.play_circle_outline_rounded,
                color: Theme.of(context).colorScheme.primary),
            title: Text(video.path.split('/').last,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() => newVideos.remove(video))))),
        if (preparingVideo)
          MediaPreparationIndicator(progress: videoPreparationProgress),
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

class _NetworkThumb extends StatelessWidget {
  final double width;
  final String url;
  final String type;
  final ValueChanged<String> onTypeChanged;
  final VoidCallback onRemove;
  const _NetworkThumb(
      {required this.width,
      required this.url,
      required this.type,
      required this.onTypeChanged,
      required this.onRemove});

  @override
  Widget build(BuildContext context) => _ThumbFrame(
        width: width,
        onRemove: onRemove,
        type: type,
        onTypeChanged: onTypeChanged,
        child: CachedNetworkImage(
            imageUrl: url,
            memCacheWidth: (width * 2).round(),
            width: width,
            height: width * .72,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => ColoredBox(
                color: Theme.of(context).colorScheme.primaryContainer)),
      );
}

class _FileThumb extends StatelessWidget {
  final double width;
  final File image;
  final String type;
  final ValueChanged<String> onTypeChanged;
  final VoidCallback onRemove;
  const _FileThumb(
      {required this.width,
      required this.image,
      required this.type,
      required this.onTypeChanged,
      required this.onRemove});

  @override
  Widget build(BuildContext context) => _ThumbFrame(
      width: width,
      onRemove: onRemove,
      type: type,
      onTypeChanged: onTypeChanged,
      child: Image.file(image,
          width: width, height: width * .72, fit: BoxFit.cover));
}

class _ThumbFrame extends StatelessWidget {
  final double width;
  final Widget child;
  final VoidCallback onRemove;
  final String type;
  final ValueChanged<String> onTypeChanged;
  const _ThumbFrame(
      {required this.width,
      required this.child,
      required this.onRemove,
      required this.type,
      required this.onTypeChanged});

  @override
  Widget build(BuildContext context) => SizedBox(
      width: width,
      child: Column(children: [
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
        ]),
        const SizedBox(height: 7),
        ListingPhotoTypePicker(value: type, onChanged: onTypeChanged)
      ]));
}
