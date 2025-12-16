import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spotifind/models/current_song.dart';
import 'package:spotifind/services/spotify_auth_service.dart';

class PlaybackService {
  final db = FirebaseFirestore.instance;
  final _spotifyAuth = SpotifyAuthService.instance;

  /// Fetches the currently playing song from Spotify
  Future<CurrentSong?> getCurrentlyPlayingFromSpotify() async {
    try {
      print('[PlaybackService] Attempting to fetch currently playing...');
      
      final data = await _spotifyAuth.getCurrentlyPlaying();
      print('[PlaybackService] getCurrentlyPlaying response: $data');
      
      if (data == null) {
        print('[PlaybackService] No track currently playing (null response)');
        return null;
      }
      
      final song = CurrentSong.fromSpotifyData(data);
      print('[PlaybackService] Successfully parsed song: ${song.songName} by ${song.songArtist}');
      return song;
    } catch (e) {
      print('[PlaybackService] Error fetching currently playing: $e');
      return null;
    }
  }

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
