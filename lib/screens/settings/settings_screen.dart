import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../services/ad_service.dart';
import '../../services/app_state.dart';
import '../../widgets/ui/app_scaffold.dart';
import '../../widgets/ui/section_title.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return AppScaffold(
      title: 'Settings',
      subtitle: 'Personalize your experience',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        children: [
          const SectionTitle(title: 'Preferences'),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Sound'),
                  subtitle: const Text('Play feedback sounds during games'),
                  value: appState.isSoundEnabled,
                  onChanged: appState.setSoundEnabled,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Vibration'),
                  subtitle: const Text('Haptic feedback on supported devices'),
                  value: appState.isVibrationEnabled,
                  onChanged: appState.setVibrationEnabled,
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Theme Mode'),
                  subtitle: Text(
                    switch (appState.themeMode) {
                      ThemeMode.light => 'Light',
                      ThemeMode.dark => 'Dark',
                      ThemeMode.system => 'System',
                    },
                  ),
                  trailing: DropdownButton<ThemeMode>(
                    value: appState.themeMode,
                    underline: const SizedBox.shrink(),
                    onChanged: (value) {
                      if (value != null) {
                        appState.setThemeMode(value);
                      }
                    },
                    items: const [
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text('System'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text('Light'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text('Dark'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Ads Mode'),
                  subtitle: Text(
                    switch (appState.adMode) {
                      'simulated' => 'Simulated (In-App)',
                      'real' => 'Real AdMob Ads',
                      'disabled' || _ => 'Disabled (No Ads)',
                    },
                  ),
                  trailing: DropdownButton<String>(
                    value: appState.adMode,
                    underline: const SizedBox.shrink(),
                    onChanged: (value) {
                      if (value != null) {
                        appState.setAdMode(value);
                        context.read<AdService>().initialize();
                      }
                    },
                    items: const [
                      DropdownMenuItem(
                        value: 'simulated',
                        child: Text('Simulated'),
                      ),
                      DropdownMenuItem(
                        value: 'real',
                        child: Text('Real AdMob'),
                      ),
                      DropdownMenuItem(
                        value: 'disabled',
                        child: Text('Disabled'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle(title: 'Data & Legal'),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Reset High Scores'),
                  subtitle: const Text(
                    'Clear all saved best scores on this device',
                  ),
                  onTap: () => _confirmReset(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('About'),
                  onTap: () => Navigator.of(context).pushNamed(AppRoutes.about),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy Policy'),
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.privacyPolicy),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final appState = context.read<AppState>();
    final shouldReset = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Reset high scores?'),
              content: const Text(
                'This removes every saved best score for LogicSprint on this device.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Reset'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldReset) {
      return;
    }

    await appState.resetHighScores();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('High scores cleared')),
    );
  }
}
