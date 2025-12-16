import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:spotifind/models/nearby_row.dart';

class NearbyService {
  // IMPORTANT: match your deployed region
  final FirebaseFunctions functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<List<dynamic>> testNearbyFeed({
    required double lat,
    required double lon,
    double radiusM = 100,
    bool debug = false,
  }) async {
    // Your function requires auth
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }

    print(
      "CALL nearbyFeed lat=$lat lon=$lon radiusM=$radiusM uid=${FirebaseAuth.instance.currentUser!.uid} debug=$debug",
    );


    final callable = functions.httpsCallable('nearbyFeed');

    final result = await callable.call({
      'lat': lat,
      'lon': lon,
      'radiusM': radiusM,
      'debug': debug,
    });

    return result.data;
  }

  /// Fetches nearby songs from Firebase and returns them as NearbyRow objects
  Future<List<NearbyRow>> getNearby({
    required double lat,
    required double lon,
    double radiusM = 500,
  }) async {
    // Ensure auth
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }

    try {
      final rawData = await testNearbyFeed(
        lat: lat,
        lon: lon,
        radiusM: radiusM,
      );

      // Parse the response into NearbyRow objects
      if (rawData is List) {
        return rawData
            .whereType<Map<String, dynamic>>()
            .map((item) => NearbyRow.fromMap(item))
            .toList();
      }

      return [];
    } catch (e) {
      print('Error fetching nearby songs: $e');
      return [];
    }
  }
}
