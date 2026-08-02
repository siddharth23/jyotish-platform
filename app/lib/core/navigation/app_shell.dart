import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../connectivity/offline_banner.dart';
import '../design/design_system.dart';
import '../l10n/generated/app_l10n.dart';

/// The persistent frame around the five tabs.
///
/// Wraps a [StatefulNavigationShell], so each tab keeps its own navigation stack
/// and scroll position. Returning to a tab three levels deep and finding it
/// reset to the root is the difference between an app that feels native and one
/// that feels like a website.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Inside the shell, above the content: the banner pushes content
            // down rather than covering a control the user was reaching for.
            const OfflineBanner(),
            Expanded(child: navigationShell),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: navigationShell.currentIndex,
        onSelected: (index) => navigationShell.goBranch(
          index,
          // Tapping the tab you are already on pops that tab back to its root,
          // which is the platform convention on both iOS and Android.
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          AppNavDestination(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home,
            label: l10n.navHome,
          ),
          AppNavDestination(
            icon: Icons.auto_awesome_outlined,
            selectedIcon: Icons.auto_awesome,
            label: l10n.navChart,
          ),
          AppNavDestination(
            icon: Icons.work_outline,
            selectedIcon: Icons.work,
            label: l10n.navCareer,
          ),
          AppNavDestination(
            icon: Icons.article_outlined,
            selectedIcon: Icons.article,
            label: l10n.navEvaluation,
          ),
          AppNavDestination(
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
            label: l10n.navProfile,
          ),
        ],
      ),
    );
  }
}
