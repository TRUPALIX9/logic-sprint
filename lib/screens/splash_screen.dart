import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../ui/brand.dart';
import '../ui/kit.dart';
import 'shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => const Shell(),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CircuitBackground(
        child: SizedBox.expand(
          child: Column(
            children: [
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LogoMark(size: 104),
                    SizedBox(height: 22),
                    Wordmark(size: 46),
                    SizedBox(height: 8),
                    MonoLabel('Brain games', size: 13, color: LS.aqua),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 64),
                child: Column(
                  children: [
                    const SizedBox(
                      width: 160,
                      height: 3,
                      child: LinearProgressIndicator(
                        color: LS.teal,
                        backgroundColor: LS.surface2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    MonoLabel('Loading', size: 10, color: LS.dim),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
