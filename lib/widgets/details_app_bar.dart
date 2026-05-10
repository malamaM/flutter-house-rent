import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:house_rent/models/house.dart';

class DetailsAppBar extends StatefulWidget {
  final House house;

  const DetailsAppBar({
    Key? key,
    required this.house,
  }) : super(key: key);

  @override
  _DetailsAppBarState createState() => _DetailsAppBarState();
}

class _DetailsAppBarState extends State<DetailsAppBar> {
  bool _isLoading = false;
  late bool _isSaved;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.house.isSaved;
  }

  _handleNavigateBack(BuildContext context) {
    Navigator.of(context).pop();
  }

  void _handleSave() async {
    setState(() => _isLoading = true);
    final isSaved = await House.toggleSaveHouse(widget.house.id);
    setState(() {
      _isLoading = false;
      _isSaved = isSaved;
      widget.house.isSaved = isSaved;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isSaved ? 'House saved to bookmarks!' : 'House removed from bookmarks.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400,
      child: Stack(
        children: [
          Image.network(
            widget.house.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => 
              Container(
                color: Colors.grey[300],
                child: Icon(Icons.error_outline),
              ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => _handleNavigateBack(context),
                    child: Container(
                      height: 40,
                      width: 40,
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: SvgPicture.asset('assets/icons/arrow.svg'),
                    ),
                  ),
                  GestureDetector(
                    onTap: _isLoading ? null : _handleSave,
                    child: Container(
                      height: 40,
                      width: 40,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isSaved ? Theme.of(context).primaryColor : Theme.of(context).colorScheme.secondary,
                        shape: BoxShape.circle,
                      ),
                      child: _isLoading 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : SvgPicture.asset('assets/icons/mark.svg', color: _isSaved ? Colors.white : null),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
