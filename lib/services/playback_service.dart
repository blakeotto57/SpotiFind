import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spotifind/models/current_song.dart';
import 'package:spotifind/models/nearby_row.dart';
import 'package:spotifind/services/spotify_auth_service.dart';

class PlaybackService {
  final db = FirebaseFirestore.instance;
  final _spotifyAuth = SpotifyAuthService.instance;

  /// Fetches the currently playing song from Spotify and writes it to Firebase
  /// Uses the /me/player endpoint which returns playback state regardless of device
  Future<CurrentSong?> getCurrentlyPlayingFromSpotify() async {
    try {
      print('[PlaybackService] Attempting to fetch currently playing...');
      
      // Try the more reliable /me/player endpoint first
      final data = await _spotifyAuth.getCurrentlyPlayingFromAnyDevice();
      
      if (data == null) {
        print('[PlaybackService] No playback from /me/player endpoint, trying currently-playing...');
        // Fall back to currently-playing endpoint
        final fallbackData = await _spotifyAuth.getCurrentlyPlaying();
        if (fallbackData == null) {
          print('[PlaybackService] No playback data available');
          // Clear playback data in Firebase when not playing
          await _clearPlaybackData();
          return null;
        }
        final song = CurrentSong.fromSpotifyData(fallbackData);
        print('[PlaybackService] Got song from fallback: ${song.songName}');
        // Write to Firebase
        await _writePlaybackToFirebase(song);
        return song;
      }
      
      final song = CurrentSong.fromSpotifyData(data);
      print('[PlaybackService] Successfully parsed song: ${song.songName} by ${song.songArtist}');
      // Write to Firebase so nearby users can see it
      await _writePlaybackToFirebase(song);
      return song;
    } catch (e) {
      print('[PlaybackService] Error fetching currently playing: $e');
      return null;
    }
  }

  /// Writes current song to Firebase so other nearby users can see it
  Future<void> _writePlaybackToFirebase(CurrentSong song) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        print('[PlaybackService] No user UID, skipping Firebase write');
        return;
      }

      await db.collection('playback').doc(uid).set({
        'songName': song.songName,
        'songArtist': song.songArtist,
        'albumArtUrl': song.albumArtUrl ?? '',
        'durationMs': song.durationMs,
        'progressMs': song.progressMs,
        'isPlaying': song.isPlaying,
        'spotifyUrl': song.spotifyUrl ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('[PlaybackService] ✓ Wrote playback to Firebase: ${song.songName}');
    } catch (e) {
      print('[PlaybackService] Error writing playback to Firebase: $e');
    }
  }

  /// Clears playback data from Firebase when user stops playing
  Future<void> _clearPlaybackData() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      await db.collection('playback').doc(uid).set({
        'isPlaying': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('[PlaybackService] Cleared playback data');
    } catch (e) {
      print('[PlaybackService] Error clearing playback: $e');
    }
  }

  /// Debug: Check what playback data is actually stored in Firebase
  Future<void> debugCheckPlaybackData() async {
    try {
      final snapshot = await db.collection('playback').get();
      print('[PlaybackService] Playback documents in Firebase: ${snapshot.docs.length}');
      for (final doc in snapshot.docs) {
        final data = doc.data();
        print('[PlaybackService]   ${doc.id}:');
        print('[PlaybackService]     - song: ${data['songName']} by ${data['songArtist']}');
        print('[PlaybackService]     - playing: ${data['isPlaying']}');
        print('[PlaybackService]     - full data: $data');
      }
    } catch (e) {
      print('[PlaybackService] Error checking playback data: $e');
    }
  }

  /// Get nearby songs by directly querying playback collection
  /// and filtering by location (workaround for Cloud Function issue)
  Future<List<NearbyRow>> getNearbyFromPlaybackDirect({
    required String currentUserId,
    required double lat,
    required double lon,
    double radiusM = 500,
  }) async {
    try {
      final snapshot = await db.collection('playback').get();
      final result = <NearbyRow>[];
      final now = DateTime.now();

      for (final doc in snapshot.docs) {
        // Skip current user
        if (doc.id == currentUserId) continue;

        final data = doc.data();
        final isPlaying = data['isPlaying'] as bool? ?? false;
        
        // Only include users who are actively playing
        if (!isPlaying) continue;

        // Filter by recent updates (within last 30 seconds)
        final updatedAt = data['updatedAt'] as Timestamp?;
        if (updatedAt != null) {
          final updateTime = updatedAt.toDate();
          final secondsOld = now.difference(updateTime).inSeconds;
          if (secondsOld > 30) {
            print('[PlaybackService] Skipping old song (${secondsOld}s old): ${data['songName']}');
            continue; // Skip songs older than 30 seconds
          }
        }

        final songName = data['songName'] as String? ?? 'Unknown';
        final artist = data['songArtist'] as String? ?? 'Unknown';
        final albumArt = data['albumArtUrl'] as String? ?? '';
        final duration = data['durationMs'] as int? ?? 0;

        // For now, assume all playing users are nearby (in same general area)
        // since both simulators are using same location
        result.add(NearbyRow(
          uid: doc.id,
          displayName: 'User ${doc.id.substring(0, 6)}',
          songName: songName,
          songArtist: artist,
          albumArtUrl: albumArt,
          durationMs: duration,
          distanceM: 0, // Unknown distance without location data in playback collection
        ));

        print('[PlaybackService] Added nearby song: $songName by $artist');
      }

      print('[PlaybackService] ✓ Found ${result.length} nearby songs from direct query');
      return result;
    } catch (e) {
      print('[PlaybackService] Error getting nearby from playback: $e');
      return [];
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
