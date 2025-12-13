import 'package:flutter/material.dart';
import 'package:spotifind/home.dart';
import '../services/spotify_session.dart';
import 'connect_spotify_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: SpotifySession.instance.isConnected(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Color(0xFF000000),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final connected = snapshot.data == true;

        if (connected) {
          return const HomeScreen();
        } else {
          return const ConnectSpotifyScreen();
        }
      },
    );
  }
}
