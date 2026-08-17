import 'package:flutter/material.dart';
import 'package:TrakOn/screens/main_navigation_screen.dart';

//import 'main_navigation_screen.dart';

// import 'mfa_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';

//import 'package:TrakOn/main.dart';

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
      'title': 'Plan Your Day',
      'subtitle':
          'Create tasks, add details, organize them by category, and use priority levels to focus on what matters most.',
    },
    {
      'icon': Icons.notifications_active_outlined,
      'title': 'Smart Notifications',
      'subtitle':
          'Set task reminders and choose how TrakOn keeps you on track. Priority-based reminders, daily motivation, summaries, and end-of-day reminders can all be managed in Settings.',
    },
    {
      'icon': Icons.repeat,
      'title': 'Repeat What Matters',
      'subtitle':
          'Create recurring tasks that repeat daily, on weekdays, weekly, or on specific days you choose.',
    },
    {
      'icon': Icons.calendar_month_outlined,
      'title': 'Plan Ahead',
      'subtitle':
          'Use the calendar and weekly preview to see upcoming tasks, plan future days, and stay ahead of your schedule.',
    },
    {
      'icon': Icons.local_fire_department_outlined,
      'title': 'Stay Consistent',
      'subtitle':
          'Complete your tasks, carry unfinished work forward when needed, track daily progress, and build your streak over time.',
    },
    {
      'icon': Icons.track_changes,
      'title': 'You’re Ready',
      'subtitle':
          'Track what needs to be done. Focus on what matters. Achieve through consistency.\n\nTrack. Focus. Achieve.',
    },
  ];

  Future<void> finishTutorial() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('hasSeenOnboarding', true);
    await prefs.setBool('isLoggedIn', true);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
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
                  child: const Text(
                    'Skip',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: nextPage,
                  child: Text(
                    isLastPage ? 'Get Started' : 'Next',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
