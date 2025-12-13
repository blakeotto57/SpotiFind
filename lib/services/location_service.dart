import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dart_geohash/dart_geohash.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  final db = FirebaseFirestore.instance;
  final _geo = GeoHasher();

  Future<void> writeCurrentLocation() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      throw Exception("Location permission not granted");
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final hash = _geo.encode(pos.longitude, pos.latitude, precision: 9);
    print("Computed geohash: $hash");

    await db.collection('locations').doc(uid).set({
      'geopoint': GeoPoint(pos.latitude, pos.longitude),
      'geohash': hash,
      'accuracy': pos.accuracy,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
