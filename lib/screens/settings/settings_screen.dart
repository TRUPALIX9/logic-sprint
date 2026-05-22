import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../services/app_state.dart';
import '../../widgets/app_gradient_background.dart';
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
          ThemedGamePanel(
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text(
                      'Sound',
                      style: TextStyle(
                        color: AppGradientBackground.textPrimary,
                      ),
                    ),
                    subtitle: const Text(
                      'Play feedback sounds during games',
                      style: TextStyle(
                        color: AppGradientBackground.textSecondary,
                      ),
                    ),
                    value: appState.isSoundEnabled,
                    onChanged: appState.setSoundEnabled,
                  ),
                  Divider(
                    height: 1,
                    color: AppGradientBackground.textSecondary.withValues(
                      alpha: 0.25,
                    ),
                  ),
                  SwitchListTile(
                    title: const Text(
                      'Vibration',
                      style: TextStyle(
                        color: AppGradientBackground.textPrimary,
                      ),
                    ),
                    subtitle: const Text(
                      'Haptic feedback on supported devices',
                      style: TextStyle(
                        color: AppGradientBackground.textSecondary,
                      ),
                    ),
                    value: appState.isVibrationEnabled,
                    onChanged: appState.setVibrationEnabled,
                  ),
                  Divider(
                    height: 1,
                    color: AppGradientBackground.textSecondary.withValues(
                      alpha: 0.25,
                    ),
                  ),
                  ListTile(
                    title: const Text(
                      'Theme Mode',
                      style: TextStyle(
                        color: AppGradientBackground.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      switch (appState.themeMode) {
                        ThemeMode.light => 'Light',
                        ThemeMode.dark => 'Dark',
                        ThemeMode.system => 'System',
                      },
                      style: const TextStyle(
                        color: AppGradientBackground.textSecondary,
                      ),
                    ),
                    trailing: DropdownButton<ThemeMode>(
                      value: appState.themeMode,
                      underline: const SizedBox.shrink(),
                      dropdownColor: AppGradientBackground.backgroundTop,
                      style: const TextStyle(
                        color: AppGradientBackground.textPrimary,
                      ),
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
          ),
          const SizedBox(height: 20),
          const SectionTitle(title: 'Data & Legal'),
          const SizedBox(height: 12),
          ThemedGamePanel(
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppGradientBackground.orangeAccent,
                    ),
                    title: const Text(
                      'Reset High Scores',
                      style: TextStyle(
                        color: AppGradientBackground.textPrimary,
                      ),
                    ),
                    subtitle: const Text(
                      'Clear all saved best scores on this device',
                      style: TextStyle(
                        color: AppGradientBackground.textSecondary,
                      ),
                    ),
                    onTap: () => _confirmReset(context),
                  ),
                  Divider(
                    height: 1,
                    color: AppGradientBackground.textSecondary.withValues(
                      alpha: 0.25,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.info_outline_rounded,
                      color: AppGradientBackground.cyanAccent,
                    ),
                    title: const Text(
                      'About',
                      style: TextStyle(
                        color: AppGradientBackground.textPrimary,
                      ),
                    ),
                    onTap: () =>
                        Navigator.of(context).pushNamed(AppRoutes.about),
                  ),
                  Divider(
                    height: 1,
                    color: AppGradientBackground.textSecondary.withValues(
                      alpha: 0.25,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.privacy_tip_outlined,
                      color: AppGradientBackground.cyanAccent,
                    ),
                    title: const Text(
                      'Privacy Policy',
                      style: TextStyle(
                        color: AppGradientBackground.textPrimary,
                      ),
                    ),
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(AppRoutes.privacyPolicy),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final appState = context.read<AppState>();
    final shouldReset =
        await showDialog<bool>(
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('High scores cleared')));
  }
}
