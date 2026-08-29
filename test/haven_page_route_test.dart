import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_rent/navigation/haven_page_route.dart';
import 'package:house_rent/widgets/haven_navigation_bar.dart';

void main() {
  testWidgets('pushed Haven pages support the iOS interactive edge swipe',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                HavenPageRoute<void>(
                  builder: (_) => const Scaffold(
                    appBar: HavenNavigationBar(title: 'Subpage'),
                    body: Text('Subpage body'),
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoNavigationBarBackButton), findsOneWidget);
      final route = ModalRoute.of(tester.element(find.text('Subpage body')))!;
      expect(route.popGestureEnabled, isTrue);

      await tester.dragFrom(const Offset(1, 300), const Offset(500, 0));
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Subpage body'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
