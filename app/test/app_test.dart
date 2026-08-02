import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish_app/core/design/gallery/design_gallery.dart';
import 'package:jyotish_app/main.dart';

void main() {
  group('JyotishApp', () {
    // Mirrors main(): the app is always mounted inside a ProviderScope.
    Widget subject() => const ProviderScope(child: JyotishApp());

    testWidgets('builds without throwing', (tester) async {
      await tester.pumpWidget(subject());
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('mounts a MaterialApp', (tester) async {
      await tester.pumpWidget(subject());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    // Until a product feature exists, the design gallery is the home screen.
    // This will need replacing with the first real screen.
    testWidgets('shows the design gallery as its home', (tester) async {
      await tester.pumpWidget(subject());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(DesignGallery), findsOneWidget);
      // The title is localised and the test host follows the device locale, so
      // match the shared substring rather than one locale's exact casing.
      expect(find.textContaining('Design'), findsWidgets);
    });
  });
}
