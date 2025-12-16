import 'package:flutter/material.dart';
import '../services/spotify_auth_service.dart';
import 'package:spotifind/home.dart';
import 'package:firebase_auth/firebase_auth.dart';


class ConnectSpotifyScreen extends StatelessWidget {
  const ConnectSpotifyScreen({super.key});

  Future<void> _startSpotifyLogin(BuildContext context) async {
  try {
    debugPrint("Starting Spotify connect...");

    await SpotifyAuthService.instance
        .connect()
        .timeout(const Duration(seconds: 60));

    debugPrint("connect() returned");

    final ok = await SpotifyAuthService.instance.isConnected();
    debugPrint("Spotify connected? $ok");

    if (!context.mounted) {
      debugPrint("Context not mounted after connection check");
      return;
    }

    if (!ok) {
      debugPrint("Spotify connection check failed");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Spotify sign-in didn't finish.")),
      );
      return;
    }

    // Sign in with Firebase (anonymously) to get a UID for the services
    debugPrint("Signing in to Firebase...");
    try {
      await FirebaseAuth.instance.signInAnonymously();
      debugPrint("Firebase sign-in complete");
    } catch (e) {
      debugPrint("Firebase sign-in error: $e");
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Firebase sign-in failed: $e")),
      );
      return;
    }

    debugPrint("About to navigate to HomeScreen");
    
    // Navigate using a simple approach
    if (context.mounted) {
      // Use a small delay to ensure context is ready
      Future.delayed(const Duration(milliseconds: 100), () {
        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
          debugPrint("Navigation pushed");
        }
      });
    }
  } catch (e, st) {
    debugPrint("Spotify connect failed: $e");
    debugPrint("$st");
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Spotify connect failed: $e")),
    );
  }
}




  void _showConnectSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                "Connect Spotify",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "We’ll open Spotify sign-in so you can share what you’re listening to nearby.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, height: 1.35),
              ),
              const SizedBox(height: 16),

              // Option 1: normal login (recommended)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DB954),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    // Close the sheet first
                    Navigator.of(ctx).pop();
                    // Then start login with the outer context
                    await _startSpotifyLogin(context);
                  },
                  child: const Text(
                    "Continue",
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Option 2: same auth flow, just different wording for now.
              // (If you want, later we can attempt a deep link to Spotify app first.)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _startSpotifyLogin(context);
                  },
                  child: const Text("Use Spotify app (if installed)"),
                ),
              ),
              const SizedBox(height: 6),

              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const Text(
                "SpotiFind",
                style: TextStyle(
                  color: Color(0xFF1DB954),
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                "Connect your Spotify to share what you’re listening to with people nearby.",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DB954),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => _showConnectSheet(context),
                  child: const Text(
                    "Connect with Spotify",
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),

              const SizedBox(height: 14),
              const Text(
                "You control sharing. You can turn this off anytime.",
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 20),
              const Text(
                "We’ll never post anything without your permission.",
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
