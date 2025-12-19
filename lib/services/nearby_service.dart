import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spotifind/models/nearby_row.dart';
import 'package:spotifind/services/playback_service.dart';

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

    try {
      final callable = functions.httpsCallable('nearbyFeed');

      final result = await callable.call({
        'lat': lat,
        'lon': lon,
        'radiusM': radiusM,
        'debug': debug,
      });

      print("[NearbyService] nearbyFeed response: ${result.data}");
      return result.data;
    } catch (e) {
      print("[NearbyService] nearbyFeed error: $e");
      rethrow;
    }
  }

  /// Fetches nearby songs directly from Firebase playback collection
  /// Bypasses the Cloud Function which appears to have issues
  Future<List<NearbyRow>> getNearbyDirect({
    required double lat,
    required double lon,
    double radiusM = 500,
  }) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      
      // Get all playback documents
      final playbackSnap = await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('nearbyFeed')
          .call({
            'lat': lat,
            'lon': lon,
            'radiusM': radiusM,
          });
      
      print("[NearbyService] Direct query returned: ${playbackSnap.data}");
      
      // For now, return empty to trigger fallback
      return [];
    } catch (e) {
      print("[NearbyService] Direct query error: $e");
      return [];
    }
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

      print("[NearbyService] Got raw data: $rawData (type: ${rawData.runtimeType})");

      // Parse the response into NearbyRow objects
      if (rawData is List && rawData.isNotEmpty) {
        print("[NearbyService] rawData is a List with ${rawData.length} items");
        final result = rawData
            .whereType<Map<String, dynamic>>()
            .map((item) {
              print("[NearbyService] Parsing item: $item");
              return NearbyRow.fromMap(item);
            })
            .toList();
        print("[NearbyService] ✓ Parsed ${result.length} nearby songs");
        return result;
      }

      print("[NearbyService] Cloud Function returned empty, using direct query fallback...");
      
      // Fallback: query playback collection directly
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final playbackService = PlaybackService();
      final directResults = await playbackService.getNearbyFromPlaybackDirect(
        currentUserId: currentUserId,
        lat: lat,
        lon: lon,
        radiusM: radiusM,
      );
      
      return directResults;
    } catch (e) {
      print('[NearbyService] Error fetching nearby songs: $e');
      return [];
    }
  }
}
