import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileService {
  final db = FirebaseFirestore.instance;

  Future<void> setShareNowPlaying(bool value) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await db.collection('users').doc(uid).set({
      'shareNowPlaying': value,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(), // safe if doc doesn't exist yet
    }, SetOptions(merge: true));
  }
}
