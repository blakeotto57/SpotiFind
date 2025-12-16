class CurrentSong {
  final String songName;
  final String songArtist;
  final String? albumArtUrl;
  final int durationMs;
  final int progressMs;
  final bool isPlaying;
  final String? spotifyUrl;

  CurrentSong({
    required this.songName,
    required this.songArtist,
    this.albumArtUrl,
    required this.durationMs,
    required this.progressMs,
    required this.isPlaying,
    this.spotifyUrl,
  });

  factory CurrentSong.fromSpotifyData(Map<String, dynamic> data) {
    final item = data['item'] as Map<String, dynamic>?;
    if (item == null) {
      throw Exception('No track currently playing (item is null)');
    }

    final track = item;
    final artists = track['artists'] as List? ?? [];
    final artistName = artists.isNotEmpty
        ? (artists[0] as Map<String, dynamic>)['name'] ?? 'Unknown Artist'
        : 'Unknown Artist';

    final images = track['album']?['images'] as List? ?? [];
    String? imageUrl;
    if (images.isNotEmpty) {
      imageUrl = (images[0] as Map<String, dynamic>)['url'] as String?;
    }

    return CurrentSong(
      songName: track['name'] ?? 'Unknown Song',
      songArtist: artistName,
      albumArtUrl: imageUrl,
      durationMs: (track['duration_ms'] ?? 0) as int,
      progressMs: (data['progress_ms'] ?? 0) as int,
      isPlaying: (data['is_playing'] ?? false) as bool,
      spotifyUrl: track['external_urls']?['spotify'] as String?,
    );
  }
}
