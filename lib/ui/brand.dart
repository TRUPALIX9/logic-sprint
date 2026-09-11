import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Double-chevron mark: speed lines feeding a blue then a teal chevron.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const LogoPainter());
}

/// Paints the mark on a 48-unit grid scaled to the canvas.
class LogoPainter extends CustomPainter {
  const LogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 48, size.height / 48);
    final speed = Paint()
      ..color = LS.dim
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(const Offset(6, 17), const Offset(13, 17), speed)
      ..drawLine(const Offset(3, 24), const Offset(12, 24), speed)
      ..drawLine(const Offset(6, 31), const Offset(13, 31), speed);

    Paint chevron(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Path arrow(double x) => Path()
      ..moveTo(x, 11)
      ..lineTo(x + 13, 24)
      ..lineTo(x, 37);
    canvas
      ..drawPath(arrow(17), chevron(LS.blue))
      ..drawPath(arrow(28), chevron(LS.teal));
  }

  @override
  bool shouldRepaint(covariant LogoPainter oldDelegate) => false;
}

/// "LOGICSPRINT" with SPRINT in teal.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    final style = LSText.display(size).copyWith(fontStyle: FontStyle.italic);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          const TextSpan(text: 'LOGIC'),
          TextSpan(
            text: 'SPRINT',
            style: style.copyWith(color: LS.teal),
          ),
        ],
      ),
      maxLines: 1,
    );
  }
}

/// Faint circuit traces behind full-screen layouts.
class CircuitBackground extends StatelessWidget {
  const CircuitBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: const _CircuitPainter(), child: child);
}

class _CircuitPainter extends CustomPainter {
  const _CircuitPainter();

  // Designed on a 390×844 frame and scaled to fit.
  static const _traces = [
    [Offset(0, 128), Offset(56, 128), Offset(76, 148), Offset(166, 148)],
    [Offset(390, 212), Offset(342, 212), Offset(318, 236), Offset(318, 332)],
    [Offset(0, 532), Offset(40, 532), Offset(70, 502), Offset(134, 502)],
    [Offset(390, 646), Offset(320, 646), Offset(300, 666), Offset(300, 786)],
    [Offset(58, 844), Offset(58, 786), Offset(78, 766), Offset(132, 766)],
    [Offset(300, 0), Offset(300, 48), Offset(280, 68), Offset(216, 68)],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 390, size.height / 844);
    final stroke = Paint()
      ..color = LS.trace
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final dot = Paint()..color = LS.trace;
    for (final trace in _traces) {
      canvas
        ..drawPath(Path()..addPolygon(trace, false), stroke)
        ..drawCircle(trace.last, 3.5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _CircuitPainter oldDelegate) => false;
}
