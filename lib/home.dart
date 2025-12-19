import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spotifind/services/nearby_service.dart';
import 'package:spotifind/services/playback_service.dart';
import 'package:spotifind/services/spotify_auth_service.dart';
import 'package:spotifind/models/nearby_row.dart';
import 'package:spotifind/models/current_song.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final NearbyService _nearbyService;
  late final PlaybackService _playbackService;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  Timer? _currentSongTimer;

  CurrentSong? _currentSong;
  List<NearbyRow> _nearbySongs = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nearbyService = NearbyService();
    _playbackService = PlaybackService();
    _loadData();
    _startCurrentSongRefresh();
  }

  @override
  void dispose() {
    _currentSongTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadCurrentSong(),
      _loadNearbySongs(),
    ]);
  }

  /// Starts a timer to refresh the currently playing song every 2 seconds
  void _startCurrentSongRefresh() {
    _currentSongTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (mounted) {
        await _loadCurrentSong();
      }
    });
  }

  Future<void> _loadCurrentSong() async {
    try {
      print('[HomeScreen] Loading current song...');
      
      // Check if Spotify is connected
      final spotifyAuth = SpotifyAuthService.instance;
      final isConnected = await spotifyAuth.isConnected();
      print('[HomeScreen] Spotify connected: $isConnected');
      
      if (!isConnected) {
        print('[HomeScreen] Spotify not connected, skipping current song load');
        setState(() {
          _currentSong = null;
        });
        return;
      }
      
      final song = await _playbackService.getCurrentlyPlayingFromSpotify();
      print('[HomeScreen] Current song result: $song');
      setState(() {
        _currentSong = song;
      });
    } catch (e) {
      print('[HomeScreen] Error loading current song: $e');
    }
  }

  Future<void> _loadNearbySongs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Check location permission
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        throw Exception("Location permission denied forever");
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      print('[HomeScreen] My location: lat=${position.latitude}, lon=${position.longitude}');

      // Fetch nearby songs
      final songs = await _nearbyService.getNearby(
        lat: position.latitude,
        lon: position.longitude,
        radiusM: 500,
      );

      print('[HomeScreen] Got ${songs.length} nearby songs');
      for (final song in songs) {
        print('[HomeScreen]   - ${song.displayName}: ${song.songName}');
      }

      setState(() {
        _nearbySongs = songs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      print('[HomeScreen] Error loading nearby songs: $e');
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadCurrentSong(),
      _loadNearbySongs(),
    ]);
  }

  Future<void> _logout() async {
    try {
      print('[HomeScreen] Logging out...');
      
      // Sign out from Spotify
      await SpotifyAuthService.instance.disconnect();
      print('[HomeScreen] Spotify disconnected');
      
      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();
      print('[HomeScreen] Firebase signed out');
      
      if (!mounted) return;
      
      // Navigate back to connect screen
      Navigator.of(context).pushReplacementNamed('/connect');
    } catch (e) {
      print('[HomeScreen] Error during logout: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout error: $e')),
      );
    }
  }

  Future<void> _openSpotifyTrack(String? spotifyUrl) async {
    if (spotifyUrl == null || spotifyUrl.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Spotify URL available')),
      );
      return;
    }

    try {
      // Try to open in Spotify app first with spotify: URI
      // Extract track ID from the spotify URL
      // URL format: https://open.spotify.com/track/TRACK_ID
      final parts = spotifyUrl.split('/');
      if (parts.length > 4) {
        final trackId = parts[4].split('?')[0]; // Remove query params
        final spotifyUri = 'spotify:track:$trackId';
        
        // Try opening with Spotify app first
        if (await canLaunchUrl(Uri.parse(spotifyUri))) {
          await launchUrl(Uri.parse(spotifyUri));
          return;
        }
      }

      // Fall back to web URL if app not available
      if (await canLaunchUrl(Uri.parse(spotifyUrl))) {
        await launchUrl(
          Uri.parse(spotifyUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Spotify')),
        );
      }
    } catch (e) {
      print('[HomeScreen] Error opening Spotify: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF000000),
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            // Current song section
            if (_currentSong != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Now Playing',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildCurrentSongTile(_currentSong!),
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFF2C2C2C), height: 1),
                    const SizedBox(height: 16),
                  ],
                ),
              )
            else
              // Show status when no song is playing
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Now Playing',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        GestureDetector(
                          onTap: _loadCurrentSong,
                          child: const Icon(
                            Icons.refresh,
                            color: Colors.grey,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Color(0xFF2C2C2C), width: 1),
                      ),
                      child: const Center(
                        child: Text(
                          'Not playing anything',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFF2C2C2C), height: 1),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            // Nearby songs section
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF1DB954),
                        ),
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Error: $_error',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadNearbySongs,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _nearbySongs.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.music_note,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No songs nearby',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _loadNearbySongs,
                                    child: const Text('Refresh'),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _refreshAll,
                              child: ListView(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                children: [
                                  const Text(
                                    'People Listening Nearby',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  for (final song in _nearbySongs)
                                    _buildNearbySongTile(song),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            child: const Icon(Icons.menu, color: Colors.white, size: 30),
          ),
          const Text(
            "SpotiFind",
            style: TextStyle(
              color: Color(0xFF1DB954),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          GestureDetector(
            onLongPress: () {
              // Debug: check playback data
              _playbackService.debugCheckPlaybackData();
            },
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey.shade800,
              child: const Icon(Icons.person, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF1A1A1A),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Drawer header
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF121212),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF1DB954),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'SpotiFind',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Discover Music',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Menu items
            ListTile(
              leading: const Icon(Icons.home, color: Color(0xFF1DB954)),
              title: const Text(
                'Home',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context),
            ),
            const Divider(color: Color(0xFF2C2C2C)),
            const SizedBox(height: 8),
            // Logout button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Log Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentSongTile(CurrentSong song) {
    return GestureDetector(
      onTap: () => _openSpotifyTrack(song.spotifyUrl),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1DB954), width: 1.5),
        ),
        child: Row(
          children: [
            // Album art
            Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(8),
              ),
              child: song.albumArtUrl != null && song.albumArtUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        song.albumArtUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.music_note,
                              color: Colors.green, size: 32);
                        },
                      ),
                    )
                  : const Icon(Icons.music_note, color: Colors.green, size: 32),
            ),
            const SizedBox(width: 12),
            // Song info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.songName,
                    style: const TextStyle(
                      color: Color(0xFF1DB954),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    song.songArtist,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: song.durationMs > 0
                          ? (song.progressMs / song.durationMs).clamp(0.0, 1.0)
                          : 0,
                      backgroundColor: const Color(0xFF2C2C2C),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF1DB954),
                      ),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Duration
            Text(
              formatDurationMs(song.durationMs),
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbySongTile(NearbyRow song) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Album art
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2C),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: song.albumArtUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          song.albumArtUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.music_note,
                                color: Colors.green, size: 28);
                          },
                        ),
                      )
                    : const Icon(Icons.music_note,
                        color: Colors.green, size: 28),
              ),
              const SizedBox(width: 12),
              // Song and artist info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.songName,
                      style: const TextStyle(
                        color: Color(0xFF1DB954),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song.songArtist,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Duration
              Text(
                formatDurationMs(song.durationMs),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // User and distance info
          Row(
            children: [
              const Icon(Icons.person, color: Colors.grey, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  song.displayName,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.location_on, color: Colors.grey, size: 14),
              const SizedBox(width: 4),
              Text(
                '${(song.distanceM / 1000).toStringAsFixed(1)} km',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Icon(Icons.home_filled, color: Color(0xFF1DB954), size: 30),
          Icon(Icons.search, color: Colors.grey, size: 28),
          Icon(Icons.swap_horiz, color: Colors.grey, size: 28),
          Icon(Icons.person_outline, color: Colors.grey, size: 28),
        ],
      ),
    );
  }
}
