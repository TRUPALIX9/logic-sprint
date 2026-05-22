import 'package:flutter/material.dart';

import '../custom_app_bar.dart';

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
      appBar: title == null
          ? null
          : CustomAppBar(title: title!, subtitle: subtitle),
      floatingActionButton: floatingActionButton,
      body: SafeArea(child: body),
    );
  }
}
