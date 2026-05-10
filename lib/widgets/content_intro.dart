import 'package:flutter/material.dart';

import 'package:house_rent/models/house.dart';

class ContentIntro extends StatelessWidget {
  final House house;

  const ContentIntro({
    Key? key,
    required this.house,
  }) : super(key: key);

  String getFullLocation() {
    List<String> parts = [];
    if (house.houseNumber != null && house.houseNumber!.isNotEmpty && house.houseNumber != 'N/A') parts.add(house.houseNumber!);
    if (house.address.isNotEmpty && house.address != 'Unknown' && house.address != 'N/A') parts.add(house.address); // city
    if (house.district != null && house.district!.isNotEmpty && house.district != 'N/A') parts.add(house.district!);
    if (house.province != null && house.province!.isNotEmpty && house.province != 'N/A') parts.add(house.province!);
    if (house.country != null && house.country!.isNotEmpty && house.country != 'N/A') parts.add(house.country!);
    
    if (parts.isEmpty) return 'Location not available';
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    String priceText = '\$0';
    String priceSuffix = '';
    
    if (house.priceRental > 0) {
      priceText = '\$${house.priceRental}';
      priceSuffix = ' Per Month';
    } else if (house.pricePurchase > 0) {
      priceText = '\$${house.pricePurchase}';
      priceSuffix = ' To Buy';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            house.name,
            style: Theme.of(context).textTheme.displayLarge!.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, color: Colors.blue, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  getFullLocation(),
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            '${house.size} sqft',
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  fontSize: 14,
                ),
          ),
          const SizedBox(height: 5),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: priceText,
                  style: Theme.of(context).textTheme.displayLarge!.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                ),
                TextSpan(
                  text: priceSuffix,
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                        fontSize: 14,
                      ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
