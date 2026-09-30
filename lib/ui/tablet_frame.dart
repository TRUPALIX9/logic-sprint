import 'package:flutter/material.dart';

/// On tablets (shortest side 600+), scales the whole app up so its
/// narrowest side is [designWidth] logical pixels, filling the screen edge
/// to edge: every screen is designed for a phone, so at the tablet's own
/// size cards would be huge and text tiny. Phones get [child] untouched.
/// [TabletFrame.isTablet] tells widgets below (the ad banners) which case
/// they're in.
class TabletFrame extends StatelessWidget {
  const TabletFrame({super.key, required this.child});

  final Widget child;

  static const designWidth = 720.0;

  /// True inside a scaled tablet frame.
  static bool isTablet(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_TabletScope>() != null;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    if (size.shortestSide < 600) {
      return child;
    }
    final scale = size.shortestSide / designWidth;
    final logical = size / scale;
    return FittedBox(
      fit: BoxFit.fill,
      child: SizedBox.fromSize(
        size: logical,
        child: MediaQuery(
          data: media.copyWith(
            size: logical,
            padding: media.padding / scale,
            viewPadding: media.viewPadding / scale,
            viewInsets: media.viewInsets / scale,
            systemGestureInsets: media.systemGestureInsets / scale,
          ),
          child: _TabletScope(child: child),
        ),
      ),
    );
  }
}

class _TabletScope extends InheritedWidget {
  const _TabletScope({required super.child});

  @override
  bool updateShouldNotify(_TabletScope oldWidget) => false;
}
