import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SpotifySession {
  SpotifySession._();

  static final SpotifySession instance = SpotifySession._();

  // Later in Step B, you will store a refresh token here.
  static const String _refreshTokenKey = 'spotify_refresh_token';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<bool> isConnected() async {
    final rt = await _storage.read(key: _refreshTokenKey);
    return rt != null && rt.isNotEmpty;
  }

  // Temporary helpers so you can test Step A right now.
  // (We'll replace these with real OAuth results in Step B.)
  Future<void> setFakeConnectedForTesting() async {
    await _storage.write(key: _refreshTokenKey, value: 'fake_refresh_token');
  }

  Future<void> disconnect() async {
    await _storage.delete(key: _refreshTokenKey);
  }
}
