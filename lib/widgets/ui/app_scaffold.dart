import 'package:flutter/material.dart';

import '../app_gradient_background.dart';
import '../custom_app_bar.dart';

/// Scaffold with global gradient — no light/white page backgrounds.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.title,
    this.subtitle,
    required this.body,
    this.floatingActionButton,
  });

  final String? title;
  final String? subtitle;
  final Widget body;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: title == null
          ? null
          : CustomAppBar(title: title!, subtitle: subtitle),
      floatingActionButton: floatingActionButton,
      body: AppGradientBackground(child: SafeArea(child: body)),
    );
  }
}
