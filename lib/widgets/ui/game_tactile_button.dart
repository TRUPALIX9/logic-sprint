import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/app_state.dart';

class GameTactileButton extends StatefulWidget {
  const GameTactileButton({
    super.key,
    required this.child,
    this.onPressed,
    required this.color,
    required this.bottomColor,
    this.borderRadius = 14.0,
    this.height = 48.0,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final Color color;
  final Color bottomColor;
  final double borderRadius;
  final double height;

  @override
  State<GameTactileButton> createState() => _GameTactileButtonState();
}

class _GameTactileButtonState extends State<GameTactileButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails _) {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = true);
    try {
      final appState = context.read<AppState>();
      if (appState.isVibrationEnabled) {
        HapticFeedback.lightImpact();
      }
    } catch (_) {
      // Fallback if AppState is not found in context (e.g. in tests)
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapUp(TapUpDetails _) {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;
    final double depth = 4.0;
    final double topPadding = _isPressed ? depth : 0.0;
    final double bottomPadding = _isPressed ? 0.0 : depth;

    final Color surfaceColor = isEnabled ? widget.color : Colors.grey.shade300;
    final Color shadowColor = isEnabled ? widget.bottomColor : Colors.grey.shade400;
    final Color contentColor = isEnabled ? Colors.white : Colors.grey.shade600;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        height: widget.height,
        padding: EdgeInsets.only(top: topPadding),
        child: Stack(
          children: [
            // Shadow / 3D base layer
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              top: depth,
              child: Container(
                decoration: BoxDecoration(
                  color: shadowColor,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                ),
              ),
            ),
            // Button face layer
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: bottomPadding,
              child: Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: DefaultTextStyle(
                    style: TextStyle(
                      color: contentColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                    child: IconTheme(
                      data: IconThemeData(
                        color: contentColor,
                        size: 20,
                      ),
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
