import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ColorScheme, Theme;
import 'package:house_rent/models/recommendation.dart';
import 'package:house_rent/services/recommendation_service.dart';

class FilterScreen extends StatefulWidget {
  final Map<String, String> initialFilters;

  const FilterScreen({super.key, required this.initialFilters});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  static const _propertyTypes = [
    'House',
    'Apartment',
    'Bedsitter',
    'Flat',
    'Townhouse',
    'Villa',
    'Other',
  ];
  static const _sortOptions = <String, String>{
    'best_match': 'Best match for me',
    'newest': 'Newest first',
    'price_low': 'Price: low to high',
    'price_high': 'Price: high to low',
  };

  final _keywordController = TextEditingController();
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();
  final _minSizeController = TextEditingController();
  late final Future<List<RentalAmenity>> _amenities;
  final Set<String> _selectedAmenities = {};
  bool _amenitiesCleared = false;

  String? _selectedType;
  int _minBedrooms = 0;
  int _minSelfContainedBedrooms = 0;
  int _minBathrooms = 0;
  String _sort = 'best_match';
  bool _verifiedOnly = false;
  bool _recentlyListed = false;
  bool _recommendedOnly = false;
  bool _dealsOnly = false;

  @override
  void initState() {
    super.initState();
    final filters = widget.initialFilters;
    _keywordController.text = filters['keyword'] ?? '';
    _minPriceController.text = filters['min_price'] ?? '';
    _maxPriceController.text = filters['max_price'] ?? '';
    _minSizeController.text = filters['min_size'] ?? '';
    _selectedType = filters['type']?.isEmpty == true ? null : filters['type'];
    _minBedrooms = int.tryParse(filters['bedrooms'] ?? '0') ?? 0;
    _minSelfContainedBedrooms =
        int.tryParse(filters['self_contained_bedrooms'] ?? '0') ?? 0;
    _minBathrooms = int.tryParse(filters['bathrooms'] ?? '0') ?? 0;
    _sort = _sortOptions.containsKey(filters['sort'])
        ? filters['sort']!
        : 'best_match';
    _amenities = _loadAmenities(filters);
    _verifiedOnly = filters['verified'] == '1';
    _recentlyListed = filters['recently_listed'] == '1';
    _recommendedOnly = filters['recommended'] == '1';
    _dealsOnly = filters['deal'] == '1';
  }

