import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../core/theme.dart';
import '../services/ads.dart';
import '../state/app_state.dart';
import '../ui/brand.dart';
import '../ui/chamfer.dart';
import '../ui/kit.dart';
import 'privacy_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen());

  Future<void> _confirmReset(BuildContext context) async {
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('RESET HIGH SCORES?'),
        content: const Text('This clears every best score on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: LSText.body(15, color: LS.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Reset',
              style: LSText.body(15, color: LS.coral, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await app.resetBests();
    messenger.showSnackBar(
      const SnackBar(content: Text('High scores cleared')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final ads = context.read<Ads>();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const LSTopBar(title: 'Settings'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _Group(
                    label: 'Gameplay',
                    rows: [
                      _Row(
                        icon: Icons.volume_up_outlined,
                        title: 'Sound',
                        subtitle: 'Click sounds on taps',
                        trailing: LSToggle(
                          value: app.soundOn,
                          onChanged: app.setSoundOn,
                        ),
                        onTap: () => app.setSoundOn(!app.soundOn),
                      ),
                      _Row(
                        icon: Icons.vibration_rounded,
                        title: 'Vibration',
                        subtitle: 'Haptics on taps and hits',
                        trailing: LSToggle(
                          value: app.vibrationOn,
                          onChanged: app.setVibrationOn,
                        ),
                        onTap: () => app.setVibrationOn(!app.vibrationOn),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  ValueListenableBuilder<bool>(
                    valueListenable: ads.privacyOptionsRequired,
                    builder: (context, consentRequired, _) => _Group(
                      label: 'Privacy',
                      rows: [
                        // Google requires this entry for users in consent regions.
                        if (consentRequired)
                          _Row(
                            icon: Icons.shield_outlined,
                            title: 'Privacy choices',
                            subtitle: 'Manage ad consent',
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: LS.dim,
                            ),
                            onTap: ads.showPrivacyOptions,
                          ),
                        _Row(
                          icon: Icons.description_outlined,
                          title: 'Privacy policy',
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: LS.dim,
                          ),
                          onTap: () =>
                              Navigator.of(context).push(PrivacyScreen.route()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _Group(
                    label: 'Data',
                    rows: [
                      _Row(
                        icon: Icons.delete_outline_rounded,
                        title: 'Reset high scores',
                        subtitle: 'Clears every best on this device',
                        color: LS.coral,
                        onTap: () => _confirmReset(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),
                  Column(
                    children: [
                      const LogoMark(size: 28),
                      const SizedBox(height: 10),
                      MonoLabel(
                        'LogicSprint ${context.read<AppInfo>().version}',
                        color: LS.dim,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.rows});

  final String label;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MonoLabel(label),
        const SizedBox(height: 8),
        ChamferBox(
          cut: Cut.lg,
          child: Column(
            children: [
              for (final (i, row) in rows.indexed) ...[
                if (i > 0) const Divider(height: 1, indent: 50, color: LS.line),
                row,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.color = LS.text,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 22, color: color == LS.text ? LS.muted : color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: LSText.body(
                        16,
                        weight: FontWeight.w500,
                        color: color,
                        height: 1.3,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: LSText.body(13, color: LS.muted, height: 1.3),
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
