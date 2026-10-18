import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/core/widgets/embedded_detail_pane.dart';

void main() {
  testWidgets('EmbeddedDetailPane closes cleanly when child calls maybePop', (tester) async {
    bool closed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmbeddedDetailPane(
            onClose: () {
              closed = true;
            },
            child: Builder(
              builder: (context) => Scaffold(
                appBar: AppBar(
                  title: const Text('Detail Page'),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ),
                body: const Text('Detail Content'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Detail Content'), findsOneWidget);
    expect(closed, isFalse);

    // Tap back button
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
  });

  testWidgets('EmbeddedDetailPane closes cleanly when child calls pop directly', (tester) async {
    bool closed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmbeddedDetailPane(
            onClose: () {
              closed = true;
            },
            child: Builder(
              builder: (context) => Scaffold(
                appBar: AppBar(
                  title: const Text('Detail Page'),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                body: const Text('Detail Content'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Detail Content'), findsOneWidget);
    expect(closed, isFalse);

    // Tap back button calling Navigator.pop directly
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
  });

  testWidgets('EmbeddedDetailPane does not close when subpage pops, but closes when root detail pops', (tester) async {
    bool closed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmbeddedDetailPane(
            onClose: () {
              closed = true;
            },
            child: Builder(
              builder: (context) => Scaffold(
                appBar: AppBar(
                  title: const Text('Base Detail'),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ),
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (subContext) => Scaffold(
                          appBar: AppBar(
                            title: const Text('Subpage'),
                            leading: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(subContext),
                            ),
                          ),
                          body: const Text('Subpage Content'),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Subpage'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Base Detail'), findsOneWidget);

    // Open subpage
    await tester.tap(find.text('Open Subpage'));
    await tester.pumpAndSettle();
    expect(find.text('Subpage Content'), findsOneWidget);
    expect(closed, isFalse);

    // Close subpage
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Base Detail'), findsOneWidget);
    expect(closed, isFalse);

    // Now close base detail
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
  });
}
