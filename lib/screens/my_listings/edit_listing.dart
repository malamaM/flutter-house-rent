import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:house_rent/models/house.dart';

class EditListingScreen extends StatefulWidget {
  final House house;

  const EditListingScreen({Key? key, required this.house}) : super(key: key);

  @override
  _EditListingScreenState createState() => _EditListingScreenState();
}

class _EditListingScreenState extends State<EditListingScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _addressController; // city
  late TextEditingController _descriptionController;
  late TextEditingController _bedroomsController;
  late TextEditingController _bathroomsController;
  late TextEditingController _sizeController;
  late TextEditingController _statusController;
  late TextEditingController _countryController;
  late TextEditingController _provinceController;
  late TextEditingController _districtController;
  late TextEditingController _houseNumberController;
  late TextEditingController _typeController;
  late TextEditingController _priceRentalController;
  late TextEditingController _pricePurchaseController;
  late TextEditingController _gymController;
  late TextEditingController _swimmingPoolController;
  late TextEditingController _garageController;
  late TextEditingController _carGarageController;

  File? _newCoverImage;
  List<File> _newGalleryImages = [];
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _existingGalleryImages = [];
  List<int> _deletedImageIds = [];
  bool _isLoadingImages = true;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.house.name);
    _addressController = TextEditingController(text: widget.house.address); // city
    _descriptionController = TextEditingController(text: widget.house.description ?? '');
    _bedroomsController = TextEditingController(text: widget.house.bedrooms.toString());
    _bathroomsController = TextEditingController(text: widget.house.bathrooms.toString());
    _sizeController = TextEditingController(text: widget.house.size.toString());
    _statusController = TextEditingController(text: widget.house.status ?? '');
    _countryController = TextEditingController(text: widget.house.country ?? '');
    _provinceController = TextEditingController(text: widget.house.province ?? '');
    _districtController = TextEditingController(text: widget.house.district ?? '');
    _houseNumberController = TextEditingController(text: widget.house.houseNumber ?? '');
    _typeController = TextEditingController(text: widget.house.type ?? '');
    _priceRentalController = TextEditingController(text: widget.house.priceRental.toString());
    _pricePurchaseController = TextEditingController(text: widget.house.pricePurchase.toString());
    _gymController = TextEditingController(text: widget.house.gym.toString());
    _swimmingPoolController = TextEditingController(text: widget.house.swimmingPool.toString());
    _garageController = TextEditingController(text: widget.house.garage.toString());
    _carGarageController = TextEditingController(text: widget.house.carGarage.toString());
    _fetchExistingGallery();
  }

  Future<void> _fetchExistingGallery() async {
    final url = Uri.parse('http://127.0.0.1:8000/api/houses/images');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: json.encode({'house_id': widget.house.id}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['images'] != null && data['images'] is List) {
          setState(() {
            _existingGalleryImages = List<Map<String, dynamic>>.from(data['images']);
            _isLoadingImages = false;
          });
          return;
        }
      } else if (response.statusCode == 418) {
        // 418 means no images found
        setState(() {
          _isLoadingImages = false;
        });
        return;
      }
    } catch (e) {
      print('Error fetching images: $e');
    }
    setState(() {
      _isLoadingImages = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _bedroomsController.dispose();
    _bathroomsController.dispose();
    _sizeController.dispose();
    _statusController.dispose();
    _countryController.dispose();
    _provinceController.dispose();
    _districtController.dispose();
    _houseNumberController.dispose();
    _typeController.dispose();
    _priceRentalController.dispose();
    _pricePurchaseController.dispose();
    _gymController.dispose();
    _swimmingPoolController.dispose();
    _garageController.dispose();
    _carGarageController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (pickedFile != null) {
      setState(() {
        _newCoverImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickGalleryImages() async {
    final pickedFiles = await _picker.pickMultiImage(
      imageQuality: 50,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _newGalleryImages.addAll(pickedFiles.map((e) => File(e.path)).toList());
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final updateData = {
      'title': _titleController.text,
      'city': _addressController.text,
      'description': _descriptionController.text,
      'bedrooms': int.tryParse(_bedroomsController.text) ?? widget.house.bedrooms,
      'bathrooms': int.tryParse(_bathroomsController.text) ?? widget.house.bathrooms,
      'size': int.tryParse(_sizeController.text) ?? widget.house.size,
      'status': _statusController.text,
      'country': _countryController.text,
      'province': _provinceController.text,
      'district': _districtController.text,
      'house_number': _houseNumberController.text,
      'type': _typeController.text,
      'price_rental': int.tryParse(_priceRentalController.text) ?? widget.house.priceRental,
      'price_purchase': int.tryParse(_pricePurchaseController.text) ?? widget.house.pricePurchase,
      'gym': int.tryParse(_gymController.text) ?? widget.house.gym,
      'swimming_pool': int.tryParse(_swimmingPoolController.text) ?? widget.house.swimmingPool,
      'garage': int.tryParse(_garageController.text) ?? widget.house.garage,
      'car_garage': int.tryParse(_carGarageController.text) ?? widget.house.carGarage,
    };

    final success = await House.updateHouse(
      widget.house.id, 
      updateData,
      coverImagePath: _newCoverImage?.path,
      galleryImagePaths: _newGalleryImages.isNotEmpty ? _newGalleryImages.map((f) => f.path).toList() : null,
      deletedImageIds: _deletedImageIds,
    );

    setState(() {
      _isLoading = false;
    });

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing updated successfully!')),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update listing')),
        );
      }
    }
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isNumber = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
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
        title: const Text('Edit Listing'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildTextField(_titleController, 'Title'),
              _buildTextField(_descriptionController, 'Description', maxLines: 3),
              _buildTextField(_typeController, 'Type (e.g., House, Apartment)'),
              _buildTextField(_statusController, 'Status (e.g., For Sale, For Rent)'),
              
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('Location Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              _buildTextField(_countryController, 'Country'),
              _buildTextField(_provinceController, 'Province/State'),
              _buildTextField(_districtController, 'District'),
              _buildTextField(_addressController, 'City'),
              _buildTextField(_houseNumberController, 'House/Street Number'),
              
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('Pricing & Dimensions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Row(
                children: [
                  Expanded(child: _buildTextField(_priceRentalController, 'Rental Price', isNumber: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField(_pricePurchaseController, 'Purchase Price', isNumber: true)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _buildTextField(_bedroomsController, 'Bedrooms', isNumber: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField(_bathroomsController, 'Bathrooms', isNumber: true)),
                ],
              ),
              _buildTextField(_sizeController, 'Size (sq ft)', isNumber: true),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('Amenities', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Row(
                children: [
                  Expanded(child: _buildTextField(_gymController, 'Gym (0/1)', isNumber: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField(_swimmingPoolController, 'Pool (0/1)', isNumber: true)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _buildTextField(_garageController, 'Garage', isNumber: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField(_carGarageController, 'Car Garage', isNumber: true)),
                ],
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('Images', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text('Cover Image', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (_newCoverImage != null)
                      Image.file(_newCoverImage!, height: 150, width: double.infinity, fit: BoxFit.cover)
                    else
                      Image.network(widget.house.imageUrl, height: 150, width: double.infinity, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(height: 150, color: Colors.grey[200], child: const Center(child: Icon(Icons.broken_image)))),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _pickCoverImage,
                      icon: const Icon(Icons.image),
                      label: const Text('Change Cover Image'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.blue),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Gallery Images', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    if (_isLoadingImages)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      if (_existingGalleryImages.isEmpty && _newGalleryImages.isEmpty)
                        const Text('No gallery images.', style: TextStyle(color: Colors.grey)),
                      
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // Existing images
                          ..._existingGalleryImages.map((img) {
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network('http://127.0.0.1:8000/storage/${img['image']}', width: 80, height: 80, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(width: 80, height: 80, color: Colors.grey[300])),
                                ),
                                Positioned(
                                  top: -12,
                                  right: -12,
                                  child: IconButton(
                                    icon: const Icon(Icons.cancel, color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        _deletedImageIds.add(img['id']);
                                        _existingGalleryImages.remove(img);
                                      });
                                    },
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                          
                          // New images
                          ..._newGalleryImages.map((file) {
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(file, width: 80, height: 80, fit: BoxFit.cover),
                                ),
                                Positioned(
                                  top: -12,
                                  right: -12,
                                  child: IconButton(
                                    icon: const Icon(Icons.cancel, color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        _newGalleryImages.remove(file);
                                      });
                                    },
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _pickGalleryImages,
                          icon: const Icon(Icons.add_photo_alternate),
                          label: const Text('Add Gallery Images'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.blue),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
