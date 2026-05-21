import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/custom_app_bar.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'About',
        subtitle: 'Version 1.0.0',
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: BrandLogo(
                      variant: BrandLogoVariant.mark,
                      height: 88,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppStrings.appTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'LogicSprint is a free offline brain game app designed to help you practice quick thinking, math, logic, and focus.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
