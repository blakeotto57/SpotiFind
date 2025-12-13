class NearbyRow {
  final String uid;
  final String displayName;
  final String songName;
  final String songArtist;
  final String albumArtUrl;
  final int durationMs;
  final double distanceM;

  NearbyRow({
    required this.uid,
    required this.displayName,
    required this.songName,
    required this.songArtist,
    required this.albumArtUrl,
    required this.durationMs,
    required this.distanceM,
  });

  factory NearbyRow.fromMap(Map<String, dynamic> m) => NearbyRow(
        uid: (m['uid'] ?? '') as String,
        displayName: (m['displayName'] ?? '') as String,
        songName: (m['songName'] ?? '') as String,
        songArtist: (m['songArtist'] ?? '') as String,
        albumArtUrl: (m['albumArtUrl'] ?? '') as String,
        durationMs: (m['durationMs'] ?? 0) as int,
        distanceM: ((m['distanceM'] ?? 0) as num).toDouble(),
      );
}

String formatDurationMs(int ms) {
  final totalSeconds = (ms / 1000).round();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
