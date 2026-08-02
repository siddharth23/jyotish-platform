import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish_app/core/connectivity/connectivity_controller.dart';
import 'package:jyotish_app/core/design/design_system.dart';
import 'package:jyotish_app/features/home/presentation/home_screen.dart';
import 'package:jyotish_app/main.dart';

void main() {
  group('JyotishApp', () {
    // Mirrors main(), but with connectivity pinned: the real controller reaches
    // for a platform channel that does not exist in a widget test.
    Widget subject() => ProviderScope(
          overrides: [
            connectivityControllerProvider.overrideWith(
              (ref) => ConnectivityController.fixed(NetworkStatus.online),
            ),
          ],
          child: const JyotishApp(),
        );

    testWidgets('builds without throwing', (tester) async {
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('mounts a routed MaterialApp', (tester) async {
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('lands on the home tab inside the shell', (tester) async {
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(AppBottomNav), findsOneWidget);
    });

    testWidgets('offers all five tabs', (tester) async {
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();
      final nav = tester.widget<AppBottomNav>(find.byType(AppBottomNav));
      expect(nav.destinations, hasLength(5));
    });
  });
}
