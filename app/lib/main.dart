import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: JyotishApp()));
}

class JyotishApp extends StatelessWidget {
  const JyotishApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jyotish',
      theme: ThemeData(useMaterial3: true),
      home: const Scaffold(
        body: Center(child: Text('Jyotish')),
      ),
    );
  }
}