  Future<List<RentalAmenity>> _loadAmenities(
      Map<String, String> filters) async {
    final options = await RecommendationService.instance.options();
    if (!_amenitiesCleared) {
      final selectedKeys = (filters['amenities'] ?? '')
          .split(',')
          .map((key) => key.trim())
          .where((key) => key.isNotEmpty)
          .toSet();
      _selectedAmenities.addAll(options.amenities
          .where((amenity) =>
              selectedKeys.contains(amenity.key) || filters[amenity.key] == '1')
          .map((amenity) => amenity.key));
    }
    return options.amenities;
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _minSizeController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _keywordController.clear();
      _minPriceController.clear();
      _maxPriceController.clear();
      _minSizeController.clear();
      _selectedType = null;
      _minBedrooms = 0;
      _minSelfContainedBedrooms = 0;
      _minBathrooms = 0;
      _sort = 'best_match';
      _selectedAmenities.clear();
      _amenitiesCleared = true;
      _verifiedOnly = false;
      _recentlyListed = false;
      _recommendedOnly = false;
      _dealsOnly = false;
    });
  }

  void _applyFilters() {
    final filters = <String, String>{};
    void addText(String key, TextEditingController controller) {
      final value = controller.text.trim();
      if (value.isNotEmpty) filters[key] = value;
    }

    addText('keyword', _keywordController);
    addText('min_price', _minPriceController);
    addText('max_price', _maxPriceController);
    addText('min_size', _minSizeController);
    if (_selectedType != null) filters['type'] = _selectedType!;
    if (_minBedrooms > 0) filters['bedrooms'] = '$_minBedrooms';
    if (_minSelfContainedBedrooms > 0) {
      filters['self_contained_bedrooms'] = '$_minSelfContainedBedrooms';
    }
    if (_minBathrooms > 0) filters['bathrooms'] = '$_minBathrooms';
    if (_sort != 'best_match') filters['sort'] = _sort;
    if (_selectedAmenities.isNotEmpty) {
      final amenities = _selectedAmenities.toList()..sort();
      filters['amenities'] = amenities.join(',');
    }
    if (_verifiedOnly) filters['verified'] = '1';
    if (_recentlyListed) filters['recently_listed'] = '1';
    if (_recommendedOnly) filters['recommended'] = '1';
    if (_dealsOnly) filters['deal'] = '1';
    Navigator.pop(context, filters);
  }

  Future<void> _pickPropertyType() async {
    final selected = await showCupertinoModalPopup<String?>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Property type'),
        message: const Text('Choose one type, or show every rental.'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, ''),
            isDefaultAction: _selectedType == null,
            child: const Text('Any property type'),
          ),
          for (final type in _propertyTypes)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, type),
              isDefaultAction: _selectedType == type,
              child: Text(type),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => _selectedType = selected.isEmpty ? null : selected);
  }

  Future<void> _pickSort() async {
    final selected = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Sort results'),
        actions: [
          for (final option in _sortOptions.entries)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, option.key),
              isDefaultAction: _sort == option.key,
              child: Text(option.value),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _sort = selected);
  }

  @override
  Widget build(BuildContext context) {
    final material = Theme.of(context);
    final colors = material.colorScheme;
    final divider = colors.outlineVariant.withValues(alpha: .55);
    return CupertinoTheme(
      data: CupertinoTheme.of(context).copyWith(
        primaryColor: colors.primary,
        scaffoldBackgroundColor: material.scaffoldBackgroundColor,
        // Keep the navigation bar opaque so CupertinoPageScaffold lays the
        // scrollable content below it instead of allowing the first row to
        // slide underneath the bar.
        barBackgroundColor: material.scaffoldBackgroundColor,
      ),
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('Refine your search'),
          leading: CupertinoNavigationBarBackButton(
            onPressed: () => Navigator.pop(context),
          ),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _resetFilters,
            child: const Text('Clear'),
          ),
          border: Border(bottom: BorderSide(color: divider, width: .5)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: CupertinoScrollbar(
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                    children: [
                      _sectionLabel('SEARCH'),
                      _group(colors, divider, [
                        _inputRow(
                          colors,
                          controller: _keywordController,
                          icon: CupertinoIcons.search,
                          placeholder: 'Area, city or property',
                          textInputAction: TextInputAction.search,
                        ),
                      ]),
                      _sectionLabel('PROPERTY'),
                      _group(colors, divider, [
                        _choiceRow(
                          colors,
                          icon: CupertinoIcons.house,
                          title: 'Property type',
                          value: _selectedType ?? 'Any property type',
                          onTap: _pickPropertyType,
                        ),
                        _divider(divider),
                        _stepperRow(
                          colors,
                          title: 'Bedrooms',
                          value: _minBedrooms,
                          onMinus: _minBedrooms == 0
                              ? null
                              : () => setState(() => _minBedrooms--),
                          onPlus: () => setState(() => _minBedrooms++),
                        ),
                        _divider(divider),
                        _stepperRow(
                          colors,
                          title: 'Self-contained bedrooms',
                          value: _minSelfContainedBedrooms,
                          onMinus: _minSelfContainedBedrooms == 0
                              ? null
                              : () =>
                                  setState(() => _minSelfContainedBedrooms--),
                          onPlus: () =>
                              setState(() => _minSelfContainedBedrooms++),
                        ),
                        _divider(divider),
                        _stepperRow(
                          colors,
                          title: 'Bathrooms',
                          value: _minBathrooms,
                          onMinus: _minBathrooms == 0
                              ? null
                              : () => setState(() => _minBathrooms--),
                          onPlus: () => setState(() => _minBathrooms++),
                        ),
                      ]),
                      _sectionLabel('MONTHLY PRICE'),
                      _group(colors, divider, [
                        Row(children: [
                          Expanded(
                            child: _numberField(
                              colors,
                              _minPriceController,
                              'No minimum',
                              prefix: 'K ',
                            ),
                          ),
                          Container(width: .5, height: 50, color: divider),
                          Expanded(
                            child: _numberField(
                              colors,
                              _maxPriceController,
                              'No maximum',
                              prefix: 'K ',
                            ),
                          ),
                        ]),
                      ]),
                      _sectionLabel('SPACE & AMENITIES'),
                      _group(colors, divider, [
                        _inputRow(
                          colors,
                          controller: _minSizeController,
                          icon: CupertinoIcons.resize,
                          placeholder: 'Minimum floor size',
                          keyboardType: TextInputType.number,
                          suffix: 'm²',
                        ),
                        _divider(divider),
                        FutureBuilder<List<RentalAmenity>>(
                          future: _amenities,
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Padding(
                                padding: const EdgeInsets.all(14),
                                child: Text(
                                  'Amenities could not be loaded.',
                                  style:
                                      TextStyle(color: colors.onSurfaceVariant),
                                ),
                              );
                            }
                            final amenities = snapshot.data;
                            if (amenities == null) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: CupertinoActivityIndicator(),
                              );
                            }
                            return Column(
                              children: [
                                for (var index = 0;
                                    index < amenities.length;
                                    index++) ...[
                                  if (index > 0) _divider(divider),
                                  _toggleRow(
                                    colors,
                                    amenities[index].name,
                                    _selectedAmenities
                                        .contains(amenities[index].key),
                                    (value) => setState(() {
                                      if (value) {
                                        _selectedAmenities
                                            .add(amenities[index].key);
                                      } else {
                                        _selectedAmenities
                                            .remove(amenities[index].key);
                                      }
                                    }),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ]),
                      _sectionLabel('TRUST & DISCOVERY'),
                      _group(colors, divider, [
                        _toggleRow(colors, 'Verified listers', _verifiedOnly,
                            (value) => setState(() => _verifiedOnly = value)),
                        _divider(divider),
                        _toggleRow(
                            colors,
                            'Listed in the last 7 days',
                            _recentlyListed,
                            (value) => setState(() => _recentlyListed = value)),
                        _divider(divider),
                        _toggleRow(
                            colors,
                            'Recommended homes',
                            _recommendedOnly,
                            (value) =>
                                setState(() => _recommendedOnly = value)),
                        _divider(divider),
                        _toggleRow(colors, 'Deals', _dealsOnly,
                            (value) => setState(() => _dealsOnly = value)),
                      ]),
                      _sectionLabel('ORDER'),
                      _group(colors, divider, [
                        _choiceRow(
                          colors,
                          icon: CupertinoIcons.sort_down,
                          title: 'Sort by',
                          value: _sortOptions[_sort]!,
                          onTap: _pickSort,
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: .94),
                  border: Border(top: BorderSide(color: divider, width: .5)),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      borderRadius: BorderRadius.circular(14),
                      onPressed: _applyFilters,
                      child: const Text('Show homes'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 12, 7),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: .15,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
      );

  Widget _group(ColorScheme colors, Color divider, List<Widget> children) =>
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: divider, width: .5),
        ),
        child: Column(children: children),
      );

  Widget _divider(Color color) => Padding(
        padding: const EdgeInsets.only(left: 48),
        child: Container(height: .5, color: color),
      );

  Widget _inputRow(
    ColorScheme colors, {
    required TextEditingController controller,
    required IconData icon,
    required String placeholder,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    String? suffix,
  }) =>
      Row(children: [
        const SizedBox(width: 14),
        Icon(icon, size: 20, color: colors.primary),
        Expanded(
          child: CupertinoTextField(
            controller: controller,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            placeholder: placeholder,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            decoration: null,
            suffix: suffix == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Text(suffix,
                        style: TextStyle(color: colors.onSurfaceVariant)),
                  ),
          ),
        ),
      ]);

  Widget _numberField(ColorScheme colors, TextEditingController controller,
          String placeholder,
          {String? prefix}) =>
      CupertinoTextField(
        controller: controller,
        keyboardType: TextInputType.number,
        placeholder: placeholder,
        prefix: prefix == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Text(prefix,
                    style: TextStyle(color: colors.onSurfaceVariant)),
              ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
        decoration: null,
      );

  Widget _choiceRow(
    ColorScheme colors, {
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) =>
      CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        onPressed: onTap,
        child: Row(children: [
          Icon(icon, size: 20),
          const SizedBox(width: 14),
          Expanded(
              child: Text(title,
                  style: TextStyle(color: colors.onSurface, fontSize: 16))),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 15),
            ),
          ),
          const SizedBox(width: 5),
          const Icon(CupertinoIcons.chevron_forward,
              size: 15, color: CupertinoColors.tertiaryLabel),
        ]),
      );

  Widget _toggleRow(ColorScheme colors, String title, bool value,
          ValueChanged<bool> onChanged) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(children: [
          Expanded(
              child: Text(title,
                  style: TextStyle(color: colors.onSurface, fontSize: 16))),
          CupertinoSwitch(
            value: value,
            activeTrackColor: colors.primary,
            onChanged: onChanged,
          ),
        ]),
      );

  Widget _stepperRow(
    ColorScheme colors, {
    required String title,
    required int value,
    required VoidCallback? onMinus,
    required VoidCallback onPlus,
  }) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
        child: Row(children: [
          Expanded(
              child: Text(title,
                  style: TextStyle(color: colors.onSurface, fontSize: 16))),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(36, 36),
            onPressed: onMinus,
            child: const Icon(CupertinoIcons.minus_circle, size: 26),
          ),
          SizedBox(
            width: 44,
            child: Text(
              value == 0 ? 'Any' : '$value+',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(36, 36),
            onPressed: onPlus,
            child: const Icon(CupertinoIcons.plus_circle, size: 26),
          ),
        ]),
      );
}
