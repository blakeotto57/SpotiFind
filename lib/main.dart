import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:spotifind/home.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:spotifind/screens/auth_gate.dart';
import 'package:spotifind/screens/connect_spotify_screen.dart';
import 'firebase_options.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load environment variables
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Spotifind',
      theme: ThemeData.dark(),
      home: const AuthGate(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/connect': (context) => const ConnectSpotifyScreen(),
      },

    );
  }
}