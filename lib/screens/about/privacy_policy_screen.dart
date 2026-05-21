import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../services/brand_content_service.dart';
import '../../widgets/custom_app_bar.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Privacy Policy',
        subtitle: 'Offline and local-only',
      ),
      body: FutureBuilder<String>(
        future: BrandContentService.loadPrivacyPolicy(),
        builder: (context, snapshot) {
          final text = snapshot.hasData
              ? _plainTextFromMarkdown(snapshot.data!)
              : AppStrings.privacySummary;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _plainTextFromMarkdown(String markdown) {
    return markdown
        .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}
