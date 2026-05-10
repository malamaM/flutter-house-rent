import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    var houses = await House.fetchHouses();
    print("Success: ${houses.length}");
  } catch (e, stack) {
    print("Error: $e");
    print(stack);
  }
}
