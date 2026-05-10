import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:house_rent/screens/profile/profile.dart';
import 'package:house_rent/screens/my_listings/my_listings.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) {
                    return Container(
                      height: 320,
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(Icons.home),
                            title: Text('Home'),
                            onTap: () {
                              Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.account_circle),
                            title: Text('Profile'),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const ProfileScreen()),
                              );
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.list),
                            title: Text('My Listings'),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const MyListingsScreen()),
                              );
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.settings),
                            title: Text('Settings'),
                            onTap: () {
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              icon: SvgPicture.asset('assets/icons/menu.svg'),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              },
              child: const ProfileAvatar(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(50);
}

class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({Key? key}) : super(key: key);

  @override
  _ProfileAvatarState createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  String profileImageUrl = "https://i.postimg.cc/0jqKB6mS/Profile-Image.png";

  @override
  void initState() {
    super.initState();
    _fetchProfileImage();
  }

  Future<void> _fetchProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final String? accessToken = prefs.getString('access_token');

    if (accessToken != null) {
      print('Access Token: $accessToken'); // Print the access token

      final response = await http.get(
        Uri.parse('http://localhost:8000/api/check-login-status'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      print('Request URL: ${response.request?.url}');
      print('Request Headers: ${response.request?.headers}');
      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String? profilePicture = data['user']?['profile_picture'];
        if (profilePicture != null) {
          final String sanitizedProfilePicture = profilePicture.replaceAll("\\", "");
          print('Profile Picture: $sanitizedProfilePicture');
          setState(() {
            profileImageUrl = "http://localhost:8000/storage/$sanitizedProfilePicture";
          });
        } else {
          // Handle missing profile picture
          print('Profile picture not found in response');
        }
      } else {
        // Handle error
        print('Failed to load profile image');
      }
    } else {
      // Handle missing token
      print('Access token not found');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundImage: NetworkImage(profileImageUrl),
    );
  }
}
