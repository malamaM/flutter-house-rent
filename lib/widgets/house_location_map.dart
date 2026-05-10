import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:house_rent/models/house.dart';

class HouseLocationMap extends StatelessWidget {
  final House house;

  const HouseLocationMap({Key? key, required this.house}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (house.latitude == null || house.longitude == null) {
      return const SizedBox.shrink();
    }

    final center = LatLng(house.latitude!, house.longitude!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Approximate Location',
            style: Theme.of(context).textTheme.displayLarge!.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          height: 250,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[200],
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FlutterMap(
              options: MapOptions(
                center: center,
                zoom: 14.0,
                maxZoom: 18.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token=YOUR_MAPBOX_TOKEN_HERE',
                  userAgentPackageName: 'com.malamachiluwe.houserent',
                  // Fallback to OSM if token is missing
                  fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                ),
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: center,
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                      borderColor: Theme.of(context).primaryColor,
                      borderStrokeWidth: 2,
                      useRadiusInMeter: true,
                      radius: 400, // 400 meters vaguely
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
