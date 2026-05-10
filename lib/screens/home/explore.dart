import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/screens/details/details.dart';
import 'package:house_rent/screens/home/filter_screen.dart';
import 'package:house_rent/widgets/custom_bottom_navigation_bar.dart';
import 'package:house_rent/widgets/search_input.dart';

class Explore extends StatefulWidget {
  const Explore({Key? key}) : super(key: key);

  @override
  _ExploreState createState() => _ExploreState();
}

class _ExploreState extends State<Explore> {
  Map<String, String> _filters = {};
  List<House> _houses = [];
  bool _isLoading = true;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _fetchHouses();
  }

  Future<void> _fetchHouses() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final houses = await House.fetchHouses(filters: _filters);
      // Filter out houses without valid coordinates
      final mappableHouses = houses.where((h) => h.latitude != null && h.longitude != null).toList();
      
      setState(() {
        _houses = mappableHouses;
        _isLoading = false;
      });

      // Optionally center map on the first house if available
      if (_houses.isNotEmpty) {
        _mapController.move(LatLng(_houses.first.latitude!, _houses.first.longitude!), 13.0);
      }
    } catch (e) {
      print('Error fetching map houses: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _openFilterScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FilterScreen(initialFilters: _filters),
      ),
    );

    if (result != null && result is Map<String, String>) {
      setState(() {
        _filters = result;
      });
      _fetchHouses();
    }
  }

  void _showHousePreview(House house) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return GestureDetector(
          onTap: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (context) => Details(house: house)));
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            height: 250,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        house.imageUrl,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Container(
                          width: 100,
                          height: 100,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            house.name,
                            style: Theme.of(context).textTheme.displayLarge!.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            house.address,
                            style: Theme.of(context).textTheme.bodyLarge!.copyWith(fontSize: 14),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '\$${house.priceRental > 0 ? house.priceRental : house.pricePurchase} ${house.priceRental > 0 ? "/ month" : ""}',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => Details(house: house)));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('View Full Details', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Map Layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: LatLng(-15.3875, 28.3228), // Default Lusaka
              zoom: 12.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token=YOUR_MAPBOX_TOKEN_HERE',
                userAgentPackageName: 'com.malamachiluwe.houserent',
                fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              ),
              CircleLayer(
                circles: _houses.map((house) {
                  return CircleMarker(
                    point: LatLng(house.latitude!, house.longitude!),
                    color: Theme.of(context).primaryColor.withOpacity(0.4),
                    borderColor: Theme.of(context).primaryColor,
                    borderStrokeWidth: 2,
                    useRadiusInMeter: true,
                    radius: 400, // 400m radius
                  );
                }).toList(),
              ),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 45,
                  size: const Size(40, 40),
                  anchor: AnchorPos.align(AnchorAlign.center),
                  fitBoundsOptions: const FitBoundsOptions(
                    padding: EdgeInsets.all(50),
                    maxZoom: 15,
                  ),
                  markers: _houses.map((house) {
                    return Marker(
                      point: LatLng(house.latitude!, house.longitude!),
                      width: 60,
                      height: 60,
                      builder: (ctx) => GestureDetector(
                        onTap: () => _showHousePreview(house),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                          ),
                          child: const Icon(Icons.home, color: Colors.white, size: 24),
                        ),
                      ),
                    );
                  }).toList(),
                  builder: (context, markers) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: Center(
                        child: Text(
                          markers.length.toString(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // Foreground Top Layer (Search Bar)
          SafeArea(
            child: Column(
              children: [
                SearchInput(onTap: _openFilterScreen),
                if (_isLoading)
                  const LinearProgressIndicator(),
              ],
            ),
          ),

          // Optional floating filter button badge if filters are active
          if (_filters.isNotEmpty)
            Positioned(
              top: 100,
              right: 20,
              child: GestureDetector(
                onTap: _openFilterScreen,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_list, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text('${_filters.length} Filters Active', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: CustomBottomNavigationBar(currentIndex: 1),
    );
  }
}
