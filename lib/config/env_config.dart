import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  // Spotify Configuration
  static String get spotifyClientId => 
      dotenv.env['SPOTIFY_CLIENT_ID'] ?? '';
  
  static String get spotifyClientSecret => 
      dotenv.env['SPOTIFY_CLIENT_SECRET'] ?? '';
  
  // Backend Configuration
  static String get backendUrl => 
      dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000';
  
  static String get jwtSecret => 
      dotenv.env['JWT_SECRET'] ?? '';
  
  static String get dbUrl => 
      dotenv.env['DB_URL'] ?? '';
  
  // Helper to check if running in production
  static bool get isProduction => 
      backendUrl.contains('https://');
}