import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import 'main_navigation_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  String displayedText = '';
  final String fullText = 'Welcome To TrakOn!';

  String mottoText = '';

  late AnimationController _logoController;
  late Animation<double> _logoOpacity;
  late Animation<double> _logoScale;

  @override
  void initState() {
    super.initState();

    // Logo animation controller
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Smooth fade-in
    _logoOpacity = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeInOut,
    );

    // Smooth scale-up
    _logoScale = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeOutCubic,
      ),
    );

    _startIntro();
  }

  Future<void> _startIntro() async {
    // Logo appears first
    await _logoController.forward();

    // Small pause after logo appears
    await Future.delayed(
      const Duration(milliseconds: 500),
    );

    if (!mounted) return;

    // Start the original splash animation
    _startSplashAnimation();
  }

  void _startSplashAnimation() {
    int index = 0;

    Timer.periodic(
      const Duration(milliseconds: 80),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (index < fullText.length) {
          setState(() {
            displayedText += fullText[index];
          });

          index++;
        } else {
          timer.cancel();

          // Keep your original timing

          Future.delayed(
            const Duration(milliseconds: 500),
            () {
              if (!mounted) return;

              setState(() {
                mottoText = 'Track.';
              });
            },
          );

          Future.delayed(
            const Duration(milliseconds: 1000),
            () {
              if (!mounted) return;

              setState(() {
                mottoText = 'Track. Focus.';
              });
            },
          );

          Future.delayed(
            const Duration(milliseconds: 1500),
            () {
              if (!mounted) return;

              setState(() {
                mottoText =
                    'Track. Focus. Achieve.';
              });
            },
          );

          Future.delayed(
            const Duration(milliseconds: 2800),
            () {
              if (!mounted) return;

              _goToNextScreen();
            },
          );
        }
      },
    );
  }

  Future<void> _goToNextScreen() async {
    final prefs =
        await SharedPreferences.getInstance();

    final bool isLoggedIn =
        prefs.getBool('isLoggedIn') ?? false;

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => isLoggedIn
            ? const MainNavigationScreen()
            : const AuthChoiceScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      body: Center(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 24),

          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,

            children: [
              // -------------------------
              // TrakOn Logo
              // -------------------------
              FadeTransition(
                opacity: _logoOpacity,

                child: ScaleTransition(
                  scale: _logoScale,

                child: Image.asset(
                  'assets/TrakOn_logo.png',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
                ),
              ),

              const SizedBox(height: 30),

              // -------------------------
              // Welcome Typewriter
              // -------------------------
              Text(
                displayedText,
                textAlign: TextAlign.center,

                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                ),
              ),

              const SizedBox(height: 18),

              // -------------------------
              // Track. Focus. Achieve.
              // -------------------------
              AnimatedSwitcher(
                duration:
                    const Duration(milliseconds: 450),

                transitionBuilder:
                    (child, animation) =>
                        FadeTransition(
                  opacity: animation,
                  child: child,
                ),

                child: Text(
                  mottoText,
                  key: ValueKey(mottoText),
                  textAlign: TextAlign.center,

                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}