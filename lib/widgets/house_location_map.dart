import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/theme/app_colors.dart';

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
            'Approximate location',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: AppColors.surfaceContainer,
            border: Border.all(color: AppColors.divider),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: FlutterMap(
              options: MapOptions(
                center: center,
                zoom: 14.0,
                maxZoom: 18.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.malamachiluwe.houserent',
                ),
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: center,
                      color:
                          Theme.of(context).primaryColor.withValues(alpha: 0.3),
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
