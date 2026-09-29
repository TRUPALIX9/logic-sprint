import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../services/ads.dart';
import '../services/network.dart';
import '../state/app_state.dart';
import '../ui/chamfer.dart';
import '../ui/kit.dart';

Future<void> showHeartsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const HeartsSheet(),
    );

/// Your hearts, and a rewarded ad that earns one (every few minutes, up to
/// the cap). A free heart also arrives each day.
class HeartsSheet extends StatefulWidget {
  const HeartsSheet({super.key});

  @override
  State<HeartsSheet> createState() => _HeartsSheetState();
}

class _HeartsSheetState extends State<HeartsSheet> {
  // Ticks the "next heart in m:ss" countdown.
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

  void _watch() {
    final app = context.read<AppState>();
    setState(() => _watching = true);
    context.read<Ads>().showRewarded(
      onReward: () async {
        await app.earnHeart();
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

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final ads = context.read<Ads>();
    final network = context.read<Network>();
    final hearts = app.hearts;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: chamfer(Cut.lg, border: LS.line),
        color: LS.surface,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4, color: LS.line)),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(child: DisplayText('Hearts', size: 28)),
                  LSIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Close',
                    color: LS.muted,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Spend a heart to keep a run going after a mistake, in any '
                'game — up to ${AppConfig.maxRevivesPerRun} times per run.',
                style: LSText.body(15, color: LS.muted),
              ),
              const SizedBox(height: 20),
              Semantics(
                label: '$hearts of ${AppState.maxHearts} hearts',
                excludeSemantics: true,
                child: Row(
                  children: [
                    for (var i = 0; i < AppState.maxHearts; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Icon(
                        i < hearts
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 34,
                        color: i < hearts ? LS.coral : LS.dim,
                      ),
                    ],
                    const Spacer(),
                    MonoLabel(
                      '$hearts / ${AppState.maxHearts}',
                      size: 14,
                      weight: FontWeight.w700,
                      color: LS.text,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              // Offline play is ad-free: no ad buttons at all.
              ValueListenableBuilder<bool>(
                valueListenable: network.online,
                builder: (context, online, _) => online
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ValueListenableBuilder<bool>(
                            valueListenable: ads.rewardedReady,
                            builder: (context, ready, _) {
                              final (label, enabled) = switch (()) {
                                _ when app.heartsFull => ('Hearts full', false),
                                _ when _watching => ('Loading ad…', false),
                                _ when !app.heartAdUnlocked => (
                                  'Finish a run to unlock a heart',
                                  false,
                                ),
                                _ when !ready => (
                                  'No ad available right now',
                                  false,
                                ),
                                _ => ('Watch ad · +1 heart', true),
                              };
                              return PrimaryButton(
                                label: label,
                                icon: enabled
                                    ? Icons.play_circle_outline_rounded
                                    : null,
                                accent: LS.coral,
                                onPressed: enabled ? _watch : null,
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          const Center(
                            child: MonoLabel(
                              'One heart ad after every run',
                              size: 10,
                              color: LS.dim,
                            ),
                          ),
                        ],
                      )
                    : const _OfflineNote(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown instead of the ad buttons while offline.
class _OfflineNote extends StatelessWidget {
  const _OfflineNote();

  @override
  Widget build(BuildContext context) {
    return ChamferBox(
      cut: Cut.sm,
      color: LS.surface2,
      borderColor: null,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: LS.muted, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You’re offline: play ad-free. Hearts and ads come back when '
              'you’re online.',
              style: LSText.body(14, color: LS.muted, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
