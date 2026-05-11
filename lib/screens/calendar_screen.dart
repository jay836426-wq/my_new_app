import 'package:flutter/material.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            
            // Calendar header with month Navigation
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),

              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,

                children: [

                  const Text(
                    'May 2026',

                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  Row(
                    children: [

                      IconButton(
                        onPressed: () {},

                        icon: const Icon(
                          Icons.chevron_left,
                          color: Colors.white,
                        ),
                      ),

                      IconButton(
                        onPressed: () {},

                        icon: const Icon(
                          Icons.chevron_right,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Calendar grid showing all days of the month
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                // Weekday labels
                children: const [
                  Text('Sun', style: TextStyle(color: Colors.white70)),
                  Text('Mon', style: TextStyle(color: Colors.white70)),
                  Text('Tue', style: TextStyle(color: Colors.white70)),
                  Text('Wed', style: TextStyle(color: Colors.white70)),
                  Text('Thu', style: TextStyle(color: Colors.white70)),
                  Text('Fri', style: TextStyle(color: Colors.white70)),
                  Text('Sat', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Calendar day grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),

              child: GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),

                children: List.generate(31, (index) {
                  return Container(
                    margin: const EdgeInsets.all(4),

                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                    ),

                    child: Center(
                      child: Text(
                        '${index + 1}',

                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Daily Productivity summary card
            Padding(
              padding: const EdgeInsets.all(20),

              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),

                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white12),
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    const Text(
                      'May 10',

                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'Tasks Completed: 3/5',

                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Productivity: 60%',

                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}