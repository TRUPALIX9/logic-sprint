import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/game.dart';
import 'chamfer.dart';

/// Uppercase condensed title text.
class DisplayText extends StatelessWidget {
  const DisplayText(
    this.text, {
    super.key,
    this.size = 22,
    this.color = LS.text,
    this.maxLines,
    this.textAlign,
  });

  final String text;
  final double size;
  final Color color;
  final int? maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: LSText.display(size, color: color),
    maxLines: maxLines,
    overflow: maxLines == null ? null : TextOverflow.ellipsis,
    textAlign: textAlign,
  );
}

/// Small uppercase monospace label.
class MonoLabel extends StatelessWidget {
  const MonoLabel(
    this.text, {
    super.key,
    this.size = 11,
    this.color = LS.muted,
    this.weight = FontWeight.w500,
  });

  final String text;
  final double size;
  final Color color;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: LSText.mono(size, color: color, weight: weight),
  );
}

/// Main call to action. Brand gradient unless a game [accent] is given.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.accent,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: ChamferBox(
        height: 56,
        borderColor: null,
        color: accent ?? LS.teal,
        gradient: accent == null ? LS.brandGradient : null,
        onTap: onPressed,
        child: _ButtonLabel(
          children: [
            DisplayText(label, size: 19, color: LS.bg),
            if (icon != null) ...[
              const SizedBox(width: 10),
              Icon(icon, size: 20, color: LS.bg),
            ],
          ],
        ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ChamferBox(
      height: 56,
      onTap: onPressed,
      child: _ButtonLabel(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: LS.text),
            const SizedBox(width: 10),
          ],
          DisplayText(label, size: 19),
        ],
      ),
    );
  }
}

/// Centered button content that scales down instead of overflowing
/// (narrow buttons, large accessibility text).
class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

/// 44px-tall filter chip.
class LSChip extends StatelessWidget {
  const LSChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChamferBox(
      cut: Cut.sm,
      height: 44,
      borderColor: null,
      color: selected ? LS.teal : LS.surface2,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: onTap,
      child: Center(
        widthFactor: 1,
        child: MonoLabel(
          label,
          size: 12,
          weight: FontWeight.w700,
          color: selected ? LS.bg : LS.muted,
        ),
      ),
    );
  }
}

/// Chamfered on/off switch.
class LSToggle extends StatelessWidget {
  const LSToggle({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      button: true,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: SizedBox(
          width: 52,
          height: 30,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: chamfer(Cut.sm),
              color: value ? LS.teal : LS.surface2,
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 150),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: chamfer(Cut.sm),
                    color: value ? LS.bg : LS.muted,
                  ),
                  child: const SizedBox(width: 22, height: 22),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Game icon on a tinted chamfered square.
class GameTile extends StatelessWidget {
  const GameTile({super.key, required this.game, this.size = 48});

  final GameId game;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ChamferBox(
      cut: Cut.sm,
      width: size,
      height: size,
      borderColor: null,
      color: game.accent.withValues(alpha: 0.12),
      child: Icon(game.icon, size: size * 0.5, color: game.accent),
    );
  }
}

/// Compact teal action inside a card ("Set name", "Edit", "Ranks").
class CardAction extends StatelessWidget {
  const CardAction({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChamferBox(
      cut: Cut.sm,
      height: 44,
      borderColor: null,
      color: LS.surface2,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      onTap: onTap,
      child: Center(
        widthFactor: 1,
        child: MonoLabel(
          label,
          size: 12,
          weight: FontWeight.w700,
          color: LS.teal,
        ),
      ),
    );
  }
}

/// 44×44 icon button.
class LSIconButton extends StatelessWidget {
  const LSIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.color = LS.text,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, color: color),
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(shape: chamfer(Cut.sm)),
    );
  }
}

/// Screen title with an optional back button and mono subtitle.
class LSTopBar extends StatelessWidget {
  const LSTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return SizedBox(
      height: 64,
      child: Padding(
        padding: EdgeInsets.only(left: canPop ? 8 : 20, right: 12),
        child: Row(
          children: [
            if (canPop) ...[
              LSIconButton(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DisplayText(title, size: 22, maxLines: 1),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    MonoLabel(subtitle!),
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
