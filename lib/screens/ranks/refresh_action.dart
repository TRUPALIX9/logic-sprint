import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../ui/chamfer.dart';
import '../../ui/kit.dart';

/// "Refresh ▶" in the Ranks header. The play icon means a rewarded ad; with
/// no ad ready it shows a plain refresh icon (a free refresh). While the
/// cooldown runs it reads "Refresh in 12s" and ticks once a second (only
/// this widget rebuilds).
class RefreshAction extends StatefulWidget {
  const RefreshAction({
    super.key,
    required this.wait,
    required this.adReady,
    required this.busy,
    required this.onPressed,
  });

  /// Remaining cooldown (zero when a refresh is allowed).
  final Duration Function() wait;
  final ValueListenable<bool> adReady;
  final bool busy;
  final VoidCallback onPressed;

  @override
  State<RefreshAction> createState() => _RefreshActionState();
}

class _RefreshActionState extends State<RefreshAction> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(RefreshAction old) {
    super.didUpdateWidget(old);
    _syncTicker();
  }

  void _syncTicker() {
    if (widget.wait() > Duration.zero) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (widget.wait() <= Duration.zero) {
          _ticker?.cancel();
          _ticker = null;
        }
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = (widget.wait().inMilliseconds / 1000).ceil();
    final cooling = seconds > 0;
    final enabled = !cooling && !widget.busy;
    return ValueListenableBuilder<bool>(
      valueListenable: widget.adReady,
      builder: (context, ad, _) {
        final label = cooling
            ? 'Refresh in ${seconds < 60 ? '${seconds}s' : formatDuration(Duration(seconds: seconds))}'
            : 'Refresh';
        final icon = cooling
            ? Icons.timer_outlined
            : (ad ? Icons.play_circle_outline_rounded : Icons.refresh_rounded);
        final color = enabled ? LS.teal : LS.dim;
        return Semantics(
          button: true,
          enabled: enabled,
          label: cooling
              ? label
              : (ad ? 'Refresh now, watch an ad' : 'Refresh now'),
          excludeSemantics: true,
          child: ChamferBox(
            cut: Cut.sm,
            height: 44,
            borderColor: null,
            color: LS.surface2,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onTap: enabled ? widget.onPressed : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MonoLabel(
                  label,
                  size: 11,
                  weight: FontWeight.w700,
                  color: color,
                ),
                const SizedBox(width: 6),
                Icon(icon, size: 18, color: color),
              ],
            ),
          ),
        );
      },
    );
  }
}
