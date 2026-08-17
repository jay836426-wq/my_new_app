import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_navigation_screen.dart';

// ---------------------------
// MFA Success Screen
// ---------------------------
class MfaSuccessScreen extends StatelessWidget {
  const MfaSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Success'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'You are verified!',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();

                await prefs.setBool('isLoggedIn', true);
                await prefs.setBool('hasSeenOnboarding', true);

                if (!context.mounted) return;

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MainNavigationScreen(),
                  ),
                );
              },
              child: const Text('Continue to TrakOn'),
            ),
          ],
        ),
      ),
    );
  }
}
