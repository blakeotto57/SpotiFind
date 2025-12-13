import 'dart:async';
import 'package:flutter/material.dart';
import '../models/nearby_row.dart';
import '../services/nearby_service.dart';

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  final service = NearbyService();
  List<NearbyRow> rows = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final raw = await service.testNearbyFeed(lat: 37.0, lon: -122.0);
      final parsed = raw
          .whereType<Map>()
          .map((e) => NearbyRow.fromMap(Map<String, dynamic>.from(e)))
          .toList();

      if (mounted) {
        setState(() => rows = parsed);
      }
    } catch (e) {
      debugPrint("nearbyFeed refresh error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0B),
        title: const Text("Nearby"),
      ),
      body: ListView.builder(
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final r = rows[index];
          final rank = index + 1;

          return _NearbyRowTile(
            rank: rank,
            songName: r.songName,
            artist: r.songArtist,
            albumArtUrl: r.albumArtUrl,
            duration: formatDurationMs(r.durationMs),
          );
        },
      ),
    );
  }
}

class _NearbyRowTile extends StatelessWidget {
  final int rank;
  final String songName;
  final String artist;
  final String albumArtUrl;
  final String duration;

  const _NearbyRowTile({
    required this.rank,
    required this.songName,
    required this.artist,
    required this.albumArtUrl,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '$rank',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: albumArtUrl.isEmpty
                ? Container(width: 52, height: 52, color: Colors.white10)
                : Image.network(
                    albumArtUrl,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  songName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            duration,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
