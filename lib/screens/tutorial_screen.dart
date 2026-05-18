import 'package:flutter/material.dart';
import 'package:my_new_app/screens/main_navigation_screen.dart';

//import 'main_navigation_screen.dart';

// import 'mfa_screen.dart';

import  'package:shared_preferences/shared_preferences.dart';

import 'package:my_new_app/main.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController pageController = PageController();
  int currentPage = 0;

  final List<Map<String, dynamic>> slides = [
    {
      'icon': Icons.check_circle_outline,
      'title': 'Track your day',
      'subtitle': 'Add tasks, check them off, and keep your day organized.',
    },
    {
      'icon': Icons.local_fire_department_outlined,
      'title': 'Build consistency',
      'subtitle': 'Complete tasks daily and grow your streak over time.',
    },
    {
      'icon': Icons.trending_up,
      'title': 'See your progress',
      'subtitle': 'Watch your progress improve as you stay focused.',
    },
  ];

  Future<void> finishTutorial() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('hasSeenOnBoarding', true);
    await prefs.setBool('isLoggedIn', true);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const MainNavigationScreen(),
      ),
    );
  }

  void nextPage() {
    if (currentPage == slides.length - 1) {
      finishTutorial();
    } else {
      pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = currentPage == slides.length - 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: finishTutorial,
                  child: const Text('Skip'),
                ),
              ),

              Expanded(
                child: PageView.builder(
                  controller: pageController,
                  itemCount: slides.length,
                  onPageChanged: (index) {
                    setState(() {
                      currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final slide = slides[index];

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          slide['icon'],
                          size: 90,
                          color: Colors.greenAccent,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          slide['title'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          slide['subtitle'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 17,
                            height: 1.4,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  slides.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: currentPage == index ? 18 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: currentPage == index
                          ? Colors.greenAccent
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: nextPage,
                  child: Text(isLastPage ? 'Get Started' : 'Next'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}