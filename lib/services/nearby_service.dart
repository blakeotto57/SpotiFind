import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
}
