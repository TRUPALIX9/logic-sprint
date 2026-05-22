import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/life_game_constants.dart';
import '../../../models/game_model.dart';
import '../../../models/second_life_config.dart';
import '../../../models/second_life_session.dart';
import '../../../services/app_state.dart';
import '../../../services/local_storage_service.dart';
import '../../../widgets/app_gradient_background.dart';
import '../../../widgets/game_second_life_layer.dart';
import '../../../widgets/game_screen_shell.dart';
import 'launch_rocket_sprite_cache.dart';

class RocketAsteroid {
  RocketAsteroid({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.rotation,
    required this.spriteIndex,
  });

  double x;
  double y;
  final double radius;
  final double speed;
  double rotation;
  final int spriteIndex;
}

class LaunchRocketScreen extends StatefulWidget {
  const LaunchRocketScreen({super.key});

  @override
  State<LaunchRocketScreen> createState() => _LaunchRocketScreenState();
}

class _LaunchRocketScreenState extends State<LaunchRocketScreen>
    with SingleTickerProviderStateMixin {
  static const _invincibilityAfterHitSeconds = 1.2;
  static const _invincibilityAfterRewardSeconds = 2.0;
  static const _nearbyAsteroidClearRadius = 150.0;

  Ticker? _ticker;
  Duration? _lastTick;
  final Random _random = Random();
  final SecondLifeSession _secondLife = SecondLifeSession();
  final LaunchRocketSpriteCache _sprites = LaunchRocketSpriteCache();

  double _rocketX = 0;
  double _rocketY = 0;
  final double _rocketWidth = 52;
  final double _rocketHeight = 72;
  final List<RocketAsteroid> _asteroids = [];
  int _score = 0;
  int _bestScore = 0;
  int _lives = LifeGameConstants.startingLives;
  double _spawnTimer = 0;
  double _gameSpeed = 1;
  double _invincibleSecondsRemaining = 0;
  bool _started = false;
  bool _loadedBest = false;
  bool _assetsLoaded = false;
  String? _assetLoadError;
  Size _gameSize = Size.zero;

  bool get _isGameplayPaused =>
      _secondLife.isPausedForRewardAd ||
      _secondLife.awaitingSecondLifeDecision ||
      _secondLife.isGameOver;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSprites());
  }

  Future<void> _loadSprites() async {
    try {
      await _sprites.load();
      if (mounted) {
        setState(() {
          _assetsLoaded = true;
          _assetLoadError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _assetsLoaded = false;
          _assetLoadError = 'Could not load game graphics.';
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedBest) {
      _loadedBest = true;
      _bestScore = context.read<LocalStorageService>().getHighScore(
        GameType.launchRocket,
        LifeGameConstants.storageDifficulty,
      );
    }
  }

  void _startGame() {
    if (_gameSize == Size.zero || !_sprites.isReady) {
      return;
    }
    _ticker?.dispose();
    _asteroids.clear();
    _score = 0;
    _lives = LifeGameConstants.startingLives;
    _spawnTimer = 0;
    _gameSpeed = 1;
    _invincibleSecondsRemaining = 0;
    _secondLife.reset();
    _rocketX = (_gameSize.width - _rocketWidth) / 2;
    _rocketY = _gameSize.height - _rocketHeight - 24;
    _lastTick = null;
    _started = true;

    _ticker = createTicker(_onTick)..start();
    setState(() {});
  }

  int get _level => 1 + (_score / 150).floor();

  void _onTick(Duration elapsed) {
    if (!_started || _isGameplayPaused) {
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

    if (_invincibleSecondsRemaining > 0) {
      _invincibleSecondsRemaining = (_invincibleSecondsRemaining - delta).clamp(
        0.0,
        10.0,
      );
    }

    _score += (delta * 10).floor();
    _gameSpeed = 1 + (_score / 200).clamp(0, 10);
    _spawnTimer += delta;

    final spawnInterval = (1.2 - _gameSpeed * 0.07).clamp(0.35, 1.2);
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
      _handleCollision();
      return;
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _spawnAsteroid() {
    if (_gameSize == Size.zero || _sprites.asteroids.isEmpty) {
      return;
    }
    final radius = 14 + _random.nextDouble() * (16 + _level * 0.5);
    _asteroids.add(
      RocketAsteroid(
        x: radius + _random.nextDouble() * (_gameSize.width - radius * 2),
        y: -radius,
        radius: radius,
        speed: 2.5 + _random.nextDouble() * 2 + _gameSpeed * 0.15,
        rotation: _random.nextDouble() * pi,
        spriteIndex: _random.nextInt(_sprites.asteroids.length),
      ),
    );
  }

  bool _checkCollision() {
    if (_invincibleSecondsRemaining > 0) {
      return false;
    }

    final rocketCenter = Offset(
      _rocketX + _rocketWidth / 2,
      _rocketY + _rocketHeight / 2,
    );
    final hitboxScale = 0.72;
    final rocketR = min(_rocketWidth, _rocketHeight) / 2 * hitboxScale;

    for (final asteroid in _asteroids) {
      final dist = (Offset(asteroid.x, asteroid.y) - rocketCenter).distance;
      if (dist < rocketR + asteroid.radius * hitboxScale) {
        return true;
      }
    }
    return false;
  }

  void _handleCollision() {
    _lives -= 1;
    _invincibleSecondsRemaining = _invincibilityAfterHitSeconds;
    _clearNearbyAsteroids();

    if (_lives <= 0) {
      _ticker?.stop();
      if (!_secondLife.secondLifeUsed) {
        _secondLife.pauseForSecondLifeOffer();
        setState(() {});
        return;
      }
      unawaited(_endGameFinal());
      return;
    }

    setState(() {});
  }

  void _clearNearbyAsteroids() {
    final rocketCenter = Offset(
      _rocketX + _rocketWidth / 2,
      _rocketY + _rocketHeight / 2,
    );
    _asteroids.removeWhere((asteroid) {
      final dist = (Offset(asteroid.x, asteroid.y) - rocketCenter).distance;
      return dist < _nearbyAsteroidClearRadius;
    });
  }

  Future<void> _resumeFromSecondLifeReward() async {
    _clearNearbyAsteroids();
    _lives = 1;
    _invincibleSecondsRemaining = _invincibilityAfterRewardSeconds;
    _lastTick = null;
    _ticker?.start();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _endGameFinal() async {
    _ticker?.stop();
    _secondLife.endGameFinal();

    final storage = context.read<LocalStorageService>();
    final previousBest = storage.getHighScore(
      GameType.launchRocket,
      LifeGameConstants.storageDifficulty,
    );
    if (_score > previousBest) {
      await storage.saveHighScoreIfHigher(
        GameType.launchRocket,
        LifeGameConstants.storageDifficulty,
        _score,
      );
      if (mounted) {
        await context.read<AppState>().recordHighScore(
          GameType.launchRocket,
          LifeGameConstants.storageDifficulty,
          _score,
          highestLevel: _level,
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
    _sprites.dispose();
    super.dispose();
  }

  Widget _buildGameArea() {
    if (_assetLoadError != null) {
      return Center(
        child: Text(
          _assetLoadError!,
          style: const TextStyle(color: AppGradientBackground.textSecondary),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (!_assetsLoaded || !_sprites.isReady) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppGradientBackground.cyanAccent,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        _gameSize = Size(constraints.maxWidth, constraints.maxHeight);
        if (!_started && !_secondLife.isGameOver) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _startGame());
        }

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            if (_isGameplayPaused) {
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
              sprites: _sprites,
              asteroids: _asteroids,
              rocketX: _rocketX,
              rocketY: _rocketY,
              rocketWidth: _rocketWidth,
              rocketHeight: _rocketHeight,
              invincible: _invincibleSecondsRemaining > 0,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = SecondLifeConfig.forGame(GameType.launchRocket);

    return GameSecondLifeLayer(
      config: config,
      session: _secondLife,
      score: _score,
      bestScore: _bestScore,
      stayOnScreenAfterFinal: true,
      onEndGameFinal: _endGameFinal,
      onPlayAgain: _playAgain,
      onResumeFromSecondLife: _resumeFromSecondLifeReward,
      child: GameScreenShell(
        title: 'Launch Rocket',
        score: _score,
        lives: _lives,
        level: _level,
        child: _buildGameArea(),
      ),
    );
  }
}

class _SpacePainter extends CustomPainter {
  _SpacePainter({
    required this.sprites,
    required this.asteroids,
    required this.rocketX,
    required this.rocketY,
    required this.rocketWidth,
    required this.rocketHeight,
    required this.invincible,
  });

  final LaunchRocketSpriteCache sprites;
  final List<RocketAsteroid> asteroids;
  final double rocketX;
  final double rocketY;
  final double rocketWidth;
  final double rocketHeight;
  final bool invincible;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0A0E27), Color(0xFF1B2A4A), Color(0xFF0D1828)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Offset.zero & size, bg);

    final starPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.5);
    for (var i = 0; i < 40; i++) {
      final x = (i * 47.0) % size.width;
      final y = (i * 83.0) % size.height;
      canvas.drawCircle(Offset(x, y), 1.2, starPaint);
    }

    final asteroidPaint = Paint()..filterQuality = FilterQuality.medium;

    for (final asteroid in asteroids) {
      final image = sprites.asteroidSprite(asteroid.spriteIndex);
      final diameter = asteroid.radius * 2.2;
      canvas.save();
      canvas.translate(asteroid.x, asteroid.y);
      canvas.rotate(asteroid.rotation);
      _drawImageCentered(
        canvas,
        image,
        Offset.zero,
        diameter,
        diameter,
        asteroidPaint,
      );
      canvas.restore();
    }

    final rocket = sprites.rocket;
    if (rocket != null) {
      final rocketPaint = Paint()
        ..filterQuality = FilterQuality.medium
        ..color = invincible
            ? const Color(0xFFFFE082)
            : const Color(0xFFFFFFFF);
      _drawImageRect(
        canvas,
        rocket,
        Rect.fromLTWH(rocketX, rocketY, rocketWidth, rocketHeight),
        rocketPaint,
      );
    }
  }

  void _drawImageCentered(
    Canvas canvas,
    ui.Image image,
    Offset center,
    double width,
    double height,
    Paint paint,
  ) {
    final dst = Rect.fromCenter(center: center, width: width, height: height);
    _drawImageRect(canvas, image, dst, paint);
  }

  void _drawImageRect(Canvas canvas, ui.Image image, Rect dst, Paint paint) {
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    canvas.drawImageRect(image, src, dst, paint);
  }

  @override
  bool shouldRepaint(covariant _SpacePainter oldDelegate) => true;
}
