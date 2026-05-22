import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../../models/game_model.dart';
import '../../../services/app_state.dart';
import '../../../services/local_storage_service.dart';

class RocketAsteroid {
  RocketAsteroid({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.rotation,
  });

  double x;
  double y;
  final double radius;
  final double speed;
  double rotation;
}

class LaunchRocketScreen extends StatefulWidget {
  const LaunchRocketScreen({super.key});

  @override
  State<LaunchRocketScreen> createState() => _LaunchRocketScreenState();
}

class _LaunchRocketScreenState extends State<LaunchRocketScreen>
    with SingleTickerProviderStateMixin {
  static const _storageDifficulty = DifficultyLevel.easy;

  Ticker? _ticker;
  Duration? _lastTick;
  final Random _random = Random();

  double _rocketX = 0;
  double _rocketY = 0;
  final double _rocketWidth = 48;
  final double _rocketHeight = 56;
  final List<RocketAsteroid> _asteroids = [];
  int _score = 0;
  int _bestScore = 0;
  double _spawnTimer = 0;
  double _gameSpeed = 1;
  bool _isGameOver = false;
  bool _started = false;
  bool _loadedBest = false;
  Size _gameSize = Size.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedBest) {
      _loadedBest = true;
      _bestScore = context.read<LocalStorageService>().getHighScore(
        GameType.launchRocket,
        _storageDifficulty,
      );
    }
  }

  void _startGame() {
    if (_gameSize == Size.zero) {
      return;
    }
    _ticker?.dispose();
    _asteroids.clear();
    _score = 0;
    _spawnTimer = 0;
    _gameSpeed = 1;
    _isGameOver = false;
    _rocketX = (_gameSize.width - _rocketWidth) / 2;
    _rocketY = _gameSize.height - _rocketHeight - 24;
    _lastTick = null;
    _started = true;

    _ticker = createTicker(_onTick)..start();
    setState(() {});
  }

  void _onTick(Duration elapsed) {
    if (_isGameOver || !_started) {
      return;
    }

    final last = _lastTick;
    _lastTick = elapsed;
    if (last == null) {
      return;
    }

    final delta = (elapsed - last).inMicroseconds / 1000000.0;
    if (delta <= 0) {
      return;
    }

    _score += (delta * 10).floor();
    _gameSpeed = 1 + (_score / 200).clamp(0, 8);
    _spawnTimer += delta;

    final spawnInterval = (1.2 - _gameSpeed * 0.08).clamp(0.45, 1.2);
    if (_spawnTimer >= spawnInterval) {
      _spawnTimer = 0;
      _spawnAsteroid();
    }

    final height = _gameSize.height;
    for (final asteroid in _asteroids) {
      asteroid.y += asteroid.speed * delta * 60 * _gameSpeed;
      asteroid.rotation += delta * 2;
    }
    _asteroids.removeWhere((a) => a.y - a.radius > height + 40);

    if (_checkCollision()) {
      _endGame();
      return;
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _spawnAsteroid() {
    if (_gameSize == Size.zero) {
      return;
    }
    final radius = 14 + _random.nextDouble() * 18;
    _asteroids.add(
      RocketAsteroid(
        x: radius + _random.nextDouble() * (_gameSize.width - radius * 2),
        y: -radius,
        radius: radius,
        speed: 2.5 + _random.nextDouble() * 2 + _gameSpeed * 0.15,
        rotation: _random.nextDouble() * pi,
      ),
    );
  }

  bool _checkCollision() {
    final rocketCenter = Offset(
      _rocketX + _rocketWidth / 2,
      _rocketY + _rocketHeight / 2,
    );
    final hitboxScale = 0.75;
    final rocketR = min(_rocketWidth, _rocketHeight) / 2 * hitboxScale;

    for (final asteroid in _asteroids) {
      final dist = (Offset(asteroid.x, asteroid.y) - rocketCenter).distance;
      if (dist < rocketR + asteroid.radius * hitboxScale) {
        return true;
      }
    }
    return false;
  }

  Future<void> _endGame() async {
    _ticker?.stop();
    _isGameOver = true;

    final storage = context.read<LocalStorageService>();
    final previousBest = storage.getHighScore(
      GameType.launchRocket,
      _storageDifficulty,
    );
    if (_score > previousBest) {
      await storage.saveHighScoreIfHigher(
        GameType.launchRocket,
        _storageDifficulty,
        _score,
      );
      if (mounted) {
        await context.read<AppState>().recordHighScore(
              GameType.launchRocket,
              _storageDifficulty,
              _score,
            );
      }
      if (mounted) {
        setState(() => _bestScore = _score);
      }
    } else if (mounted) {
      setState(() => _bestScore = previousBest);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _playAgain() {
    _startGame();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050818),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Launch Rocket'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _gameSize = Size(constraints.maxWidth, constraints.maxHeight);
          if (!_started && !_isGameOver) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _startGame());
          }

          return Stack(
            children: [
              GestureDetector(
                onHorizontalDragUpdate: (details) {
                  if (_isGameOver) {
                    return;
                  }
                  setState(() {
                    _rocketX = (_rocketX + details.delta.dx).clamp(
                      0,
                      _gameSize.width - _rocketWidth,
                    );
                  });
                },
                child: CustomPaint(
                  size: _gameSize,
                  painter: _SpacePainter(
                    asteroids: _asteroids,
                    rocketX: _rocketX,
                    rocketY: _rocketY,
                    rocketWidth: _rocketWidth,
                    rocketHeight: _rocketHeight,
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Score: $_score',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Best: $_bestScore',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isGameOver)
                _GameOverOverlay(
                  score: _score,
                  bestScore: _bestScore,
                  onPlayAgain: _playAgain,
                  onBack: () => Navigator.of(context).pop(),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({
    required this.score,
    required this.bestScore,
    required this.onPlayAgain,
    required this.onBack,
  });

  final int score;
  final int bestScore;
  final VoidCallback onPlayAgain;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      alignment: Alignment.center,
      child: Card(
        margin: const EdgeInsets.all(28),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Game Over',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text('Score: $score'),
              Text('Best: $bestScore'),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onPlayAgain,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Play Again'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.home_rounded),
                label: const Text('Back to Games'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpacePainter extends CustomPainter {
  _SpacePainter({
    required this.asteroids,
    required this.rocketX,
    required this.rocketY,
    required this.rocketWidth,
    required this.rocketHeight,
  });

  final List<RocketAsteroid> asteroids;
  final double rocketX;
  final double rocketY;
  final double rocketWidth;
  final double rocketHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0A0E27), Color(0xFF1B2A4A), Color(0xFF0D1828)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Offset.zero & size, bg);

    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.5);
    for (var i = 0; i < 40; i++) {
      final x = (i * 47.0) % size.width;
      final y = (i * 83.0) % size.height;
      canvas.drawCircle(Offset(x, y), 1.2, starPaint);
    }

    for (final asteroid in asteroids) {
      final paint = Paint()..color = const Color(0xFF8B7355);
      canvas.save();
      canvas.translate(asteroid.x, asteroid.y);
      canvas.rotate(asteroid.rotation);
      canvas.drawCircle(Offset.zero, asteroid.radius, paint);
      canvas.drawCircle(
        Offset(-asteroid.radius * 0.3, -asteroid.radius * 0.2),
        asteroid.radius * 0.35,
        Paint()..color = const Color(0xFF5C4A3A),
      );
      canvas.restore();
    }

    final rocketRect = Rect.fromLTWH(
      rocketX,
      rocketY,
      rocketWidth,
      rocketHeight,
    );
    final rocketPaint = Paint()..color = const Color(0xFFFF8A00);
    final path = Path()
      ..moveTo(rocketRect.center.dx, rocketRect.top)
      ..lineTo(rocketRect.right, rocketRect.bottom)
      ..lineTo(rocketRect.left, rocketRect.bottom)
      ..close();
    canvas.drawPath(path, rocketPaint);
    canvas.drawRect(
      Rect.fromLTWH(rocketRect.center.dx - 6, rocketRect.top + 12, 12, 18),
      Paint()..color = const Color(0xFF45D7FF),
    );
  }

  @override
  bool shouldRepaint(covariant _SpacePainter oldDelegate) => true;
}
