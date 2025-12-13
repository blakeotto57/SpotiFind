import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PlaybackService {
  final db = FirebaseFirestore.instance;

  Future<void> writeTestPlayback() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await db.collection('playback').doc(uid).set({
      'songName': 'September Rain',
      'songArtist': 'Makoto Matsushita',
      'albumArtUrl': 'https://i.scdn.co/image/ab67616d0000b273xxxxxxxxxxxxxxxxxxxx', // any image url works
      'durationMs': 264000,
      'isPlaying': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
