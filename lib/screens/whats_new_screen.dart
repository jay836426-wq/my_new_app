import 'package:flutter/material.dart';

/// Version 1.2 highlights, displayed before the Home screen is mounted.
class WhatsNewScreen extends StatefulWidget {
  const WhatsNewScreen({super.key, required this.onFinished});

  final Future<void> Function() onFinished;

  @override
  State<WhatsNewScreen> createState() => _WhatsNewScreenState();
}

class _WhatsNewScreenState extends State<WhatsNewScreen> {
  final PageController _controller = PageController();
  int _page = 0;
  bool _finishing = false;

  static const _slides = [
    (
      icon: Icons.view_week_outlined,
      title: 'Make room for what matters',
      description:
          'Plan your days and weeks, set task durations, and spot overlapping time blocks.',
      caption: 'A clearer plan for your time.',
    ),
    (
      icon: Icons.timer_outlined,
      title: 'Focus, one step at a time',
      description:
          'Use the focus timer and break tasks into checkable subtasks. Set monthly, yearly, or custom repeat intervals.',
      caption: 'Small steps. Steady progress.',
    ),
    (
      icon: Icons.restore_from_trash_outlined,
      title: 'Keep your progress safe',
      description:
          'Restore deleted tasks from Recently Deleted, choose weekly or long-term goals, and export your task history.',
      caption: 'Your plans, with more control.',
    ),
    (
      icon: Icons.mood,
      title: 'Make space for you',
      description:
          'Save a daily mood and optional note. See today’s check-in on Home, edit it, and explore your mood history on this device.',
      caption: 'Your day is more than a checklist.',
    ),
    (
      icon: Icons.notifications_active_outlined,
      title: 'Reminders on your terms',
      description:
          'Choose planning, goal, weekly review, mood and focus alerts. On iPhone, scroll to choose a time. Saving a mood cancels that day’s pending check-in reminder.',
      caption: 'Optional reminders. More control.',
    ),
    (
      icon: Icons.ios_share,
      title: 'See the bigger picture',
      description:
          'Weeks run Sunday–Saturday. Review your Calendar productivity card and export a week, month or year as PDF, Excel, CSV or JSON.',
      caption: 'Keep a copy of your progress.',
    ),
    (
      icon: Icons.play_circle_outline,
      title: 'Make progress visible',
      description:
          'Start a task to mark it In Progress. Active tasks stay prominent on Home, with focus, subtasks and completion actions.',
      caption: 'Start small. Keep moving.',
    ),
    (
      icon: Icons.flag_outlined,
      title: 'Goals that grow with you',
      description:
          'Choose weekly, monthly or long-term goals. Keep achievement history through resets, and opt into motivation, goal recognition and task check-ins.',
      caption: 'Your progress deserves recognition.',
    ),
  ];

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      await widget.onFinished();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _page == _slides.length - 1;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'What’s new in 1.2',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _finishing ? null : _finish,
                      child: const Text(
                        'Skip',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (page) => setState(() => _page = page),
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        padding: const EdgeInsets.all(28),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: (constraints.maxHeight - 56).clamp(
                              0.0,
                              double.infinity,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 144,
                                height: 144,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF11271C),
                                  borderRadius: BorderRadius.circular(36),
                                  border: Border.all(
                                    color: const Color(0xFF28583D),
                                  ),
                                ),
                                child: Icon(
                                  slide.icon,
                                  size: 76,
                                  color: Colors.greenAccent,
                                ),
                              ),
                              const SizedBox(height: 36),
                              Text(
                                slide.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                slide.description,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 18,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                slide.caption,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  children: [
                    Semantics(
                      label: 'Slide ${_page + 1} of ${_slides.length}',
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _slides.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 8,
                            width: index == _page ? 24 : 8,
                            decoration: BoxDecoration(
                              color: index == _page
                                  ? Colors.greenAccent
                                  : Colors.white24,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(0, 54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _finishing
                            ? null
                            : () {
                                if (isLastPage) {
                                  _finish();
                                } else {
                                  _controller.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              },
                        child: Text(
                          _finishing
                              ? 'Opening TrakOn…'
                              : isLastPage
                              ? 'Let’s go'
                              : 'Next',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
