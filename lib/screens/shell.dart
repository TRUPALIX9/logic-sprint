import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../core/theme.dart';
import '../ui/ad_banner.dart';
import '../ui/brand.dart';
import '../ui/chamfer.dart';
import '../ui/kit.dart';
import 'home_tab.dart';
import 'profile_tab.dart';
import 'ranks_tab.dart';

/// Bottom-nav shell: Ranks · Play · Profile, with Play in the middle.
class Shell extends StatelessWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context) {
    final tabs = context.watch<NavTabs>();
    return PopScope(
      // Back from Ranks/Profile returns to Play before leaving the app.
      canPop: tabs.value == NavTabs.play,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          tabs.value = NavTabs.play;
        }
      },
      child: Scaffold(
        body: CircuitBackground(
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(child: _TabStack(index: tabs.value)),
                // One banner for all three tabs: loads once and stays while
                // switching. The bottom gap keeps it off the nav buttons.
                const AdBanner(padding: EdgeInsets.fromLTRB(0, 8, 0, 12)),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _BottomNav(
          index: tabs.value,
          onSelect: (i) => tabs.value = i,
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  // Order matches the NavTabs indices.
  static const _items = [
    (Icons.emoji_events_outlined, 'Ranks'),
    (Icons.play_arrow_rounded, 'Play'),
    (Icons.person_outline_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: LS.surface,
        border: Border(top: BorderSide(color: LS.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Row(
            children: [
              for (final (i, (icon, label)) in _items.indexed)
                Expanded(
                  child: _NavItem(
                    icon: icon,
                    label: label,
                    selected: i == index,
                    primary: i == NavTabs.play,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.primary,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;

  /// The centre Play item gets a chamfered badge behind its icon.
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? LS.teal : LS.dim;
    final iconWidget = primary
        ? DecoratedBox(
            decoration: ShapeDecoration(
              shape: chamferShape,
              gradient: selected ? LS.brandGradient : null,
              color: selected ? null : LS.surface2,
            ),
            child: SizedBox(
              width: 48,
              height: 32,
              child: Icon(icon, size: 24, color: selected ? LS.bg : LS.muted),
            ),
          )
        : Icon(icon, size: 22, color: color);
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (selected && !primary)
              Positioned(
                top: 0,
                child: Container(
                  width: 32,
                  height: 2,
                  decoration: BoxDecoration(
                    color: LS.teal,
                    boxShadow: [
                      BoxShadow(
                        color: LS.teal.withValues(alpha: 0.6),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  iconWidget,
                  const SizedBox(height: 6),
                  MonoLabel(label, color: color, weight: FontWeight.w700),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The three tabs, kept alive (an [IndexedStack]) so each keeps its scroll
/// and state. Switching fades the new tab in with a short slide from the side
/// it sits on; instant under reduce motion.
class _TabStack extends StatefulWidget {
  const _TabStack({required this.index});

  final int index;

  @override
  State<_TabStack> createState() => _TabStackState();
}

class _TabStackState extends State<_TabStack>
    with SingleTickerProviderStateMixin {
  late final _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );
  double _from = 0;

  @override
  void didUpdateWidget(covariant _TabStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _from = widget.index > oldWidget.index ? 0.04 : -0.04;
      if (MediaQuery.disableAnimationsOf(context)) {
        _in.value = 1;
      } else {
        _in.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _in, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curve,
      child: AnimatedBuilder(
        animation: curve,
        builder: (context, child) => FractionalTranslation(
          translation: Offset(_from * (1 - curve.value), 0),
          child: child,
        ),
        child: IndexedStack(
          index: widget.index,
          children: const [RanksTab(), HomeTab(), ProfileTab()],
        ),
      ),
    );
  }
}
