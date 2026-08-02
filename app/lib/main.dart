import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design/gallery/design_gallery.dart';

void main() {
  runApp(const ProviderScope(child: JyotishApp()));
}

/// Application root.
///
/// The home screen is currently the design system gallery (US-004). No product
/// feature exists yet — the birth-data capture flow, chart rendering and the paid
/// evaluation are all still empty folders under `lib/features/`, and the
/// calculation engine has no native build. Replace this home once the first real
/// screen lands.
class JyotishApp extends StatelessWidget {
  const JyotishApp({super.key});

  @override
  Widget build(BuildContext context) => const DesignGallery();
}
