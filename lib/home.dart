import 'package:flutter/material.dart';
import 'package:spotifind/services/location_service.dart';
import 'package:spotifind/services/nearby_service.dart';
import 'package:spotifind/services/playback_service.dart';
import 'package:spotifind/services/profile_service.dart';
import 'package:geolocator/geolocator.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = NearbyService();
    final profile = ProfileService();
    final loc = LocationService();

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildSongTile(),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () async {
                      try {
                        // Ensure permission (simulators still require it)
                        LocationPermission perm =
                            await Geolocator.checkPermission();
                        if (perm == LocationPermission.denied) {
                          perm = await Geolocator.requestPermission();
                        }
                        if (perm == LocationPermission.deniedForever) {
                          throw Exception("Location permission denied forever");
                        }

                        final pos = await Geolocator.getCurrentPosition(
                          desiredAccuracy: LocationAccuracy.high,
                        );

                        print(
                          "CALL nearbyFeed lat=${pos.latitude}, lon=${pos.longitude}",
                        );

                        final rows = await service.testNearbyFeed(
                          lat: pos.latitude,
                          lon: pos.longitude,
                          radiusM: 500, // use 500 while testing
                        );

                        print('nearbyFeed rows: $rows');
                      } catch (e) {
                        print('nearbyFeed error: $e');
                      }
                    },
                    child: const Text('Test nearbyFeed'),
                  ),

                  ElevatedButton(
                    onPressed: () async {
                      await profile.setShareNowPlaying(true);
                      print("shareNowPlaying = true");
                    },
                    child: const Text("Enable Sharing"),
                  ),

                  ElevatedButton(
                    onPressed: () async {
                      await loc.writeCurrentLocation();
                      print("Wrote current location");
                    },
                    child: const Text("Update Location"),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await PlaybackService().writeTestPlayback();
                      print("Wrote test playback");
                    },
                    child: const Text("Update Playback"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Icon(Icons.menu, color: Colors.white, size: 30),
          const Text(
            "SpotiFind",
            style: TextStyle(
              color: Color(0xFF1DB954),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey.shade800,
            child: const Icon(Icons.person, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildSongTile() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2C),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.image, color: Colors.green, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              "Come Back — Buddha Remastered",
              style: const TextStyle(
                color: Color(0xFF1DB954),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Icon(Icons.home_filled, color: Color(0xFF1DB954), size: 30),
          Icon(Icons.search, color: Colors.grey, size: 28),
          Icon(Icons.swap_horiz, color: Colors.grey, size: 28),
          Icon(Icons.person_outline, color: Colors.grey, size: 28),
        ],
      ),
    );
  }
}
