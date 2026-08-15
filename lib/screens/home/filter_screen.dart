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
    if (_keywordController.text.isNotEmpty)
      filters['keyword'] = _keywordController.text.trim();
    if (_selectedType != null) filters['type'] = _selectedType!;
    if (_minPriceController.text.isNotEmpty)
      filters['min_price'] = _minPriceController.text.trim();
    if (_maxPriceController.text.isNotEmpty)
      filters['max_price'] = _maxPriceController.text.trim();
    if (_minBedrooms > 0) filters['bedrooms'] = _minBedrooms.toString();
    if (_minBathrooms > 0) filters['bathrooms'] = _minBathrooms.toString();

    Navigator.pop(context, filters);
  }

  void _clearFilters() {
    Navigator.pop(context, <String, String>{});
  }

  Widget _buildCounter(String label, int value, VoidCallback onDecrement,
      VoidCallback onIncrement) {
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
              color: value > 0 ? Colors.blue : Colors.grey,
            ),
            Text('$value+',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: onIncrement,
              color: Colors.blue,
            ),
          ],
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Advanced Search'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          TextButton(
            onPressed: _clearFilters,
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Search Keyword',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _keywordController,
              decoration: InputDecoration(
                hintText: 'City, title, or description...',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Property Details',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedType,
              hint: const Text('Property type'),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none),
              ),
              items: ['House', 'Apartment', 'Townhouse', 'Villa']
                  .map((type) =>
                      DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedType = val),
            ),
            const SizedBox(height: 24),
            const Text('Price Range',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minPriceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Min Price',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none),
                    ),
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
                    decoration: InputDecoration(
                      hintText: 'Max Price',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none),
                    ),
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
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: const Offset(0, -2))
          ],
        ),
        child: ElevatedButton(
          onPressed: _applyFilters,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Apply Filters',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
