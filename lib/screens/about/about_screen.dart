import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/constants/app_strings.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/custom_app_bar.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _versionLabel = 'Version …';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    setState(() {
      _versionLabel = 'Version ${info.version} (${info.buildNumber})';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'About',
        subtitle: _versionLabel,
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
                  const SizedBox(height: 8),
                  Text(
                    _versionLabel,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'LogicSprint is a free brain game app with quick mini-games for math, memory, and logic. Play offline anytime; optionally submit scores to the Global Top 10 leaderboard powered by Supabase.',
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
