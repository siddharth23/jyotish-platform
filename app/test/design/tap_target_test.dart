import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish_app/core/design/design_system.dart';

/// Renders [child] inside the real app theme, constrained like a phone screen.
Widget _host(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
    home: Scaffold(
      body: Center(
        child: SizedBox(width: 360, child: child),
      ),
    ),
  );
}

void main() {
  const minimum = AppSpacing.minTapTarget;

  group('US-004 AC4 — 44pt minimum tap targets', () {
    testWidgets('AppButton at every size', (tester) async {
      for (final size in AppButtonSize.values) {
        await tester.pumpWidget(
          _host(AppButton(label: 'Weiter', onPressed: () {}, size: size)),
        );
        final rendered = tester.getSize(find.byType(AppButton));
        expect(
          rendered.height,
          greaterThanOrEqualTo(minimum),
          reason: '${size.name} button is ${rendered.height}pt tall',
        );
        expect(rendered.width, greaterThanOrEqualTo(minimum));
      }
    });

    // The classic failure: the glyph is 20pt, so the button looks done while
    // offering under a quarter of the required touch area.
    testWidgets('AppIconButton is 44pt even with a 16pt glyph', (tester) async {
      await tester.pumpWidget(
        _host(
          Align(
            alignment: Alignment.centerLeft,
            child: AppIconButton(
              icon: Icons.close,
              onPressed: () {},
              tooltip: 'Schliessen',
              iconSize: 16,
            ),
          ),
        ),
      );
      final rendered = tester.getSize(find.byType(AppIconButton));
      expect(rendered.height, greaterThanOrEqualTo(minimum));
      expect(rendered.width, greaterThanOrEqualTo(minimum));
    });

    testWidgets('AppChip', (tester) async {
      await tester.pumpWidget(
        _host(
          Align(
            alignment: Alignment.centerLeft,
            child: AppChip(label: 'D9', onTap: () {}),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(AppChip)).height,
        greaterThanOrEqualTo(minimum),
      );
    });

    testWidgets('AppListTile', (tester) async {
      await tester.pumpWidget(
        _host(AppListTile(title: 'Geburtsdatum', onTap: () {})),
      );
      expect(
        tester.getSize(find.byType(AppListTile)).height,
        greaterThanOrEqualTo(minimum),
      );
    });

    testWidgets('AppSwitch', (tester) async {
      await tester.pumpWidget(
        _host(AppSwitch(
            label: 'Benachrichtigungen', value: false, onChanged: (_) {})),
      );
      expect(
        tester.getSize(find.byType(AppSwitch)).height,
        greaterThanOrEqualTo(minimum),
      );
    });

    testWidgets('AppCheckbox', (tester) async {
      await tester.pumpWidget(
        _host(AppCheckbox(
            label: 'Ich stimme zu', value: false, onChanged: (_) {})),
      );
      expect(
        tester.getSize(find.byType(AppCheckbox)).height,
        greaterThanOrEqualTo(minimum),
      );
    });

    testWidgets('AppSegmentedControl', (tester) async {
      await tester.pumpWidget(
        _host(
          AppSegmentedControl<int>(
            segments: const [
              AppSegment(value: 0, label: 'Nord'),
              AppSegment(value: 1, label: 'Süd'),
            ],
            value: 0,
            onChanged: (_) {},
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(AppSegmentedControl<int>)).height,
        greaterThanOrEqualTo(minimum),
      );
    });

    testWidgets('AppRadioGroup rows', (tester) async {
      await tester.pumpWidget(
        _host(
          AppRadioGroup<String>(
            options: const [
              AppRadioOption(value: 'lahiri', label: 'Lahiri'),
              AppRadioOption(value: 'raman', label: 'Raman'),
            ],
            value: 'lahiri',
            onChanged: (_) {},
          ),
        ),
      );
      // Two rows share the group's height, so measure the rows themselves.
      final rows = find.descendant(
        of: find.byType(AppRadioGroup<String>),
        matching: find.byType(ConstrainedBox),
      );
      expect(rows, findsWidgets);
      for (final element in rows.evaluate()) {
        final box = element.renderObject! as RenderBox;
        if (box.size.height > 0) {
          expect(box.size.height, greaterThanOrEqualTo(minimum));
        }
      }
    });

    testWidgets('AppCard when tappable', (tester) async {
      await tester.pumpWidget(
        _host(AppCard(onTap: () {}, child: const Text('x'))),
      );
      expect(
        tester.getSize(find.byType(AppCard)).height,
        greaterThanOrEqualTo(minimum),
      );
    });

    testWidgets('AppBottomNav destinations', (tester) async {
      await tester.pumpWidget(
        _host(
          AppBottomNav(
            destinations: const [
              AppNavDestination(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home,
                label: 'Start',
              ),
              AppNavDestination(
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
                label: 'Profil',
              ),
            ],
            currentIndex: 0,
            onSelected: (_) {},
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(AppBottomNav)).height,
        greaterThanOrEqualTo(minimum),
      );
    });
  });

  group('Targets hold under accessibility text scaling', () {
    // Large-text settings must not shrink a target or clip its label.
    testWidgets('AppButton at 2x text scale', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  child: AppButton(label: 'Weiter', onPressed: () {}),
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(AppButton)).height,
        greaterThanOrEqualTo(minimum),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Disabled controls keep their footprint', () {
    // A disabled button that collapses causes the layout to jump when it
    // re-enables.
    testWidgets('AppButton disabled is the same height as enabled',
        (tester) async {
      await tester
          .pumpWidget(_host(const AppButton(label: 'Weiter', onPressed: null)));
      final disabled = tester.getSize(find.byType(AppButton));

      await tester
          .pumpWidget(_host(AppButton(label: 'Weiter', onPressed: () {})));
      final enabled = tester.getSize(find.byType(AppButton));

      expect(disabled.height, enabled.height);
      expect(disabled.height, greaterThanOrEqualTo(minimum));
    });
  });
}
