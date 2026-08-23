import 'package:flutter/material.dart';

class FilterScreen extends StatefulWidget {
  final Map<String, String> initialFilters;

  const FilterScreen({Key? key, required this.initialFilters})
      : super(key: key);

  @override
  _FilterScreenState createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  final TextEditingController _keywordController = TextEditingController();
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();

  String? _selectedType;
  int _minBedrooms = 0;
  int _minBathrooms = 0;

  @override
  void initState() {
    super.initState();
    _keywordController.text = widget.initialFilters['keyword'] ?? '';
    _minPriceController.text = widget.initialFilters['min_price'] ?? '';
    _maxPriceController.text = widget.initialFilters['max_price'] ?? '';

    _selectedType = widget.initialFilters['type'];
    if (_selectedType != null && _selectedType!.isEmpty) _selectedType = null;

    _minBedrooms = int.tryParse(widget.initialFilters['bedrooms'] ?? '0') ?? 0;
    _minBathrooms =
        int.tryParse(widget.initialFilters['bathrooms'] ?? '0') ?? 0;
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    Map<String, String> filters = {};
    if (_keywordController.text.isNotEmpty) {
      filters['keyword'] = _keywordController.text.trim();
    }
    if (_selectedType != null) filters['type'] = _selectedType!;
    if (_minPriceController.text.isNotEmpty) {
      filters['min_price'] = _minPriceController.text.trim();
    }
    if (_maxPriceController.text.isNotEmpty) {
      filters['max_price'] = _maxPriceController.text.trim();
    }
    if (_minBedrooms > 0) filters['bedrooms'] = _minBedrooms.toString();
    if (_minBathrooms > 0) filters['bathrooms'] = _minBathrooms.toString();

    Navigator.pop(context, filters);
  }

  void _clearFilters() {
    Navigator.pop(context, <String, String>{});
  }

  Widget _buildCounter(String label, int value, VoidCallback onDecrement,
      VoidCallback onIncrement) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: value > 0 ? onDecrement : null,
              color: value > 0 ? colors.primary : colors.onSurfaceVariant,
            ),
            Text('$value+',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: onIncrement,
              color: colors.primary,
            ),
          ],
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Refine your search'),
        actions: [
          TextButton(
            onPressed: _clearFilters,
            child: Text('Clear all',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Search', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _keywordController,
              decoration: const InputDecoration(
                hintText: 'City, title, or description…',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 24),
            Text('Property details',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              hint: const Text('Property type'),
              decoration: const InputDecoration(
                  labelText: 'Property type',
                  prefixIcon: Icon(Icons.home_work_outlined)),
              items: [
                'House',
                'Apartment',
                'Bedsitter',
                'Flat',
                'Townhouse',
                'Villa'
              ]
                  .map((type) =>
                      DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedType = val),
            ),
            const SizedBox(height: 24),
            Text('Monthly price range',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Minimum', prefixText: 'K '),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('-'),
                ),
                Expanded(
                  child: TextField(
                    controller: _maxPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Maximum', prefixText: 'K '),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildCounter(
                'Bedrooms',
                _minBedrooms,
                () => setState(() => _minBedrooms--),
                () => setState(() => _minBedrooms++)),
            const SizedBox(height: 16),
            _buildCounter(
                'Bathrooms',
                _minBathrooms,
                () => setState(() => _minBathrooms--),
                () => setState(() => _minBathrooms++)),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surface,
          boxShadow: [
            BoxShadow(
                color: colors.shadow.withValues(alpha: .1),
                blurRadius: 10,
                offset: const Offset(0, -2))
          ],
        ),
        child: ElevatedButton(
          onPressed: _applyFilters,
          child: const Text('Apply filters'),
        ),
      ),
    );
  }
}
