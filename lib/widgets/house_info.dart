import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:house_rent/models/house.dart';

class HouseInfo extends StatelessWidget {
  final House house;
  
  const HouseInfo({Key? key, required this.house}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              _MenuInfo(
                imageUrl: 'assets/icons/bedroom.svg',
                content: '${house.bedrooms} Bedroom${house.bedrooms != 1 ? 's' : ''}',
              ),
              _MenuInfo(
                imageUrl: 'assets/icons/bathroom.svg',
                content: '${house.bathrooms} Bathroom${house.bathrooms != 1 ? 's' : ''}',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MenuInfo(
                imageUrl: 'assets/icons/kitchen.svg',
                content: 'Size\n${house.size} sqft',
              ),
              _MenuInfo(
                imageUrl: 'assets/icons/parking.svg',
                content: '${house.carGarage} Car Garage',
              ),
            ],
          )
        ],
      ),
    );
  }
}

class _MenuInfo extends StatelessWidget {
  final String imageUrl;
  final String content;

  const _MenuInfo({
    Key? key,
    required this.imageUrl,
    required this.content,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          SvgPicture.asset(imageUrl),
          const SizedBox(width: 20),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  fontSize: 12,
                ),
          ),
        ],
      ),
    );
  }
}
