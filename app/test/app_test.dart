import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish_app/main.dart';

void main() {
  group('JyotishApp', () {
    // Mirrors main(): the app is always mounted inside a ProviderScope.
    Widget subject() => const ProviderScope(child: JyotishApp());

    testWidgets('builds without throwing', (tester) async {
      await tester.pumpWidget(subject());
      expect(tester.takeException(), isNull);
    });

    testWidgets('mounts a MaterialApp', (tester) async {
      await tester.pumpWidget(subject());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('renders its home screen', (tester) async {
      await tester.pumpWidget(subject());
      expect(find.text('Jyotish'), findsOneWidget);
    });
  });
}
