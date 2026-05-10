import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:house_rent/models/house.dart';

class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({Key? key}) : super(key: key);

  @override
  _CreateListingScreenState createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final PageController _pageController = PageController();
  final ImagePicker _picker = ImagePicker();

  int _currentPage = 0;
  bool _isLoading = false;

  // We need multiple form keys to validate each page independently
  final _formKeys = List.generate(5, (_) => GlobalKey<FormState>());

  // Controllers for text fields
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _typeController = TextEditingController(text: 'House');
  final _statusController = TextEditingController(text: 'For Sale');
  
  final _countryController = TextEditingController();
  final _provinceController = TextEditingController();
  final _districtController = TextEditingController();
  final _cityController = TextEditingController();
  final _houseNumberController = TextEditingController();
  
  final _priceRentalController = TextEditingController();
  final _pricePurchaseController = TextEditingController();
  final _bedroomsController = TextEditingController();
  final _bathroomsController = TextEditingController();
  final _sizeController = TextEditingController();
  
  final _gymController = TextEditingController();
  final _swimmingPoolController = TextEditingController();
  final _garageController = TextEditingController();
  final _carGarageController = TextEditingController();

  File? _coverImage;
  List<File> _galleryImages = [];

  @override
  void dispose() {
    _pageController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _typeController.dispose();
    _statusController.dispose();
    _countryController.dispose();
    _provinceController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    _houseNumberController.dispose();
    _priceRentalController.dispose();
    _pricePurchaseController.dispose();
    _bedroomsController.dispose();
    _bathroomsController.dispose();
    _sizeController.dispose();
    _gymController.dispose();
    _swimmingPoolController.dispose();
    _garageController.dispose();
    _carGarageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    // Validate current page before moving to next
    if (_currentPage != 2 && !_formKeys[_currentPage].currentState!.validate()) {
      return;
    }

    if (_currentPage == 2) {
      if (_coverImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a cover image')));
        return;
      }
      if (_galleryImages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one gallery image')));
        return;
      }
    }

    if (_currentPage < 4) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _submit();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  Future<void> _pickCoverImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _coverImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickGalleryImages() async {
    final pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _galleryImages.addAll(pickedFiles.map((e) => File(e.path)));
      });
    }
  }

  Future<void> _submit() async {
    // Final check
    if (!_formKeys[4].currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final data = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : 'N/A',
      'type': _typeController.text.trim().isNotEmpty ? _typeController.text.trim() : 'House',
      'status': _statusController.text.trim().isNotEmpty ? _statusController.text.trim() : 'For Sale',
      'country': _countryController.text.trim().isNotEmpty ? _countryController.text.trim() : 'N/A',
      'province': _provinceController.text.trim().isNotEmpty ? _provinceController.text.trim() : 'N/A',
      'district': _districtController.text.trim().isNotEmpty ? _districtController.text.trim() : 'N/A',
      'city': _cityController.text.trim(),
      'address': _cityController.text.trim(), 
      'house_number': _houseNumberController.text.trim().isNotEmpty ? _houseNumberController.text.trim() : 'N/A',
      'price_rental': int.tryParse(_priceRentalController.text) ?? 0,
      'price_purchase': int.tryParse(_pricePurchaseController.text) ?? 0,
      'bedrooms': int.tryParse(_bedroomsController.text) ?? 0,
      'bathrooms': int.tryParse(_bathroomsController.text) ?? 0,
      'size': int.tryParse(_sizeController.text) ?? 0,
      'gym': int.tryParse(_gymController.text) ?? 0,
      'swimming_pool': int.tryParse(_swimmingPoolController.text) ?? 0,
      'garage': int.tryParse(_garageController.text) ?? 0,
      'car_garage': int.tryParse(_carGarageController.text) ?? 0,
      'captions[0]': '',
      'types[0]': '',
    };

    final galleryPaths = _galleryImages.map((f) => f.path).toList();

    final success = await House.createHouse(data, _coverImage!.path, galleryPaths);

    setState(() {
      _isLoading = false;
    });

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing created successfully!')),
        );
        Navigator.pop(context, true);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create listing')),
        );
      }
    }
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (index) {
          bool isActive = index == _currentPage;
          bool isCompleted = index < _currentPage;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted || isActive ? Colors.blue : Colors.grey[300],
                  ),
                  child: Center(
                    child: isCompleted 
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : Text('${index + 1}', style: TextStyle(color: isActive ? Colors.white : Colors.grey[600], fontWeight: FontWeight.bold)),
                  ),
                ),
                if (index < 4)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isCompleted ? Colors.blue : Colors.grey[300],
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller, 
    required String label, 
    bool isRequired = false, 
    bool isNumber = false, 
    int maxLines = 1
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label + (isRequired ? ' *' : ''),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        validator: (value) {
          if (isRequired && (value == null || value.trim().isEmpty)) {
            return 'This field is required';
          }
          if (isNumber && value != null && value.trim().isNotEmpty) {
            final parsed = int.tryParse(value.trim());
            if (parsed == null || parsed < 0) {
              return 'Please enter a valid positive number';
            }
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Add New Listing', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: _buildStepIndicator(),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  // Page 1: Basic Info
                  Form(
                    key: _formKeys[0],
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const Text('Basic Information', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text('Start with the main details of the property.', style: TextStyle(color: Colors.grey[600])),
                        const SizedBox(height: 24),
                        _buildTextField(controller: _titleController, label: 'Title', isRequired: true),
                        _buildTextField(controller: _descriptionController, label: 'Description', maxLines: 4),
                        _buildTextField(controller: _typeController, label: 'Type (e.g., House, Apartment)'),
                        _buildTextField(controller: _statusController, label: 'Status (e.g., For Sale, For Rent)'),
                      ],
                    ),
                  ),
                  // Page 2: Location
                  Form(
                    key: _formKeys[1],
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const Text('Location Details', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text('Where is this property located?', style: TextStyle(color: Colors.grey[600])),
                        const SizedBox(height: 24),
                        _buildTextField(controller: _cityController, label: 'City', isRequired: true),
                        _buildTextField(controller: _countryController, label: 'Country'),
                        _buildTextField(controller: _provinceController, label: 'Province/State'),
                        _buildTextField(controller: _districtController, label: 'District'),
                        _buildTextField(controller: _houseNumberController, label: 'House/Street Number'),
                      ],
                    ),
                  ),
                  // Page 3: Images
                  Form(
                    key: _formKeys[2],
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const Text('Images', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text('Showcase the property with high-quality photos.', style: TextStyle(color: Colors.grey[600])),
                        const SizedBox(height: 32),
                        
                        // Cover Image Selector
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blue.withOpacity(0.3), width: 2),
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.blue.withOpacity(0.05),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.image, size: 48, color: Colors.blue[300]),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _pickCoverImage,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.blue, elevation: 0, side: const BorderSide(color: Colors.blue)),
                                child: const Text('Pick Cover Image *'),
                              ),
                              if (_coverImage != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12.0),
                                  child: Text('Selected: ${_coverImage!.path.split('/').last}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Gallery Selector
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.withOpacity(0.3), width: 2),
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.grey.withOpacity(0.05),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.photo_library, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _pickGalleryImages,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 0, side: const BorderSide(color: Colors.grey)),
                                child: const Text('Pick Gallery Images *'),
                              ),
                              if (_galleryImages.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12.0),
                                  child: Text('${_galleryImages.length} images selected', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Page 4: Pricing & Size
                  Form(
                    key: _formKeys[3],
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const Text('Pricing & Dimensions', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text('Set the price and spatial layout.', style: TextStyle(color: Colors.grey[600])),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(child: _buildTextField(controller: _pricePurchaseController, label: 'Purchase Price', isNumber: true)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildTextField(controller: _priceRentalController, label: 'Rental Price', isNumber: true)),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(child: _buildTextField(controller: _bedroomsController, label: 'Bedrooms', isNumber: true)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildTextField(controller: _bathroomsController, label: 'Bathrooms', isNumber: true)),
                          ],
                        ),
                        _buildTextField(controller: _sizeController, label: 'Size (sq ft)', isNumber: true),
                      ],
                    ),
                  ),
                  // Page 5: Amenities
                  Form(
                    key: _formKeys[4],
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const Text('Amenities', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text('Optional extras to make the listing stand out.', style: TextStyle(color: Colors.grey[600])),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(child: _buildTextField(controller: _gymController, label: 'Gym (0/1)', isNumber: true)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildTextField(controller: _swimmingPoolController, label: 'Pool (0/1)', isNumber: true)),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(child: _buildTextField(controller: _garageController, label: 'Garage', isNumber: true)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildTextField(controller: _carGarageController, label: 'Car Garage', isNumber: true)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 8,
                  )
                ]
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: _prevPage,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      child: const Text('Back', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                    )
                  else
                    const SizedBox.shrink(),
                    
                  ElevatedButton(
                    onPressed: _isLoading ? null : _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(_currentPage == 4 ? 'Publish Listing' : 'Next Step', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
