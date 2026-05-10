import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/widgets/custom_bottom_navigation_bar.dart';
import 'package:house_rent/screens/details/details.dart';

class SavedHousesScreen extends StatefulWidget {
  const SavedHousesScreen({Key? key}) : super(key: key);

  @override
  _SavedHousesScreenState createState() => _SavedHousesScreenState();
}

class _SavedHousesScreenState extends State<SavedHousesScreen> {
  List<House> _savedHouses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSavedHouses();
  }

  Future<void> _fetchSavedHouses() async {
    setState(() => _isLoading = true);
    try {
      final houses = await House.fetchSavedHouses();
      setState(() {
        _savedHouses = houses;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching saved houses: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Saved Houses', style: Theme.of(context).textTheme.displayLarge!.copyWith(fontSize: 20, fontWeight: FontWeight.bold)),
        centerTitle: true,
        automaticallyImplyLeading: false, // Prevent back button since it's a bottom nav tab
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedHouses.isEmpty
              ? const Center(child: Text('You have no saved houses yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _savedHouses.length,
                  itemBuilder: (context, index) {
                    final house = _savedHouses[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => Details(house: house)));
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
                              child: Image.network(
                                house.imageUrl,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Container(width: 120, height: 120, color: Colors.grey[300], child: const Icon(Icons.image)),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      house.name,
                                      style: Theme.of(context).textTheme.displayLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      house.address,
                                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      '\$${house.priceRental > 0 ? house.priceRental : house.pricePurchase}',
                                      style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      bottomNavigationBar: CustomBottomNavigationBar(currentIndex: 4), // 4 is the index of home_mark
    );
  }
}
