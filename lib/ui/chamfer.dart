import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Corner cuts. The app never uses rounded corners.
abstract final class Cut {
  static const sm = 6.0;
  static const md = 10.0;
  static const lg = 16.0;
}

/// Top-left and bottom-right corners cut at [cut] px.
OutlinedBorder chamfer(double cut, {Color? border}) => BeveledRectangleBorder(
  borderRadius: BorderRadius.only(
    topLeft: Radius.circular(cut),
    bottomRight: Radius.circular(cut),
  ),
  side: border == null ? BorderSide.none : BorderSide(color: border),
);

/// Small chamfer for badges and icon plates.
final OutlinedBorder chamferShape = chamfer(Cut.sm);

/// A chamfered surface; tappable when [onTap] is set.
class ChamferBox extends StatelessWidget {
  const ChamferBox({
    super.key,
    required this.child,
    this.cut = Cut.md,
    this.color = LS.surface,
    this.borderColor = LS.line,
    this.gradient,
    this.padding = EdgeInsets.zero,
    this.width,
    this.height,
    this.onTap,
  });

  final Widget child;
  final double cut;
  final Color color;
  final Color? borderColor;
  final Gradient? gradient;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = chamfer(cut, border: borderColor);
    final content = Padding(padding: padding, child: child);
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        shape: shape,
        color: gradient == null ? color : Colors.transparent,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: gradient == null
              ? null
              : ShapeDecoration(shape: chamfer(cut), gradient: gradient),
          child: onTap == null
              ? content
              : InkWell(onTap: onTap, customBorder: shape, child: content),
        ),
      ),
    );
  }
}
