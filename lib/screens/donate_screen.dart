import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../services/ads.dart';
import '../services/network.dart';
import '../state/app_state.dart';
import '../ui/chamfer.dart';
import '../ui/kit.dart';

/// "Donate a view": watching a rewarded ad supports the app, and earns
/// [AppState.donateHearts] hearts (at most every
/// [AppState.donateRewardCooldown]). Links to the website.
class DonateScreen extends StatefulWidget {
  const DonateScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const DonateScreen());

  @override
  State<DonateScreen> createState() => _DonateScreenState();
}

class _DonateScreenState extends State<DonateScreen> {
  // Ticks the thank-you countdown.
  late final Timer _tick = Timer.periodic(
    const Duration(seconds: 1),
    (_) => setState(() {}),
  );
  bool _watching = false;

  @override
  void initState() {
    super.initState();
    _tick;
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  void _donate() {
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _watching = true);
    context.read<Ads>().showRewarded(
      onReward: () async {
        final earned = await app.recordDonation();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              earned > 0
                  ? 'Thank you! +$earned hearts'
                  : 'Thank you for supporting LogicSprint!',
            ),
          ),
        );
        if (mounted) {
          setState(() => _watching = false);
        }
      },
      onDone: () {
        if (mounted) {
          setState(() => _watching = false);
        }
      },
    );
  }

  Future<void> _openWebsite() async {
    final ok = await launchUrl(
      Uri.parse(AppConfig.websiteUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t open the website')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final ads = context.read<Ads>();
    final network = context.read<Network>();
    final wait = app.donateRewardWait();
    final host = Uri.parse(AppConfig.websiteUrl).host;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const LSTopBar(title: 'Support', subtitle: 'Donate a view'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  ChamferBox(
                    cut: Cut.lg,
                    borderColor: LS.coral.withValues(alpha: 0.45),
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.favorite_rounded,
                          size: 56,
                          color: LS.coral,
                        ),
                        const SizedBox(height: 14),
                        const DisplayText(
                          'Donate a view',
                          size: 30,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'LogicSprint is free and made by one developer. '
                          'Watching one short ad is the least I can ask — it '
                          'keeps every game free. As a thank-you, you get '
                          '${AppState.donateHearts} hearts.',
                          textAlign: TextAlign.center,
                          style: LSText.body(15, color: LS.muted),
                        ),
                        const SizedBox(height: 22),
                        ListenableBuilder(
                          listenable: Listenable.merge([
                            ads.rewardedReady,
                            network.online,
                          ]),
                          builder: (context, _) {
                            final ready = ads.rewardedReady.value;
                            final (label, enabled) = switch (()) {
                              // Offline play is ad-free.
                              _ when !network.online.value => (
                                'Offline · connect to donate',
                                false,
                              ),
                              _ when _watching => ('Loading ad…', false),
                              _ when !ready => (
                                'No ad available right now',
                                false,
                              ),
                              _ when wait > Duration.zero => (
                                'Watch ad to support',
                                true,
                              ),
                              _ => (
                                'Watch ad · +${AppState.donateHearts} hearts',
                                true,
                              ),
                            };
                            return PrimaryButton(
                              label: label,
                              icon: enabled
                                  ? Icons.play_circle_outline_rounded
                                  : null,
                              accent: LS.coral,
                              onPressed: enabled ? _donate : null,
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        MonoLabel(
                          wait > Duration.zero
                              ? 'Next heart thank-you in ${formatDuration(wait)}'
                              : app.donations == 0
                              ? 'No purchase, no sign-up'
                              : 'You’ve donated ${app.donations} '
                                    '${app.donations == 1 ? 'view' : 'views'} · thank you',
                          size: 10,
                          color: LS.dim,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SecondaryButton(
                    label: host,
                    icon: Icons.open_in_new_rounded,
                    onPressed: _openWebsite,
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: MonoLabel(
                      'Feedback: ${AppConfig.supportEmail}',
                      size: 10,
                      color: LS.dim,
                    ),
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
