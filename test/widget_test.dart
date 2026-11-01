import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:TrakOn/screens/whats_new_screen.dart';

void main() {
  testWidgets('Version 1.2 intro can advance and finish', (tester) async {
    var finished = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: WhatsNewScreen(
          onFinished: () async {
            finished++;
          },
        ),
      ),
    );
    expect(find.text('What’s new in 1.2'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Focus, one step at a time'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Let’s go'));
    await tester.pumpAndSettle();
    expect(finished, 1);
  });
  testWidgets('Skip marks the intro as finished', (tester) async {
    var finished = false;
    await tester.pumpWidget(
      MaterialApp(
        home: WhatsNewScreen(
          onFinished: () async {
            finished = true;
          },
        ),
      ),
    );
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(finished, true);
  });
}
