import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../services/app_state.dart';
import '../../widgets/custom_app_bar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Settings',
        subtitle: 'Personalize your local experience',
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Sound'),
                  subtitle: const Text('Enable sound-ready feedback hooks'),
                  value: appState.isSoundEnabled,
                  onChanged: appState.setSoundEnabled,
                ),
                SwitchListTile(
                  title: const Text('Vibration'),
                  subtitle: const Text('Keep haptic preference ready for later'),
                  value: appState.isVibrationEnabled,
                  onChanged: appState.setVibrationEnabled,
                ),
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
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Reset high scores'),
                  subtitle: const Text('Clear all saved best scores on this device'),
                  onTap: () => _confirmReset(context),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('About'),
                  onTap: () => Navigator.of(context).pushNamed(AppRoutes.about),
                ),
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
